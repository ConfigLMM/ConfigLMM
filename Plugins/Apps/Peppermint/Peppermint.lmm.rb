
module ConfigLMM
    module LMM
        class Peppermint < Framework::NginxApp

            USER = 'peppermint'
            HOME_DIR = '/var/lib/peppermint'
            HOST_IP = '10.0.2.2'

            def actionPeppermintDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        dbPassword = self.configurePostgreSQL(target['Database'], ssh)
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'Peppermint Ticket Management', distroInfo, ssh)

                        path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                        self.class.sshExec!(ssh, " echo 'DB_HOST=#{HOST_IP}' > #{path}/Peppermint.env")
                        self.class.sshExec!(ssh, " echo 'DB_USERNAME=#{USER}' >> #{path}/Peppermint.env")
                        self.class.sshExec!(ssh, " echo 'DB_PASSWORD=#{dbPassword}' >> #{path}/Peppermint.env")
                        self.class.sshExec!(ssh, " echo 'SECRET=#{SecureRandom.urlsafe_base64(60)}' >> #{path}/Peppermint.env")
                        self.class.sshExec!(ssh, " echo 'API_URL=https://#{target['Domain']}/api' >> #{path}/Peppermint.env")
                        self.class.sshExec!(ssh, "chown #{USER}:#{USER} #{path}/Peppermint.env")
                        self.class.sshExec!(ssh, "chmod 600 #{path}/Peppermint.env")

                        ssh.scp.upload!(__dir__ + '/Peppermint.container', path)
                        self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ daemon-reload")
                        self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ start Peppermint")

                        Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        self.writeNginxConfig(__dir__, 'Peppermint', id, target, state, context, options)
                        self.deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)
                    end
                else
                    # TODO
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

