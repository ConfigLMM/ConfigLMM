require 'gpgme'

require_relative 'Info'

module ConfigLMM
    module LMM
        module OS
            module Common

            IMAGE_LOCATION = '~/.cache/configlmm/images/'

            TRUSTED_KEYS = [
            ]

            def prepareConfig(target, context)
                target['SSH'] ||= {}
                target['SSH']['Config'] ||= {}
                target['Users'] ||= {}
                target['HostName'] = target['Name'] unless target['HostName']

                if target['SecretId'] && context.secrets.load(target['SecretId'], 'ROOT_PASSWORD_HASH')
                    target['Users']['root'] ||= {}
                    target['Users']['root']['PasswordHash'] = context.secrets.load(target['SecretId'], 'ROOT_PASSWORD_HASH')
                elsif target['SecretId'] && context.secrets.load(target['SecretId'], 'ROOT_PASSWORD')
                    target['Users']['root'] ||= {}
                    target['Users']['root']['Password'] = context.secrets.load(target['SecretId'], 'ROOT_PASSWORD')
                    target['Users']['root']['PasswordHash'] = self.class.linuxPasswordHash(target['Users']['root']['Password'])
                elsif target['Users'].key?('root')
                    if !target['Users']['root'].key?('Password') &&
                       !target['Users']['root'].key?('PasswordHash')
                        password = SecureRandom.urlsafe_base64(20)
                        context.secrets.store(target['SecretId'], 'ROOT_PASSWORD', password) if target['SecretId']
                        target['Users']['root']['Password'] = password
                        target['Users']['root']['PasswordHash'] = self.class.linuxPasswordHash(password)
                    elsif target['Users']['root']['Password'] == false
                        target['Users']['root'].delete('Password')
                    end
                end

                target['Users'].each do |user, info|
                    newKeys = []
                    info['AuthorizedKeys'].to_a.each do |key|
                        if key.start_with?('/') || key.start_with?('~') || key.start_with?('.') || key.end_with?('.pub')
                            newKeys << File.read(File.expand_path(key)).strip
                        else
                            newKeys << key
                        end
                    end
                    info['AuthorizedKeys'] = newKeys
                end

                newApps = []
                target['Services'] ||= []
                target['Packages'] = target['Apps'].dup
                prepareDefaultNetwork(target)
            end

            def prepareDefaultNetwork(target)
                target['DefaultNetwork'] = {}
                target['DefaultNetwork']['IP'] = 'dhcp'
                target['DefaultNetwork']['Interface'] = 'enp1s0'
                target['DefaultNetwork']['VLAN'] = nil

                if target['Network'].is_a?(Hash)
                    ipaddr = nil
                    if target['Network']['IP']
                        ipaddr = target['Network']['IP']
                    end
                    gateway = nil
                    if target['Network']['Gateway']
                        gateway = target['Network']['Gateway']
                    end
                    dns = nil
                    if target['Network']['DNS']
                        dns = target['Network']['DNS']
                    end
                    interface = nil
                    vlan = nil
                    if gateway.nil? && target['Network']['Interfaces'].is_a?(Hash)
                        cadidates = target['Network']['Interfaces'].select { |name, data| name[0] == 'e' }
                        target['DefaultNetwork']['Interface'] = cadidates.first unless cadidates.empty?
                        target['Network']['Interfaces'].each do |name, data|
                            if data.is_a?(Hash) && data['Gateway']
                                ipaddr = data['IP']
                                gateway = data['Gateway']
                                dns = data['DNS']
                                interface = name
                                if data['Ports']
                                    interface = data['Ports'].first
                                end
                                if name.split('.').length == 2
                                    interface, vlan = name.split('.')
                                    if target['Network']['Interfaces'][interface].is_a?(Hash) &&
                                       target['Network']['Interfaces']['Ports']
                                        interface = target['Network']['Interfaces']['Ports'].first
                                    end
                                end
                                break
                            end
                        end
                    end
                    if ipaddr
                        target['DefaultNetwork']['IP'] = ipaddr
                        addr = IPAddr.new(ipaddr)
                        target['DefaultNetwork']['Subnet'] = [((1 << 32) - 1) << (32 - addr.prefix)].pack('N').bytes.join('.')
                        target['DefaultNetwork']['Broadcast'] = addr.to_range.last.to_s
                    end
                    target['DefaultNetwork']['Gateway'] = gateway if gateway
                    target['DefaultNetwork']['DNS'] = dns if dns
                    target['DefaultNetwork']['Interface'] = interface if interface
                    target['DefaultNetwork']['VLAN'] = vlan if vlan
                end
            end

            def downloadImage(url, checksumUrl = nil, signatureUrl = nil, signatureKeyUrl = nil)
                image = local.remoteDownload(url, IMAGE_LOCATION)
                if checksumUrl
                    if checksumUrl.start_with?('https://')
                        checksumPath = local.remoteDownload(checksumUrl, IMAGE_LOCATION)
                        checksumContent = File.read(checksumPath)
                        checksum = checksumContent.split(' ').first
                    else
                        checksumContent = checksumUrl
                        checksumUrl = nil
                        checksumPath = nil
                        checksum = checksumContent
                    end
                    if checksum.length == 256 / 8 * 2 # 256 bits, 2 digits per byte
                        sha256 = Digest::SHA256.file(image)
                        if sha256.hexdigest != checksum.downcase
                            logger.error("Checksum doesn't match for #{File.basename(image)}!")
                            logger.error("Expected #{checksum.downcase} but")
                            logger.error("Got      #{sha256.hexdigest}")
                            raise 'Invalid checksum!'
                        end
                    else
                        raise "Unimplemented checksum format!"
                    end
                    if signatureUrl
                        signaturePath = local.remoteDownload(signatureUrl, IMAGE_LOCATION)
                        signature = File.read(signaturePath)
                        crypto = GPGME::Crypto.new
                        if signatureKeyUrl
                            signatureKeyPath = local.remoteDownload(signatureKeyUrl, IMAGE_LOCATION)
                            signatureKey = File.read(signatureKeyPath)
                            importResult = GPGME::Key.import(signatureKey)
                            if importResult.imports.empty?
                                raise "Failed to import key #{File.basename(signatureKeyPath)}"
                            end
                            if !TRUSTED_KEYS.include?(importResult.imports.first.fingerprint)
                                raise "Imported key #{File.basename(signatureKeyPath)} (#{importResult.imports.first.fingerprint}) is untrusted!"
                            end
                        end
                        result = crypto.verify(signature, :signed_text => checksumContent) do |signature|
                            if !signature.valid?
                                logger.error("Signature validation failed for #{checksumPath ? File.basename(checksumPath) : ''} with #{File.basename(signaturePath)}")
                                raise signature.to_s
                            end
                        end
                    end
                end
                image
            end

            end
        end
    end
end
