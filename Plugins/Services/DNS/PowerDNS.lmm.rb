
# require 'fog'
require 'uri'
require 'addressable/uri'
require 'addressable/idna'
require 'fog/powerdns'
require 'http'

module ConfigLMM
    module LMM
        class PowerDNS < Framework::DNS

            CONFIG_DIR = '/etc/pdns/pdns.d'
            DEFAULT_HOST = 'localhost'
            DEFAULT_PORT = 8081
            SSH_TIMEOUT = 10
            PACKAGE_NAME = 'PowerDNS'
            SERVICE_NAME = 'pdns'
            USER = 'pdns'

            # TODO
            # def actionPowerDNSValidate(id, target, activeState, context, options)
            #     We should check that target['DNS'] looks like valid config
            #end

            def actionPowerDNSBuild(id, target, activeState, context, options)
                if target['Settings']
                    prepareSettings(target)
                    targetDir = options['output'] + CONFIG_DIR + '/'
                    mkdir(targetDir, options['dry'])
                    content = ''
                    target['Settings'].each do |name, value|
                        content += "#{name}=#{value}\n"
                    end
                    fileWrite(targetDir + 'configlmm.conf', content, options['dry'])
                end
            end

            def actionPowerDNSRefresh(id, target, activeState, context, options)

                connect(id, target, activeState, context, options) do |host, port, key|
                    refreshDNS(host, port, key, target['DNS'], activeState) if target['DNS']
                end
            end

            #def actionPowerDNSDiff(id, target, activeState, context, options)
            #end

            def actionPowerDNSDeploy(id, target, activeState, context, options)
                #actionPowerDNSDiff(id, target, activeState, context, options)

                deploySettings(target, activeState, context, options)
                connect(id, target, activeState, context, options) do |host, port, key|
                    if target['TSIG']
                        updateTSIG(host, port, key, target, context)
                    end
                    if target['DNS']
                        updateDNS(host, port, key, target['DNS'])
                    end
                    if target['Metadata']
                        updateMetadata(host, port, key, target['Metadata'])
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:PowerDNS, configs, state, context, options) do |item, id, state, context, options, connection|
                    if item['Config']['Deploy']
                        Linux.withConnection(connection) do |linuxConnection|
                            linuxConnection.stopService(SERVICE_NAME, options)
                            linuxConnection.firewallRemoveService('dns', options)
                            linuxConnection.removePackage(PACKAGE_NAME, options)

                            state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                            if options[:destroy]
                                item['Config']['Database'] ||= {}
                                PostgreSQL.withConnection(item['Config']['Database'], linuxConnection) do |connectionDB|
                                    connectionDB.dropUserAndDB(USER, options)
                                end
                                linuxConnection.rm('/etc/pdns', options[:dry])
                                state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                            end
                        end
                    else
                        # TODO
                    end
                end
            end

            def authenticate(actionMethod, target, activeState, context, options)
                true
            end

            private

            def refreshDNS(host, port, key, targetDNS, activeState)
                dns = Fog::DNS::PowerDNS.new({
                  host: host,
                  port: port,
                  pdns_api_key: key
                })

                server = 'localhost'

                targetDNS.each do |domain, info|
                    domain = Addressable::IDNA.to_ascii(domain)
                    canonicalDomain = domain + '.'

                    result = dns.list_zones(server)
                    domainsInfo = result.map { |info| [ info['name'], { :_meta_ => info } ] }.flatten
                    activeState['DNS'] = Hash[*domainsInfo]
                    activeState['DNS'].each do |domain, info|
                        zone = dns.get_zone(server, domain)
                        info[:_records_] = zone.to_h
                    end
                end
            end

            def updateDNS(host, port, key, targetDNS)

                dns = Fog::DNS::PowerDNS.new({
                  host: host,
                  port: port,
                  pdns_api_key: key
                })

                server = 'localhost'
                targetDNS.each do |domain, info|
                    domain = Addressable::IDNA.to_ascii(domain)
                    canonicalDomain = domain + '.'

                    if !dns.list_zones(server).map { |zone| zone['name'].downcase }.include?(canonicalDomain.downcase)
                        dns.create_zone(server, canonicalDomain, [], { kind: 'Native' }.update(info['!'].to_h))
                    elsif !info['!'].to_h.empty?
                        dns.update_zone(server, canonicalDomain, { kind: 'Native' }.update(info['!'].to_h))
                    end

                    zone = dns.get_zone(server, canonicalDomain)

                    rrsets = []
                    remove = []
                    info.each do |name, data|
                        next if name == '!'
                        name = Framework::Variables.stringEval(name, context)
                        fullName = Addressable::IDNA.to_ascii(name) + '.' + Addressable::IDNA.to_ascii(domain) + '.'
                        fullName = Addressable::IDNA.to_ascii(domain) + '.' if name == '@'
                        self.processDNS(domain, data, context).each do |type, records|
                            #remove += removeConflicting(zone, fullName, type)
                            rrset = {
                                name: fullName,
                                type: type,
                                ttl: records.first[:ttl],
                                changetype: 'REPLACE',
                                records: []
                            }
                            records.each do |record|
                                record[:content] = Addressable::IDNA.to_ascii(record[:content]) + '.' if type == 'CNAME' || type == 'ALIAS' || type == 'NS'
                                if type == 'TXT' && record[:content][0] != '"'
                                    record[:content] = '"' + record[:content] + '"'
                                elsif type == 'MX'
                                    priority, name = record[:content].split(' ')
                                    name = Addressable::IDNA.to_ascii(name) + '.'
                                    record[:content] = [priority, name].join(' ')
                                elsif type == 'SOA'
                                    ns, email, serial, refresh, again, expire, ttl = record[:content].split(' ')
                                    record[:content] = [Addressable::IDNA.to_ascii(ns) + '.',
                                                        Addressable::IDNA.to_ascii(email) + '.',
                                                        serial.to_s,
                                                        refresh.to_s,
                                                        again.to_s,
                                                        expire.to_s,
                                                        ttl.to_s].join(' ')
                                end
                                rrset[:records] << { content: record[:content], disabled: false }
                            end
                            rrsets << rrset
                        end
                    end

                    if !remove.empty?
                        dns.update_rrsets('localhost', zone['name'], { 'rrsets' => remove })
                    end
                    dns.update_rrsets('localhost', zone['name'], { 'rrsets' => rrsets })
                end

            end

            def updateTSIG(host, port, key, target, context)
                server = 'localhost'
                url = "http://#{host}:#{port}/api/v1/servers/#{server}/tsigkeys"
                headers = { 'X-Api-Key' => key }
                target['TSIG'].each do |name, info|
                    data = { name: name, algorithm: info['Algorithm'] }
                    response = HTTP.headers(headers).post(url, json: data)
                    if response.status == 201
                        result = response.parse(:json)
                        key = result['key']
                        context.secrets.store(target['SecretId'], "TSIG_#{result['name'].upcase}_KEY", key)
                        context.secrets.print("TSIG #{result['name']} Key", key)
                    elsif response.status != 409
                        prompt.say(response.body.to_s, :color => :red)
                        raise 'Failed to create TSIG key!'
                    end
                end
            end

            def updateMetadata(host, port, key, targetMetadata)
                server = 'localhost'
                headers = { 'X-Api-Key' => key }
                targetMetadata.each do |zone, info|
                    info.each do |kind, metadata|
                        url = "http://#{host}:#{port}/api/v1/servers/#{server}/zones/#{Addressable::IDNA.to_ascii(zone)}/metadata/#{kind}"
                        metadata = [metadata] unless metadata.is_a?(Array)
                        data = { kind: kind, metadata: metadata }
                        response = HTTP.headers(headers).put(url, json: data)
                        if response.status != 200
                            prompt.say(response.body.to_s, :color => :red)
                            raise "Failed to update Metadata for #{zone}!"
                        end
                    end
                end
            end

            def prepareSettings(target)
                if !target['Settings'].key?('api')
                    target['Settings']['api'] = 'yes'
                end
                if !target['Settings'].key?('expand-alias')
                    target['Settings']['expand-alias'] = 'yes'
                end
                if !target['Settings'].key?('launch')
                    target['Settings']['launch'] = 'gpgsql'
                    target['Settings']['gpgsql-host'] = '/run/postgresql'
                    target['Settings']['gpgsql-user'] = USER
                    target['Settings']['gpgsql-dbname'] = USER
                end
            end

            def deploySettings(target, activeState, context, options)
                target['Deploy'] = !!target['Settings'] unless target.key?('Deploy')
                if target['Deploy']
                    self.withConnection(target['Location'], target) do |connection|
                        Linux.withConnection(connection) do |linuxConnection|
                            linuxConnection.ensurePackages([PACKAGE_NAME], options)
                            linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)
                            if target['Settings']
                                prepareSettings(target)
                                linuxConnection.createDirs(options, CONFIG_DIR)
                                linuxConnection.fileReplace('/etc/pdns/pdns.conf', '# include-dir=', "include-dir=#{CONFIG_DIR}", options)
                                linuxConnection.upload(options['output'] + CONFIG_DIR + '/configlmm.conf', CONFIG_DIR + '/configlmm.conf', options)
                                apiKeyFile = CONFIG_DIR + '/apiKey.conf'
                                apiKey = context.secrets.load(target['SecretId'], 'POWERDNS_API_KEY')
                                if linuxConnection.filePresent?(apiKeyFile, options)
                                    if !apiKey
                                        if options['dry']
                                            linuxConnection.exec("cat #{apiKeyFile} | grep api-key | cut -d '=' -f 2", false, options)
                                        end
                                        apiKey = linuxConnection.exec("cat #{apiKeyFile} | grep api-key | cut -d '=' -f 2", false, { **options, 'dry' => false }).strip
                                        context.secrets.store(target['SecretId'], 'POWERDNS_API_KEY', apiKey)
                                    end
                                else
                                    if !apiKey
                                        apiKey = SecureRandom.urlsafe_base64(60)
                                        context.secrets.store(target['SecretId'], 'POWERDNS_API_KEY', apiKey)
                                        context.secrets.print('PowerDNS API Key', apiKey)
                                    end
                                    linuxConnection.fileWrite(apiKeyFile, "api-key=#{apiKey}", options)
                                    linuxConnection.setUserGroup(apiKeyFile, USER, USER, options)
                                    linuxConnection.setPrivate(apiKeyFile, options)
                                end
                                if !target.key?('Database') || target['Database']
                                    self.configurePostgreSQL(target['Settings'], linuxConnection, options)
                                end
                            end
                            linuxConnection.firewallAddService('dns', options)
                            linuxConnection.restartService(SERVICE_NAME, options)
                        end
                    end
                end
            end

            def configurePostgreSQL(settings, linuxConnection, options)
                dbSettings = {}
                dbSettings['HostName'] = settings['gpgsql-host']
                dbSettings['HostName'] = 'localhost' if dbSettings['HostName'].start_with?('/')
                PostgreSQL.withConnection(dbSettings, linuxConnection) do |postgresConnection|
                    password = SecureRandom.alphanumeric(20)
                    postgresConnection.createUserAndDB(USER, password, options)
                    if linuxConnection.filePresent?('/usr/share/doc/pdns/schema.pgsql.sql')
                        postgresConnection.importSQL(USER, USER, '/usr/share/doc/pdns/schema.pgsql.sql', options)
                    else
                        postgresConnection.importSQL(USER, USER, '/usr/share/doc/packages/pdns/schema.pgsql.sql', options)
                    end
                    postgresConnection.updateOwner(USER, USER, options)
                end
            end

            def connect(id, target, activeState, context, options)
                host = DEFAULT_HOST
                port = DEFAULT_PORT
                key = context.secrets.load(target['SecretId'], 'POWERDNS_API_KEY')
                raise Framework::PluginProcessError.new('PowerDNS missing API key!') unless key

                sshServer = nil
                sshUser = nil
                sshPort = nil
                sshPassword = context.secrets.load(target['SecretId'], 'POWERDNS_SSH_PASSWORD')

                if target['Location']
                    uri = Addressable::URI.parse(target['Location'])
                    if uri.scheme == 'ssh'
                        sshServer = uri.hostname
                        sshUser = uri.user
                        sshPort = uri.port if uri.port
                        params = {}
                        params = CGI.parse(uri.query) if uri.query
                        host = params['host'].first if params['host']
                        port = params['port'].first if params['port']
                    elsif uri.scheme == 'pdns'
                        host = uri.hostname
                        port = uri.port if uri.port
                    else
                        raise Framework::PluginProcessError.new('Unexpected protocol! Should be either ssh or pdns!')
                    end
                end

                if sshServer
                    sshParams = {}
                    sshParams[:port] = sshPort if sshPort
                    sshParams[:user] = sshUser if sshUser
                    sshParams[:password] = sshPassword if sshPassword

                    startPortForward(sshServer, sshParams, host, port) do |acquiredPort|
                        port = acquiredPort
                        host = 'localhost'
                        self.class.externalIp = externalIpFromSSH
                    end
                    waitPortForward(SSH_TIMEOUT)
                end

                yield(host, port, key)

                if sshServer
                    finishPortForward
                end
            end

            def removeConflicting(zone, name, type)
                remove = []
                if type == 'CNAME'
                    zone['rrsets'].each do |rrset|
                        if (rrset['name'].downcase == name.downcase && rrset['type'] == 'A')
                            remove << {
                                name: name,
                                type: 'A',
                                changetype: 'DELETE',
                                records: []
                            }
                        end
                    end
                end
                remove
            end

            def startPortForward(server, sshParams, targetHost, targetPort)
                @SSHFowardProcessing = false
                @SSHError = nil
                @SSHThread = Thread.new do
                    @SSH = nil
                    Net::SSH.start(server, nil, sshParams) do |ssh|
                        @SSH = ssh
                        port = getFreePort
                        yield(port)

                        ssh.forward.local(port, targetHost, targetPort)
                        @SSHFowardProcessing = true
                        ssh.loop { ssh.busy? || @SSHFowardProcessing }
                    end
                    @SSH = nil
                rescue IOError, SocketError, SystemCallError, Net::SSH::Exception, ScriptError => e
                    @SSHError = e.message
                end
                @SSHThread.report_on_exception = true
                @SSHThread.abort_on_exception = true
            end

            def waitPortForward(timeout)
                while !@SSHFowardProcessing && timeout.positive?
                    raise Framework::PluginProcessError, 'PowerDNS: ' + @SSHError.to_s unless @SSHError.nil?

                    sleep(0.2)
                    timeout -= 0.2
                end

                return if timeout.positive?

                @SSHThread.terminate
                raise Framework::PluginProcessError, 'PowerDNS: Timeout while waiting for SSH connection!'
            end

            def finishPortForward
                @SSHFowardProcessing = false
                @SSHThread.join(3)
            end

           def externalIpFromSSH
                envs = @SSH.exec!('env').split("\n")
                envVars = Hash[envs.map { |vars| vars.split('=', 2) }]
                envVars['SSH_CLIENT'].split.first
            end

            def getFreePort
                port = nil
                TCPServer.open(0) do |socket|
                    port = socket.addr[1]
                end
                port
            end
        end
    end
end
