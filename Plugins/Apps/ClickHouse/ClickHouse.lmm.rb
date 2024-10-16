
require_relative 'Connection'

module ConfigLMM
    module LMM
        class ClickHouse < Framework::Plugin

            USER = 'clickhouse'
            HOME_DIR = '/var/lib/clickhouse'
            SERVICE_NAME = 'ClickHouse'
            CONTAINER_NAME = 'ClickHouse'
            PORT = '19100'
            DEFAULT_CLUSTER = 'default'

            def actionClickHouseDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.createUser(USER, HOME_DIR, 'ClickHouse', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/data', '~/logs', '~/server/config.d' ,'~/server/users.d')
                        end

                        user = target['AdminUsername'] || context.secrets.load(target['SecretId'], 'USERNAME') || 'admin'
                        context.secrets.store(target['SecretId'], 'USERNAME', user)
                        password = context.secrets.load(target['SecretId'], 'PASSWORD')
                        if password.nil?
                            password = SecureRandom.alphanumeric(20)
                            context.secrets.store(target['SecretId'], 'PASSWORD', password)
                            context.secrets.print("#{user} password", password)
                        end

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.fileWrite("#{path}/ClickHouse.env", "CLICKHOUSE_USER=#{user}", options)
                        linuxConnection.fileAppend("#{path}/ClickHouse.env", "CLICKHOUSE_PASSWORD=#{password}", { **options, hide: true })
                        linuxConnection.fileAppend("#{path}/ClickHouse.env", "CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1", options)

                        linuxConnection.setUserGroup("#{path}/ClickHouse.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/ClickHouse.env", options)

                        loggerConfigFile = __dir__ + '/Config/logger.yaml'
                        if target['LogLevel']
                            loggerConfig = YAML.load_file(loggerConfigFile)
                            loggerConfig['logger']['level'] = target['LogLevel']
                            loggerConfigFile = options['output'] + '/logger.yaml'
                            File.write(loggerConfigFile, loggerConfig.to_yaml)
                        end

                        linuxConnection.upload(__dir__ + '/ClickHouse.container', path, options)
                        linuxConnection.upload(__dir__ + '/Config/listen.yaml', HOME_DIR + '/server/config.d/', options)
                        linuxConnection.upload(loggerConfigFile, HOME_DIR + '/server/config.d/', options)
                        linuxConnection.upload(__dir__ + '/Config/zookeepers.yaml', HOME_DIR + '/server/config.d/', options)
                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, SERVICE_NAME, options)
                    end
                end
            end

            def self.defaults(settings)
                settings['HostName'] = 'localhost' unless settings['HostName']
                settings['Port'] = PORT unless settings['Port']
            end

            def self.withConnection(settings, linuxConnection, secrets, options)
                if settings['HostName'].nil? || settings['HostName'] == 'localhost'
                    settings = settings.dup
                    settings.delete('HostName')
                    settings.delete('Port')
                    linuxConnection.withUserShell(USER) do |shellConnection|
                        Podman.withConnection(shellConnection, Podman.container(CONTAINER_NAME, shellConnection, options)) do |connection|
                            yield(ClickHouseConnection.new(connection, settings))
                        end
                    end
                else
                    if settings['ClickHouseSecretId'].nil?
                        raise Framework::PluginError.new('You need to set ClickHouseSecretId!')
                    end

                    self.defaults(settings)
                    adminUsername = secrets.load(settings['ClickHouseSecretId'], 'USERNAME')
                    adminPassword = secrets.load(settings['ClickHouseSecretId'], 'PASSWORD')

                    if adminUsername.nil? || adminPassword.nil?
                        raise Framework::PluginError.new('Invalid ClickHouseSecretId!')
                    end

                    raise 'Not Implemented!'
                    yield(nil)
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:ClickHouse, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.stopUserService(USER, SERVICE_NAME, options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm("#{path}/ClickHouse.container", options[:dry])

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

