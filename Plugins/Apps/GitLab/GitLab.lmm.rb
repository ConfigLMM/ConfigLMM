
module ConfigLMM
    module LMM
        class GitLab < Framework::Plugin

            HOME_DIR = '/var/lib/gitlab'
            IMAGE_ID = 'docker.io/gitlab/gitlab-ce:latest'

            def actionGitLabDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.createDirs(options, "#{HOME_DIR}/config", "#{HOME_DIR}/logs", "#{HOME_DIR}/data", "#{HOME_DIR}/backups")

                        path = '/etc/containers/systemd'
                        linuxConnection.upload(__dir__ + '/GitLab.container', path, options)

                        if !target.key?('Proxy') || target['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.provisionProxy('http://127.0.0.1:18100', 'GitLab', target, activeState, context, options)
                            end
                        elsif target.key?('Proxy') && target['Proxy'] == false
                            linuxConnection.fileReplace("#{path}/GitLab.container", 'PublishPort=127.0.0.1:18100:', 'PublishPort=0.0.0.0:18100:', options)
                            linuxConnection.firewallAddPort('18100/tcp', options)
                        end

                        linuxConnection.reloadServiceManager(options)
                        linuxConnection.restartService('GitLab', options)

                        configFile = HOME_DIR + '/config/gitlab.rb'
                        if options['dry']
                            linuxConnection.filePresent?(configFile, options)
                        else
                            counter = 200
                            while !linuxConnection.filePresent?(configFile, options)
                                counter -= 1
                                raise "Timeout while waiting for #{configFile}!" if counter <= 0
                                sleep(2)
                            end
                        end
                        linuxConnection.updateFile(configFile, options, true) do |fileLines|
                            fileLines << "external_url 'https://#{target['Domain']}'\n"
                            fileLines << "letsencrypt['enable'] = false\n"
                            fileLines << "nginx['listen_port'] = 80\n"
                            fileLines << "nginx['listen_https'] = false\n"
                            fileLines << "registry_nginx['listen_port'] = 80\n"
                            fileLines << "registry_nginx['listen_https'] = false\n"
                            fileLines << "mattermost_nginx['listen_port'] = 80\n"
                            fileLines << "mattermost_nginx['listen_https'] = false\n"
                            if target['SMTP']
                                fileLines << "gitlab_rails['smtp_address'] = '#{target['SMTP']['Host']}'\n"
                                fileLines << "gitlab_rails['smtp_port'] = '#{target['SMTP']['Port']}'\n"
                                fileLines << "gitlab_rails['smtp_user_name'] = '#{target['SMTP']['Username']}'\n"
                                if target['SMTP']['TLS']
                                    fileLines << "gitlab_rails['smtp_tls'] = true\n"
                                    fileLines << "gitlab_rails['smtp_openssl_verify_mode'] = 'peer'\n"
                                end
                            end
                        end

                        linuxConnection.restartService('GitLab', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:GitLab, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if item['Config']['Proxy'].nil? || item['Config']['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.cleanupConfig('GitLab', context, options)
                                nginxConnection.reload(options)
                            end
                        end
                        linuxConnection.firewallRemovePort('18100/tcp', options)
                        linuxConnection.stopService('GitLab', options)
                        linuxConnection.rm('/etc/containers/systemd/GitLab.container', options[:dry])
                        linuxConnection.exec("podman rmi #{IMAGE_ID}", true, options)
                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]
                        if options[:destroy]
                            connection.rm('/var/lib/gitlab', options[:dry])
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end

    end
end

