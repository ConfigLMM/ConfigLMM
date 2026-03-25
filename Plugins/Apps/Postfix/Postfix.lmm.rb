
require 'addressable/idna'
require 'public_suffix'

module ConfigLMM
    module LMM
        class Postfix < Framework::Plugin
            PACKAGE_NAME = 'Postfix'
            SERVICE_NAME = 'postfix'
            MASTER_FILE = 'master.cf'
            MAIN_FILE = 'main.cf'
            TRANSPORT_FILE = 'transport'
            PASSWORD_FILE = 'sasl_passwd'
            DEFAULT_MAIL_UID = 1000
            DEFAULT_MAIL_GID = 1000

            def actionPostfixDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackages([PACKAGE_NAME, 'CyrusSASL'], options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        domain = target['Domain']
                        domain = linuxConnection.exec("hostname --fqdn", false, { **options, 'dry' => false }).strip unless domain
                        topdomain = PublicSuffix.domain(domain)

                        deploySettings(target, linuxConnection, domain, topdomain, context, options)
                        deployAccounts(target, linuxConnection, context, options)
                        deployMailboxes(target, linuxConnection, topdomain, context, options)

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

            def deploySettings(target, linuxConnection, domain, topdomain, context, options)
                postfixDirName = 'postfix'
                postfixDirName = 'postfix-' + target['Instance'] if target['Instance']
                postfixDir = '/etc/' + postfixDirName + '/'

                if target['Instance']
                    linuxConnection.exec("postmulti -e init", false, options)
                    linuxConnection.exec("postmulti -I #{postfixDirName} -e create", true, options)
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^master_service_disable/, '#master_service_disable', options)
                end

                linuxConnection.fileReplace("#{postfixDir + MASTER_FILE}", /^tlsmgr/, '#tlsmgr', options)
                if target.key?('SMTP')
                    if !target['SMTP'] || target['SMTP'] == 'unix'
                        linuxConnection.fileReplace("#{postfixDir + MASTER_FILE}", /^smtp/, '#smtp', options)
                    end
                end

                linuxConnection.updateFile(postfixDir + MASTER_FILE, options, true) do |fileLines|
                    if target['AlternativePort']
                        fileLines << "#{target['AlternativePort']}      inet  n       -       n       -       -       smtpd\n"
                        fileLines << "tlsmgr    unix  -       -       n       1000?   1       tlsmgr\n"
                    else
                        fileLines << "tlsmgr    unix  -       -       n       1000?   1       tlsmgr\n"
                        if target['SMTP'] == 'unix'
                            fileLines << "smtp      unix  -       -       n       -       -       smtp\n"
                        end
                    end
                    if target['Submission']
                        # Some distributions like Red Hat/AlmaLinux doesn't know "submissions" port so have to enter it manually
                        fileLines << "465     inet  n       -       n       -       -       smtpd\n"
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
                        linuxConnection.fileAppend("/etc/postfix/header_cleanup", '/^Message-ID:\s*<(.*)@.*?>\s*$/ REPLACE Message-ID: <$1@' + topdomain + '>', options)
                    end
                    fileLines
                end

                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^myhostname = .*/, "myhostname = #{domain}", options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^#myhostname = virtual.domain.tld/, "myhostname = #{domain}", options)

                # Fix config bug
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^alias_maps = :\/etc\/aliases/, 'alias_maps = lmdb:/etc/aliases', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^canonical_maps = :\/etc\/postfix\/canonical/, 'canonical_maps = lmdb:/etc/postfix/canonical', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^relocated_maps = :\/etc\/postfix\/relocated/, 'relocated_maps = lmdb:/etc/postfix/relocated', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^sender_canonical_maps = :\/etc\/postfix\/sender_canonical/, 'sender_canonical_maps = lmdb:/etc/postfix/sender_canonical', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^transport_maps = :\/etc\/postfix\/transport/, 'transport_maps = lmdb:/etc/postfix/transport', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^smtpd_sender_restrictions = :\/etc\/postfix\/access/, 'smtpd_sender_restrictions = lmdb:/etc/postfix/access', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^virtual_alias_maps = :\/etc\/postfix\/virtual/, 'virtual_alias_maps = lmdb:/etc/postfix/virtual', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^relay_domains = $mydestination :\/etc\/postfix\/relay/, 'relay_domains = $mydestination lmdb:/etc/postfix/relay', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^relay_recipient_maps = :\/etc\/postfix\/relay_recipients/, 'relay_recipient_maps = lmdb:/etc/postfix/relay_recipients', options)
                linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^virtual_mailbox_maps =.*/, 'virtual_mailbox_maps = lmdb:/etc/postfix/mailboxes', options)

                if target['AlternativePort']
                    linuxConnection.firewallAddPort("#{target['AlternativePort']}/tcp", options)
                else
                    linuxConnection.firewallAddService('smtp', options)
                end
                linuxConnection.firewallAddService('smtps', options)

                linuxConnection.createDirs(options, '/etc/sasl2', '/var/mail/virtual')
                linuxConnection.upload(__dir__ + '/smtpd.conf', '/etc/sasl2/smtpd.conf', options)
                linuxConnection.ensureFile('/etc/sasldb2', options)
                linuxConnection.setUserGroup('/etc/sasldb2', 'postfix', 'postfix', options)
                linuxConnection.setUserGroup('/etc/sasl2', 'postfix', 'postfix', options)
                linuxConnection.setUserGroup('/var/mail/virtual', DEFAULT_MAIL_UID, DEFAULT_MAIL_GID, options)
                linuxConnection.ensureFile("#{postfixDir}access", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}access", false, options)
                linuxConnection.ensureFile("#{postfixDir}mailboxes", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}mailboxes", false, options)
                linuxConnection.ensureFile("#{postfixDir}virtual_uids", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}virtual_uids", false, options)
                linuxConnection.ensureFile("#{postfixDir}virtual_gids", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}virtual_gids", false, options)
                linuxConnection.ensureFile("#{postfixDir}virtual", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}virtual", false, options)
                linuxConnection.ensureFile("#{postfixDir}sender_login", options)
                linuxConnection.exec("postmap lmdb:#{postfixDir}sender_login", false, options)
                linuxConnection.ensureFile("/etc/postfix/#{PASSWORD_FILE}", options)

                if !target['Aliases'].to_h.empty?
                    if !linuxConnection.filePresent?('/etc/aliases', options)
                        linuxConnection.exec('cp /etc/postfix/aliases /etc/', false, options)
                        linuxConnection.rm("/etc/postfix/aliases", false, options[:dry])
                    end
                    target['Aliases'].each do |name, destination|
                        linuxConnection.fileReplace('/etc/aliases', /^#{name}:/, '#' + name + ':', options)
                    end
                    linuxConnection.updateFile('/etc/aliases', options, true) do |fileLines|
                        target['Aliases'].each do |name, destination|
                            fileLines << "#{(name.to_s + ':').ljust(16)}#{self.class.punnycodeEMail(destination)}\n"
                        end
                        fileLines
                    end
                    linuxConnection.exec('postalias lmdb:/etc/aliases', false, options)
                end

                postfixVersion = linuxConnection.exec('postconf mail_version | cut -d "=" -f 2', false, options).strip.to_f

                certDir = linuxConnection.createWildecardCertificate(options)
                target['Settings'] ||= {}
                target['Settings']['alias_maps'] = 'lmdb:/etc/aliases'
                target['Settings']['alias_database'] = '$alias_maps'
                target['Settings']['default_database_type'] = 'lmdb'

                target['Settings']['myorigin'] = '$mydomain' unless target['Settings']['myorigin']
                defaultMyDestination =  target.key?('Mailboxes') ? '$myhostname localhost.$mydomain localhost' : '$myhostname localhost.$mydomain localhost $mydomain'
                target['Settings']['mydestination'] = defaultMyDestination unless target['Settings']['mydestination']
                target['Settings']['virtual_mailbox_base'] = '/var/mail/virtual' unless target['Settings']['virtual_mailbox_base']
                target['Settings']['virtual_mailbox_domains'] = '$virtual_mailbox_maps' unless target['Settings']['virtual_mailbox_domains']
                target['Settings']['virtual_mailbox_maps'] = "lmdb:#{postfixDir}mailboxes" unless target['Settings']['virtual_mailbox_maps']
                target['Settings']['virtual_uid_maps'] = "lmdb:#{postfixDir}virtual_uids" unless target['Settings']['virtual_uid_maps']
                target['Settings']['virtual_gid_maps'] = "lmdb:#{postfixDir}virtual_gids" unless target['Settings']['virtual_gid_maps']
                target['Settings']['virtual_alias_maps'] = "lmdb:#{postfixDir}virtual" unless target['Settings']['virtual_alias_maps']
                target['Settings']['smtpd_sender_login_maps'] = "lmdb:#{postfixDir}sender_login" unless target['Settings']['smtpd_sender_login_maps']
                target['Settings']['smtpd_sender_restrictions'] = "lmdb:#{postfixDir}access" unless target['Settings']['smtpd_sender_restrictions']

                target['Settings']['smtp_sasl_password_maps'] = 'lmdb:/etc/postfix/' + PASSWORD_FILE
                target['Settings']['smtp_sasl_security_options'] = 'noanonymous'

                target['Settings']['smtp_tls_security_level'] = 'may' unless target['Settings']['smtp_tls_security_level']
                if postfixVersion >= 3.6
                    target['Settings']['smtpd_tls_mandatory_protocols'] = '>=TLSv1.2' unless target['Settings']['smtpd_tls_mandatory_protocols']
                else
                    target['Settings']['smtpd_tls_mandatory_protocols'] = '!SSLv2, !SSLv3, !TLSv1, !TLSv1.1' unless target['Settings']['smtpd_tls_mandatory_protocols']
                end
                target['Settings']['smtpd_tls_mandatory_ciphers'] = 'high' unless target['Settings']['smtpd_tls_mandatory_ciphers']
                target['Settings']['smtpd_tls_auth_only'] = 'yes' unless target['Settings']['smtpd_tls_auth_only']
                target['Settings']['smtpd_tls_security_level'] = 'may' unless target['Settings']['smtpd_tls_security_level']
                target['Settings']['smtpd_tls_cert_file'] = certDir + 'fullchain.pem' unless target['Settings']['smtpd_tls_cert_file']
                target['Settings']['smtpd_tls_key_file'] = certDir + 'privkey.pem' unless target['Settings']['smtpd_tls_key_file']
                target['Settings']['tls_preempt_cipherlist'] = 'yes' unless target['Settings']['tls_preempt_cipherlist']
                target['Settings']['tls_ssl_options'] = 'NO_RENEGOTIATION' unless target['Settings']['tls_ssl_options']

                target['Settings']['message_size_limit'] = 100*1024*1024 unless target['Settings']['message_size_limit'] # 100 MiB
                target['Settings']['mailbox_size_limit'] = 50*1024*1024*1024 unless target['Settings']['mailbox_size_limit'] # 50 GiB
                target['Settings']['virtual_mailbox_limit'] = target['Settings']['mailbox_size_limit'] unless target['Settings']['virtual_mailbox_limit']
                raise "mailbox_size_limit (#{target['Settings']['mailbox_size_limit']}) can\'t be smaller than message_size_limit (#{target['Settings']['message_size_limit']})" if target['Settings']['mailbox_size_limit'] < target['Settings']['message_size_limit']
                raise "virtual_mailbox_limit (#{target['Settings']['virtual_mailbox_limit']}) can\'t be smaller than message_size_limit (#{target['Settings']['message_size_limit']})" if target['Settings']['virtual_mailbox_limit'] < target['Settings']['message_size_limit']

                # Prevent user/email enumeration
                target['Settings']['disable_vrfy_command'] = 'yes' unless target['Settings']['disable_vrfy_command']
                target['Settings']['show_user_unknown_table_name'] = 'no' unless target['Settings']['show_user_unknown_table_name']

                # Allow only local users listed in aliases (this prevents actual user enumeration)
                target['Settings']['local_recipient_maps'] = '$alias_maps' unless target['Settings']['local_recipient_maps']

                if target['Relay']
                    port = target['Relay']['Port'].to_s
                    port = '587' if port.empty?
                    target['Settings']['relayhost'] = "#{target['Relay']['Host']}:#{port}" unless target['Settings']['relayhost']
                    target['Settings']['smtp_sasl_auth_enable'] = 'yes'
                    if port == '465'
                        target['Settings']['smtp_tls_security_level'] = 'encrypt'
                        target['Settings']['smtp_tls_wrappermode'] = 'yes'
                    end
                    if target['Relay']['SecretId']
                        username = target['Relay']['Username'].to_s
                        password = context.secrets.load(target['Relay']['SecretId'], username.upcase + '_PASSWORD')
                        linuxConnection.updateFile('/etc/postfix/' + PASSWORD_FILE, options) do |fileLines|
                            fileLines << "#{target['Settings']['relayhost']}   #{username}:#{password}\n"
                        end
                    end
                end
                linuxConnection.exec("postmap lmdb:/etc/postfix/#{PASSWORD_FILE}", false, options)

                loadIntegrationSettings(target, target['Location'], target['Settings'])

                target['Settings'].each do |name, value|
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^#{name}[[:blank:]]*=[[:blank:]]*/, "##{name} = ", options)
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
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^#virtual_transport =.*/, 'virtual_transport = lmtp:unix:/run/dovecot/lmtp', options)
                end

                if target['ForwardAll']
                    linuxConnection.fileReplace(postfixDir + MAIN_FILE, /^transport_maps =.*/, "transport_maps = lmdb:#{postfixDir}transport", options)

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
                    senderLoginRemotePath = self.class.postfixFile(target, 'sender_login')

                    linuxConnection.ensureFile(senderLoginRemotePath, { **options, 'dry' => false })
                    linuxConnection.download(senderLoginRemotePath, options['output'], { **options, 'dry' => false })
                    senderLoginLocalPath = options['output'] + '/sender_login'
                    accountData = File.read(senderLoginLocalPath)
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
                        File.write(senderLoginLocalPath, accountData)
                        linuxConnection.upload(senderLoginLocalPath, senderLoginRemotePath, options)
                    end
                    linuxConnection.exec("postmap lmdb:#{senderLoginRemotePath}", false, options)
                end
            end

            def deployMailboxes(target, linuxConnection, topdomain, context, options)
                mailboxes = []
                #if target['Accounts']
                #    mailboxes += target['Accounts'].keys
                #end
                if target.key?('Mailboxes')
                    if target['Mailboxes'].is_a?(Array)
                        mailboxes += target['Mailboxes']
                    elsif target['Mailboxes'].is_a?(Hash) && target['Mailboxes']['File']
                        # TODO
                    else
                        mailboxes = nil
                    end
                #elsif mailboxes.empty?
                #    mailboxes << '@' + topdomain
                end
                uidsPath = self.class.postfixFile(target, 'virtual_uids')
                gidsPath = self.class.postfixFile(target, 'virtual_gids')
                mailboxesPath = self.class.postfixFile(target, 'mailboxes')
                addresses = mailboxes ? mailboxes.uniq.sort : []
                domains = addresses.map { |addr| addr.split('@').last }.uniq.sort

                linuxConnection.updateFile(uidsPath, options) do |fileLines|
                    domains.each do |domain|
                        fileLines << "@#{domain} #{DEFAULT_MAIL_UID}\n"
                    end
                    fileLines
                end

                linuxConnection.updateFile(gidsPath, options) do |fileLines|
                    domains.each do |domain|
                        fileLines << "@#{domain} #{DEFAULT_MAIL_GID}\n"
                    end
                    fileLines
                end

                linuxConnection.updateFile(mailboxesPath, options) do |fileLines|
                    domains.each do |domain|
                        fileLines << "#{domain} -\n"
                    end
                    addresses.each do |address|
                        fileLines << "#{address} #{address}\n"
                    end
                    fileLines
                end

                linuxConnection.exec("postmap lmdb:#{uidsPath}", false, options)
                linuxConnection.exec("postmap lmdb:#{gidsPath}", false, options)
                linuxConnection.exec("postmap lmdb:#{mailboxesPath}", false, options)
            end

            def self.postfixDir(target)
                postfixDirName = 'postfix'
                postfixDirName = 'postfix-' + target['Instance'] if target['Instance']
                '/etc/' + postfixDirName + '/'
            end

            def self.postfixFile(target, filename)
                self.postfixDir(target) + filename
            end

            def loadIntegrationSettings(target, location, settings)
                rspamdState = state.getLocationType(location, :Rspamd)
                if target['Rspamd'] || (rspamdState && target['Rspamd'] != false)
                    settings['smtpd_milters'] = 'inet:127.0.0.1:11332' unless settings['smtpd_milters']
                    settings['non_smtpd_milters'] = 'inet:127.0.0.1:11332' unless settings['non_smtpd_milters']
                    settings['milter_mail_macros'] = 'i {mail_addr} {client_addr} {client_name} {auth_authen}' unless settings['milter_mail_macros']
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

            def self.punnycodeEMail(email)
                emailLocal, emailDomain = email.to_s.split('@')
                if emailLocal && emailDomain && emailLocal.ascii_only? && !emailDomain.ascii_only?
                    email = emailLocal + '@' + Addressable::IDNA.to_ascii(emailDomain)
                end
                email
            end

        end

    end
end
