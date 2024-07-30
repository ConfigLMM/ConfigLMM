
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
                        if !target.key?('Proxy') || target['Proxy'] != 'only'
                            Framework::LinuxApp.ensurePackagesOverSSH([PHP_FPM::PHPFPM_PACKAGE], ssh)
                            Framework::LinuxApp.ensureServiceAutoStartOverSSH(PHP_FPM::PHPFPM_SERVICE, ssh)
                            distroInfo = Framework::LinuxApp.ensurePackagesOverSSH([PACKAGE_NAME], ssh)
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
                        end
                        if !target.key?('Proxy') || target['Proxy']
                            self.class.prepareNginxConfig(target, ssh)
                            self.writeNginxConfig(__dir__, 'Nextcloud', id, target, state, context, options)
                            distroInfo = Framework::LinuxApp.ensurePackagesOverSSH([PACKAGE_NAME], ssh)
                            webappsDir = PHP_FPM::webappsDir(distroInfo)
                            nginxFile = options['output'] + '/nginx/servers-lmm/Nextcloud.conf'
                            `sed -i 's|root .*|root #{webappsDir}nextcloud;|' #{nginxFile}`
                            deployNginxConfig(id, target, activeState, context, options)
                        end
                    end
                else
                    if !target.key?('Proxy') || target['Proxy']
                        deployNginxConfig(id, target, activeState, context, options)
                    end
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
