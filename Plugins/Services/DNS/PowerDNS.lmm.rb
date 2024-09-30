
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

                deploySettings(target, activeState, options)
                connect(id, target, activeState, context, options) do |host, port, key|
                    if target['TSIG']
                        updateTSIG(host, port, key, target['TSIG'])
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
                cleanupType(:PowerDNS, configs, state, context, options) do |item, id, state, context, options, ssh|
                    if item['Deploy']
                        Framework::LinuxApp.stopService(SERVICE_NAME, ssh, options[:dry])
                        Framework::LinuxApp.firewallRemoveService('dns', ssh, options[:dry])
                        Framework::LinuxApp.removePackage(PACKAGE_NAME, ssh, options[:dry])

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            item['Database'] ||= {}
                            PostgreSQL.dropUserAndDB(item['Database'], USER, ssh, options[:dry])
                            rm('/etc/pdns', options[:dry], ssh)
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
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
                        puts ({ kind: 'Native' }.update(info['!'].to_h).inspect)
                        dns.update_zone(server, canonicalDomain, { kind: 'Native' }.update(info['!'].to_h))
                    end

                    zone = dns.get_zone(server, canonicalDomain)

                    rrsets = []
                    remove = []
                    info.each do |name, data|
                        next if name == '!'
                        fullName = Addressable::IDNA.to_ascii(name) + '.' + Addressable::IDNA.to_ascii(domain) + '.'
                        fullName = Addressable::IDNA.to_ascii(domain) + '.' if name == '@'
                        self.processDNS(domain, data).each do |type, records|
                            #remove += removeConflicting(zone, fullName, type)
                            rrset = {
                                name: fullName,
                                type: type,
                                ttl: records.first[:ttl],
                                changetype: 'REPLACE',
                                records: []
                            }
                            records.each do |record|
                                record[:content] = Addressable::IDNA.to_ascii(record[:content]) + '.' if type == 'CNAME' || type == 'ALIAS'
                                if type == 'MX'
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

            def updateTSIG(host, port, key, targetTSIG)
                server = 'localhost'
                url = "http://#{host}:#{port}/api/v1/servers/#{server}/tsigkeys"
                headers = { 'X-Api-Key' => key }
                targetTSIG.each do |name, info|
                    data = { name: name, algorithm: info['Algorithm'] }
                    response = HTTP.headers(headers).post(url, json: data)
                    if response.status == 201
                        result = response.parse(:json)
                        prompt.say("TSIG #{result['name']} key: #{result['key']}", :color => :magenta)
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

            def deploySettings(target, activeState, options)
                if target['Location']
                    uri = Addressable::URI.parse(target['Location'])
                    params = {}
                    params = CGI.parse(uri.query) if uri.query
                    if uri.scheme == 'ssh' && !params.key?('host')
                        self.class.sshStart(uri) do |ssh|
                            target['Deploy'] = !!target['Settings'] unless target.key?('Deploy')
                            activeState['Deploy'] = target['Deploy']
                            if target['Deploy']
                                Framework::LinuxApp.ensurePackages([PACKAGE_NAME], ssh)
                                Framework::LinuxApp.ensureServiceAutoStartOverSSH(SERVICE_NAME, ssh)
                            end
                            if target['Settings']
                                prepareSettings(target)
                                self.class.sshExec!(ssh, "mkdir -p #{CONFIG_DIR}")
                                self.class.sshExec!(ssh, "sed -i 's|# include-dir=|include-dir=#{CONFIG_DIR}|' /etc/pdns/pdns.conf")
                                ssh.scp.upload!(options['output'] + CONFIG_DIR + '/configlmm.conf', CONFIG_DIR + '/configlmm.conf')
                                apiKeyFile = CONFIG_DIR + '/apiKey.conf'
                                if !self.class.remoteFilePresent?(apiKeyFile, ssh)
                                    apiKey = ENV['POWERDNS_API_KEY']
                                    apiKey = SecureRandom.urlsafe_base64(60) unless apiKey
                                    self.class.sshExec!(ssh, " echo 'api-key=#{apiKey}' > #{apiKeyFile}")
                                    self.class.sshExec!(ssh, " chown #{USER}:#{USER} #{apiKeyFile}")
                                    self.class.sshExec!(ssh, " chmod 400 #{apiKeyFile}")
                                    prompt.say("PowerDNS API Key: #{apiKey}", )
                                end
                                self.configurePostgreSQL(target['Settings'], ssh)
                            end
                            if target['Deploy']
                                Framework::LinuxApp.firewallAddServiceOverSSH('dns', ssh)
                                Framework::LinuxApp.startServiceOverSSH(SERVICE_NAME, ssh)
                                activeState['Status'] = State::STATUS_DEPLOYED
                            end
                        end
                    end
                else
                    # TODO
                end
            end

            def configurePostgreSQL(settings, ssh)
                password = SecureRandom.alphanumeric(20)
                if settings['gpgsql-host'] == 'localhost' || settings['gpgsql-host'].start_with?('/')
                    PostgreSQL.createUserAndDBOverSSH(USER, password, ssh)
                    PostgreSQL.importSQL(USER, USER, '/usr/share/doc/packages/pdns/schema.pgsql.sql', ssh)
                    PostgreSQL.updateOwner(USER, USER, ssh)
                else
                    self.class.sshStart("ssh://#{settings['gpgsql-host']}/") do |ssh|
                        PostgreSQL.createUserAndDBOverSSH(USER, password, ssh)
                        PostgreSQL.importSQL(USER, USER, '/usr/share/doc/packages/pdns/schema.pgsql.sql', ssh)
                        PostgreSQL.updateOwner(USER, USER, ssh)
                    end
                end
                password
            end

            def connect(id, target, activeState, context, options)
                host = DEFAULT_HOST
                port = DEFAULT_PORT
                key = ENV['POWERDNS_API_KEY']
                key = target['Key'] if target['Key']
                raise Framework::PluginProcessError.new('PowerDNS missing API key!') unless key

                sshServer = nil
                sshUser = nil
                sshPort = nil
                sshPassword = ENV['POWERDNS_SSH_PASSWORD']

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
                TCPServer.open(0) do |socket|
                    return socket.addr[1]
                end
            end
        end
    end
end
