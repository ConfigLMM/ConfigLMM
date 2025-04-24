
require 'base64'
require 'openssl'
require 'public_suffix'

module ConfigLMM
    module LMM
        class Mastodon < Framework::Plugin

            NAME = 'Mastodon'
            USER = 'mastodon'
            HOME_DIR = '/var/lib/mastodon'
            PORT = '13600'
            STREAMING_PORT = '14000'

            def actionMastodonBuild(id, target, state, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, NAME, target, state, context, options)
                end
            end

            def actionMastodonDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionMastodonDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !target.key?('Proxy') || target['Proxy'] == false
                            deployService(linuxConnection, target, activeState, context, options)
                        end

                        deployNginxConfig(linuxConnection, target, activeState, context, options)
                    end
                end
            end

            def deployService(linuxConnection, target, activeState, context, options)
                target['Database'] ||= {}
                dbPassword = self.configurePostgreSQL(target['Database'], linuxConnection, options)

                Podman.ensurePresent(linuxConnection, options)
                Podman.createUser(USER, HOME_DIR, 'Mastodon', linuxConnection, options)
                linuxConnection.withUserShell(USER) do |shell|
                    shell.createDirs(options, '~/system', '~/.configlmm')
                end

                path = Podman.containersPath(HOME_DIR)

                localDomain = PublicSuffix.domain(target['Domain'])
                raise Framework::PluginProcessError.new('Invalid Domain!') unless localDomain

                localDomain = target['LocalDomain'] if target['LocalDomain']
                linuxConnection.fileWrite("#{path}/Mastodon.env", "LOCAL_DOMAIN=#{Addressable::IDNA.to_ascii(localDomain)}", options)

                webDomain = nil
                if localDomain != target['Domain']
                    webDomain = target['Domain']
                end
                linuxConnection.fileAppend("#{path}/Mastodon.env", "WEB_DOMAIN=#{Addressable::IDNA.to_ascii(webDomain)}", options) if webDomain

                secretKeyBase = context.secrets.load(target['SecretId'], 'SECRET_KEY_BASE')
                if !secretKeyBase
                    secretKeyBase = SecureRandom.hex(64)
                    context.secrets.store(target['SecretId'], 'SECRET_KEY_BASE', secretKeyBase) unless options['dry']
                end
                linuxConnection.fileAppend("#{path}/Mastodon.env", "SECRET_KEY_BASE=#{secretKeyBase}", { **options, hide: true })

                otpSecret = context.secrets.load(target['SecretId'], 'OTP_SECRET')
                if !otpSecret
                    otpSecret = SecureRandom.hex(64)
                    context.secrets.store(target['SecretId'], 'OTP_SECRET', otpSecret) unless options['dry']
                end
                linuxConnection.fileAppend("#{path}/Mastodon.env", "OTP_SECRET=#{otpSecret}", { **options, hide: true })

                deterministicKey = context.secrets.load(target['SecretId'], 'ENCRYPTION_DETERMINISTIC_KEY')
                if !deterministicKey
                    deterministicKey = SecureRandom.alphanumeric(32)
                    context.secrets.store(target['SecretId'], 'ENCRYPTION_DETERMINISTIC_KEY', deterministicKey) unless options['dry']
                end

                keySalt = context.secrets.load(target['SecretId'], 'KEY_DERIVATION_SALT')
                if !keySalt
                    keySalt = SecureRandom.alphanumeric(32)
                    context.secrets.store(target['SecretId'], 'KEY_DERIVATION_SALT', keySalt) unless options['dry']
                end

                primaryKey = context.secrets.load(target['SecretId'], 'ENCRYPTION_PRIMARY_KEY')
                if !primaryKey
                    primaryKey = SecureRandom.alphanumeric(32)
                    context.secrets.store(target['SecretId'], 'ENCRYPTION_PRIMARY_KEY', primaryKey) unless options['dry']
                end

                linuxConnection.fileAppend("#{path}/Mastodon.env", "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=#{deterministicKey}", { **options, hide: true })
                linuxConnection.fileAppend("#{path}/Mastodon.env", "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=#{keySalt}", { **options, hide: true })
                linuxConnection.fileAppend("#{path}/Mastodon.env", "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=#{primaryKey}", { **options, hide: true })

                vapidPrivateKey = context.secrets.load(target['SecretId'], 'VAPID_PRIVATE_KEY')
                vapidPublicKey = context.secrets.load(target['SecretId'], 'VAPID_PUBLIC_KEY')
                if !vapidPrivateKey || !vapidPublicKey
                    curve = OpenSSL::PKey::EC.generate('prime256v1')
                    vapidPrivateKey = Base64.urlsafe_encode64(curve.public_key.to_bn.to_s(2))
                    vapidPublicKey = Base64.urlsafe_encode64(curve.private_key.to_s(2))
                    context.secrets.store(target['SecretId'], 'VAPID_PRIVATE_KEY', vapidPrivateKey) unless options['dry']
                    context.secrets.store(target['SecretId'], 'VAPID_PUBLIC_KEY', vapidPublicKey) unless options['dry']
                end

                linuxConnection.fileAppend("#{path}/Mastodon.env", "VAPID_PRIVATE_KEY=#{vapidPrivateKey}", { **options, hide: true })
                linuxConnection.fileAppend("#{path}/Mastodon.env", "VAPID_PUBLIC_KEY=#{vapidPublicKey}", { **options, hide: true })

                databaseHost = Podman.updateHost(target['Database'].to_h['HostName'])
                linuxConnection.fileAppend("#{path}/Mastodon.env", "DB_HOST=#{databaseHost}", options)
                linuxConnection.fileAppend("#{path}/Mastodon.env", "DB_PORT=#{target['Database']['Port']}", options) if target['Database'].to_h['Port']
                linuxConnection.fileAppend("#{path}/Mastodon.env", "DB_USER=#{USER}", options)
                linuxConnection.fileAppend("#{path}/Mastodon.env", "DB_NAME=#{USER}", options)
                linuxConnection.fileAppend("#{path}/Mastodon.env", "DB_PASS=#{dbPassword}", { **options, hide: true })

                valkeyHost = Podman.updateHost(target['Valkey'].to_h['Host'])
                linuxConnection.fileAppend("#{path}/Mastodon.env", "REDIS_HOST=#{valkeyHost}", options)
                if target['Valkey'].to_h['SecretId']
                    valkeyPassword = context.secrets.load(target['Valkey']['SecretId'], 'VALKEY_PASSWORD')
                    if !valkeyPassword.nil?
                        linuxConnection.fileAppend("#{path}/Mastodon.env", "REDIS_PASSWORD=#{valkeyPassword}", { **options, hide: true })
                    end
                end

                if target['Admin'].to_h['Username']
                    linuxConnection.fileAppend("#{path}/Mastodon.env", "ADMIN_USERNAME=#{target['Admin']['Username']}", options)
                end

                if target['Admin'].to_h['EMail']
                    adminPassword = context.secrets.load(target['SecretId'], 'ADMIN_PASSWORD')
                    if adminPassword.nil?
                        adminPassword = SecureRandom.alphanumeric(20)
                        context.secrets.store(target['SecretId'], 'ADMIN_PASSWORD', adminPassword)
                        context.secrets.print("Mastodon Admin '#{target['Admin']['EMail']}' password", adminPassword)
                    end
                    linuxConnection.fileAppend("#{path}/Mastodon.env", "ADMIN_EMAIL=#{target['Admin']['EMail']}", options)
                    linuxConnection.fileAppend("#{path}/Mastodon.env", "ADMIN_PASSWORD=#{adminPassword}", options)
                end

                if !target['SMTP'].to_h.empty?
                    emailHost = Podman.updateHost(target['SMTP']['Host'])

                    linuxConnection.fileAppend("#{path}/Mastodon.env", "SMTP_SERVER=#{emailHost}", options)

                    if target['SMTP']['Port']
                        linuxConnection.fileAppend("#{path}/Mastodon.env", "SMTP_PORT=#{target['SMTP']['Port']}", options)
                    end

                    if target['SMTP']['Username']
                        linuxConnection.fileAppend("#{path}/Mastodon.env", "SMTP_LOGIN=#{target['SMTP']['Username']}", options)
                    end

                    if target['SMTP']['SecretId']
                        smtpPassword = context.secrets.load(target['SMTP']['SecretId'], target['SMTP']['Username'].upcase + '_PASSWORD')
                        linuxConnection.fileAppend("#{path}/Mastodon.env", "SMTP_PASSWORD=#{smtpPassword}", { **options, hide: true })
                    end

                    if target['SMTP']['Port'] == 465
                        linuxConnection.fileAppend("#{path}/Mastodon.env", "SMTP_TLS=true", options)
                    end

                    if target['SMTP']['From']
                        linuxConnection.fileAppend("#{path}/Mastodon.env", "SMTP_FROM_ADDRESS=#{target['SMTP']['From']}", options)
                    end
                end

                if !target['Settings'].to_h.empty?
                    target['Settings'].each do |name, value|
                        linuxConnection.fileAppend("#{path}/Mastodon.env", "#{name}=#{value}", options)
                    end
                end

                linuxConnection.setUserGroup("#{path}/Mastodon.env", USER, USER, options)
                linuxConnection.setPrivate("#{path}/Mastodon.env", options)

                linuxConnection.upload(__dir__ + '/configlmm.rake', HOME_DIR + '/.configlmm/', options)
                linuxConnection.upload(__dir__ + '/entrypoint.sh', HOME_DIR + '/.configlmm/', options)
                linuxConnection.makeExecutable(HOME_DIR + '/.configlmm/entrypoint.sh', options)

                linuxConnection.upload(__dir__ + '/Mastodon.container', path, options)
                linuxConnection.upload(__dir__ + '/Mastodon-Sidekiq.container', path, options)
                linuxConnection.upload(__dir__ + '/Mastodon-Streaming.container', path, options)

                if target['Proxy'] == false
                    linuxConnection.fileReplace("#{path}/Mastodon.container", 'PublishPort=127.0.0.1:', 'PublishPort=0.0.0.0:', options)
                    linuxConnection.fileReplace("#{path}/Mastodon-Streaming.container", 'PublishPort=127.0.0.1:', 'PublishPort=0.0.0.0:', options)
                    linuxConnection.firewallAddPort("#{PORT}/tcp", options)
                    linuxConnection.firewallAddPort("#{STREAMING_PORT}/tcp", options)
                end

                linuxConnection.reloadUserServices(USER, options)
                linuxConnection.restartUserService(USER, 'Mastodon', options)
                linuxConnection.restartUserService(USER, 'Mastodon-Sidekiq', options)
                linuxConnection.restartUserService(USER, 'Mastodon-Streaming', options)
            end

            def deployNginxConfig(linuxConnection, target, activeState, context, options)
                if !target.key?('Proxy') || target['Proxy']
                    Nginx.withConnection(linuxConnection) do |nginxConnection|
                        target['Server'] = '127.0.0.1' unless target['Server']
                        nginxConnection.provision(__dir__, 'Mastodon', target, activeState, context, options)
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

            def cleanup(configs, state, context, options)
                cleanupType(:Mastodon, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        if !item['Config'].key?('Proxy') || item['Config']['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.cleanupConfig('Mastodon', context, options)
                                nginxConnection.reload(options)
                            end
                        elsif item['Config'].key?('Proxy') && item['Config']['Proxy'] == false
                            linuxConnection.firewallRemovePort("#{PORT}/tcp", options)
                            linuxConnection.firewallRemovePort("#{STREAMING_PORT}/tcp", options)
                        end

                        if !item['Config'].key?('Proxy') || item['Config']['Proxy'] == false
                            linuxConnection.stopUserService(USER, 'Mastodon-Sidekiq', options)
                            linuxConnection.stopUserService(USER, 'Mastodon-Streaming', options)
                            linuxConnection.stopUserService(USER, 'Mastodon', options)

                            path = Podman.containersPath(HOME_DIR)
                            linuxConnection.rm(path + '/Mastodon.container', options[:dry])
                            linuxConnection.rm(path + '/Mastodon-Streaming.container', options[:dry])
                            linuxConnection.rm(path + '/Mastodon-Sidekiq.container', options[:dry])

                            state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                            if options[:destroy]
                                linuxConnection.deleteUserAndGroup(USER, options)
                                linuxConnection.rm(HOME_DIR, options[:dry])
                                state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                            end
                        else
                            state.item(id)['Status'] = options[:destroy] ? State::STATUS_DESTROYED : State::STATUS_DELETED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end
