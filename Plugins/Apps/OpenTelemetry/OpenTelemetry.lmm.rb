require 'yaml'
require 'uri'
require 'addressable/idna'

module ConfigLMM
    module LMM
        class OpenTelemetry < Framework::Plugin

            PACKAGE_NAME = 'otelcol-contrib'
            SERVICE_NAME = :'otelcol-contrib'

            def actionOtelCollectorDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        linuxConnection.createDirs(options, '/var/lib/otelcol/file_storage')
                        linuxConnection.setUserGroup('/var/lib/otelcol/file_storage', 'otelcol-contrib', 'otelcol-contrib', options)
                        linuxConnection.exec("usermod -a -G systemd-journal otelcol-contrib", false, options)

                        config = YAML.load_file(__dir__ + '/Config/config.yaml')
                        configureEnvironment(config, target['Environment'])
                        configureServices(config, target['Services'], linuxConnection, options)
                        configureReceivers(config, target['Receivers'])
                        configureProcessors(config, target['Processors'])
                        configureExporters(config, target['Exporters'])
                        configFile = options['output'] + '/config.yaml'
                        File.write(configFile, config.to_yaml)

                        linuxConnection.upload(configFile, '/etc/otelcol-contrib/', options)

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:OtelCollector, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                      linuxConnection.stopService(SERVICE_NAME, options)
                      linuxConnection.disableService(SERVICE_NAME, options)
                      linuxConnection.removePackage(PACKAGE_NAME, options)

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.rm('/etc/otelcol-contrib', options[:dry])
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

            private

            def configureEnvironment(config, environment)
                return unless environment
                environmentNameAttr = config['processors']['resource']['attributes'].find { |attrs| attrs['key'] == 'deployment.environment.name' }
                environmentNameAttr['value'] = environment
                # This is deprecated but SigNoz still uses it
                environmentNameAttr = config['processors']['resource']['attributes'].find { |attrs| attrs['key'] == 'deployment.environment' }
                environmentNameAttr['value'] = environment
            end

            def configureServices(config, services, linuxConnection, options)
                services.to_h.each do |name, settings|
                    if name == 'nginx'
                        linuxConnection.exec("usermod -a -G nginx otelcol-contrib", false, options)
                        receiverName = 'filelog/nginx'
                        config['receivers'][receiverName] = config['receiverTemplate'][receiverName]
                        config['service']['pipelines']['logs']['receivers'] << receiverName
                    elsif name == 'php'
                        settings['Users'].to_a.each do |user|
                            linuxConnection.exec("usermod -a -G #{user} otelcol-contrib", false, options)
                        end
                        receiverName = 'filelog/php'
                        config['receivers'][receiverName] = config['receiverTemplate'][receiverName]
                        config['service']['pipelines']['logs']['receivers'] << receiverName
                        receiverName = 'filelog/php_json'
                        config['receivers'][receiverName] = config['receiverTemplate'][receiverName]
                        config['service']['pipelines']['logs']['receivers'] << receiverName
                    end
                end
                config.delete('receiverTemplate')
            end

            def configureReceivers(config, receivers)
                return unless receivers
                config['receivers'] = self.class.mergeConfig(config['receivers'], receivers)
                config['receivers'].each do |name, data|
                    types = []
                    receiverType = name.split('/').first
                    if receiverType == 'jaeger' || receiverType == 'zipkin'
                        types << 'traces'
                    elsif receiverType == 'prometheus' || receiverType == 'hostmetrics'
                        types << 'metrics'
                    elsif receiverType == 'journald' || receiverType == 'filelog'
                        types << 'logs'
                    else
                        types = ['traces', 'metrics', 'logs']
                    end

                    if types.include?('traces')
                        config['service']['pipelines']['traces']['receivers'] << name unless config['service']['pipelines']['traces']['receivers'].include?(name)
                    end
                    if types.include?('metrics')
                        config['service']['pipelines']['metrics']['receivers'] << name unless config['service']['pipelines']['metrics']['receivers'].include?(name)
                    end
                    if types.include?('logs')
                        config['service']['pipelines']['logs']['receivers'] << name unless config['service']['pipelines']['logs']['receivers'].include?(name)
                    end
                end
            end

            def configureProcessors(config, processors)
                return unless processors
                config['processors'] = self.class.mergeConfig(config['processors'], processors)
            end

            def configureExporters(config, exporters)
                return unless exporters
                config['exporters'] = self.class.mergeConfig(config['exporters'], exporters)
                config['exporters'].each do |name, data|
                    types = ['traces', 'metrics', 'logs']
                    if types.include?('traces')
                        config['service']['pipelines']['traces']['exporters'] << name unless config['service']['pipelines']['traces']['exporters'].include?(name)
                    end
                    if types.include?('metrics')
                        config['service']['pipelines']['metrics']['exporters'] << name unless config['service']['pipelines']['metrics']['exporters'].include?(name)
                    end
                    if types.include?('logs')
                        config['service']['pipelines']['logs']['exporters'] << name unless config['service']['pipelines']['logs']['exporters'].include?(name)
                    end
                    if data['endpoint']
                        data['endpoint'] = Addressable::IDNA.to_ascii(data['endpoint'])
                        config['exporters'][name] = data
                    end
                end
            end

            def self.mergeConfig(defaultConfig, targetConfig)
                return defaultConfig unless targetConfig
                defaultConfig.merge(targetConfig) { |key, a_val, b_val| a_val.merge(b_val) }
            end
        end
    end
end
