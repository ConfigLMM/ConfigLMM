require 'uri'

module ConfigLMM
    module LMM
        class Valkey < Framework::LinuxApp
            PACKAGE_NAME = 'Valkey'
            CONFIG_FILE = '/etc/redis/redis.conf'
            PID_FILE = '/run/redis/redis.pid'

            def actionValkeyDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)

                        serviceName = 'redis'
                        if linuxConnection.distroID == SUSE_ID
                            serviceName = 'redis@redis'
                            linuxConnection.exec("touch #{CONFIG_FILE}", false, options)

                            target['Settings'] ||= {}
                            target['Settings']['pidfile'] = PID_FILE
                            target['Settings']['supervised'] = 'systemd'
                            target['Settings']['dir'] = '/var/lib/redis/default/'
                        end

                        password = context.secrets.load(target['SecretId'], 'VALKEY_PASSWORD')
                        if password.nil?
                            password = SecureRandom.urlsafe_base64(20)
                            context.secrets.store(target['SecretId'], 'VALKEY_PASSWORD', password)
                        end

                        if !password.empty? && password != 'no' && target['Password'] != false
                            target['Settings']['requirepass'] = password
                        end

                        if target['Settings']
                            target['Settings']['bind'] = '127.0.0.1' unless target['Settings']['bind']
                            linuxConnection.updateFile(CONFIG_FILE, options, false) do |configLines|
                                target['Settings'].each do |name, value|
                                    configLines << "#{name} #{value}\n"
                                end
                                configLines
                            end
                        end

                        target['Settings']['requirepass'] = '<REDACTED>' if target['Settings']['requirepass']

                        linuxConnection.setUserGroup(CONFIG_FILE, 'redis', nil, options)
                        linuxConnection.setPrivate(CONFIG_FILE, options)

                        linuxConnection.ensureServiceAutoStart(serviceName, options)
                        linuxConnection.restartService(serviceName, options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Valkey, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        serviceName = 'redis'
                        serviceName = 'redis@redis' if linuxConnection.distroID == SUSE_ID

                        linuxConnection.stopService(serviceName, options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.rm('/etc/redis', options[:dry])

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
