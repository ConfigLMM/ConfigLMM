
module ConfigLMM
    module LMM
        class Gollum < Framework::Plugin

            NAME = 'gollum'
            USER = 'gollum'
            GOLLUM_PATH = '/srv/gollum'
            GOLLUM_PORT = '14567'

            def actionGollumBuild(id, target, activeState, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, NAME, target, state, context, options)
                end
                targetDir = options['output'] + GOLLUM_PATH
                local.mkdir(targetDir + '/config', options['dry'])
                local.copy(__dir__ + '/config.ru', targetDir, options['dry'])
                local.exec("git init #{targetDir}/repo", options)
            end

            def actionGollumRefresh(id, target, activeState, context, options)
                # Would need to parse deployed config to implement
            end

            def actionGollumDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !target.key?('Proxy') || !!target['Proxy']
                            #if !target['Root']
                            #    gollumPath = linuxConnection.exec('gem which gollum', true).strip
                            #    target['Root'] = File.dirname(gollumPath) + '/gollum/public'
                            #end
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.writeConfig(__dir__, NAME, target, state, context, options)
                                nginxConnection.deployAllConfigs(target, activeState, context, options)
                            end
                        end
                        if !target.key?('Proxy') || target['Proxy'] != 'only'
                            Podman.ensurePresent(linuxConnection, options)
                            Podman.createUser(USER, GOLLUM_PATH, 'gollum', linuxConnection, options)
                            linuxConnection.withUserShell(USER) do |shell|
                                shell.createDirs(options, '~/data')
                            end

                            if !linuxConnection.filePresent?(GOLLUM_PATH, options)
                                if target['Config']
                                    local.copy(target['Config'], "#{options['output'] + GOLLUM_PATH}/config/config.rb", options['dry'])
                                else
                                    local.fileWrite(options['output'] + GOLLUM_PATH + "/config/config.rb", '', options['dry'])
                                end
                                linuxConnection.uploadFolder(options['output'] + GOLLUM_PATH, '/srv', options)
                            else
                                if target['Config']
                                    linuxConnection.upload(target['Config'], "#{GOLLUM_PATH}/config/config.rb", options)
                                end
                            end

                            path = Podman.containersPath(GOLLUM_PATH)
                            linuxConnection.upload(__dir__ + '/gollum.container', path, options)

                            linuxConnection.setUserGroup(GOLLUM_PATH, USER, USER, options)
                            linuxConnection.reloadUserServices(USER, options)
                            linuxConnection.restartUserService(USER, 'gollum', options)
                            if target['Proxy'] != 'only'
                                linuxConnection.firewallAddPort(GOLLUM_PORT + '/tcp', options)
                            end
                        end
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Gollum, configs, state, context, options) do |item, id, state, context, options, connection|
                    if !item['Config'].key?('Proxy') || !!item['Config']['Proxy']
                        Linux.withConnection(connection) do |linuxConnection|
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.cleanupConfig(NAME, context, options)
                                nginxConnection.reload(options)
                            end
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end
        end
    end
end
