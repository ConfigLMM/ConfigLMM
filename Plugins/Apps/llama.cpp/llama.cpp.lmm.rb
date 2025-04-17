

module ConfigLMM
    module LMM
        class Llamacpp < Framework::Plugin

            USER = 'llama.cpp'
            HOME_DIR = '/var/lib/llama.cpp'
            PORT = 18900

            def actionLlamacppDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Model field must be set!') unless target['Model']

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'llama.cpp', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/models', '~/.cache')
                        end

                        path = Podman.containersPath(HOME_DIR)

                        linuxConnection.fileWrite("#{path}/llama.cpp.env", '', options)
                        if target['Model'].end_with?('.gguf')
                            linuxConnection.fileAppend("#{path}/llama.cpp.env", 'LLAMA_ARG_MODEL=' + target['Model'], options)
                        else
                            linuxConnection.fileAppend("#{path}/llama.cpp.env", 'LLAMA_ARG_HF_REPO=' + target['Model'], options)
                        end

                        linuxConnection.setUserGroup("#{path}/llama.cpp.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/llama.cpp.env", options)

                        linuxConnection.upload(__dir__ + '/llama.cpp.container', path, options)

                        devices = linuxConnection.getGPUDevices(options)
                        groups = linuxConnection.getGPUGroups(devices, options)
                        linuxConnection.userAddGroups(USER, groups, options)

                        image = nil
                        if devices.include?('/dev/kfd')
                            #image = 'full-rocm'
                        elsif devices.include?('nvidia.com/gpu=all')
                            image = 'full-cuda'
                        end

                        if image
                            linuxConnection.fileReplace("#{path}/llama.cpp.container", ':full', ':' + image, options)
                        end

                        args = target['Args'].to_s
                        linuxConnection.fileReplace("#{path}/llama.cpp.container", '\$ARGS', args, options)

                        devicesString = ''
                        if !devices.empty?
                            devicesString = devices.map { |device| "AddDevice=#{device}" }.join('\n')
                        end
                        linuxConnection.fileReplace("#{path}/llama.cpp.container", '\$DEVICES', devicesString, { **options, escape: false })

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'llama.cpp', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:llamacpp, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.stopUserService(USER, 'llama.cpp', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + '/llama.cpp.container', options[:dry])

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

