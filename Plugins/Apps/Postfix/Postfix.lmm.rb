
module ConfigLMM
    module LMM
        class Postfix < Framework::Plugin
            PACKAGE_NAME = 'Postfix'
            SERVICE_NAME = 'postfix'
            MASTER_FILE = 'master.cf'
            MAIN_FILE = 'main.cf'
            TRANSPORT_FILE = 'transport'

            def actionPostfixDeploy(id, target, activeState, context, options)
                plugins[:Linux].ensurePackages([PACKAGE_NAME, 'CyrusSASL'], target['Location'])
                plugins[:Linux].ensureServiceAutoStart(SERVICE_NAME, target['Location'])

                deploySettings(target, target['Location'], options)

                plugins[:Linux].startService(SERVICE_NAME, target['Location'])
            end

            def deploySettings(target, location, options)
                postfixDirName = 'postfix'
                postfixDirName = 'postfix-' + target['Instance'] if target['Instance']
                postfixDir = '/etc/' + postfixDirName + '/'
                if location && location != '@me'
                    self.class.sshStart(location) do |ssh|
                        if target['Instance']
                            self.class.sshExec!(ssh, "postmulti -e init")
                            self.class.sshExec!(ssh, "postmulti -I #{postfixDirName} -e create", true)
                            self.class.sshExec!(ssh, "sed -i 's|^master_service_disable|#master_service_disable|' #{postfixDir + MAIN_FILE}")
                        end
                        self.class.sshExec!(ssh, "sed -i 's|^tlsmgr|#tlsmgr|' #{postfixDir + MASTER_FILE}")
                        if target.key?('SMTP')
                            if !target['SMTP'] || target['SMTP'] == 'unix'
                                self.class.sshExec!(ssh, "sed -i 's|^smtp|#smtp|' #{postfixDir + MASTER_FILE}")
                            end
                        end
                        updateRemoteFile(ssh, postfixDir + MASTER_FILE, options, true) do |fileLines|
                            if target['AlternativePort']
                                fileLines << "#{target['AlternativePort']}      inet  n       -       n       -       -       smtpd\n"
                                fileLines << "tlsmgr    unix  -       -       n       1000?   1       tlsmgr\n"
                            else
                                if !target.key?('Submission') || (target.key?('Submission') && target['Submission'])
                                    fileLines << "submissions     inet  n       -       n       -       -       smtpd\n"
                                    fileLines << "    -o syslog_name=postfix/submissions\n"
                                    fileLines << "    -o smtpd_tls_wrappermode=yes\n"
                                    fileLines << "    -o smtpd_tls_security_level=encrypt\n"
                                    fileLines << "    -o smtpd_sasl_auth_enable=yes\n"
                                    fileLines << "    -o cleanup_service_name=header_cleanup\n"
                                    fileLines << "header_cleanup unix n   -       -       -       0       cleanup\n"
                                    fileLines << "    -o header_checks=regexp:/etc/postfix/header_cleanup\n"

                                    self.class.sshExec!(ssh, "echo '/^Received:/ IGNORE' > /etc/postfix/header_cleanup")
                                    self.class.sshExec!(ssh, "echo '/^User-Agent:/ IGNORE' >> /etc/postfix/header_cleanup")
                                end
                                fileLines << "tlsmgr    unix  -       -       n       1000?   1       tlsmgr\n"
                                if target['SMTP'] == 'unix'
                                    fileLines << "smtp      unix  -       -       n       -       -       smtp\n"
                                end
                            end
                            fileLines
                        end

                        domain = target['Domain']
                        domain = self.class.sshExec!(ssh, "hostname --fqdn").strip unless domain
                        command = "sed -i 's|^myhostname = .*|myhostname = #{domain}|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^#myhostname = virtual.domain.tld|myhostname = #{domain}|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)

                        # Fix config bug
                        command = "sed -i 's|^alias_maps = :/etc/aliases|alias_maps = lmdb:/etc/aliases|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^canonical_maps = :/etc/postfix/canonical|canonical_maps = lmdb:/etc/postfix/canonical|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^relocated_maps = :/etc/postfix/relocated|relocated_maps = lmdb:/etc/postfix/relocated|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^sender_canonical_maps = :/etc/postfix/sender_canonical|sender_canonical_maps = lmdb:/etc/postfix/sender_canonical|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^transport_maps = :/etc/postfix/transport|transport_maps = lmdb:/etc/postfix/transport|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^smtpd_sender_restrictions = :/etc/postfix/access|smtpd_sender_restrictions = lmdb:/etc/postfix/access|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^virtual_alias_maps = :/etc/postfix/virtual|virtual_alias_maps = lmdb:/etc/postfix/virtual|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^relay_domains = $mydestination :/etc/postfix/relay|relay_domains = $mydestination lmdb:/etc/postfix/relay|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^relay_recipient_maps = :/etc/postfix/relay_recipients|relay_recipient_maps = lmdb:/etc/postfix/relay_recipients|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                        command = "sed -i 's|^virtual_mailbox_maps =.*|virtual_mailbox_maps = lmdb:/etc/postfix/mailboxes|' #{postfixDir + MAIN_FILE}"
                        self.class.sshExec!(ssh, command)


                        if target['AlternativePort']
                            self.class.sshExec!(ssh, "firewall-cmd -q --add-port='#{target['AlternativePort']}/tcp'")
                            self.class.sshExec!(ssh, "firewall-cmd -q --permanent --add-port='#{target['AlternativePort']}/tcp'")
                        else
                            self.class.sshExec!(ssh, "firewall-cmd -q --add-service='smtp'")
                            self.class.sshExec!(ssh, "firewall-cmd -q --permanent --add-service='smtp'")
                        end
                        self.class.sshExec!(ssh, "firewall-cmd -q --add-service='smtps'")
                        self.class.sshExec!(ssh, "firewall-cmd -q --permanent --add-service='smtps'")

                        ssh.scp.upload!(__dir__ + '/smtpd.conf', '/etc/sasl2/smtpd.conf')
                        self.class.sshExec!(ssh, "touch /etc/sasldb2")
                        self.class.sshExec!(ssh, "chown postfix:postfix /etc/sasldb2")
                        self.class.sshExec!(ssh, "touch #{postfixDir}access")
                        self.class.sshExec!(ssh, "postmap #{postfixDir}access")
                        self.class.sshExec!(ssh, "touch #{postfixDir}sender_login")
                        self.class.sshExec!(ssh, "postmap #{postfixDir}sender_login")

                        certDir = Framework::LinuxApp.createCertificateOverSSH(ssh)
                        target['Settings'] ||= []
                        target['Settings']['smtpd_sender_login_maps'] = "lmdb:#{postfixDir}sender_login" unless target['Settings']['smtpd_sender_login_maps']
                        target['Settings']['smtpd_sender_restrictions'] = "reject_sender_login_mismatch, lmdb:#{postfixDir}access" unless target['Settings']['smtpd_sender_restrictions']
                        target['Settings']['smtp_tls_security_level'] = 'may' unless target['Settings']['smtp_tls_security_level']
                        target['Settings']['smtpd_tls_mandatory_protocols'] = '>=TLSv1.2' unless target['Settings']['smtpd_tls_mandatory_protocols']
                        target['Settings']['smtpd_tls_auth_only'] = 'yes' unless target['Settings']['smtpd_tls_auth_only']
                        target['Settings']['smtpd_tls_security_level'] = 'may' unless target['Settings']['smtpd_tls_security_level']
                        target['Settings']['smtpd_tls_cert_file'] = certDir + 'fullchain.pem' unless target['Settings']['smtpd_tls_cert_file']
                        target['Settings']['smtpd_tls_key_file'] = certDir + 'privkey.pem' unless target['Settings']['smtpd_tls_key_file']
                        target['Settings']['tls_preempt_cipherlist'] = 'yes' unless target['Settings']['tls_preempt_cipherlist']
                        target['Settings']['tls_ssl_options'] = 'NO_RENEGOTIATION' unless target['Settings']['tls_ssl_options']


                        target['Settings'].each do |name, value|
                            command = "sed -i 's|^#{name} =.*|##{name} = #{value}|' #{postfixDir + MAIN_FILE}"
                            self.class.sshExec!(ssh, command)
                        end
                        updateRemoteFile(ssh, postfixDir + MAIN_FILE, options) do |fileLines|
                            target['Settings'].each do |name, value|
                                value = 'yes' if value == true
                                value = 'no' if value == false
                                fileLines << "#{name} = #{value}\n"
                            end
                            fileLines
                        end

                        if target['ForwardDovecot']
                            command = "sed -i 's|^#virtual_transport =.*|virtual_transport = lmtp:unix:/run/dovecot/lmtp|' #{postfixDir + MAIN_FILE}"
                            self.class.sshExec!(ssh, command)
                        end

                        if target['ForwardAll']
                            command = "sed -i 's|^transport_maps =.*|transport_maps = lmdb:#{postfixDir}transport|' #{postfixDir + MAIN_FILE}"
                            self.class.sshExec!(ssh, command)
                            updateRemoteFile(ssh, postfixDir + TRANSPORT_FILE, options, true) do |fileLines|
                                hostname, port = target['ForwardAll'].split(':')
                                hostname = '[' + hostname + ']'
                                line = '* smtp:' + hostname
                                line += ':' + port if port
                                fileLines << line + "\n"
                            end
                            self.class.sshExec!(ssh, "postmap #{postfixDir + TRANSPORT_FILE}")
                        end

                        if target['Instance']
                            self.class.sshExec!(ssh, "postmulti -i #{postfixDirName} -e enable")
                            self.class.sshExec!(ssh, "postmulti -i #{postfixDirName} -p start", true)
                        end
                    end
                else
                    if target['AlternativePort']
                        updateLocalFile(postfixDir + MASTER_FILE, options, true) do |fileLines|
                            fileLines << "#{target['AlternativePort']}      inet  n       -       n       -       -       smtpd\n"
                        end
                    end
                    if target['Settings']
                        target['Settings'].each do |name, value|
                            `sed -i 's|^#{name} =.*|#{name} = #{value}|' #{postfixDir + MAIN_FILE}`
                        end
                    end
                    if target['ForwardAll']
                        updateLocalFile(postfixDir + TRANSPORT_FILE, options, true) do |fileLines|
                            fileLines << '* smtp:[' + target['ForwardAll'] + "]\n"
                        end
                        `postmap #{postfixDir + TRANSPORT_FILE}`
                    end
                end
            end

        end

    end
end
