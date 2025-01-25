
module ConfigLMM
    module LMM
        class Discourse < Framework::Plugin

            USER = 'discourse'
            HOME_DIR = '/var/lib/discourse'
            HOST_IP = '10.0.2.2'
            CONTAINER_NAME = 'Discourse'

            def actionDiscourseDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        target['Database'] ||= {}

                        dbPassword = self.configurePostgreSQL(target['Database'], linuxConnection, options)

                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Discourse', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/data', '~/sidekiq')
                        end

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.fileWrite("#{path}/Discourse.env", "DISCOURSE_DATABASE_HOST=#{HOST_IP}", options)
                        linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_DATABASE_NAME=#{USER}", options)
                        linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_DATABASE_USER=#{USER}", options)
                        linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_DATABASE_PASSWORD=#{dbPassword}", { **options, hide: true })
                        linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_HOST=#{target['Domain']}", options)
                        linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_REDIS_HOST=#{HOST_IP}", options)

                        if target['ValkeySecretId']
                            linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_REDIS_PASSWORD=#{context.secrets.load(target['ValkeySecretId'], 'VALKEY_PASSWORD')}", { **options, hide: true })
                        end

                        if target['SMTP']
                            host = target['SMTP']['Host']
                            host = HOST_IP if ['localhost', '127.0.0.1'].include?(host)

                            linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_SMTP_HOST=#{host}", options)
                            linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_SMTP_PORT_NUMBER=#{target['SMTP']['Port']}", options)
                            linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_SMTP_USER=#{target['SMTP']['Username']}", options)

                            smtpPassword = ''
                            if target['SMTP']['SecretId']
                                smtpPassword = context.secrets.load(target['SMTP']['SecretId'], target['SMTP']['Username'].upcase + '_PASSWORD')
                            end
                            linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_SMTP_PASSWORD=#{smtpPassword}", { **options, hide: true })

                            auth = target['SMTP']['Auth'].to_s.downcase
                            auth = 'plain' if auth.empty?
                            linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_SMTP_AUTH=#{auth}", options)
                            if target['SMTP']['Port'] == 465
                                linuxConnection.fileAppend("#{path}/Discourse.env", "DISCOURSE_EXTRA_CONF_CONTENT=smtp_force_tls = true", options)
                            end
                        end

                        linuxConnection.fileAppend("#{path}/Discourse.env", 'DISCOURSE_PRECOMPILE_ASSETS=no', options)
                        linuxConnection.fileAppend("#{path}/Discourse.env", 'CHEAP_SOURCE_MAPS=1', options)
                        linuxConnection.fileAppend("#{path}/Discourse.env", 'JOBS=1', options)

                        linuxConnection.setUserGroup("#{path}/Discourse.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Discourse.env", options)

                        linuxConnection.upload(__dir__ + '/Discourse.container', path, options)
                        linuxConnection.upload(__dir__ + '/Discourse-Sidekiq.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Discourse', options)
                        linuxConnection.restartUserService(USER, 'Discourse-Sidekiq', options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.provision(__dir__, 'Discourse', target, activeState, context, options)
                        end

                        linuxConnection.withUserShell(USER) do |shellConnection|
                            Podman.withConnection(shellConnection, Podman.container(CONTAINER_NAME, shellConnection, { **options, 'dry' => false })) do |podmanConnection|
                                if !target['Plugins'].to_a.empty?
                                    target['Plugins'].each do |plugin|
                                        podmanConnection.exec("RAILS_ENV=production bundle exec rake plugin:install repo=#{plugin}", true, { **options, workdir: '/opt/bitnami/discourse' })
                                    end
                                end
                                podmanConnection.exec('RAILS_ENV=production CHEAP_SOURCE_MAPS=1 JOBS=1 bundle exec rake assets:precompile', false, { **options, workdir: '/opt/bitnami/discourse' })
                            end
                        end
                    end
                end
            end

            def configurePostgreSQL(dbSettings, linuxConnection, options)
                password = SecureRandom.alphanumeric(20)
                PostgreSQL.withConnection(dbSettings, linuxConnection) do |postgresConnection|
                    postgresConnection.createUserAndDB(USER, password, options)
                    postgresConnection.createExtensions(USER, ['hstore', 'pg_trgm'], options)
                end
                password
            end

        end
    end
end

