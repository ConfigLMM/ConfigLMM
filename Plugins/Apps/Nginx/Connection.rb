
module ConfigLMM
    module LMM
        class NginxConnection

            NGINX_PACKAGE = 'nginx'
            CONFIG_DIR = '/etc/nginx/'
            WWW_DIR = '/srv/www/'

            attr_reader :connection
            attr_reader :nginxVersion

            def initialize(connection)
                @connection = connection
            end

            def nginxVersion
                # Allow to fail when nginx is not installed
                @nginxVersion ||= connection.exec('nginx -v', true).strip.split('/')[1].to_f
            end

            def reload(options)
                connection.reloadService(:nginx, options)
            end

            def writeConfig(dir, name, target, activeState, context, options)
                outputFolder = options['output']

                config = prepareConfig(target)

                config['NginxVersion'] = nginxVersion
                template = ERB.new(File.read(dir + '/' + name + '.conf.erb'))
                name = config['ConfigName'] if config['ConfigName']
                connection.local.renderTemplate(template, config, outputFolder + '/nginx/servers-lmm/' + name.to_s + '.conf', options)
            end

            def deployAllConfigs(target, activeState, context, options)
                outputFolder = options['output'] + '/nginx/servers-lmm'

                connection.createDirs(options, CONFIG_DIR)
                connection.uploadFolder(outputFolder, CONFIG_DIR, options)
                if target['TLS']
                    connection.firewallAddService('https', options)
                else
                    connection.firewallAddService('http', options)
                end
                reload(options)
            end

            def cleanupConfig(name, context, options)
                connection.rm('/etc/nginx/servers-lmm/' + name + '.conf', options['dry'])
            end

            def provision(dir, configName, target, activeState, context, options)
                connection.ensurePackage(NGINX_PACKAGE, options)
                connection.ensureServiceAutoStart(:nginx, options)
                writeConfig(dir, configName, target, activeState, context, options)
                connection.startService(:nginx, options)
                deployAllConfigs(target, activeState, context, options)
                reload(options)
            end

            def provisionProxy(server, name, target, activeState, context, options)
                target = target.dup
                target['Proxy'] = server
                target['Name'] = name if name
                target['ConfigName'] = target['Name']
                provision(__dir__, 'proxy', target, activeState, context, options)
            end

            private

            def prepareConfig(target)
                config = target.dup
                config['TLS'] = true if config['TLS'].nil?

                if !config['Port']
                    config['Port'] = config['TLS'] ? 443 : 80
                end
                if config['Domain']
                    config['Domain'] = Addressable::IDNA.to_ascii(config['Domain'])
                end
                if config['Server'] && !config['Server'].start_with?('/') && !config['Server'].include?(':/')
                    config['Server'] = Addressable::IDNA.to_ascii(config['Server'])
                end
                if config['AuthentikDomain']
                    config['AuthentikDomain'] = Addressable::IDNA.to_ascii(config['AuthentikDomain'])
                end
                config
            end
        end
    end
end
