
module ConfigLMM
    module LMM
        class Matrix < Framework::Plugin

            USER = 'matrix'
            HOME_DIR = '/var/lib/matrix'

            def actionMatrixBuild(id, target, state, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, 'Matrix', target, state, context, options)
                end
            end

            def actionMatrixDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionMatrixDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']
                raise Framework::PluginProcessError.new('ServerName field must be set!') unless target['ServerName']

                target['Database'] ||= {}

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        target['Database'] ||= {}
                        dbPassword = self.configurePostgreSQL(target['Database'], linuxConnection, options)

                        Podman.createUser(USER, HOME_DIR, 'Matrix', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/data')
                        end

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.ensureFile("#{path}/Matrix.env", options)

                        linuxConnection.setUserGroup("#{path}/Matrix.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Matrix.env", options)

                        linuxConnection.upload(__dir__ + '/homeserver.yaml', HOME_DIR + '/data/', options)
                        linuxConnection.upload(__dir__ + '/log.config', HOME_DIR + '/data/', options)
                        linuxConnection.upload(__dir__ + '/config.json', HOME_DIR + '/', options)
                        linuxConnection.setUserGroup("#{HOME_DIR}/data", USER, USER, options)

                        linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$SERVER_NAME', target['ServerName'], options)
                        linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$SYNAPSE_DOMAIN', target['SynapseDomain'].downcase, options)
                        linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$DB_PASSWORD', dbPassword, { **options, hide: true })
                        linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$SECRET1', SecureRandom.urlsafe_base64(45), { **options, hide: true })
                        linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$SECRET2', SecureRandom.urlsafe_base64(45), { **options, hide: true })
                        linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$SECRET3', SecureRandom.urlsafe_base64(45), { **options, hide: true })

                        linuxConnection.fileReplace("#{HOME_DIR}/config.json", '$SYNAPSE_DOMAIN', target['SynapseDomain'], options)
                        linuxConnection.fileReplace("#{HOME_DIR}/config.json", '$SERVER_NAME', target['ServerName'], options)

                        if target['SMTP']
                            host = target['SMTP']['Host']
                            host = HOST_IP if ['localhost', '127.0.0.1'].include?(host)
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'smtp_host:.*', "smtp_host: #{host}", options)
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'smtp_port:.*', "smtp_port: #{target['SMTP']['Port']}", options)
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'smtp_user:.*', "smtp_user: #{target['SMTP']['Username']}", options)
                            smtpPassword = ''
                            if target['SMTP']['SecretId']
                                smtpPassword = context.secrets.load(target['SMTP']['SecretId'], target['SMTP']['Username'].upcase + '_PASSWORD')
                            end
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'smtp_pass:.*', "smtp_pass: #{smtpPassword}", { **options, hide: true })
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'notif_from:.*', "notif_from: #{target['SMTP']['From']}", options)

                            if target['SMTP']['Port'] == 465
                                linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'force_tls:.*', 'force_tls: true', options)
                            end
                        else
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'email:', 'ignore_email:', options)
                        end

                        if target['OIDC']
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$OIDC_ISSUER', "#{target['OIDC']['Issuer']}", options)
                            clientId = ''
                            clientSecret = ''
                            if target['OIDC']['SecretId']
                                clientId = context.secrets.load(target['OIDC']['SecretId'], 'MATRIX_CLIENT_ID')
                                clientSecret = context.secrets.load(target['OIDC']['SecretId'], 'MATRIX_CLIENT_SECRET')
                            end
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$CLIENT_ID', clientId, { **options, hide: true })
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", '$CLIENT_SECRET', clientSecret, { **options, hide: true })
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'enabled: true', 'enabled: false', options)
                        else
                            linuxConnection.fileReplace("#{HOME_DIR}/data/homeserver.yaml", 'oidc_providers:', 'ignore_oidc_providers:', options)
                        end

                        linuxConnection.upload(__dir__ + '/Synapse.container', path, options)
                        linuxConnection.upload(__dir__ + '/Element.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Synapse', options)
                        linuxConnection.restartUserService(USER, 'Element', options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.provision(__dir__, 'Matrix', target, activeState, context, options)
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
