
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

                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Matrix', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/data')
                        end

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.ensureFile("#{path}/Matrix.env", options)

                        linuxConnection.setUserGroup("#{path}/Matrix.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Matrix.env", options)

                        homeserver = YAML.load_file(__dir__ + '/homeserver.yaml')
                        configureHomeserver(homeserver, dbPassword, target)
                        homeserverFile = options['output'] + '/homeserver.yaml'
                        File.write(homeserverFile, homeserver.to_yaml)

                        linuxConnection.upload(homeserverFile, HOME_DIR + '/data/', options)

                        linuxConnection.upload(__dir__ + '/log.config', HOME_DIR + '/data/', options)
                        linuxConnection.upload(__dir__ + '/config.json', HOME_DIR + '/', options)
                        linuxConnection.setUserGroup("#{HOME_DIR}/data", USER, USER, options)

                        linuxConnection.fileReplace("#{HOME_DIR}/config.json", '$SYNAPSE_DOMAIN', target['SynapseDomain'], options)
                        linuxConnection.fileReplace("#{HOME_DIR}/config.json", '$SERVER_NAME', target['ServerName'], options)

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

            def configureHomeserver(homeserver, dbPassword, target)
                homeserver['server_name'] = target['ServerName']
                homeserver['public_baseurl'] = "https://#{target['SynapseDomain'].downcase}/"

                homeserver['database']['args']['password'] = dbPassword

                homeserver['registration_shared_secret'] = SecureRandom.urlsafe_base64(45)
                homeserver['macaroon_secret_key'] = SecureRandom.urlsafe_base64(45)
                homeserver['form_secret'] = SecureRandom.urlsafe_base64(45)

                if target['SMTP']
                    host = target['SMTP']['Host']
                    host = Podman::HOST_IP if host.to_s.empty? || ['localhost', '127.0.0.1'].include?(host)

                    homeserver['email']['smtp_host'] = host
                    if target['SMTP']['Port']
                        homeserver['email']['smtp_port'] = target['SMTP']['Port']
                    end
                    if target['SMTP']['Username']
                        homeserver['email']['smtp_user'] = target['SMTP']['Username']
                        smtpPassword = nil
                        if target['SMTP']['SecretId']
                            smtpPassword = context.secrets.load(target['SMTP']['SecretId'], target['SMTP']['Username'].upcase + '_PASSWORD')
                        end
                        homeserver['email']['smtp_pass'] = smtpPassword if smtpPassword
                    end

                    homeserver['email']['notif_from'] = target['SMTP']['From']

                    if target['SMTP']['Port'] == 465
                        homeserver['email']['force_tls'] = true
                    end
                else
                    homeserver.delete('email')
                end

                if target['OIDC']
                    raise Framework::PluginProcessError.new('OIDC.SecretId must be set!') if target['OIDC']['SecretId'].to_s.empty?

                    homeserver['oidc_providers'][0]['issuer'] = target['OIDC']['Issuer']

                    clientId = context.secrets.load(target['OIDC']['SecretId'], 'MATRIX_CLIENT_ID')
                    clientSecret = context.secrets.load(target['OIDC']['SecretId'], 'MATRIX_CLIENT_SECRET')

                    if !clientId || !clientSecret
                        prompt.say("Secrets #{context.secrets.getID(target['OIDC']['SecretId'], 'MATRIX_CLIENT_ID')} and #{context.secrets.getID(target['OIDC']['SecretId'], 'MATRIX_CLIENT_SECRET')} must be set!", :color => :magenta)
                        raise 'Required secrets are missing!'
                    end

                    homeserver['oidc_providers'][0]['client_id'] = clientId
                    homeserver['oidc_providers'][0]['client_secret'] = clientSecret
                    homeserver['password_config']['enabled'] = false
                else
                    homeserver.delete('oidc_providers')
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
