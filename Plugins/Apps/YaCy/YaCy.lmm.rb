require 'digest'

module ConfigLMM
    module LMM
        class YaCy < Framework::Plugin

            USER = 'yacy'
            HOME_DIR = '/var/lib/yacy'
            PORT = 8090

            def actionYaCyDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !target.key?('Proxy') || target['Proxy'] == false
                            deployYaCyService(linuxConnection, target, activeState, context, options)
                        end

                        deployYaCyProxy(linuxConnection, target, activeState, context, options)

                        if !target.key?('Proxy') || target['Proxy'] == false
                            linuxConnection.reloadUserServices(USER, options)
                            linuxConnection.restartUserService(USER, 'YaCy', options)
                        end
                    end
                end
            end

            def deployYaCyService(linuxConnection, target, activeState, context, options)
                Podman.ensurePresent(linuxConnection, options)
                Podman.createUser(USER, HOME_DIR, 'YaCy', linuxConnection, options)
                linuxConnection.withUserShell(USER) do |shell|
                    shell.createDirs(options, '~/DATA')
                end

                path = Podman.containersPath(HOME_DIR)

                linuxConnection.fileWrite("#{path}/YaCy.env", '', options)

                linuxConnection.setUserGroup("#{path}/YaCy.env", USER, USER, options)
                linuxConnection.setPrivate("#{path}/YaCy.env", options)

                linuxConnection.upload(__dir__ + '/YaCy.container', path, options)

                linuxConnection.reloadUserServices(USER, options)

                configMissing = !linuxConnection.filePresent?("#{HOME_DIR}/DATA/SETTINGS/yacy.conf", { **options, 'dry': false })

                linuxConnection.restartUserService(USER, 'YaCy', options) if configMissing

                linuxConnection.stopUserService(USER, 'YaCy', options)

                settings = target['Settings'].to_h
                settings['remotesearch.https.preferred'] = true if settings['remotesearch.https.preferred'] != false
                settings['network.unit.protocol.https.preferred'] = true if settings['network.unit.protocol.https.preferred'] != false
                settings['upnp.enabled'] = false if settings['upnp.enabled'] != true
                settings['browserPopUpTrigger'] = false if settings['browserPopUpTrigger'] != false
                settings['seedFilePath'] = '/opt/yacy_search_server/DATA/HTDOCS/seed.txt' unless settings['seedFilePath']

                settings['adminAccountUserName'] = nil
                settings['adminRealm'] = nil

                if !target['Admin'].to_h.empty?
                    settings['adminAccountUserName'] = target['Admin']['Username']
                    settings['adminRealm'] = target['Admin']['Realm']
                end

                if !settings['adminAccountUserName']
                    settings['adminAccountUserName'] = linuxConnection.exec("grep '^adminAccountUserName=' '#{HOME_DIR}/DATA/SETTINGS/yacy.conf' | cut -d= -f2").strip
                end

                if !settings['adminRealm']
                    settings['adminRealm'] = linuxConnection.exec("grep '^adminRealm=' '#{HOME_DIR}/DATA/SETTINGS/yacy.conf' | cut -d= -f2").strip
                end

                adminPassword = context.secrets.load(target['SecretId'], 'ADMIN_PASSWORD')
                if !adminPassword
                    adminPassword = SecureRandom.alphanumeric(30)
                    if !options['dry']
                        context.secrets.store(target['SecretId'], 'ADMIN_PASSWORD', adminPassword)
                        context.secrets.print("YaCy Admin '#{settings['adminAccountUserName']}' password", adminPassword)
                    end
                end

                settings['adminAccountBase64MD5'] = 'MD5:' + Digest::MD5.hexdigest("#{settings['adminAccountUserName']}:#{settings['adminRealm']}:#{adminPassword}")

                settings.each do |name, value|
                    hide = name == 'adminAccountBase64MD5'
                    linuxConnection.fileReplace("#{HOME_DIR}/DATA/SETTINGS/yacy.conf", /^#{name}=.*/, "#{name}=#{value}", { **options, hide: hide })
                end

                target['Profile'].to_h.each do |name, value|
                    linuxConnection.fileReplace("#{HOME_DIR}/DATA/SETTINGS/profile.txt", /^#{name}=.*/, "#{name}=#{value.gsub(':', '\\:')}", options)
                end

                if settings['staticIP']
                    linuxConnection.fileReplace("#{HOME_DIR}/DATA/INDEX/freeworld/NETWORK/mySeed.txt", /IP=[^,]*,/, "IP=#{settings['staticIP']},", options)
                end

                if target['PeerName']
                    linuxConnection.fileReplace("#{HOME_DIR}/DATA/INDEX/freeworld/NETWORK/mySeed.txt", /Name=[^,]*,/, "Name=#{target['PeerName']},", options)
                end

                if target['SeedURL']
                    linuxConnection.fileReplace("#{HOME_DIR}/DATA/INDEX/freeworld/NETWORK/mySeed.txt", /seedURL=[^,]*,/, "seedURL=#{target['SeedURL']},", options)
                end

                settings['adminAccountBase64MD5'] = '<REDACTED>'
            end

            def deployYaCyProxy(linuxConnection, target, activeState, context, options)
                if !target.key?('Proxy') || target['Proxy']
                    raise Framework::PluginProcessError.new('Domain field must be set!') if !target['Domain'] && (!target.key?('Proxy') || target['Proxy'])
                    Nginx.withConnection(linuxConnection) do |nginxConnection|
                        target['Server'] = '127.0.0.1:' + PORT.to_s unless target['Server']
                        target['Server'] += ':'  + PORT.to_s unless target['Server'].include?(':')
                        nginxConnection.writeConfig(__dir__, 'YaCy', target, activeState, context, options)
                        nginxConnection.deployAllConfigs(target, activeState, context, options)
                    end
                elsif target.key?('Proxy') && target['Proxy'] == false
                    path = Podman.containersPath(HOME_DIR)
                    linuxConnection.fileReplace("#{path}/YaCy.container", 'PublishPort=127.0.0.1:', 'PublishPort=0.0.0.0:', options)
                    linuxConnection.firewallAddPort("#{PORT}/tcp", options)
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:YaCy, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        if !item['Config'].key?('Proxy') || item['Config']['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.cleanupConfig('YaCy', context, options)
                                nginxConnection.reload(options)
                            end
                        elsif item['Config'].key?('Proxy') && item['Config']['Proxy'] == false
                            linuxConnection.firewallRemovePort("#{PORT}/tcp", options)
                        end

                        if !target.key?('Proxy') || target['Proxy'] == false
                            linuxConnection.stopUserService(USER, 'YaCy', options)

                            path = Podman.containersPath(HOME_DIR)
                            linuxConnection.rm(path + '/YaCy.container', options[:dry])

                            state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                            if options[:destroy]
                                linuxConnection.deleteUserAndGroup(USER, options)
                                state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                            end
                        else
                            state.item(id)['Status'] = options[:destroy] ? State::STATUS_DESTROYED : State::STATUS_DELETED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end
