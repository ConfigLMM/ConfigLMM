
module ConfigLMM
    module LMM
        class Ollama < Framework::Plugin

            USER = 'ollama'
            HOME_DIR = '/var/lib/ollama'
            PORT = 11434

            def actionOllamaDeploy(id, target, activeState, context, options)

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Ollama', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                                shell.createDirs(options, '~/data')
                        end

                        path = Podman.containersPath(HOME_DIR)

                        linuxConnection.fileWrite("#{path}/Ollama.env", '', options)

                        linuxConnection.setUserGroup("#{path}/Ollama.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Ollama.env", options)

                        linuxConnection.upload(__dir__ + '/Ollama.container', path, options)

                        devices = linuxConnection.getGPUDevices(options)
                        groups = linuxConnection.getGPUGroups(devices, options)
                        linuxConnection.userAddGroups(USER, groups, options)

                        if devices.include?('/dev/kfd')
                            linuxConnection.fileReplace("#{path}/Ollama.container", ':latest', ':rocm', options)
                        end

                        devicesString = ''
                        if !devices.empty?
                            devicesString = devices.map { |device| "AddDevice=#{device}" }.join('\n')
                        end
                        linuxConnection.fileReplace("#{path}/Ollama.container", '$DEVICES', devicesString, { **options, escape: false })

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Ollama', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Ollama, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.stopUserService(USER, 'Ollama', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + '/Ollama.container', options[:dry])

                        linuxConnection.reloadUserServices(USER, options)

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.deleteUserAndGroup(USER, options)
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end

