
module ConfigLMM
    module LMM
        class LetsEncrypt < Framework::LinuxApp

            PACKAGE_NAME = 'CertBotNginx'
            CONFIG_DIR = '/etc/letsencrypt/'

            def actionLetsEncryptDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)

                        linuxConnection.upload(__dir__ + '/rfc2136.ini', CONFIG_DIR, options)
                        linuxConnection.upload(__dir__ + '/renew-certificates.service', '/etc/systemd/system/', options)
                        linuxConnection.upload(__dir__ + '/renew-certificates.timer', '/etc/systemd/system/', options)
                        linuxConnection.createDirs(options, CONFIG_DIR + "renewal-hooks/deploy")
                        target['Hooks'].to_a.each do |hook|
                            linuxConnection.upload(__dir__ + '/hooks/' + hook + '.sh', "#{CONFIG_DIR}renewal-hooks/deploy/", options)
                        end
                        linuxConnection.exec("chmod +x #{CONFIG_DIR}renewal-hooks/deploy/*.sh", false, options)
                        linuxConnection.fileReplace(CONFIG_DIR + 'rfc2136.ini', '$IP', target['DNS']['IP'] , options)

                        secretId, secretName = target['DNS']['SecretId'].to_s.split('.')
                        key = nil
                        key = context.secrets.load(secretId, secretName) if secretId && secretName
                        key = ENV['LETSENCRYPT_DNS_SECRET'] if key.nil?
                        raise Framework::PluginProcessError.new('LetsEncrypt missing RFC2136 TSIG key! Specify DNS.SecretId or LETSENCRYPT_DNS_SECRET env variable') unless key

                        linuxConnection.fileReplace(CONFIG_DIR + 'rfc2136.ini', '$SECRET', key, options)
                        linuxConnection.setPrivate(CONFIG_DIR + 'rfc2136.ini', options)
                        if target['Domain']
                            createCertificate('Wildcard', target['Domain'], target, linuxConnection, options)
                        end
                        target['Certificates'].to_h.each do |name, domains|
                            createCertificate(name, domains, target, linuxConnection, options)
                        end

                        linuxConnection.reloadServiceManager(options)
                        linuxConnection.ensureServiceAutoStart('renew-certificates.timer', options)
                        linuxConnection.startService('renew-certificates.timer', options)

                        target['Hooks'].to_a.each do |hook|
                            linuxConnection.exec("#{CONFIG_DIR}renewal-hooks/deploy/#{hook}.sh", false, options)
                        end
                    end
                end
            end

            def createCertificate(name, domains, target, connection, options)
                return if connection.fileLink?("#{CONFIG_DIR}live/#{name}/fullchain.pem", options)
                connection.exec("rm -rf #{CONFIG_DIR}live/#{name}", false, options)

                domainList = []
                domains = [domains] unless domains.is_a?(Array)
                domains.each do |domain|
                    domainList << '--domains "' + Addressable::IDNA.to_ascii(domain) + '"'
                    if domain.start_with?('*.')
                        domainList << '--domains "' + Addressable::IDNA.to_ascii(domain[2..-1]) + '"'
                    end
                end
                extra = ''
                extra = '--dns-rfc2136-propagation-seconds ' + target['DNS']['Propagation'].to_s if target['DNS']['Propagation']

                connection.exec("certbot certonly --dns-rfc2136 --dns-rfc2136-credentials=#{CONFIG_DIR}rfc2136.ini #{extra} --non-interactive --agree-tos --email #{target['EMail']} --cert-name '#{name}' #{domainList.join(' ')}", false, options)
            end

        end

    end
end
