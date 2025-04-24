
require 'json'

module ConfigLMM
    module LMM
        class Authentik < Framework::Plugin

            USER = 'authentik'
            HOME_DIR = '/var/lib/authentik'

            def actionAuthentikBuild(id, target, state, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, 'Authentik', target, state, context, options)
                end
            end

            def actionAuthentikDeploy(id, target, activeState, context, options)

                if target['Location'].start_with?('http')
                    apiURL = target['Location']
                    configureAuthentik(apiURL, id, target, activeState, context, options)
                else
                    deployServerAndReverseProxy(id, target, activeState, context, options)
                end
            end

            def deployServerAndReverseProxy(id, target, activeState, context, options)

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        target['Database'] ||= {}
                        target['Deploy'] = true unless target.key?('Deploy')

                        if target['Deploy']
                            if !target.key?('Proxy') || target['Proxy'] == false
                                self.deployServer(linuxConnection, target, activeState, context, options)
                                self.deployProxyOutpost(target, linuxConnection, options)
                            end

                            self.deployReverseProxy(id, linuxConnection, target, activeState, context, options)
                        end
                    end
                end

                apiURL = "https://#{target['Domain']}/"
                configureAuthentik(apiURL, id, target, activeState, context, options)
            end

            def deployServer(linuxConnection, target, activeState, context, options)
                dbPassword = self.configurePostgreSQL(target['Database'], linuxConnection, options)

                Podman.ensurePresent(linuxConnection, options)
                Podman.createUser(USER, HOME_DIR, 'Authentik IdP and SSO', linuxConnection, options)
                linuxConnection.withUserShell(USER) do |shell|
                    shell.createDirs(options, '~/media', '~/templates', '~/certs')
                end

                path = Podman.containersPath(HOME_DIR)
                secretKey = context.secrets.load(target['SecretId'], 'SECRET_KEY')
                if secretKey.nil?
                    secretKey = SecureRandom.urlsafe_base64(60)
                    context.secrets.store(target['SecretId'], 'SECRET_KEY', secretKey) unless options['dry']
                end
                linuxConnection.fileWrite("#{path}/Authentik.env", "AUTHENTIK_SECRET_KEY=#{secretKey}", { **options, hide: true })

                valkeyHost = Podman.updateHost(target['Valkey'].to_h['Host'])
                linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_REDIS__HOST=#{valkeyHost}", options)
                if target['Valkey'].to_h['SecretId']
                    valkeyPassword = context.secrets.load(target['Valkey']['SecretId'], 'VALKEY_PASSWORD')
                    if !valkeyPassword.nil?
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_REDIS__PASSWORD=#{valkeyPassword}", { **options, hide: true })
                    end
                end

                postgresHost = Podman.updateHost(target['Database'].to_h['HostName'])
                linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_POSTGRESQL__HOST=#{postgresHost}", options)
                linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_POSTGRESQL__PASSWORD=#{dbPassword}", { **options, hide: true })

                if !target['SMTP'].to_h.empty?
                    host = target['SMTP']['Host']
                    host = Podman::HOST_IP if host.to_s.empty? || ['localhost', '127.0.0.1'].include?(host)

                    linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_EMAIL__HOST=#{host}", options)

                    if target['SMTP']['Port']
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_EMAIL__PORT=#{target['SMTP']['Port']}", options)
                    end

                    if target['SMTP']['Username']
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_EMAIL__USERNAME=#{target['SMTP']['Username']}", options)
                    end

                    if target['SMTP']['SecretId']
                        smtpPassword = context.secrets.load(target['SMTP']['SecretId'], target['SMTP']['Username'].upcase + '_PASSWORD')
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_EMAIL__PASSWORD=#{smtpPassword}", { **options, hide: true })
                    end

                    if target['SMTP']['Port'] == 465
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_EMAIL__USE_TLS=true", options)
                    end

                    if target['SMTP']['From']
                        linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_EMAIL__FROM=#{target['SMTP']['From']}", options)
                    end
                else
                    linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_EMAIL__HOST=#{Podman::HOST_IP}", options)
                end

                adminPassword = context.secrets.load(target['SecretId'], 'ADMIN_PASSWORD')
                if adminPassword.nil?
                    raise 'Missing Authentik Admin.EMail' unless target['Admin'].to_h.key?('EMail')
                    adminPassword = SecureRandom.urlsafe_base64(30)
                    if !options['dry']
                        context.secrets.store(target['SecretId'], 'ADMIN_PASSWORD', adminPassword)
                        context.secrets.print("Authentik Admin password", adminPassword)
                    end
                end
                if target['Admin'].to_h.key?('EMail')
                    email = target['Admin']['EMail']
                    linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_BOOTSTRAP_EMAIL=#{email}", options)
                    linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_BOOTSTRAP_PASSWORD=#{adminPassword}", { **options, hide: true })
                end

                adminToken = context.secrets.load(target['SecretId'], 'ADMIN_TOKEN')
                if adminToken.nil?
                    adminToken = SecureRandom.urlsafe_base64(60)
                    if !options['dry']
                        context.secrets.store(target['SecretId'], 'ADMIN_TOKEN', adminToken) unless options['dry']
                        context.secrets.print("Authentik Admin token", adminToken)
                    end
                end
                linuxConnection.fileAppend("#{path}/Authentik.env", "AUTHENTIK_BOOTSTRAP_TOKEN=#{adminToken}", { **options, hide: true })

                linuxConnection.setUserGroup("#{path}/Authentik.env", USER, USER, options)
                linuxConnection.setPrivate("#{path}/Authentik.env", options)

                linuxConnection.upload(__dir__ + '/Authentik-Server.container', path, options)
                linuxConnection.upload(__dir__ + '/Authentik-Worker.container', path, options)

                if target['Proxy'] == false
                    linuxConnection.fileReplace("#{path}/Authentik-Server.container", 'PublishPort=127.0.0.1:19000:', 'PublishPort=0.0.0.0:19000:', options)
                    linuxConnection.firewallAddPort('19000/tcp', options)
                end

                linuxConnection.reloadUserServices(USER, options)
                linuxConnection.restartUserService(USER, 'Authentik-Server', options)
                linuxConnection.restartUserService(USER, 'Authentik-Worker', options)
            end

            def deployReverseProxy(id, linuxConnection, target, activeState, context, options)
                if !target.key?('Proxy') || target['Proxy']
                    raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']
                    Nginx.withConnection(linuxConnection) do |nginxConnection|
                        target['Server'] = '127.0.0.1' unless target['Server']
                        target['ConfigName'] = target['Name']
                        nginxConnection.provision(__dir__, 'Authentik', target, activeState, context, options)
                    end
                end
            end

            def configureAuthentik(apiURL, id, target, activeState, context, options)
                if target['Groups'] || target['Providers'] || target['Applications']
                    prompt.say('Configuring specified settings for Authentik is not implemented! You\'ll have to configure those manually.', :color => :magenta)
                end
            end

            def waitTilReady(baseURL, target, linuxConnection, options)
                if !options['dry']
                    timeout = 3600 # 1h
                    loop do
                        begin
                            linuxConnection.exec("curl --no-progress-meter --show-error --fail #{baseURL}/", false, options)
                            break
                        rescue
                            timeout -= 30
                        end
                        raise "Timeout while waiting #{baseURL}/ to be ready!" if timeout <= 0
                        sleep(30)
                    end
                end
            end

            def viewToken(baseURL, target, tokenIdentifier, adminToken, linuxConnection, options)
                url = "#{baseURL}/api/v3/core/tokens/#{tokenIdentifier}/view_key/"
                result = linuxConnection.http(url, options, { 'Authorization' => 'Bearer ' + adminToken })
                data = JSON.parse(result)
                return nil unless data['key']
                data['key']
            end

            def loadProxyOutpostToken(baseURL, target, linuxConnection, options)
                return '' if options['dry']
                adminToken = context.secrets.load(target['SecretId'], 'ADMIN_TOKEN')
                if adminToken.nil?
                    prompt.say("Authentik Admin token missing! You need to set secret: #{context.secrets.getID(target['SecretId'], 'ADMIN_TOKEN')}", :color => :magenta)
                    raise 'Authentik Admin token missing!'
                end
                url = "#{baseURL}/api/v3/outposts/instances/?name__iexact=authentik+Embedded+Outpost"
                result = JSON.parse(linuxConnection.http(url, options, { 'Authorization' => 'Bearer ' + adminToken }))
                if result['results'].to_a.empty?
                    prompt.say(result, :color => :red)
                    raise 'Failed to get Embedded Proxy Outpost info!'
                end

                tokenIdentifier = result['results'][0]['token_identifier']
                tokenValue = viewToken(baseURL, target, tokenIdentifier, adminToken, linuxConnection, options)
                raise 'Failed to get Embedded Proxy Outpost token!' if tokenValue.nil?
                context.secrets.store(target['SecretId'], 'PROXYOUTPOST_TOKEN', tokenValue)
                tokenValue
            end

            def deployProxyOutpost(target, linuxConnection, options)
                return unless target['Outposts'].to_a.include?('Proxy')

                proxyOutpostToken = context.secrets.load(target['SecretId'], 'PROXYOUTPOST_TOKEN')
                if proxyOutpostToken.nil?
                    baseURL = "http://127.0.0.1:19000"
                    waitTilReady(baseURL, target, linuxConnection, options)
                    proxyOutpostToken = loadProxyOutpostToken(baseURL, target, linuxConnection, options)
                end

                Podman.ensurePresent(linuxConnection, options)
                path = Podman.containersPath(HOME_DIR)
                linuxConnection.fileWrite("#{path}/ProxyOutpost.env", "AUTHENTIK_HOST=https://#{target['Domain'].downcase}", options)
                linuxConnection.fileAppend("#{path}/ProxyOutpost.env", 'AUTHENTIK_INSECURE=false', options)
                linuxConnection.fileAppend("#{path}/ProxyOutpost.env", "AUTHENTIK_TOKEN=#{proxyOutpostToken}", { **options, hide: true })
                valkeyHost = Podman.updateHost(target['Valkey'].to_h['Host'])
                linuxConnection.fileAppend("#{path}/ProxyOutpost.env", "AUTHENTIK_REDIS__HOST=#{valkeyHost}", options)
                if target['Valkey'].to_h['SecretId']
                    valkeyPassword = context.secrets.load(target['Valkey']['SecretId'], 'VALKEY_PASSWORD')
                    if !valkeyPassword.nil?
                        linuxConnection.fileAppend("#{path}/ProxyOutpost.env", "AUTHENTIK_REDIS__PASSWORD=#{valkeyPassword}", { **options, hide: true })
                    end
                end

                linuxConnection.setUserGroup("#{path}/ProxyOutpost.env", USER, USER, options)
                linuxConnection.setPrivate("#{path}/ProxyOutpost.env", options)

                linuxConnection.upload(__dir__ + '/Authentik-ProxyOutpost.container', path)

                if target['Proxy'] == false
                    linuxConnection.fileReplace("#{path}/Authentik-ProxyOutpost.container", 'PublishPort=127.0.0.1:19010:', 'PublishPort=0.0.0.0:19010:', options)
                    linuxConnection.firewallAddPort('19010/tcp', options)
                end

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
