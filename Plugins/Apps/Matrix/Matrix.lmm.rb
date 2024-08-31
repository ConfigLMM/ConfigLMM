
module ConfigLMM
    module LMM
        class Matrix < Framework::NginxApp

            USER = 'matrix'
            HOME_DIR = '/var/lib/matrix'

            def actionMatrixBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Matrix', id, target, state, context, options)
            end

            def actionMatrixDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionMatrixDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']
                raise Framework::PluginProcessError.new('ServerName field must be set!') unless target['ServerName']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        dbPassword = self.configurePostgreSQL(target['Database'], ssh)
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)

                        Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'Matrix', distroInfo, ssh)
                        self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/data'")

                        path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                        self.class.exec("touch #{path}/Matrix.env", ssh)

                        self.class.exec("chown #{USER}:#{USER} #{path}/Matrix.env", ssh)
                        self.class.exec("chmod 600 #{path}/Matrix.env", ssh)

                        ssh.scp.upload!(__dir__ + '/homeserver.yaml', HOME_DIR + '/data/')
                        ssh.scp.upload!(__dir__ + '/log.config', HOME_DIR + '/data/')
                        ssh.scp.upload!(__dir__ + '/config.json', HOME_DIR + '/')
                        self.class.exec("chown -R #{USER}:#{USER} #{HOME_DIR}/data", ssh)

                        self.class.exec("sed -i 's|$SERVER_NAME|#{target['ServerName']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        self.class.exec("sed -i 's|$SYNAPSE_DOMAIN|#{target['SynapseDomain'].downcase}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        self.class.exec("sed -i 's|$DB_PASSWORD|#{dbPassword}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        self.class.exec("sed -i 's|$SECRET1|#{SecureRandom.urlsafe_base64(45)}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        self.class.exec("sed -i 's|$SECRET2|#{SecureRandom.urlsafe_base64(45)}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        self.class.exec("sed -i 's|$SECRET3|#{SecureRandom.urlsafe_base64(45)}|' #{HOME_DIR}/data/homeserver.yaml", ssh)

                        self.class.exec("sed -i 's|$SYNAPSE_DOMAIN|#{target['SynapseDomain']}|' #{HOME_DIR}/config.json", ssh)
                        self.class.exec("sed -i 's|$SERVER_NAME|#{target['ServerName']}|' #{HOME_DIR}/config.json", ssh)

                        if target['SMTP']
                            host = target['SMTP']['Host']
                            host = HOST_IP if ['localhost', '127.0.0.1'].include?(host)
                            self.class.exec("sed -i 's|smtp_host:.*|smtp_host: #{host}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            self.class.exec("sed -i 's|smtp_port:.*|smtp_port: #{target['SMTP']['Port']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            self.class.exec("sed -i 's|smtp_user:.*|smtp_user: #{target['SMTP']['Username']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            self.class.exec("sed -i 's|smtp_pass:.*|smtp_pass: #{ENV['MATRIX_SMTP_PASSWORD']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            self.class.exec("sed -i 's|notif_from:.*|notif_from: #{target['SMTP']['From']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)

                            if target['SMTP']['Port'] == 465
                                self.class.exec("sed -i 's|force_tls:.*|force_tls: true|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            end
                        else
                            self.class.exec("sed -i 's|email:|ignore_email:|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        end

                        if target['OIDC']
                            self.class.exec("sed -i 's|$OIDC_ISSUER|#{target['OIDC']['Issuer']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            self.class.exec("sed -i 's|$CLIENT_ID|#{ENV['MATRIX_OIDC_CLIENT_ID']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            self.class.exec("sed -i 's|$CLIENT_SECRET|#{ENV['MATRIX_OIDC_CLIENT_SECRET']}|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                            self.class.exec("sed -i 's|enabled: true|enabled: false|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        else
                            self.class.exec("sed -i 's|oidc_providers:|ignore_oidc_providers:|' #{HOME_DIR}/data/homeserver.yaml", ssh)
                        end

                        ssh.scp.upload!(__dir__ + '/Synapse.container', path)
                        ssh.scp.upload!(__dir__ + '/Element.container', path)
                        self.class.exec("systemctl --user --machine=#{USER}@ daemon-reload", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart Synapse", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart Element", ssh)

                        Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        self.writeNginxConfig(__dir__, 'Matrix', id, target, state, context, options)
                        self.deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)

                    end
                else
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

            def configurePostgreSQL(settings, ssh)
                password = SecureRandom.alphanumeric(20)
                PostgreSQL.createRemoteUserAndDBOverSSH(settings, USER, password, ssh)
                password
            end

        end
    end
end
