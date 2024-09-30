
module ConfigLMM
    module LMM
        class WireGuard < Framework::LinuxApp

            WIREGUARD_PACKAGE = 'WireGuard'
            SERVICE_NAME = 'wg-quick@wg0'
            CONFIG_FILE = '/etc/wireguard/wg0.conf'
            PORT = '51820'
            SUBNET = '172.20.0.0/20'

            persistBuildDir

            def actionWireGuardDeploy(id, target, activeState, context, options)
                self.prepareConfig(target)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        self.class.sshExec!(ssh, "firewall-cmd -q --permanent --add-port='#{PORT}/udp'")
                        self.class.sshExec!(ssh, "firewall-cmd -q --add-port='#{PORT}/udp'")
                        self.class.sshExec!(ssh, "firewall-cmd -q --permanent --zone=trusted --add-source=#{SUBNET}")
                        self.class.sshExec!(ssh, "firewall-cmd -q --zone=trusted --add-source=#{SUBNET}")
                        self.class.sshExec!(ssh, "firewall-cmd -q --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE")
                        self.class.sshExec!(ssh, "firewall-cmd -q --direct --add-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE")

                        self.class.ensurePackages([WIREGUARD_PACKAGE], ssh)
                        self.class.ensureServiceAutoStartOverSSH(SERVICE_NAME, ssh)

                        dir = options['output'] + '/' + id + '/etc/wireguard/'
                        mkdir(dir, false)
                        template = ERB.new(File.read(__dir__ + '/wg0.conf.erb'))

                        if self.class.remoteFilePresent?(CONFIG_FILE, ssh)
                            # TODO Implement adding and removing peers
                        else
                            if !target['PrivateKey']
                                target['PrivateKey'] = ENV['WIREGUARD_PRIVATEKEY_' + id]
                                if !target['PrivateKey']
                                    target['PrivateKey'] = genkeyOverSSH(ssh)
                                end
                            end
                            publicKey = pubkeyOverSSH(target['PrivateKey'], ssh)
                            self.class.sshExec!(ssh, "echo '#{publicKey}' > /etc/wireguard/pubkey")
                            target['Peers'].each do |name, data|
                                if !data['PublicKey']
                                    data['PrivateKey'] = genkeyOverSSH(ssh)
                                    data['PublicKey'] = pubkeyOverSSH(data['PrivateKey'], ssh)
                                end
                                if !data['PresharedKey']
                                    data['PresharedKey'] = ENV['WIREGUARD_PRESHAREDKEY_' + id + '_' + name]
                                    if !data['PresharedKey']
                                        data['PresharedKey'] = genpskOverSSH(ssh)
                                    end
                                end
                            end

                            target['Peers'].each do |name, data|
                                templateData = {}
                                templateData['Address'] = target['Address']
                                templateData['PrivateKey'] = data['PrivateKey']
                                templateData['Peers'] = {}
                                templateData['Peers'][id] = { 'PublicKey' => publicKey, 'PresharedKey' => data['PresharedKey'] }
                                target['Peers'].each do |otherName, otherData|
                                    next if name == otherName
                                    pskIdB = 'PresharedKey_' + otherName + '_' + name
                                    if otherData.key?(pskIdB)
                                        psk = otherData[pskIdB]
                                    else
                                        pskIdA = 'PresharedKey_' + name + '_' + otherName
                                        data[pskIdA] = genpskOverSSH(ssh)
                                        psk = data[pskIdA]
                                    end
                                    templateData['Peers'][otherName] = { 'PublicKey' => otherData['PublicKey'], 'PresharedKey' => psk }
                                end

                                renderTemplate(template, templateData, dir + name + '.conf', options)
                            end

                            renderTemplate(template, target, dir + 'wg0.conf', options)
                            ssh.scp.upload!(dir + 'wg0.conf', CONFIG_FILE)
                        end

                    end
                else
                    # TODO
                end
                self.startService(SERVICE_NAME, target['Location'])

                activeState['Status'] = State::STATUS_DEPLOYED
            end

            def cleanup(configs, state, context, options)
                cleanupType(:WireGuard, configs, state, context, options) do |item, id, state, context, options, ssh|
                    Framework::LinuxApp.stopService(SERVICE_NAME, ssh, options[:dry])
                    Framework::LinuxApp.disableService(SERVICE_NAME, ssh, options[:dry])
                    Framework::LinuxApp.removePackage(WIREGUARD_PACKAGE, ssh, options[:dry])

                    self.class.exec("firewall-cmd -q --permanent --remove-port='#{PORT}/udp'", ssh, false, options[:dry])
                    self.class.exec("firewall-cmd -q --remove-port='#{PORT}/udp'", ssh, false, options[:dry])
                    self.class.exec("firewall-cmd -q --permanent --zone=trusted --remove-source=#{SUBNET}", ssh, false, options[:dry])
                    self.class.exec("firewall-cmd -q --zone=trusted --remove-source=#{SUBNET}", ssh, false, options[:dry])
                    self.class.exec("firewall-cmd -q --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE", ssh, false, options[:dry])
                    self.class.exec("firewall-cmd -q --direct --remove-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE", ssh, false, options[:dry])

                    state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                    if options[:destroy]
                        rm('/etc/wireguard', options[:dry], ssh)

                        state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                    end
                end
            end

            def genkeyOverSSH(ssh)
              self.class.sshExec!(ssh, 'wg genkey')
            end

            def genpskOverSSH(ssh)
              self.class.sshExec!(ssh, 'wg genpsk')
            end

            def pubkeyOverSSH(privateKey, ssh)
              self.class.sshExec!(ssh, " echo '#{privateKey}' | wg pubkey")
            end

            def prepareConfig(target)
                target['Address'] = '172.20.0.1' unless target['Address']
                target['Peers'].each do |name, data|
                    data['AllowedIPs'] = SUBNET unless data['AllowedIPs']
                end
            end
        end
    end
end
