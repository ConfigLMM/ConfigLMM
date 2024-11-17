
module ConfigLMM
    module LMM
        class Peppermint < Framework::NginxApp

            USER = 'peppermint'
            HOME_DIR = '/var/lib/peppermint'
            HOST_IP = '10.0.2.2'

            def actionPeppermintDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        dbPassword = self.configurePostgreSQL(target['Database'], linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Peppermint Ticket Management', linuxConnection, options)

                        path = Podman.containersPath(HOME_DIR)

                        linuxConnection.fileWrite("#{path}/Peppermint.env", "DB_HOST=#{HOST_IP}", options)
                        linuxConnection.fileAppend("#{path}/Peppermint.env", "DB_USERNAME=#{USER}", options)
                        linuxConnection.fileAppend("#{path}/Peppermint.env", "DB_PASSWORD=#{dbPassword}", { **options, hide: true })
                        linuxConnection.fileAppend("#{path}/Peppermint.env", "SECRET=#{SecureRandom.urlsafe_base64(60)}", { **options, hide: true })
                        linuxConnection.fileAppend("#{path}/Peppermint.env", "API_URL=https://#{target['Domain']}/api", options)

                        linuxConnection.setUserGroup("#{path}/Peppermint.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Peppermint.env", options)

                        linuxConnection.upload(__dir__ + '/Peppermint.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Peppermint', options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.provision(__dir__, 'Peppermint', target, activeState, context, options)
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

