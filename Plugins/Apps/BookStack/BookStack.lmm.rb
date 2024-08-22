
module ConfigLMM
    module LMM
        class BookStack < Framework::NginxApp

            USER = 'bookstack'
            HOME_DIR = '/var/lib/bookstack'
            HOST_IP = '10.0.2.2'

            def actionBookStackDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        dbPassword = self.configureMariaDB(target['Database'], activeState, ssh)
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'BookStack', distroInfo, ssh)
                        self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/config'")

                        path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                        self.class.exec(" echo 'DB_HOST=#{HOST_IP}' > #{path}/BookStack.env", ssh)
                        self.class.exec(" echo 'DB_DATABASE=#{USER}' >> #{path}/BookStack.env", ssh)
                        self.class.exec(" echo 'DB_USERNAME=#{USER}' >> #{path}/BookStack.env", ssh)
                        self.class.exec(" echo 'DB_PASSWORD=#{dbPassword}' >> #{path}/BookStack.env", ssh)
                        self.class.exec(" echo 'APP_URL=https://#{target['Domain']}' >> #{path}/BookStack.env", ssh)

                        if target['OIDC'] && target['OIDC']['Issuer']
                            self.class.exec(" echo 'AUTH_METHOD=oidc' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'AUTH_AUTO_INITIATE=true' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'OIDC_CLIENT_ID=#{ENV['BOOKSTACK_OIDC_CLIENT_ID']}' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'OIDC_CLIENT_SECRET=#{ENV['BOOKSTACK_OIDC_CLIENT_SECRET']}' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'OIDC_ISSUER=#{target['OIDC']['Issuer']}' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'OIDC_ISSUER_DISCOVER=true' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'OIDC_USER_TO_GROUPS=true' >> #{path}/BookStack.env", ssh)
                        end

                        if target['SMTP']
                            host = target['SMTP']['Host']
                            host = HOST_IP if ['localhost', '127.0.0.1'].include?(host)
                            self.class.exec(" echo 'MAIL_HOST=#{host}' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'MAIL_PORT=#{target['SMTP']['Port']}' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'MAIL_USERNAME=#{target['SMTP']['Username']}' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'MAIL_PASSWORD=#{ENV['BOOKSTACK_SMTP_PASSWORD']}' >> #{path}/BookStack.env", ssh)
                            self.class.exec(" echo 'MAIL_FROM=#{target['SMTP']['From']}' >> #{path}/BookStack.env", ssh)
                        end

                        self.class.exec("chown #{USER}:#{USER} #{path}/BookStack.env", ssh)
                        self.class.exec("chmod 600 #{path}/BookStack.env", ssh)

                        ssh.scp.upload!(__dir__ + '/BookStack.container', path)
                        self.class.exec("systemctl --user --machine=#{USER}@ daemon-reload", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart BookStack", ssh)

                        Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        self.writeNginxConfig(__dir__, 'BookStack', id, target, state, context, options)
                        self.deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)
                    end
                else
                    # TODO
                end
            end

            def configureMariaDB(settings, activeState, ssh)
                password = SecureRandom.alphanumeric(20)
                MariaDB.createRemoteUserAndDB(settings, USER, password, ssh)
                password
            end

        end
    end
end

