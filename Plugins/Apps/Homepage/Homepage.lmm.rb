
module ConfigLMM
    module LMM
        class Homepage < Framework::Plugin

            NAME = 'Homepage'
            USER = 'homepage'
            HOME_DIR = '/var/lib/homepage'

            def actionHomepageBuild(id, target, activeState, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, NAME, target, state, context, options)
                end
            end

            def actionHomepageDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !target.key?('Proxy') || target['Proxy'] != 'only'
                            Podman.createUser(USER, HOME_DIR, 'Homepage', linuxConnection, options)
                            linuxConnection.withUserShell(USER) do |shell|
                                shell.createDirs(options, '~/config')
                            end

                            configPath = './Homepage'
                            configPath = target['ConfigPath'] if target['ConfigPath']
                            Dir[configPath + '/*'].each do |file|
                                linuxConnection.upload(file, HOME_DIR + '/config/', options)
                            end

                            path = Podman.containersPath(HOME_DIR)
                            linuxConnection.upload(__dir__ + '/Homepage.container', path, options)
                            if target.key?('Proxy') && target['Proxy'] == false
                                linuxConnection.exec("sed -i 's|PublishPort=127.0.0.1:13400:|PublishPort=0.0.0.0:13400:|' #{path}/Homepage.container", false, options)
                                linuxConnection.firewallAddPort('13400/tcp', options)
                            end

                            linuxConnection.reloadUserServices(USER, options)
                            linuxConnection.restartUserService(USER, 'Homepage', options)
                        end
                        if !target.key?('Proxy') || !!target['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                target['ConfigName'] = target['Name']
                                nginxConnection.provision(__dir__, NAME, target, activeState, context, options)
                            end
                        end
                    end
                end
            end

        end
    end
end
