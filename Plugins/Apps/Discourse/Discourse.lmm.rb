
module ConfigLMM
    module LMM
        class Discourse < Framework::NginxApp

            USER = 'discourse'
            HOME_DIR = '/var/lib/discourse'
            HOST_IP = '10.0.2.2'

            def actionDiscourseDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        dbPassword = self.configurePostgreSQL(target['Database'], ssh)
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'Discourse', distroInfo, ssh)
                        self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/data ~/sidekiq'")

                        path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                        self.class.exec("echo 'DISCOURSE_DATABASE_HOST=#{HOST_IP}' > #{path}/Discourse.env", ssh)
                        self.class.exec("echo 'DISCOURSE_DATABASE_NAME=#{USER}' >> #{path}/Discourse.env", ssh)
                        self.class.exec(" echo 'DISCOURSE_DATABASE_USER=#{USER}' >> #{path}/Discourse.env", ssh)
                        self.class.exec(" echo 'DISCOURSE_DATABASE_PASSWORD=#{dbPassword}' >> #{path}/Discourse.env", ssh)
                        self.class.exec("echo 'DISCOURSE_HOST=#{target['Domain']}' >> #{path}/Discourse.env", ssh)

                        self.class.exec("echo 'DISCOURSE_REDIS_HOST=#{HOST_IP}' >> #{path}/Discourse.env", ssh)
                        self.class.exec(" echo 'DISCOURSE_REDIS_PASSWORD=#{ENV['REDIS_PASSWORD']}' >> #{path}/Discourse.env", ssh)

                        if target['SMTP']
                            host = target['SMTP']['Host']
                            host = HOST_IP if ['localhost', '127.0.0.1'].include?(host)
                            self.class.exec("echo 'DISCOURSE_SMTP_HOST=#{host}' >> #{path}/Discourse.env", ssh)
                            self.class.exec("echo 'DISCOURSE_SMTP_PORT_NUMBER=#{target['SMTP']['Port']}' >> #{path}/Discourse.env", ssh)
                            self.class.exec(" echo 'DISCOURSE_SMTP_USER=#{target['SMTP']['Username']}' >> #{path}/Discourse.env", ssh)
                            self.class.exec(" echo 'DISCOURSE_SMTP_PASSWORD=#{ENV['DISCOURSE_SMTP_PASSWORD']}' >> #{path}/Discourse.env", ssh)
                            auth = target['SMTP']['Auth'].to_s.downcase
                            auth = 'plain' if auth.empty?
                            self.class.exec("echo 'DISCOURSE_SMTP_AUTH=#{auth}' >> #{path}/Discourse.env", ssh)
                            if target['SMTP']['Port'] == 465
                                self.class.exec("echo 'DISCOURSE_EXTRA_CONF_CONTENT=smtp_force_tls = true' >> #{path}/Discourse.env", ssh)
                            end
                        end

                        self.class.exec(" echo 'DISCOURSE_PRECOMPILE_ASSETS=no' >> #{path}/Discourse.env", ssh)
                        self.class.exec("echo 'CHEAP_SOURCE_MAPS=1' >> #{path}/Discourse.env", ssh)
                        self.class.exec("echo 'JOBS=1' >> #{path}/Discourse.env", ssh)

                        self.class.exec("chown #{USER}:#{USER} #{path}/Discourse.env", ssh)
                        self.class.exec("chmod 600 #{path}/Discourse.env", ssh)

                        ssh.scp.upload!(__dir__ + '/Discourse.container', path)
                        ssh.scp.upload!(__dir__ + '/Discourse-Sidekiq.container', path)
                        self.class.exec("systemctl --user --machine=#{USER}@ daemon-reload", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart Discourse", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart Discourse-Sidekiq", ssh)

                        Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        self.writeNginxConfig(__dir__, 'Discourse', id, target, state, context, options)
                        self.deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)

                        containers = JSON.parse(self.class.exec("su --login #{USER} --shell /usr/bin/sh --command 'podman ps --format json --filter name=^Discourse$'", ssh).strip)
                        raise 'Failed to find container!' if containers.empty?
                        if !target['Plugins'].to_a.empty?
                            target['Plugins'].each do |plugin|
                                self.class.exec("su --login #{USER} --shell /usr/bin/sh --command \"podman exec --workdir /opt/bitnami/discourse #{containers.first['Id']} sh -c 'RAILS_ENV=production bundle exec rake plugin:install repo=#{plugin}'\"", ssh, true)
                            end
                        end

                        self.class.exec("su --login #{USER} --shell /usr/bin/sh --command \"podman exec --workdir /opt/bitnami/discourse #{containers.first['Id']} sh -c 'RAILS_ENV=production CHEAP_SOURCE_MAPS=1 JOBS=1 bundle exec rake assets:precompile'\"", ssh)
                    end
                else
                    # TODO
                end
            end

            def configurePostgreSQL(settings, ssh)
                password = SecureRandom.alphanumeric(20)
                PostgreSQL.createRemoteUserAndDBOverSSH(settings, USER, password, ssh)
                PostgreSQL.createExtensions(settings, USER, ['hstore', 'pg_trgm'], ssh)
                password
            end

        end
    end
end

