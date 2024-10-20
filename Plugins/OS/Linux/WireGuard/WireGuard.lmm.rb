
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
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.firewallAddPort("#{PORT}/udp", options)
                        linuxConnection.exec("firewall-cmd -q --permanent --zone=trusted --add-source=#{SUBNET}", options)
                        linuxConnection.exec("firewall-cmd -q --zone=trusted --add-source=#{SUBNET}", options)
                        linuxConnection.exec("firewall-cmd -q --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE", options)
                        linuxConnection.exec("firewall-cmd -q --direct --add-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE", options)

                        linuxConnection.ensurePackage(WIREGUARD_PACKAGE, options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        dir = options['output'] + '/' + id + '/etc/wireguard/'
                        mkdir(dir, false)
                        template = ERB.new(File.read(__dir__ + '/wg0.conf.erb'))

                        target = target.dup
                        target['PrivateKey'] = context.secrets.load(target['SecretId'], 'PRIVATEKEY')
                        if target['PrivateKey'].nil?
                            target['PrivateKey'] = genkey(connection, options)
                            if !options['dry']
                                context.secrets.store(target['SecretId'], 'PRIVATEKEY', target['PrivateKey'])
                                context.secrets.print("Private Key", target['PrivateKey'])
                            end
                        end

                        if connection.filePresent?(CONFIG_FILE, { **options, 'dry' => false })
                            # TODO Implement adding and removing peers
                        else
                            publicKey = pubkey(target['PrivateKey'], connection, options)
                            context.secrets.store(target['SecretId'], 'PUBLICKEY', publicKey) unless options['dry']
                            connection.exec("echo '#{publicKey}' > /etc/wireguard/pubkey", false, options)

                            target['Peers'].each do |name, data|
                                if data['SecretId']
                                    data['PublicKey'] = context.secrets.load(data['SecretId'], 'PUBLICKEY')
                                    data['PrivateKey'] = context.secrets.load(data['SecretId'], 'PRIVATEKEY')
                                    if data['PublicKey'].nil?
                                        data['PrivateKey'] = genkey(connection, options)
                                        data['PublicKey'] = pubkey(data['PrivateKey'], connection, options)
                                        if !options['dry']
                                            context.secrets.store(data['SecretId'], 'PRIVATEKEY', data['PrivateKey'])
                                            context.secrets.store(data['SecretId'], 'PUBLICKEY', data['PublicKey'])
                                        end
                                    end
                                    sharedSecretId = "#{target['SecretId'].upcase}_#{data['SecretId'].upcase}"
                                    data['PresharedKey'] = context.secrets.load(sharedSecretId, 'PRESHAREDKEY')
                                    if data['PresharedKey'].nil?
                                        sharedSecretId2 = "#{data['SecretId'].upcase}_#{target['SecretId'].upcase}"
                                        data['PresharedKey'] = context.secrets.load(sharedSecretId2, 'PRESHAREDKEY')
                                        if data['PresharedKey'].nil?
                                            data['PresharedKey'] = genpsk(connection, options)
                                            context.secrets.store(sharedSecretId, 'PRESHAREDKEY', data['PresharedKey']) unless options['dry']
                                        end
                                    end
                                else
                                    data['PrivateKey'] = genkey(connection, options)
                                    data['PublicKey'] = pubkey(data['PrivateKey'], connection, options)
                                    data['PresharedKey'] = genpsk(connection, options)
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
                                        data[pskIdA] = genpsk(connection, options)
                                        psk = data[pskIdA]
                                    end
                                    templateData['Peers'][otherName] = { 'PublicKey' => otherData['PublicKey'], 'PresharedKey' => psk }
                                end

                                renderTemplate(template, templateData, dir + name + '.conf', options)
                            end

                            renderTemplate(template, target, dir + 'wg0.conf', options)
                            connection.upload(dir + 'wg0.conf', CONFIG_FILE, options)
                        end

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:WireGuard, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.stopService(SERVICE_NAME, options[:dry])
                        linuxConnection.disableService(SERVICE_NAME, options[:dry])
                        linuxConnection.removePackage(WIREGUARD_PACKAGE, options[:dry])

                        linuxConnection.firewallRemovePort("#{PORT}/udp", options)
                        linuxConnection.exec("firewall-cmd -q --permanent --zone=trusted --remove-source=#{SUBNET}", false, options[:dry])
                        linuxConnection.exec("firewall-cmd -q --zone=trusted --remove-source=#{SUBNET}", false, options[:dry])
                        linuxConnection.exec("firewall-cmd -q --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE", false, options[:dry])
                        linuxConnection.exec("firewall-cmd -q --direct --remove-rule ipv4 nat POSTROUTING 0 -s #{SUBNET} ! -d #{SUBNET} -j MASQUERADE", false, options[:dry])
                    end

                    state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                    if options[:destroy]
                        connection.rm('/etc/wireguard', options[:dry])

                        state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                    end
                end
            end

            def genkey(connection, options)
                key = connection.exec('wg genkey', false, options).strip
                if options['dry']
                    key = connection.exec('wg genkey', false, { **options, 'dry' => false }).strip
                end
                key
            end

            def genpsk(connection, options)
                key = connection.exec('wg genpsk', false, options).strip
                if options['dry']
                    key = connection.exec('wg genpsk', false, { **options, 'dry' => false }).strip
                end
                key
            end

            def pubkey(privateKey, connection, options)
                key = connection.exec(" echo '#{privateKey}' | wg pubkey", false, { **options, hide: true }).strip
                if options['dry']
                    key = connection.exec(" echo '#{privateKey}' | wg pubkey", false, { **options, 'dry' => false, hide: true }).strip
                end
                key
            end

            def prepareConfig(target)
                target['Address'] = '172.20.0.1' unless target['Address']
            end
        end
    end
end
