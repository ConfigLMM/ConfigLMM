
module ConfigLMM
    module LMM
        class WikiJS < Framework::Plugin

            USER = 'wikijs'
            HOME_DIR = '/var/lib/wikijs'
            HOST_IP = '10.0.2.2'

            def actionWikiJSDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        target['Database'] ||= {}
                        dbPassword = self.configurePostgreSQL(target['Database'], linuxConnection, options)

                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Wiki.js', linuxConnection, options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.fileWrite("#{path}/Wiki.js.env", 'DB_TYPE=postgres', options)
                        linuxConnection.fileAppend("#{path}/Wiki.js.env", "DB_HOST=#{HOST_IP}", options)
                        linuxConnection.fileAppend("#{path}/Wiki.js.env", "DB_PORT=5432", options)
                        linuxConnection.fileAppend("#{path}/Wiki.js.env", "DB_USER=#{USER}", options)
                        linuxConnection.fileAppend("#{path}/Wiki.js.env", "DB_NAME=#{USER}", options)
                        linuxConnection.fileAppend("#{path}/Wiki.js.env", "DB_PASS=#{dbPassword}", { **options, hide: true })

                        linuxConnection.setUserGroup("#{path}/Wiki.js.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Wiki.js.env", options)

                        linuxConnection.upload(__dir__ + '/Wiki.js.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Wiki.js', options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.provision(__dir__, 'Wiki.js', target, activeState, context, options)
                        end
                    end
                end
            end

            def configurePostgreSQL(dbSettings, linuxConnection, options)
                password = SecureRandom.alphanumeric(20)
                PostgreSQL.withConnection(dbSettings, linuxConnection) do |postgresConnection|
                    postgresConnection.createUserAndDB(USER, password, options)
                end
                password
            end

        end
    end
end
