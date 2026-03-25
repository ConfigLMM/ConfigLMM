require 'addressable/idna'

module ConfigLMM
    module LMM
        class Dovecot < Framework::Plugin
            PACKAGE_NAME = 'Dovecot'
            SERVICE_NAME = 'dovecot'
            DOVECOT_DIR = '/etc/dovecot/'
            EMAIL_HOME = '/var/lib/email'
            EMAIL_USER = 'email'

            def actionDovecotDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.ensurePackage(PACKAGE_NAME, options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        linuxConnection.createServiceUser(EMAIL_USER, EMAIL_HOME, 'Dovecot EMail', options)

                        uid = linuxConnection.exec("id -u #{EMAIL_USER}", false, options).strip


                        linuxConnection.fileReplace("#{DOVECOT_DIR}conf.d/10-mail.conf", /^#mail_uid =.*/, "mail_uid = #{uid}", options)
                        linuxConnection.fileReplace("#{DOVECOT_DIR}conf.d/10-mail.conf", /^#mail_gid =.*/, "mail_gid = #{uid}", options)
                        linuxConnection.fileReplace("#{DOVECOT_DIR}conf.d/10-mail.conf", /^#mail_location =.*/, "mail_location = maildir:~/Mail", options)

                        if !target['Protocols'].to_a.empty?
                            linuxConnection.updateFile(DOVECOT_DIR + 'dovecot.conf', options) do |configLines|
                                configLines << "protocols = #{target['Protocols'].join(' ')}\n"
                            end
                        end

                        linuxConnection.updateFile(DOVECOT_DIR + 'conf.d/10-mail.conf', options) do |configLines|
                            configLines << "mail_home = #{EMAIL_HOME}/emails/%u\n"
                            configLines << "first_valid_uid = #{uid}\n"
                            configLines << "last_valid_uid = #{uid}\n"
                        end

                        self.class.cutConfigSection(DOVECOT_DIR + 'conf.d/10-master.conf', 'service lmtp', options, linuxConnection)
                        linuxConnection.updateFile(DOVECOT_DIR + 'conf.d/10-master.conf', options) do |configLines|
                            configLines << "service lmtp {\n"
                            configLines << "    unix_listener lmtp {\n"
                            configLines << "        user = postfix\n"
                            configLines << "        group = postfix\n"
                            configLines << "        mode = 0600\n"
                            configLines << "    }\n"
                            configLines << "}\n"
                        end

                        self.class.cutConfigSection(DOVECOT_DIR + 'conf.d/15-mailboxes.conf', 'namespace inbox', options, linuxConnection)
                        linuxConnection.updateFile(DOVECOT_DIR + 'conf.d/15-mailboxes.conf', options) do |configLines|
                            configLines << "namespace inbox {\n"
                            configLines << "    mailbox INBOX {\n"
                            configLines << "        auto = subscribe\n"
                            configLines << "    }\n"
                            configLines << "    mailbox Drafts {\n"
                            configLines << "        special_use = \\Drafts\n"
                            configLines << "        auto = subscribe\n"
                            configLines << "    }\n"
                            #configLines << "    mailbox Junk {\n"
                            #configLines << "        special_use = \\Junk\n"
                            #configLines << "        auto = subscribe\n"
                            #configLines << "    }\n"
                            configLines << "    mailbox Trash {\n"
                            configLines << "        special_use = \\Trash\n"
                            configLines << "        auto = subscribe\n"
                            configLines << "    }\n"
                            configLines << "    mailbox Sent {\n"
                            configLines << "        special_use = \\Sent\n"
                            configLines << "        auto = subscribe\n"
                            configLines << "    }\n"
                            configLines << "}\n"
                        end

                        linuxConnection.firewallAddService('imaps', options)

                        linuxConnection.fileReplace("#{DOVECOT_DIR}conf.d/10-auth.conf", /^!include auth-system.conf.ext/, "#!include auth-system.conf.ext", options)

                        if target['OAuth2']
                            linuxConnection.fileReplace("#{DOVECOT_DIR}conf.d/10-auth.conf", /auth_mechanisms =.*/, "auth_mechanisms = xoauth2 oauthbearer", options)

                            linuxConnection.updateFile(DOVECOT_DIR + 'conf.d/10-auth.conf', options) do |configLines|
                                configLines << "userdb {\n"
                                configLines << "    driver = static\n"
                                configLines << "    args = allow_all_users=yes\n"
                                configLines << "}\n"
                                configLines << "passdb {\n"
                                configLines << "    driver = oauth2\n"
                                configLines << "    mechanisms = xoauth2 oauthbearer\n"
                                configLines << "    args = #{DOVECOT_DIR}dovecot-oauth2.conf.ext\n"
                                configLines << "}\n"
                            end

                            linuxConnection.updateFile(DOVECOT_DIR + 'dovecot-oauth2.conf.ext', options) do |configLines|
                                # Need v2.3.16+
                                #configLines << "openid_configuration_url = #{target['OAuth2']['OIDC']}\n"
                                if target['OAuth2']['TokenInfo']
                                    configLines << "tokeninfo_url = #{target['OAuth2']['TokenInfo']}\n"
                                end
                                if target['OAuth2']['Introspection']
                                    configLines << "introspection_url = #{target['OAuth2']['Introspection']}\n"
                                end

                                secretId = target['OAuth2']['SecretId']
                                secretId = target['SecretId'] unless secretId
                                clientId = context.secrets.load(secretId, 'OAUTH2_CLIENT_ID')
                                clientId = target['OAuth2']['ClientID'] unless clientId
                                clientSecret = context.secrets.load(secretId, 'OAUTH2_CLIENT_SECRET')

                                if clientId
                                    configLines << "client_id = #{clientId}\n"
                                end
                                if clientSecret
                                    configLines << "client_secret = #{clientSecret}\n"
                                end
                            end
                        else
                            linuxConnection.fileReplace("#{DOVECOT_DIR}conf.d/10-auth.conf", /auth_mechanisms =.*/, "auth_mechanisms = plain", options)

                            linuxConnection.updateFile(DOVECOT_DIR + 'conf.d/10-auth.conf', options) do |configLines|
                                configLines << "auth_username_format = %u\n"
                                configLines << "userdb {\n"
                                configLines << "    driver = static\n"
                                configLines << "    args = allow_all_users=yes\n"
                                configLines << "}\n"
                                configLines << "passdb {\n"
                                configLines << "    driver = passwd-file\n"
                                configLines << "    args = #{DOVECOT_DIR}passwords\n"
                                configLines << "}\n"
                            end
                            linuxConnection.exec("touch #{DOVECOT_DIR}passwords", options)
                            linuxConnection.setUserGroup("#{DOVECOT_DIR}passwords", 'dovecot', 'dovecot', options)
                            linuxConnection.setPrivate("#{DOVECOT_DIR}passwords", options)
                        end

                        certDir = linuxConnection.createWildecardCertificate(options)
                        linuxConnection.updateFile(DOVECOT_DIR + 'conf.d/10-ssl.conf', options) do |configLines|
                            configLines << "ssl_cert = <#{certDir}fullchain.pem\n"
                            configLines << "ssl_key = <#{certDir}privkey.pem\n"
                            if !target['Domains'].to_h.empty?
                                target['Domains'].each do |domain, config|
                                    if config['CertName']
                                        configLines << "local_name #{Addressable::IDNA.to_ascii(domain)} {\n"
                                        configLines << "    ssl_cert = </etc/letsencrypt/live/#{config['CertName']}/fullchain.pem\n"
                                        configLines << "    ssl_key = </etc/letsencrypt/live/#{config['CertName']}/privkey.pem\n"
                                        configLines << "}\n"
                                    end
                                end
                            end
                            configLines
                        end

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Dovecot, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.stopService(SERVICE_NAME, options)
                        linuxConnection.firewallRemoveService('imaps', options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.deleteUserAndGroup(EMAIL_USER, options)

                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

            def self.cutConfigSection(file, sectionStart, options, linuxConnection)
                localFile = options['output'] + '/' + SecureRandom.alphanumeric(10)
                File.write(localFile, '')
                linuxConnection.exec("touch #{file}", options)
                linuxConnection.download(file, localFile, options)
                fileData = File.read(localFile)
                position = fileData.index(sectionStart)
                if position
                    # Find the index of the closing brace of the section
                    # We use a regular expression to find the next non-nested closing brace
                    match = fileData[position..-1].match(/(?<=\{)(.*?)(^\})/m)
                    if match
                        fileData = fileData[0...position] + fileData[(position + match.end(0))..-1]
                    else
                        fileData = fileData[0...position]
                    end
                    File.write(localFile, fileData)
                    linuxConnection.upload(localFile, file, options)
                end
            end
        end

    end
end
