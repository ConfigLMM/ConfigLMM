
module ConfigLMM
    module LMM
        class SearXNG < Framework::Plugin

            USER = 'searxng'
            HOME_DIR = '/var/lib/searxng'
            PORT = 18800

            def actionSearXNGDeploy(id, target, activeState, context, options)

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'SearXNG', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                                shell.createDirs(options, '~/config')
                        end

                        if !linuxConnection.filePresent?(HOME_DIR + '/config/limiter.toml', { **options, 'dry': false })
                            linuxConnection.upload(__dir__ + '/limiter.toml', HOME_DIR + '/config/', options)
                        end

                        settings = YAML.load_file(__dir__ + '/settings.yml')
                        if target['Settings']
                            settings.merge!(target['Settings'])
                        end
                        settingsFile = options['output'] + '/settings.yml'
                        File.write(settingsFile, settings.to_yaml)
                        linuxConnection.upload(settingsFile, HOME_DIR + '/config/', options)

                        path = Podman.containersPath(HOME_DIR)

                        secret = SecureRandom.alphanumeric(30)
                        linuxConnection.fileWrite("#{path}/SearXNG.env", "SEARXNG_SECRET=#{secret}", { **options, hide: true })

                        if target['Valkey']
                            host = Podman.updateHost(target['Valkey']['Host'])
                            valkeyPassword = nil
                            if target['Valkey']['SecretId']
                                valkeyPassword = context.secrets.load(target['Valkey']['SecretId'], 'VALKEY_PASSWORD')
                            end
                            redisURL = Valkey.connectionURL({ Host: host, Password: valkeyPassword })
                            linuxConnection.fileAppend("#{path}/SearXNG.env", "SEARXNG_REDIS_URL=#{redisURL}", { **options, hide: true })
                        end

                        linuxConnection.setUserGroup("#{path}/SearXNG.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/SearXNG.env", options)

                        linuxConnection.upload(__dir__ + '/SearXNG.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'SearXNG', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:SearXNG, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.stopUserService(USER, 'SearXNG', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + '/SearXNG.container', options[:dry])

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
