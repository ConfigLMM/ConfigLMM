
module ConfigLMM
    module LMM
        class Nextcloud < Framework::NginxApp

            USER = 'nextcloud'
            HOME_DIR = '/var/lib/nextcloud'
            PACKAGE_NAME = 'Nextcloud'

            def actionNextcloudBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Nextcloud', id, target, state, context, options)
            end

            def actionNextcloudDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionNextcloudDeploy(id, target, activeState, context, options)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        Framework::LinuxApp.ensurePackages([PHP_FPM::PHPFPM_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(PHP_FPM::PHPFPM_SERVICE, ssh)
                        distroInfo = Framework::LinuxApp.ensurePackages([PACKAGE_NAME], ssh)
                        addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{HOME_DIR}' --create-home --comment 'Nextcloud' #{USER}"
                        self.class.sshExec!(ssh, addUserCmd, true)
                        self.class.sshExec!(ssh, "mkdir -p /var/log/php/ /var/lib/nextcloud/apps/ /var/lib/nextcloud/data/")
                        self.class.sshExec!(ssh, "touch /var/log/php/nextcloud.errors.log")
                        self.class.sshExec!(ssh, "touch /var/log/php/nextcloud.mail.log")
                        self.class.sshExec!(ssh, "chown #{USER}:#{USER} /var/log/php/nextcloud.errors.log")
                        self.class.sshExec!(ssh, "chown #{USER}:#{USER} /var/log/php/nextcloud.mail.log")
                        PHP_FPM::fixConfigFileOverSSH(distroInfo, ssh)

                        webappsDir = PHP_FPM::webappsDir(distroInfo)
                        configDir = webappsDir + 'nextcloud/config/'
                        if !self.class.remoteFilePresent?(configDir + 'config.php', ssh)
                            self.class.uploadNotPresent(__dir__ + '/config.php', configDir, ssh)
                            self.class.sshExec!(ssh, "sed -i \"s|'instanceid' .*|'instanceid' => '#{SecureRandom.alphanumeric(10)}',|\" #{configDir}config.php")
                            self.class.sshExec!(ssh, "touch #{configDir}CAN_INSTALL")
                            self.class.sshExec!(ssh, "sed -i 's|/usr/share/webapps/|#{webappsDir}|' #{configDir}config.php")
                        end
                        self.class.sshExec!(ssh, "chown -R nextcloud:nextcloud #{configDir}")
                        self.class.sshExec!(ssh, "chown -R nextcloud:nextcloud /var/lib/nextcloud/")

                        target['Database'] ||= {}
                        if !target['Database']['Type'] || target['Database']['Type'] == 'pgsql'
                            PostgreSQL.createRemoteUserAndDBOverSSH(target['Database'], USER, nil, ssh)
                        end

                        target['User'] = USER unless target['User']
                        name = 'nextcloud'
                        self.updateRemoteFile(ssh, PHP_FPM.configDir(distroInfo) + name + '.conf', options, false, ';') do |configLines|
                            PHP_FPM.writeConfig(name, target, distroInfo, configLines)
                        end

                        Framework::LinuxApp.startServiceOverSSH(PHP_FPM::PHPFPM_SERVICE, ssh)

                        self.class.ensurePackage(ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        self.writeNginxConfig(__dir__, 'Nextcloud', id, target, state, context, options)
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        webappsDir = PHP_FPM::webappsDir(distroInfo)
                        nginxFile = options['output'] + '/nginx/servers-lmm/Nextcloud.conf'
                        `sed -i 's|root .*|root #{webappsDir}nextcloud;|' #{nginxFile}`
                        deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startService(NGINX_PACKAGE, ssh)
                        self.class.reload(ssh)
                    end
                else
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
                activeState['Status'] = State::STATUS_DEPLOYED
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Nextcloud, configs, state, context, options) do |item, id, state, context, options, ssh|
                    self.cleanupNginxConfig('Nextcloud', id, state, context, options, ssh)
                    self.class.reload(ssh, options[:dry])
                    distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                    rm(PHP_FPM.configDir(distroInfo) + 'nextcloud.conf', options[:dry], ssh)
                    Framework::LinuxApp.reloadService(PHP_FPM::PHPFPM_SERVICE, ssh, options[:dry])
                    Framework::LinuxApp.removePackage(PACKAGE_NAME, ssh, options[:dry])
                    state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]
                    if options[:destroy]
                        rm(PHP_FPM::webappsDir(distroInfo) + 'nextcloud', options[:dry], ssh)
                        item['Database'] ||= {}
                        if !item['Database']['Type'] || item['Database']['Type'] == 'pgsql'
                            PostgreSQL.dropUserAndDB(item['Database'], USER, ssh, options[:dry])
                        end
                        Framework::LinuxApp.deleteUserAndGroup(USER, ssh, options[:dry])
                        rm('/var/log/php/nextcloud.access.log', options[:dry], ssh)
                        rm('/var/log/php/nextcloud.errors.log', options[:dry], ssh)
                        rm('/var/log/php/nextcloud.mail.log', options[:dry], ssh)
                        rm('/var/log/nginx/nextcloud.access.log', options[:dry], ssh)
                        rm('/var/log/nginx/nextcloud.error.log', options[:dry], ssh)
                        state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                    end
                end
            end

        end
    end
end
