require 'uri'

module ConfigLMM
    module LMM
        class Valkey < Framework::LinuxApp
            PACKAGE_NAME = 'Valkey'
            CONFIG_FILE = '/etc/valkey/valkey.conf'
            DEFAULT_DIR = '/var/lib/valkey/'

            REDIS_CONFIG_FILE = '/etc/redis/redis.conf'
            REDIS_PID_FILE = '/run/redis/redis.pid'
            REDIS_DEFAULT_DIR = '/var/lib/redis/'

            def actionValkeyDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)

                        config = {
                            serviceName: 'redis',
                            configFile: REDIS_CONFIG_FILE,
                            userName: 'redis'
                        }

                        target['Settings'] ||= {}
                        target['Settings']['supervised'] = 'systemd'

                        if linuxConnection.distroID == OS::SUSE_LEAP_ID
                            config[:serviceName] = 'redis@redis'
                            target['Settings']['pidfile'] = REDIS_PID_FILE
                            target['Settings']['dir'] = '/var/lib/redis/default/'
                        end

                        updateConfig(config, linuxConnection, activeState, options)

                        password = context.secrets.load(target['SecretId'], 'VALKEY_PASSWORD')
                        if password.nil?
                            password = SecureRandom.urlsafe_base64(20)
                            context.secrets.store(target['SecretId'], 'VALKEY_PASSWORD', password) unless options['dry']
                        end

                        if !password.empty? && password != 'no' && target['Password'] != false
                            target['Settings']['requirepass'] = password
                        end

                        linuxConnection.exec("touch #{config[:configFile]}", false, options)
                        if target['Settings']
                            target['Settings']['bind'] = '127.0.0.1 -::1' unless target['Settings']['bind']
                            target['Settings'].each do |name, value|
                                linuxConnection.fileReplace(config[:configFile], "^#{name}[[:blank:]]", "##{name} ", options)
                            end
                            linuxConnection.updateFile(config[:configFile], options, false) do |configLines|
                                target['Settings'].each do |name, value|
                                    configLines << "#{name} #{value}\n"
                                end
                                configLines
                            end
                        end

                        target['Settings']['requirepass'] = '<REDACTED>' if target['Settings']['requirepass']

                        linuxConnection.setUserGroup(config[:configFile], config[:userName], nil, options)
                        linuxConnection.setPrivate(config[:configFile], options)

                        linuxConnection.ensureServiceAutoStart(config[:serviceName], options)
                        linuxConnection.restartService(config[:serviceName], options)
                    end
                end
            end

            def updateConfig(config, linuxConnection, activeState, options)
                if linuxConnection.hasBinaries?('valkey-server', options)
                    config[:serviceName] = 'valkey-server'
                    config[:configFile] = CONFIG_FILE
                    config[:userName] = 'valkey'
                    activeState[:Valkey] = true
                end
                config
            end

            def actionValkeyBackup(id, activeState, context, options)
                target = activeState['Config'].to_h
                withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        cmd = activeState[:Valkey] ? 'valkey-cli' : 'redis-cli'
                        cmd += ' SAVE'
                        hide = false
                        if target['Settings']['requirepass']
                            password = context.secrets.load(target['SecretId'], 'VALKEY_PASSWORD')
                            cmd = 'REDISCLI_AUTH="' + password + '" ' + cmd
                            hide = true
                        end

                        result = linuxConnection.exec(cmd, false, { **options, hide: hide })
                        if result.downcase.include?('error') || !result.include?('OK')
                            prompt.error(result)
                            raise result
                        end

                        defaultDir = activeState[:Valkey] ? DEFAULT_DIR : REDIS_DEFAULT_DIR
                        dir = target['Settings']['dir'] ? target['Settings']['dir'] : defaultDir
                        linuxConnection.download(dir + 'dump.rdb', options['output'] + '/dump.rdb', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Valkey, configs, state, context, options) do |item, id, state, context, options, connection|
                    isValkey = !!state.item(id)[:Valkey]
                    Linux.withConnection(connection) do |linuxConnection|
                        serviceName = isValkey ? 'valkey' : 'redis'
                        serviceName = 'redis@redis' if linuxConnection.distroID == OS::SUSE_LEAP_ID

                        linuxConnection.stopService(serviceName, options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            configFolder = isValkey ? '/etc/valkey' : '/etc/redis'
                            linuxConnection.rm(configFolder, options[:dry])

                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

            def self.connectionURL(params)
                args = { scheme: 'redis', host: params[:host].to_s, path: '/' }
                args[:scheme] += 's' if params[:ssl]
                args[:path] += params[:db] if params[:db]

                if args[:host].include?(':')
                    args[:host], args[:port] = args[:host].split(':')
                end

                userinfo = ''
                if params[:username]
                    userinfo = URI.encode_uri_component(params[:username])
                end
                if params.key?(:password) && !params[:password].nil?
                    userinfo += ':' + URI.encode_uri_component(params[:password])
                end
                args[:userinfo] = userinfo unless userinfo.empty?

                URI::Generic.build(args).to_s
            end
        end

    end
end
