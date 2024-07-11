
# require 'fog'
require 'uri'
require 'addressable/uri'
require 'addressable/idna'
require 'fog/powerdns'

module ConfigLMM
    module LMM
        class PowerDNS < Framework::DNS

            CONFIG_DIR = '/etc/pdns/pdns.d'
            DEFAULT_HOST = 'localhost'
            DEFAULT_PORT = 8081
            SSH_TIMEOUT = 10

            # TODO
            # def actionPowerDNSValidate(id, target, activeState, context, options)
            #     We should check that target['DNS'] looks like valid config
            #end

            def actionPowerDNSBuild(id, target, activeState, context, options)
                if target['Settings']
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

                deploySettings(target)
                if target['DNS']
                    connect(id, target, activeState, context, options) do |host, port, key|
                        updateDNS(host, port, key, target['DNS'])
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
                        dns.create_zone(server, canonicalDomain, [], { kind: 'Native' })
                    end

                    zone = dns.get_zone(server, canonicalDomain)

                    rrsets = []
                    remove = []
                    info.each do |name, data|
                        fullName = name + '.' + domain + '.'
                        fullName = domain + '.' if name == '@'
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

            def deploySettings(target)
                if target['Settings']
                    # TODO
                end
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
