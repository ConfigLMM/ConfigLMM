require 'yaml'
require 'uri'

module ConfigLMM
    module LMM
        class SigNoz < Framework::Plugin

            VERSION = 'v0.79.1'
            COLLECTOR_VERSION = 'v0.111.39'

            USER = 'signoz'
            COLLECTOR_USER = 'signoz-collector'
            FRONTEND_USER = 'signoz-frontend'
            HOME_DIR = '/var/lib/signoz'
            COLLECTOR_HOME_DIR = '/var/lib/signoz-collector'
            FRONTEND_HOME_DIR = '/var/lib/signoz-frontend'
            HOST_IP = '10.0.2.2'
            DB_ANALYTICS = 'signoz_analytics'
            DB_METADATA = 'signoz_metadata'
            DB_TRACES = 'signoz_traces'
            DB_METRICS = 'signoz_metrics'
            DB_LOGS = 'signoz_logs'

            def actionSigNozDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !target.key?('Proxy') || target['Proxy'] == false
                            deploySigNozService(linuxConnection, target, activeState, context, options)
                        end

                        deploySigNozProxy(id, linuxConnection, target, activeState, context, options)

                        if !target.key?('Proxy') || target['Proxy'] == false
                            linuxConnection.reloadUserServices(USER, options)
                            linuxConnection.restartUserService(USER, 'SigNoz-Migrator', options)
                            linuxConnection.restartUserService(USER, 'SigNoz', options)
                        end
                    end
                end
            end

            def deploySigNozService(linuxConnection, target, activeState, context, options)
                Podman.ensurePresent(linuxConnection, options)
                username, password = self.configureClickHouseSigNoz(target, linuxConnection, activeState, context, options)
                Podman.createUser(USER, HOME_DIR, 'SigNoz', linuxConnection, options)
                linuxConnection.withUserShell(USER) do |shell|
                    shell.createDirs(options, '~/data', '~/config/dashboards')
                end

                path = Podman.containersPath(HOME_DIR)

                dbUrl = self.class.buildEndpoint(target['Database']['HostName'],
                                                 target['Database']['Port'],
                                                 '',
                                                 username,
                                                 password)

                jwtSecret = SecureRandom.alphanumeric(30)

                linuxConnection.fileWrite("#{path}/SigNoz.env", 'TELEMETRY_ENABLED=false', options)
                linuxConnection.fileAppend("#{path}/SigNoz.env", 'SIGNOZ_JWT_SECRET=' + jwtSecret, options)
                linuxConnection.fileAppend("#{path}/SigNoz.env", 'SIGNOZ_TELEMETRYSTORE_PROVIDER=clickhouse', options)
                linuxConnection.fileAppend("#{path}/SigNoz.env", "SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN=#{dbUrl}", options)

                if target['SMTP'] && target['SMTP']['Host']
                    port = target['SMTP']['Port']
                    port = 25 unless port
                    linuxConnection.fileAppend(path + '/SigNoz.env', 'SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__SMARTHOST=' + target['SMTP']['Host'] + ':' + port.to_s, options)
                    if target['SMTP']['Username']
                        linuxConnection.fileAppend(path + '/SigNoz.env', 'SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__USERNAME=' + target['SMTP']['Username'], options)
                    end
                    if target['SMTP']['SecretId']
                        smtpPassword = context.secrets.load(target['SMTP']['SecretId'], target['SMTP']['Username'].upcase + '_PASSWORD')
                        linuxConnection.fileAppend(path + '/SigNoz.env', 'SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__PASSWORD=' + smtpPassword.to_s, { **options, hide: true })
                    end
                    if target['SMTP']['FromAddress']
                        linuxConnection.fileAppend(path + '/SigNoz.env', 'SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__FROM=' + target['SMTP']['Username'], options)
                    end
                end

                linuxConnection.setUserGroup("#{path}/SigNoz.env", USER, USER, options)
                linuxConnection.setPrivate("#{path}/SigNoz.env", options)

                config = YAML.load_file(__dir__ + '/Config/prometheus.yml')
                config['remote_read'].first['url'] = self.class.buildEndpoint(target['Database']['HostName'],
                                                                              target['Database']['Port'],
                                                                              DB_METRICS)

                configFile = options['output'] + '/prometheus.yml'
                File.write(configFile, config.to_yaml)

                linuxConnection.upload(__dir__ + '/SigNoz.container', path, options)
                linuxConnection.upload(__dir__ + '/SigNoz-Migrator.container', path, options)
                linuxConnection.upload(configFile, HOME_DIR + '/config', options)
                linuxConnection.upload(__dir__ + '/Config/alerts.yml', HOME_DIR + '/config', options)

                linuxConnection.fileReplace("#{path}/SigNoz.container", '\$VERSION', VERSION, options)
                linuxConnection.fileReplace("#{path}/SigNoz-Migrator.container", '\$VERSION', COLLECTOR_VERSION, options)
                linuxConnection.fileReplace("#{path}/SigNoz-Migrator.container", '\$DSN', dbUrl, { **options, hide: true })
            end

            def deploySigNozProxy(id, linuxConnection, target, activeState, context, options)
                if !target.key?('Proxy') || target['Proxy']
                    raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']
                    Nginx.withConnection(linuxConnection) do |nginxConnection|
                        target['Server'] = '127.0.0.1:18600' unless target['Server']
                        target['Server'] += ':18600' unless target['Server'].include?(':')
                        target['ConfigName'] = target['Name']
                        nginxConnection.provision(__dir__, 'SigNoz', target, activeState, context, options)
                    end
                elsif target.key?('Proxy') && target['Proxy'] == false
                    path = Podman.containersPath(HOME_DIR)
                    linuxConnection.fileReplace("#{path}/SigNoz.container", 'PublishPort=127.0.0.1:18600:', 'PublishPort=0.0.0.0:18600:', options)
                    linuxConnection.firewallAddPort('18600/tcp', options)
                end
            end

            def actionSigNozCollectorDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        username, password = self.configureClickHouseCollector(target, linuxConnection, activeState, context, options)
                        Podman.createUser(COLLECTOR_USER, COLLECTOR_HOME_DIR, 'SigNoz Collector', linuxConnection, options)

                        config = YAML.load_file(__dir__ + '/Config/otel-collector-config.yaml')

                        config['exporters']['clickhousetraces']['datasource'] = self.class.buildEndpoint(target['Database']['HostName'],
                                                                                                         target['Database']['Port'],
                                                                                                         DB_TRACES,
                                                                                                         username,
                                                                                                         password)

                        config['exporters']['clickhousemetricswrite']['endpoint'] = self.class.buildEndpoint(target['Database']['HostName'],
                                                                                                            target['Database']['Port'],
                                                                                                            DB_METRICS,
                                                                                                            username,
                                                                                                            password)

                        config['exporters']['clickhousemetricswrite/prometheus']['endpoint'] = self.class.buildEndpoint(target['Database']['HostName'],
                                                                                                                        target['Database']['Port'],
                                                                                                                        DB_METRICS,
                                                                                                                        username,
                                                                                                                        password)

                        config['exporters']['signozclickhousemetrics']['dsn'] = self.class.buildEndpoint(target['Database']['HostName'],
                                                                                                         target['Database']['Port'],
                                                                                                         DB_METRICS,
                                                                                                         username,
                                                                                                         password)

                        config['exporters']['clickhouselogsexporter']['dsn'] = self.class.buildEndpoint(target['Database']['HostName'],
                                                                                                        target['Database']['Port'],
                                                                                                        DB_LOGS,
                                                                                                        username,
                                                                                                        password)

                        configFile = options['output'] + '/otel-collector-config.yaml'
                        File.write(configFile, config.to_yaml)

                        linuxConnection.upload(__dir__ + '/SigNoz-Collector.container', Podman.containersPath(COLLECTOR_HOME_DIR), options)
                        linuxConnection.upload(configFile, COLLECTOR_HOME_DIR, options)
                        linuxConnection.upload(__dir__ + '/Config/otel-collector-opamp-config.yaml', COLLECTOR_HOME_DIR, options)

                        path = Podman.containersPath(COLLECTOR_HOME_DIR)
                        linuxConnection.fileReplace("#{path}/SigNoz-Collector.container", '\$VERSION', COLLECTOR_VERSION, options)

                        if target['Listen']
                            linuxConnection.fileReplace("#{path}/SigNoz-Collector.container", 'PublishPort=127.0.0.1:', "PublishPort=#{target['Listen']}:", options)
                            linuxConnection.firewallAddPort('4317/tcp', options)
                            linuxConnection.firewallAddPort('4318/tcp', options)
                        end

                        linuxConnection.reloadUserServices(COLLECTOR_USER, options)
                        linuxConnection.restartUserService(COLLECTOR_USER, 'SigNoz-Collector', options)
                    end
                end
            end

            def configureClickHouseSigNoz(target, linuxConnection, activeState, context, options)
                target['Database'] ||= {}
                ClickHouse.defaults(target['Database'])
                username = target['Database']['Username'] || context.secrets.load(target['SecretId'], 'CLICKHOUSE_USERNAME') || USER
                context.secrets.store(target['SecretId'], 'CLICKHOUSE_USERNAME', username)
                password = context.secrets.load(target['SecretId'], 'CLICKHOUSE_PASSWORD')
                if password.nil?
                    password = SecureRandom.alphanumeric(20)
                    context.secrets.store(target['SecretId'], 'CLICKHOUSE_PASSWORD', password)
                end

                ClickHouse.withConnection(target['Database'], linuxConnection, context.secrets, options) do |connection|
                    connection.createUser(username, password, nil, options)
                    connection.createDB(DB_ANALYTICS, ClickHouse::DEFAULT_CLUSTER, options)
                    connection.createDB(DB_METADATA, ClickHouse::DEFAULT_CLUSTER, options)
                    connection.grantDB('ALL', username, DB_ANALYTICS, nil, options)
                    connection.grantDB('ALL', username, DB_METADATA, nil, options)
                    connection.grantDB('ALL', username, DB_TRACES, nil, options)
                    connection.grantDB('ALL', username, DB_METRICS, nil, options)
                    connection.grantDB('ALL', username, DB_LOGS, nil, options)
                    connection.grant('SELECT', username, 'system.clusters', nil, options)
                    connection.grant('SELECT', username, 'system.distributed_ddl_queue', nil, options)
                    connection.grant('SELECT', username, 'system.disks', nil, options)
                    connection.grantCluster(username, nil, options)
                    connection.grantRemote(username, nil, options)
                end

                if target['Database']['HostName'] == 'localhost'
                    target['Database']['HostName'] = HOST_IP
                end
                [username, password]
            end

            def configureClickHouseCollector(target, linuxConnection, activeState, context, options)
                target['Database'] ||= {}
                ClickHouse.defaults(target['Database'])
                username = target['Database']['Username'] || context.secrets.load(target['SecretId'], 'CLICKHOUSE_USERNAME') || 'otel'
                context.secrets.store(target['SecretId'], 'CLICKHOUSE_USERNAME', username)
                password = context.secrets.load(target['SecretId'], 'CLICKHOUSE_PASSWORD')
                if password.nil?
                    password = SecureRandom.alphanumeric(20)
                    context.secrets.store(target['SecretId'], 'CLICKHOUSE_PASSWORD', password)
                end

                ClickHouse.withConnection(target['Database'], linuxConnection, context.secrets, options) do |connection|
                    connection.createUser(username, password, nil, options)
                    connection.createDB(DB_TRACES, ClickHouse::DEFAULT_CLUSTER, options)
                    connection.createDB(DB_METRICS, ClickHouse::DEFAULT_CLUSTER, options)
                    connection.createDB(DB_LOGS, ClickHouse::DEFAULT_CLUSTER, options)
                    connection.grantDB('CREATE DATABASE', username, DB_TRACES, nil, options)
                    connection.grantDB('INSERT', username, DB_TRACES, nil, options)
                    connection.grantDB('SELECT', username, DB_TRACES, nil, options)
                    connection.grantDB('INSERT', username, DB_METRICS, nil, options)
                    connection.grantDB('SELECT', username, DB_METRICS, nil, options)
                    connection.grantDB('INSERT', username, DB_LOGS, nil, options)
                    connection.grantDB('SELECT', username, DB_LOGS, nil, options)
                    connection.grant('SELECT', username, 'system.clusters', nil, options)
                    connection.grantCluster(username, nil, options)
                end

                if target['Database']['HostName'] == 'localhost'
                    target['Database']['HostName'] = HOST_IP
                end
                [username, password]
            end

            def self.buildEndpoint(hostname, port, database, username = nil, password = nil)
                query = ''
                if username
                    username = URI.encode_uri_component(username)
                    query = "?username=#{username}"
                    if password
                        password = URI.encode_uri_component(password)
                        query += "&password=#{password}"
                    end
                end
                "tcp://#{hostname}:#{port}/#{database}#{query}"
            end

            def cleanup(configs, state, context, options)
                cleanupType(:SigNozCollector, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.stopUserService(USER, 'signoz-otel-collector', options)

                        path = Podman.containersPath(COLLECTOR_HOME_DIR)
                        linuxConnection.rm(path + 'signoz-otel-collector.container', options[:dry])

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            username = context.secrets.load(item['Config']['SecretId'], 'CLICKHOUSE_USERNAME')
                            if !username.nil?
                                ClickHouse.withConnection(item['Config']['Database'], connection, context.secrets, options) do |connection|
                                    connection.dropUser(username)
                                end
                            end
                            linuxConnection.deleteUserAndGroup(COLLECTOR_USER, options)
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
                cleanupType(:SigNoz, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !item['Config'].key?('Proxy') || item['Config']['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.cleanupConfig('SigNoz', context, options)
                                nginxConnection.reload(options)
                            end
                        elsif item['Config'].key?('Proxy') && item['Config']['Proxy'] == false
                            linuxConnection.firewallRemovePort('3301/tcp', options)
                        end

                        linuxConnection.stopUserService(USER, 'SigNoz', options)
                        linuxConnection.stopUserService(USER, 'SigNoz-Migrator', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + 'SigNoz.container', options[:dry])
                        linuxConnection.rm(path + 'SigNoz-Migrator.container', options[:dry])

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            ClickHouse.withConnection(item['Config']['Database'], connection, context.secrets, options) do |connection|
                                username = context.secrets.load(item['Config']['SecretId'], 'CLICKHOUSE_USERNAME')
                                if !username.nil?
                                    connection.dropUser(username, nil, options)
                                end
                                connection.dropDB(DB_TRACES, ClickHouse::DEFAULT_CLUSTER, options)
                                connection.dropDB(DB_METRICS, ClickHouse::DEFAULT_CLUSTER, options)
                                connection.dropDB(DB_LOGS, ClickHouse::DEFAULT_CLUSTER, options)
                            end
                            linuxConnection.deleteUserAndGroup(USER, connection, options[:dry])
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end
