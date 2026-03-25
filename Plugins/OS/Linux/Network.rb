
require 'securerandom'

module ConfigLMM
    module LMM
        module OS
            module LinuxNetwork

                def networkManagerEnabled?(target, connection, options)
                    connection.serviceEnabled?('NetworkManager', options)
                end

                def configureNetworkManager(target, connection, options)
                    # TODO FIXME implement `nmcli`
                end

                def networkingEnabled?(target, connection, options)
                    connection.serviceEnabled?('networking', options)
                end

                def configureNetworking(target, connection, options)
                    links = self.networkLinks(connection)
                    raise 'Didn\'t find network links!' if links.empty?
                    linkType = nil
                    dnsSearch = connection.exec('cat /etc/resolv.conf | grep search', false, { **options, 'dry' => false }).strip.split(' ').last
                    if target['Network'].is_a?(String)
                        linkType = target['Network']
                        target['Network'] = {}
                    end
                    if !target['Network']['Interfaces'].to_h.empty?
                        links.each do |link|
                            target['Network']['Interfaces'][link] = 'manual' unless target['Network']['Interfaces'].key?(link)
                        end
                    end
                    if !target['Network'].key?('Interfaces') ||
                           target['Network']['Interfaces'].to_h.empty? ||
                           !target['Network']['Interfaces'].key?(links.first)
                        target['Network']['Interfaces'] ||= {}
                        if !linkType.nil?
                            target['Network']['Interfaces'][links.first] = linkType
                        elsif target['Network']['IP']
                            target['Network']['Interfaces'][links.first] = {}
                            target['Network']['Interfaces'][links.first]['IP'] = target['Network']['IP']
                            target['Network']['Interfaces'][links.first]['Gateway'] = target['Network']['Gateway'] if target['Network']['Gateway']
                            target['Network']['Interfaces'][links.first]['DNS'] = target['Network']['DNS'] if target['Network']['DNS']
                        end
                    end
                    if target['Network']['Interfaces'].key?('vmbr0')
                        if !target['Network']['Interfaces']['vmbr0'].is_a?(Hash)
                            target['Network']['Interfaces']['vmbr0'] = { }
                        end
                        if target['Network']['Interfaces']['vmbr0']['Ports'].nil?
                            target['Network']['Interfaces']['vmbr0']['Ports'] = [links.first]
                            target['Network']['Interfaces'][links.first] = 'manual'
                        end
                    end
                    interfacesFile = '/etc/network/interfaces'
                    localFile = options['output'] + '/' + SecureRandom.alphanumeric(10)
                    connection.download(interfacesFile, localFile)
                    fileLines = File.read(localFile).lines
                    if fileLines.index(IO::Local::CONFIGLMM_SECTION_BEGIN).nil?
                        lines = []
                        iface = false
                        fileLines.each do |line|
                            if line.start_with?('iface')
                                if line.strip.split(' ')[1].start_with?('enp')
                                    iface = true
                                else
                                    lines << line
                                end
                            elsif iface && (line.start_with?(' ') || line.start_with?("\t"))
                                # Drop line
                            else
                                iface = false
                                lines << line
                            end
                        end
                        fileWrite(localFile, lines.join(), options[:dry])
                        connection.upload(localFile, interfacesFile)
                    end
                    connection.updateFile(interfacesFile, options) do |fileLines|
                        target['Network']['Interfaces'].each do |name, data|
                            fileLines << "auto #{name}\n"
                            data = 'manual' if data.nil?
                            if data.is_a?(String)
                                fileLines << "iface #{name} inet #{data}\n"
                            else
                                if data['IP']
                                    fileLines << "iface #{name} inet static\n"
                                    fileLines << "        address #{data['IP']}\n"
                                    fileLines << "        gateway #{data['Gateway']}\n" if data['Gateway']
                                else
                                    fileLines << "iface #{name} inet manual\n"
                                end
                                if data.key?('Ports')
                                    if data['Ports']
                                        fileLines << "        bridge-ports #{data['Ports'].join(' ')}\n"
                                    else
                                        fileLines << "        bridge-ports none\n"
                                    end
                                    fileLines << "        bridge-stp off\n"
                                    fileLines << "        bridge-fd 0\n"
                                    if data['VLANFiltering']
                                        fileLines << "        bridge-vlan-aware yes\n"
                                    end
                                    if data['VLANS']
                                        fileLines << "        bridge-vids #{data['VLANS']}\n"
                                    end
                                end
                                if data['DNS']
                                    fileLines << "        # dns-* options are implemented by the resolvconf package, if installed\n"
                                    fileLines << "        dns-nameservers #{data['DNS']}\n"
                                    fileLines << "        dns-search #{dnsSearch}\n" if dnsSearch
                                end
                                if data['NAT']
                                    addr = IPAddr.new(data['IP'])
                                    sourceAddr = "#{addr.to_s}/#{addr.prefix}"
                                    outputInterface = ''
                                    if data['NAT'].is_a?(String)
                                        outputInterface = " -o #{data['NAT']}"
                                    end
                                    fileLines << "        post-up   iptables -t nat -A POSTROUTING -s #{sourceAddr}#{outputInterface} -j MASQUERADE\n"
                                    fileLines << "        post-down iptables -t nat -D POSTROUTING -s #{sourceAddr}#{outputInterface} -j MASQUERADE\n"
                                end
                            end
                            fileLines << "\n"
                        end
                        fileLines
                    end
                end

                def networkLinks(connection)
                    connection.exec("ls /sys/class/net/").strip.split("\n").select { |name| name.start_with?('enp') }
                end

                def self.kernelNetworkCMD(target)
                    ip = 'ip=dhcp'
                    if target['DefaultNetwork']['IP'] != 'dhcp'
                        ip = 'ip=' + target['DefaultNetwork']['IP'].split('/').first
                        ip += ':'
                        ip += ':' + target['DefaultNetwork']['Gateway'].to_s
                        ip += ':' + IPAddr.new(target['DefaultNetwork']['IP']).netmask
                        ip += ':' + (target['Domain'] ? target['Domain'] : '')
                        ip += ':'
                        ip += ':off'
                        ip += ':' + target['DefaultNetwork']['DNS'] if target['DefaultNetwork']['DNS']
                    end
                    ip
                end
            end
        end
    end
end
