

module ConfigLMM
    module LMM
        class VLLM < Framework::Plugin

            USER = 'vllm'
            HOME_DIR = '/var/lib/vllm'
            PORT = 18050

            CPU_IMAGE = 'public.ecr.aws/q9t5s3a7/vllm-cpu-release-repo:v0.8.4'
            CUDA_IMAGE = 'docker.io/vllm/vllm-openai:latest'
            ROCM_IMAGE = 'docker.io/rocm/vllm:instinct_main'

            def actionVLLMDeploy(id, target, activeState, context, options)
                #raise Framework::PluginProcessError.new('Model field must be set!') unless target['Model']

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'vLLM', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/.cache', '~/.triton')
                        end

                        path = Podman.containersPath(HOME_DIR)

                        linuxConnection.fileWrite("#{path}/vLLM.env", '', options)

                        linuxConnection.setUserGroup("#{path}/vLLM.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/vLLM.env", options)

                        linuxConnection.upload(__dir__ + '/vLLM.container', path, options)

                        devices = linuxConnection.getGPUDevices(options)
                        groups = linuxConnection.getGPUGroups(devices, options)
                        linuxConnection.userAddGroups(USER, groups, options)

                        image = CPU_IMAGE
                        if devices.include?('/dev/kfd')
                            image = ROCM_IMAGE
                        elsif devices.include?('nvidia.com/gpu=all')
                            image = CUDA_IMAGE
                        end
                        linuxConnection.fileReplace("#{path}/vLLM.container", '\$IMAGE', image, options)

                        args = target['Args'].to_s
                        if target['Model']
                            args += ' --model ' + target['Model'].to_s
                        end
                        linuxConnection.fileReplace("#{path}/vLLM.container", '\$ARGS', args, options)

                        devicesString = ''
                        if !devices.empty?
                            devicesString = devices.map { |device| "AddDevice=#{device}" }.join('\n')
                        end

                        linuxConnection.fileReplace("#{path}/vLLM.container", '\$DEVICES', devicesString, { **options, escape: false })

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'vLLM', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:vLLM, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.stopUserService(USER, 'vLLM', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + '/vLLM.container', options[:dry])

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
