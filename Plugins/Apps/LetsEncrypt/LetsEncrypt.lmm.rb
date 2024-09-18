
module ConfigLMM
    module LMM
        class LetsEncrypt < Framework::LinuxApp

            PACKAGE_NAME = 'CertBotNginx'
            CONFIG_DIR = '/etc/letsencrypt/'

            def actionLetsEncryptDeploy(id, target, activeState, context, options)
                self.ensurePackage(PACKAGE_NAME, target['Location'])

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        ssh.scp.upload!(__dir__ + '/rfc2136.ini', CONFIG_DIR)
                        ssh.scp.upload!(__dir__ + '/renew-certificates.service', '/etc/systemd/system/')
                        ssh.scp.upload!(__dir__ + '/renew-certificates.timer', '/etc/systemd/system/')
                        self.class.exec("mkdir -p #{CONFIG_DIR}renewal-hooks/deploy", ssh)
                        target['Hooks'].to_a.each do |hook|
                            ssh.scp.upload!(__dir__ + '/hooks/' + hook + '.sh', "#{CONFIG_DIR}renewal-hooks/deploy/")
                        end
                        self.class.exec("chmod +x #{CONFIG_DIR}renewal-hooks/deploy/*.sh", ssh)
                        self.class.exec("sed -i 's|$IP|#{target['DNS']['IP']}|' #{CONFIG_DIR}/rfc2136.ini", ssh)
                        self.class.exec("sed -i 's|$SECRET|#{ENV['LETSENCRYPT_DNS_SECRET']}|' #{CONFIG_DIR}/rfc2136.ini", ssh)
                        self.class.exec("chmod 600 #{CONFIG_DIR}/rfc2136.ini", ssh)
                        if target['Domain']
                            createCertificate('Wildcard', target['Domain'], target, ssh)
                        end
                        target['Certificates'].to_h.each do |name, domain|
                            createCertificate(name, domain, target, ssh)
                        end

                        self.class.exec("systemctl daemon-reload", ssh)
                        self.class.exec("systemctl enable renew-certificates.timer", ssh)
                        self.class.exec("systemctl start renew-certificates.timer", ssh)
                    end
                else
                    # TODO
                end
            end

            def createCertificate(name, domain, target, ssh)
                domains = ['--domains "' + Addressable::IDNA.to_ascii(domain) + '"']
                if domain.start_with?('*.')
                    domains << '--domains "' + Addressable::IDNA.to_ascii(domain[2..-1]) + '"'
                end
                extra = ''
                extra = '--dns-rfc2136-propagation-seconds ' + target['DNS']['Propagation'].to_s if target['DNS']['Propagation']
                self.class.exec("certbot certonly --dns-rfc2136 --dns-rfc2136-credentials=/etc/letsencrypt/rfc2136.ini #{extra} --non-interactive --agree-tos --email #{target['EMail']} --cert-name '#{name}' #{domains.join(' ')}", ssh)
            end

        end

    end
end
