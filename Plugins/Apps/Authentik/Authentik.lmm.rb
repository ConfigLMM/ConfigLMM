
module ConfigLMM
    module LMM
        class Authentik < Framework::Plugin

            USER = 'authentik'
            HOME_DIR = '/var/lib/authentik'
            HOST_IP = '10.0.2.2'

            def actionAuthentikBuild(id, target, state, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, 'Authentik', target, state, context, options)
                end
            end

            def actionAuthentikDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        target['Database'] ||= {}

                        dbPassword = self.configurePostgreSQL(target['Database'], linuxConnection, options)

                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Authentik IdP and SSO', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/media', '~/templates', '~/certs')
                        end

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.fileWrite("#{path}/Authentik.env", "AUTHENTIK_SECRET_KEY=#{SecureRandom.urlsafe_base64(60)}", options)
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_REDIS__HOST=#{HOST_IP}", options)
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_POSTGRESQL__HOST=#{HOST_IP}", options)
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_POSTGRESQL__PASSWORD=#{dbPassword}", { **options, hide: true })

                        linuxConnection.setUserGroup("#{path}/Authentik.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Authentik.env", options)

                        linuxConnection.upload(__dir__ + '/Authentik-Server.container', path, options)
                        linuxConnection.upload(__dir__ + '/Authentik-Worker.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Authentik-Server', options)
                        linuxConnection.restartUserService(USER, 'Authentik-Worker', options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.provision(__dir__, 'Authentik', target, activeState, context, options)
                        end

                        self.deployProxyOutpost(target, linuxConnection, options)
                    end
                end
            end

            def deployProxyOutpost(target, linuxConnection, options)
                return unless target['Outposts'].to_a.include?('Proxy')

                Podman.ensurePresent(linuxConnection, options)
                path = Podman.containersPath(HOME_DIR)
                linuxConnection.fileWrite("#{path}/ProxyOutpost.env", "AUTHENTIK_HOST=https://#{target['Domain'].downcase}", options)
                linuxConnection.fileAppend("#{path}/ProxyOutpost.env", 'AUTHENTIK_INSECURE=false', options)
                linuxConnection.fileAppend("#{path}/ProxyOutpost.env", "AUTHENTIK_TOKEN=#{ENV['AUTHENTIK_TOKEN']}", { **options, hide: true })

                linuxConnection.setUserGroup("#{path}/ProxyOutpost.env", USER, USER, options)
                linuxConnection.setPrivate("#{path}/ProxyOutpost.env", options)

                linuxConnection.upload(__dir__ + '/Authentik-ProxyOutpost.container', path)

                linuxConnection.reloadUserServices(USER, options)
                linuxConnection.restartUserService(USER, 'Authentik-ProxyOutpost', options)
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
