
module ConfigLMM
    module LMM
        class Postfix < Framework::Plugin
            PACKAGE_NAME = 'Postfix'
            SERVICE_NAME = 'postfix'
            MASTER_FILE = 'master.cf'
            MAIN_FILE = 'main.cf'
            TRANSPORT_FILE = 'transport'

            def actionPostfixDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackages([PACKAGE_NAME, 'CyrusSASL'], options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        deploySettings(target, linuxConnection, options)
                        deployAccounts(target, linuxConnection, context, options)

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

            def deploySettings(target, linuxConnection, options)
                postfixDirName = 'postfix'
                postfixDirName = 'postfix-' + target['Instance'] if target['Instance']
                postfixDir = '/etc/' + postfixDirName + '/'

                if target['Instance']
                    linuxConnection.exec("postmulti -e init", false, options)
                    linuxConnection.exec("postmulti -I #{postfixDirName} -e create", true, options)
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^master_service_disable', '#master_service_disable', options)
                end

                linuxConnection.fileReplace("#{postfixDir + MASTER_FILE}", '^tlsmgr', '#tlsmgr', options)
                if target.key?('SMTP')
                    if !target['SMTP'] || target['SMTP'] == 'unix'
                        linuxConnection.fileReplace("#{postfixDir + MASTER_FILE}", '^smtp', '#smtp', options)
                    end
                end

                linuxConnection.updateFile(postfixDir + MASTER_FILE, options, true) do |fileLines|
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
                            fileLines << "    -o smtpd_client_restrictions=permit_sasl_authenticated,reject\n"
                            fileLines << "    -o smtpd_sender_restrictions=reject_sender_login_mismatch,lmdb:#{postfixDir}access\n"
                            fileLines << "    -o cleanup_service_name=header_cleanup\n"
                            fileLines << "header_cleanup unix n   -       -       -       0       cleanup\n"
                            fileLines << "    -o header_checks=regexp:/etc/postfix/header_cleanup\n"

                             linuxConnection.fileWrite("/etc/postfix/header_cleanup", '/^Received:/ IGNORE', options)
                             linuxConnection.fileAppend("/etc/postfix/header_cleanup", '/^User-Agent:/ IGNORE', options)
                        end
                        fileLines << "tlsmgr    unix  -       -       n       1000?   1       tlsmgr\n"
                        if target['SMTP'] == 'unix'
                            fileLines << "smtp      unix  -       -       n       -       -       smtp\n"
                        end
                    end
                    fileLines
                end

                domain = target['Domain']
                domain = linuxConnection.exec("hostname --fqdn", false, { **options, 'dry' => false }).strip unless domain

                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^myhostname = .*', "myhostname = #{domain}", options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^#myhostname = virtual.domain.tld', "myhostname = #{domain}", options)

                # Fix config bug
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^alias_maps = :/etc/aliases', 'alias_maps = lmdb:/etc/aliases', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^canonical_maps = :/etc/postfix/canonical', 'canonical_maps = lmdb:/etc/postfix/canonical', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^relocated_maps = :/etc/postfix/relocated', 'relocated_maps = lmdb:/etc/postfix/relocated', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^sender_canonical_maps = :/etc/postfix/sender_canonical', 'sender_canonical_maps = lmdb:/etc/postfix/sender_canonical', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^transport_maps = :/etc/postfix/transport', 'transport_maps = lmdb:/etc/postfix/transport', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^smtpd_sender_restrictions = :/etc/postfix/access', 'smtpd_sender_restrictions = lmdb:/etc/postfix/access', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^virtual_alias_maps = :/etc/postfix/virtual', 'virtual_alias_maps = lmdb:/etc/postfix/virtual', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^relay_domains = $mydestination :/etc/postfix/relay', 'relay_domains = $mydestination lmdb:/etc/postfix/relay', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^relay_recipient_maps = :/etc/postfix/relay_recipients', 'relay_recipient_maps = lmdb:/etc/postfix/relay_recipients', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^virtual_mailbox_maps =.*', 'virtual_mailbox_maps = lmdb:/etc/postfix/mailboxes', options)

                if target['AlternativePort']
                    linuxConnection.firewallAddPort("#{target['AlternativePort']}/tcp", options)
                else
                    linuxConnection.firewallAddService('smtp', options)
                end
                linuxConnection.firewallAddService('smtps', options)

                linuxConnection.createDirs(options, '/etc/sasl2')
                linuxConnection.upload(__dir__ + '/smtpd.conf', '/etc/sasl2/smtpd.conf', options)
                linuxConnection.ensureFile('/etc/sasldb2', options)
                linuxConnection.setUserGroup('/etc/sasldb2', 'postfix', 'postfix', options)
                linuxConnection.ensureFile("#{postfixDir}access", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}access", false, options)
                linuxConnection.ensureFile("#{postfixDir}sender_login", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}sender_login", false, options)

                certDir = linuxConnection.createWildecardCertificate(options)
                target['Settings'] ||= {}
                target['Settings']['default_database_type'] = 'lmdb'
                target['Settings']['smtpd_sender_login_maps'] = "lmdb:#{postfixDir}sender_login" unless target['Settings']['smtpd_sender_login_maps']
                target['Settings']['smtpd_sender_restrictions'] = "lmdb:#{postfixDir}access" unless target['Settings']['smtpd_sender_restrictions']
                target['Settings']['smtp_tls_security_level'] = 'may' unless target['Settings']['smtp_tls_security_level']
                target['Settings']['smtpd_tls_mandatory_protocols'] = '>=TLSv1.2' unless target['Settings']['smtpd_tls_mandatory_protocols']
                target['Settings']['smtpd_tls_auth_only'] = 'yes' unless target['Settings']['smtpd_tls_auth_only']
                target['Settings']['smtpd_tls_security_level'] = 'may' unless target['Settings']['smtpd_tls_security_level']
                target['Settings']['smtpd_tls_cert_file'] = certDir + 'fullchain.pem' unless target['Settings']['smtpd_tls_cert_file']
                target['Settings']['smtpd_tls_key_file'] = certDir + 'privkey.pem' unless target['Settings']['smtpd_tls_key_file']
                target['Settings']['tls_preempt_cipherlist'] = 'yes' unless target['Settings']['tls_preempt_cipherlist']
                target['Settings']['tls_ssl_options'] = 'NO_RENEGOTIATION' unless target['Settings']['tls_ssl_options']

                target['Settings'].each do |name, value|
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, "^#{name}[[:blank:]]*=[[:blank:]]*", "##{name} = ", options)
                end
                linuxConnection.updateFile(postfixDir + MAIN_FILE, options) do |fileLines|
                    target['Settings'].each do |name, value|
                        value = 'yes' if value == true
                        value = 'no' if value == false
                        fileLines << "#{name} = #{value}\n"
                    end
                    fileLines
                end

                if target['ForwardDovecot']
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^#virtual_transport =.*', 'virtual_transport = lmtp:unix:/run/dovecot/lmtp', options)
                end

                if target['ForwardAll']
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, '^transport_maps =.*', "transport_maps = lmdb:#{postfixDir}transport", options)

                    linuxConnection.updateFile(postfixDir + TRANSPORT_FILE, options, true) do |fileLines|
                        hostname, port = target['ForwardAll'].split(':')
                        hostname = '[' + hostname + ']'
                        line = '* smtp:' + hostname
                        line += ':' + port if port
                        fileLines << line + "\n"
                    end
                    linuxConnection.exec("postmap lmdb:#{postfixDir + TRANSPORT_FILE}", false, options)
                end

                if target['Instance']
                    linuxConnection.exec("postmulti -i #{postfixDirName} -e enable", false, options)
                    linuxConnection.exec("postmulti -i #{postfixDirName} -p start", true, options)
                end
            end

            def deployAccounts(target, linuxConnection, context, options)
                if target['Accounts']
                    postfixDirName = 'postfix'
                    postfixDirName = 'postfix-' + target['Instance'] if target['Instance']
                    postfixDir = '/etc/' + postfixDirName + '/'

                    linuxConnection.ensureFile("#{postfixDir}sender_login", { **options, 'dry' => false })
                    linuxConnection.download("#{postfixDir}sender_login", options['output'], { **options, 'dry' => false })
                    senderLoginFile = options['output'] + '/sender_login'
                    accountData = File.read(senderLoginFile)
                    addAccounts = []
                    accountPasswords = linuxConnection.exec('sasldblistusers2', false, { **options, 'dry' => false })
                    target['Accounts'].each do |account, emails|
                        accountLine = "#{account} #{account}"
                        if !accountData.include?(accountLine)
                            addAccounts << accountLine
                        end
                        if !accountPasswords.include?(account + ':')
                            passwordName = account.upcase + '_PASSWORD'
                            password = context.secrets.load(target['SecretId'], passwordName)
                            if password.nil?
                                password = SecureRandom.urlsafe_base64(20)
                                context.secrets.store(target['SecretId'], passwordName, password) unless options['dry']
                            end
                            linuxConnection.exec("echo '#{password}' | saslpasswd2 -p #{account}", false, { **options, hide: true })
                        end
                        if emails.is_a?(String)
                            accountLine = "#{emails} #{account}"
                            if !accountData.include?(accountLine)
                                addAccounts << accountLine
                            end
                        elsif emails.is_a?(Array)
                            emails.each do |email|
                                accountLine = "#{email} #{account}"
                                if !accountData.include?(accountLine)
                                    addAccounts << accountLine
                                end
                            end
                        end
                    end
                    if !addAccounts.empty?
                        addAccounts.each do |accountLine|
                            accountData << "\n" + accountLine
                        end
                        accountData << "\n"
                        File.write(senderLoginFile, accountData)
                        linuxConnection.upload(senderLoginFile, "#{postfixDir}sender_login", options)
                        linuxConnection.exec("postmap lmdb:#{postfixDir}sender_login", false, options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Postfix, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        instances = linuxConnection.exec('postmulti -l | wc -l', true).strip.to_i
                        if instances <= 1
                            linuxConnection.stopService(SERVICE_NAME, options)
                            linuxConnection.firewallRemoveService('smtps', options)
                            if item['AlternativePort']
                                linuxConnection.firewallRemovePort("#{item['AlternativePort']}/tcp", options)
                            else
                                linuxConnection.firewallRemoveService('smtp', options)
                            end
                            linuxConnection.removePackage(PACKAGE_NAME, options)

                            state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                            if options[:destroy]
                                linuxConnection.rm('/etc/postfix', options[:dry])

                                state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                            end
                        else
                            prompt.say('Postfix multiple instance cleanup not implemented!', :color => :red)
                        end
                    end
                end
            end
        end

    end
end
