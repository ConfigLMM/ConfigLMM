
module ConfigLMM
    module LMM
        class GitLab < Framework::NginxApp

            HOME_DIR = '/var/lib/gitlab'
            IMAGE_ID = 'docker.io/gitlab/gitlab-ce:latest'

            def actionGitLabDeploy(id, target, activeState, context, options)

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        self.prepareConfig(target, ssh)

                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        self.class.exec("mkdir -p #{HOME_DIR}/config", ssh)
                        self.class.exec("mkdir -p #{HOME_DIR}/logs", ssh)
                        self.class.exec("mkdir -p #{HOME_DIR}/data", ssh)
                        self.class.exec("mkdir -p #{HOME_DIR}/backups", ssh)

                        path = '/etc/containers/systemd'
                        ssh.scp.upload!(__dir__ + '/GitLab.container', path)

                        if !target.key?('Proxy') || target['Proxy']
                            deployNginxProxyConfig('http://127.0.0.1:18100', 'GitLab', id, target, activeState, state, context, options, ssh)
                        elsif target.key?('Proxy') && target['Proxy'] == false
                            self.class.exec("sed -i 's|PublishPort=127.0.0.1:18100:|PublishPort=0.0.0.0:18100:|' #{path}/GitLab.container", ssh)
                            Framework::LinuxApp.firewallAddPort('18100/tcp', ssh)
                        end

                        Framework::LinuxApp.reloadServiceManager(ssh)
                        Framework::LinuxApp.restartService('GitLab', ssh)

                        configFile = HOME_DIR + '/config/gitlab.rb'
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

                        Framework::LinuxApp.restartService('GitLab', ssh)
                    end
                else
                    # TODO
                end
                activeState['Status'] = State::STATUS_DEPLOYED
            end

            def prepareConfig(target, ssh)
              raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

              Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
              self.class.prepareNginxConfig(target, ssh)
            end

            def cleanup(configs, state, context, options)
                cleanupType(:GitLab, configs, state, context, options) do |item, id, state, context, options, ssh|
                    if item['Proxy'].nil? || item['Proxy']
                        self.cleanupNginxConfig('GitLab', id, state, context, options, ssh)
                        self.class.reload(ssh, options[:dry])
                    end
                    Framework::LinuxApp.firewallRemovePort('18100/tcp', ssh, options[:dry])
                    Framework::LinuxApp.stopService('GitLab', ssh, options[:dry])
                    rm('/etc/containers/systemd/GitLab.container', options[:dry], ssh)
                    self.class.exec("podman rmi #{IMAGE_ID}", ssh, true, options[:dry])
                    state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]
                    if options[:destroy]
                        rm('/var/lib/gitlab', options[:dry], ssh)
                        rm('/var/log/nginx/gitlab.access.log', options[:dry], ssh)
                        rm('/var/log/nginx/gitlab.error.log', options[:dry], ssh)
                        state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                    end
                end
            end

        end

    end
end

