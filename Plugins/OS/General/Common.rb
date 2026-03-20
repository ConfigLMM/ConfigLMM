
module ConfigLMM
    module LMM
        module OS
            module Common

            IMAGE_LOCATION = '~/.cache/configlmm/images/'

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

            def flavourInfo(distro, flavour)
                url = nil
                flavour = distro unless flavour
                flavourInfo = YAML.load_file(__dir__ + '/../Linux/Flavours.yaml')[flavour]
                if flavourInfo.nil?
                    raise Framework::PluginProcessError.new("#{id}: Unknown Linux Distro: #{flavour}!")
                end
                flavourInfo
            end

            def downloadImage(url)
                local.remoteDownload(url, IMAGE_LOCATION)
            end

            end
        end
    end
end
