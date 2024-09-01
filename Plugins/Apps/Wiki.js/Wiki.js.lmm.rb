
module ConfigLMM
    module LMM
        class WikiJS < Framework::NginxApp

            USER = 'wikijs'
            HOME_DIR = '/var/lib/wikijs'
            HOST_IP = '10.0.2.2'

            def actionWikiJSDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        dbPassword = self.configurePostgreSQL(target['Database'], ssh)
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'Wiki.js', distroInfo, ssh)

                        path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                        self.class.exec("echo 'DB_TYPE=postgres' > #{path}/Wiki.js.env", ssh)
                        self.class.exec("echo 'DB_HOST=#{HOST_IP}' >> #{path}/Wiki.js.env", ssh)
                        self.class.exec("echo 'DB_PORT=5432' >> #{path}/Wiki.js.env", ssh)
                        self.class.exec("echo 'DB_USER=#{USER}' >> #{path}/Wiki.js.env", ssh)
                        self.class.exec("echo 'DB_NAME=#{USER}' >> #{path}/Wiki.js.env", ssh)
                        self.class.exec(" echo 'DB_PASS=#{dbPassword}' >> #{path}/Wiki.js.env", ssh)

                        self.class.exec("chown #{USER}:#{USER} #{path}/Wiki.js.env", ssh)
                        self.class.exec("chmod 600 #{path}/Wiki.js.env", ssh)

                        ssh.scp.upload!(__dir__ + '/Wiki.js.container', path)
                        self.class.exec("systemctl --user --machine=#{USER}@ daemon-reload", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart Wiki.js", ssh)

                        Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        self.writeNginxConfig(__dir__, 'Wiki.js', id, target, state, context, options)
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

