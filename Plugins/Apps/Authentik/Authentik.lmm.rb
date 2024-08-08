
module ConfigLMM
    module LMM
        class Authentik < Framework::NginxApp

            USER = 'authentik'
            HOME_DIR = '/var/lib/authentik'
            HOST_IP = '10.0.2.2'

            def actionAuthentikBuild(id, target, state, context, options)
                self.writeNginxConfig(__dir__, 'Authentik', id, target, state, context, options)
            end

            def actionAuthentikDeploy(id, target, activeState, context, options)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'ssh'
                        self.class.sshStart(uri) do |ssh|
                            self.prepareConfig(target, ssh)

                            dbPassword = self.configurePostgreSQL(target['Database'], ssh)
                            distroInfo = Framework::LinuxApp.distroInfoFromSSH(ssh)
                            Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'Authentik IdP and SSO', distroInfo, ssh)
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/media'")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/templates'")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/certs'")

                            path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                            self.class.sshExec!(ssh, " echo 'AUTHENTIK_SECRET_KEY=#{SecureRandom.urlsafe_base64(60)}' > #{path}/Authentik.env")
                            self.class.sshExec!(ssh, " echo 'AUTHENTIK_REDIS__HOST=#{HOST_IP}' >> #{path}/Authentik.env")
                            self.class.sshExec!(ssh, " echo 'AUTHENTIK_POSTGRESQL__HOST=#{HOST_IP}' >> #{path}/Authentik.env")
                            self.class.sshExec!(ssh, " echo 'AUTHENTIK_POSTGRESQL__PASSWORD=#{dbPassword}' >> #{path}/Authentik.env")
                            self.class.sshExec!(ssh, "chown #{USER}:#{USER} #{path}/Authentik.env")
                            self.class.sshExec!(ssh, "chmod 600 #{path}/Authentik.env")

                            ssh.scp.upload!(__dir__ + '/Authentik-Server.container', path)
                            ssh.scp.upload!(__dir__ + '/Authentik-Worker.container', path)
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ daemon-reload")
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ start Authentik-Server")
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ start Authentik-Worker")

                            Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                            self.writeNginxConfig(__dir__, 'Authentik', id, target, state, context, options)
                            self.deployNginxConfig(id, target, activeState, context, options)
                            Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)
                        end
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    # TODO
                end
            end

            def prepareConfig(target, ssh)
              target['Database'] ||= {}

              raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

              Framework::LinuxApp.ensurePackagesOverSSH([NGINX_PACKAGE], ssh)
              self.class.prepareNginxConfig(target, ssh)
            end

            def configurePostgreSQL(settings, ssh)
                password = SecureRandom.alphanumeric(20)
                PostgreSQL.createRemoteUserAndDBOverSSH(settings, USER, password, ssh)
                password
            end

        end
    end
end
