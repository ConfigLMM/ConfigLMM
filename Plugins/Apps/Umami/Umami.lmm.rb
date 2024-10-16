
module ConfigLMM
    module LMM
        class Umami < Framework::Plugin

            USER = 'umami'
            HOME_DIR = '/var/lib/umami'
            HOST_IP = '10.0.2.2'

            def actionUmamiDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') if (!target.key?('Proxy') || target['Proxy']) && !target['Domain']

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !target.key?('Proxy') || target['Proxy'] == false
                            dbUser, dbPassword = self.configurePostgreSQL(target, linuxConnection, context, options)
                            Podman.createUser(USER, HOME_DIR, 'Umami', linuxConnection, options)

                            path = Podman.containersPath(HOME_DIR)

                            dbHost = target['Database']['HostName']
                            dbPort = target['Database']['Port']
                            linuxConnection.fileWrite("#{path}/Umami.env", "DATABASE_URL=postgresql://#{dbUser}:#{dbPassword}@#{dbHost}:#{dbPort}/#{dbUser}", { **options, hide: true })

                            linuxConnection.setUserGroup("#{path}/Umami.env", USER, USER, options)
                            linuxConnection.setPrivate("#{path}/Umami.env", options)

                            linuxConnection.upload(__dir__ + '/Umami.container', path, options)
                        end

                        if !target.key?('Proxy') || target['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                 nginxConnection.provisionProxy('http://127.0.0.1:13300', 'Umami', target, activeState, context, options)
                            end
                        elsif target.key?('Proxy') && target['Proxy'] == false
                            linuxConnection.fileReplace("#{path}/Umami.container", 'PublishPort=127.0.0.1:13300:', 'PublishPort=0.0.0.0:13300:', options)
                            linuxConnection.firewallAddPort('13300/tcp', options)
                        end

                        if !target.key?('Proxy') || target['Proxy'] == false
                            linuxConnection.reloadUserServices(USER, options)
                            linuxConnection.restartUserService(USER, 'Umami', options)
                        end
                    end
                end
            end

            def configurePostgreSQL(target, linuxConnection, context, options)
                target['Database'] ||= {}
                target['Database']['Type'] = 'pgsql'
                PostgreSQL.defaults(target['Database'])
                username = target['Database']['Username'] || context.secrets.load(target['SecretId'], 'POSTGRESQL_USERNAME') || USER
                context.secrets.store(target['SecretId'], 'POSTGRESQL_USERNAME', username)
                password = context.secrets.load(target['SecretId'], 'POSTGRESQL_PASSWORD')
                if password.nil?
                    password = SecureRandom.alphanumeric(20)
                    context.secrets.store(target['SecretId'], 'POSTGRESQL_PASSWORD', password)
                end
                PostgreSQL.withConnection(target['Database'], linuxConnection) do |postgres|
                    postgres.createUserAndDB(username, password, options)
                end
                if target['Database']['HostName'] == 'localhost'
                    target['Database']['HostName'] = HOST_IP
                end
                [username, password]
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Umami, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !item['Config'].key?('Proxy') || item['Config']['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.cleanupConfig('Umami', context, options)
                                nginxConnection.reload(connection, options[:dry])
                            end
                        elsif item['Config'].key?('Proxy') && item['Config']['Proxy'] == false
                            linuxConnection.firewallRemovePort('13300/tcp', connection, options)
                        end

                        if !item['Config'].key?('Proxy') || item['Config']['Proxy'] == false
                            linuxConnection.stopUserService(USER, 'Umami', options)

                            path = Podman.containersPath(HOME_DIR)
                            linuxConnection.rm(path + '/Umami.container', options[:dry])
                        end

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            if !item['Config'].key?('Proxy') || item['Config']['Proxy'] == false
                                if item['Config']['Database']['Type'] == 'pgsql'
                                    username = context.secrets.load(target['SecretId'], 'POSTGRESQL_USERNAME') || USER
                                    PostgreSQL.withConnection(settings, linuxConnection) do |postgres|
                                        postgres.dropUserAndDB(item['Config']['Database'], username, options)
                                    end
                                end
                                linuxConnection.deleteUserAndGroup(USER, options)
                            end
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end
