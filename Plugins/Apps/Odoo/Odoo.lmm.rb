
module ConfigLMM
    module LMM
        class Odoo < Framework::NginxApp

            USER = 'odoo'
            HOME_DIR = '/var/lib/odoo'

            def actionOdooBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Odoo', id, target, state, context, options)
            end

            def actionOdooDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionOdooDeploy(id, target, activeState, context, options)
                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        if !target.key?('Proxy') || target['Proxy'] != 'only'
                            dbPassword = self.configurePostgreSQL(target['Database'], ssh)
                            distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                            Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'Odoo', distroInfo, ssh)
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/config'")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/data'")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/addons'")

                            path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                            dbHost = '10.0.2.2'
                            dbHost = target['Database']['HostName'] if target['Database']['HostName']

                            self.class.sshExec!(ssh, " echo 'HOST=#{dbHost}' > #{path}/Odoo.env")
                            self.class.sshExec!(ssh, " echo 'USER=#{USER}' >> #{path}/Odoo.env")
                            self.class.sshExec!(ssh, " echo 'PASSWORD=#{dbPassword}' >> #{path}/Odoo.env")
                            self.class.sshExec!(ssh, "chown #{USER}:#{USER} #{path}/Odoo.env")
                            self.class.sshExec!(ssh, "chmod 600 #{path}/Odoo.env")

                            ssh.scp.upload!(__dir__ + '/Odoo.container', path)
                            ssh.scp.upload!(__dir__ + '/odoo.conf', HOME_DIR + '/config/')
                            self.class.sshExec!(ssh, "chown #{USER}:#{USER} #{HOME_DIR}/config/odoo.conf")
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ daemon-reload")
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ start Odoo")
                        end

                        if !target.key?('Proxy') || target['Proxy'] == true || target['Proxy'] == 'only'
                            raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                            Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
                            Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                            self.class.prepareNginxConfig(target, ssh)
                            self.writeNginxConfig(__dir__, 'Odoo', id, target, state, context, options)
                            self.deployNginxConfig(id, target, activeState, context, options)
                            Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)
                        end

                        Framework::LinuxApp.firewallAddPortOverSSH('8069/tcp', uri)
                    end
                else
                    if !target.key?('Proxy') || target['Proxy'] == true || target['Proxy'] == 'only'
                        deployNginxConfig(id, target, activeState, context, options)
                    end
                    activeState['Location'] = '@me'
                end
            end

            def configurePostgreSQL(settings, ssh)
                user = USER
                password = SecureRandom.alphanumeric(20)
                PostgreSQL.executeRemotelyOverSSH(settings, ssh) do |ssh|
                    self.class.sshExec!(ssh, "su --login #{PostgreSQL::USER_NAME} --command 'createuser --createdb #{user}'", true)
                    PostgreSQL.executeSQL("ALTER USER #{user} WITH PASSWORD '#{password}'", nil, ssh)
                end
                password
            end

        end
    end
end
