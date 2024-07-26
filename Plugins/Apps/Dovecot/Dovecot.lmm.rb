
module ConfigLMM
    module LMM
        class Dovecot < Framework::Plugin
            PACKAGE_NAME = 'Dovecot'
            SERVICE_NAME = 'dovecot'
            DOVECOT_DIR = '/etc/dovecot/'
            EMAIL_HOME = '/var/lib/email'
            EMAIL_USER = 'email'

            def actionDovecotDeploy(id, target, activeState, context, options)
                plugins[:Linux].ensurePackage(PACKAGE_NAME, target['Location'])
                plugins[:Linux].ensureServiceAutoStart(SERVICE_NAME, target['Location'])

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        distroInfo = Framework::LinuxApp.distroInfoFromSSH(ssh)
                        addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{EMAIL_HOME}' --create-home --comment 'Dovecot EMail' #{EMAIL_USER}"
                        self.class.sshExec!(ssh, addUserCmd, true)
                        uid = self.class.sshExec!(ssh, "id -u #{EMAIL_USER}").strip

                        cmd = "sed -i 's|^#mail_uid =.*|mail_uid = #{uid}|' #{DOVECOT_DIR}conf.d/10-mail.conf"
                        self.class.sshExec!(ssh, cmd)
                        cmd = "sed -i 's|^#mail_gid =.*|mail_gid = #{uid}|' #{DOVECOT_DIR}conf.d/10-mail.conf"
                        self.class.sshExec!(ssh, cmd)
                        cmd = "sed -i 's|^#mail_location =.*|mail_location = maildir:~/Mail|' #{DOVECOT_DIR}conf.d/10-mail.conf"
                        self.class.sshExec!(ssh, cmd)

                        updateRemoteFile(ssh, DOVECOT_DIR + 'conf.d/10-mail.conf', options) do |configLines|
                            configLines << "mail_home = #{EMAIL_HOME}/emails/%u\n"
                            configLines << "first_valid_uid = #{uid}\n"
                            configLines << "last_valid_uid = #{uid}\n"
                        end

                        self.class.cutConfigSection(DOVECOT_DIR + 'conf.d/10-master.conf', 'service lmtp', options, ssh)
                        updateRemoteFile(ssh, DOVECOT_DIR + 'conf.d/10-master.conf', options) do |configLines|
                            configLines << "service lmtp {\n"
                            configLines << "    unix_listener lmtp {\n"
                            configLines << "        user = postfix\n"
                            configLines << "        group = postfix\n"
                            configLines << "        mode = 0600\n"
                            configLines << "    }\n"
                            configLines << "}\n"
                        end

                        self.class.cutConfigSection(DOVECOT_DIR + 'conf.d/15-mailboxes.conf', 'namespace inbox', options, ssh)
                        updateRemoteFile(ssh, DOVECOT_DIR + 'conf.d/15-mailboxes.conf', options) do |configLines|
                            configLines << "namespace inbox {\n"
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

                        self.class.sshExec!(ssh, "firewall-cmd -q --add-service='imaps'")
                        self.class.sshExec!(ssh, "firewall-cmd -q --permanent --add-service='imaps'")

                        cmd = "sed -i 's|^!include auth-system.conf.ext|#!include auth-system.conf.ext|' #{DOVECOT_DIR}conf.d/10-auth.conf"
                        self.class.sshExec!(ssh, cmd)

                        if target['OAuth2']
                            cmd = "sed -i 's|auth_mechanisms =.*|auth_mechanisms = xoauth2 oauthbearer|' #{DOVECOT_DIR}conf.d/10-auth.conf"
                            self.class.sshExec!(ssh, cmd)

                            updateRemoteFile(ssh, DOVECOT_DIR + 'conf.d/10-auth.conf', options) do |configLines|
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

                            updateRemoteFile(ssh, DOVECOT_DIR + 'dovecot-oauth2.conf.ext', options) do |configLines|
                                # Need v2.3.16+
                                #configLines << "openid_configuration_url = #{target['OAuth2']['OIDC']}\n"
                                if target['OAuth2']['TokenInfo']
                                    configLines << "tokeninfo_url = #{target['OAuth2']['TokenInfo']}\n"
                                end
                                if target['OAuth2']['Introspection']
                                    configLines << "introspection_url = #{target['OAuth2']['Introspection']}\n"
                                end
                                if target['OAuth2']['ClientID']
                                    configLines << "client_id = #{target['OAuth2']['ClientID']}\n"
                                end
                                if ENV['DOVECOT_OAUTH2_SECRET']
                                    configLines << "client_secret = #{ENV['DOVECOT_OAUTH2_SECRET']}\n"
                                end
                            end
                        else
                            cmd = "sed -i 's|auth_mechanisms =.*|auth_mechanisms = plain|' #{DOVECOT_DIR}conf.d/10-auth.conf"
                            self.class.sshExec!(ssh, cmd)

                            updateRemoteFile(ssh, DOVECOT_DIR + 'conf.d/10-auth.conf', options) do |configLines|
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
                            self.class.sshExec!(ssh, "touch #{DOVECOT_DIR}passwords")
                            self.class.sshExec!(ssh, "chown dovecot:dovecot #{DOVECOT_DIR}passwords")
                            self.class.sshExec!(ssh, "chmod 600 #{DOVECOT_DIR}passwords")
                        end

                        certDir = Framework::LinuxApp.createCertificateOverSSH(ssh)
                        updateRemoteFile(ssh, DOVECOT_DIR + 'conf.d/10-ssl.conf', options) do |configLines|
                            configLines << "ssl_cert = <#{certDir}fullchain.pem\n"
                            configLines << "ssl_key = <#{certDir}privkey.pem\n"
                        end
                    end
                else
                    # TODO
                end

                plugins[:Linux].startService(SERVICE_NAME, target['Location'])
            end

            def self.cutConfigSection(file, sectionStart, options, ssh)
                localFile = options['output'] + '/' + SecureRandom.alphanumeric(10)
                File.write(localFile, '')
                self.sshExec!(ssh, "touch #{file}")
                ssh.scp.download!(file, localFile)
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
                    ssh.scp.upload!(localFile, file)
                end
            end
        end

    end
end
