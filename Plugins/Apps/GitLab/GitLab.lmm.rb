
module ConfigLMM
    module LMM
        class GitLab < Framework::NginxApp

            HOME_DIR = '/var/lib/gitlab'

            def actionGitLabDeploy(id, target, activeState, context, options)

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        self.prepareConfig(target, ssh)

                        distroInfo = Framework::LinuxApp.distroInfoFromSSH(ssh)
                        self.class.sshExec!(ssh, "mkdir -p #{HOME_DIR}/config")
                        self.class.sshExec!(ssh, "mkdir -p #{HOME_DIR}/logs")
                        self.class.sshExec!(ssh, "mkdir -p #{HOME_DIR}/data")
                        self.class.sshExec!(ssh, "mkdir -p #{HOME_DIR}/backups")

                        path = '/etc/containers/systemd'
                        ssh.scp.upload!(__dir__ + '/GitLab.container', path)
                        self.class.sshExec!(ssh, "systemctl daemon-reload")
                        self.class.sshExec!(ssh, "systemctl start GitLab")

                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.writeNginxConfig(__dir__, 'GitLab', id, target, state, context, options)
                        self.deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)

                        configFile = '/var/lib/gitlab/config/gitlab.rb'
                        while !self.class.remoteFilePresent?(configFile, ssh)
                            sleep(2)
                        end
                        updateRemoteFile(ssh, configFile, options, true) do |fileLines|
                            fileLines << "external_url 'https://#{target['Domain']}'\n"
                            fileLines << "letsencrypt['enable'] = false\n"
                            fileLines << "nginx['listen_port'] = 80\n"
                            fileLines << "nginx['listen_https'] = false\n"
                            fileLines << "registry_nginx['listen_port'] = 80\n"
                            fileLines << "registry_nginx['listen_https'] = false\n"
                            fileLines << "mattermost_nginx['listen_port'] = 80\n"
                            fileLines << "mattermost_nginx['listen_https'] = false\n"
                            if target['SMTP']
                                fileLines << "gitlab_rails['smtp_address'] = '#{target['SMTP']['HostName']}'\n"
                                fileLines << "gitlab_rails['smtp_port'] = '#{target['SMTP']['Port']}'\n"
                                fileLines << "gitlab_rails['smtp_user_name'] = '#{target['SMTP']['User']}'\n"
                                if target['SMTP']['TLS']
                                    fileLines << "gitlab_rails['smtp_tls'] = true\n"
                                    fileLines << "gitlab_rails['smtp_openssl_verify_mode'] = 'peer'\n"
                                end
                            end
                        end

                        self.class.sshExec!(ssh, "systemctl restart GitLab")
                    end
                else
                    # TODO
                end
            end

            def prepareConfig(target, ssh)
              raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

              Framework::LinuxApp.ensurePackagesOverSSH([NGINX_PACKAGE], ssh)
              self.class.prepareNginxConfig(target, ssh)
            end

        end

    end
end

