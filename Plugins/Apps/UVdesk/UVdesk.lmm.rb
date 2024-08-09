
module ConfigLMM
    module LMM
        class UVdesk < Framework::NginxApp

            USER = 'uvdesk'
            HOME_DIR = '/srv/uvdesk'
            DOWNLOAD_URL = 'https://cdn.uvdesk.com/uvdesk/downloads/opensource/uvdesk-community-current-stable.zip'

            def actionUVdeskDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        dbPassword = self.configureMariaDB(target['Database'], ssh)

                        Framework::LinuxApp.ensurePackagesOverSSH([PHP_FPM::PHPFPM_PACKAGE, 'php-pecl', 'make'], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(PHP_FPM::PHPFPM_SERVICE, ssh)
                        distroInfo = Framework::LinuxApp.distroInfoFromSSH(ssh)
                        addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{HOME_DIR}' --create-home --comment 'UVdesk' #{USER}"
                        self.class.sshExec!(ssh, addUserCmd, true)
                        if !self.class.remoteFilePresent?(HOME_DIR + '/public/index.php', ssh)
                            self.class.sshExec!(ssh, "curl #{DOWNLOAD_URL} > /tmp/uvdesk.zip")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'cd ~ && unzip /tmp/uvdesk.zip'")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mv ~/uvdesk-*/* ~/'")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mv ~/uvdesk-*/.[!.]* ~/'")
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'rm -r ~/uvdesk-*'")
                            self.class.sshExec!(ssh, 'rm -f /tmp/uvdesk.zip')
                        end

                        self.class.sshExec!(ssh, "mkdir -p /var/log/php/")
                        self.class.sshExec!(ssh, "touch /var/log/php/uvdesk.errors.log")
                        self.class.sshExec!(ssh, "touch /var/log/php/uvdesk.mail.log")
                        self.class.sshExec!(ssh, "chown #{USER}:#{USER} /var/log/php/uvdesk.errors.log")
                        self.class.sshExec!(ssh, "chown #{USER}:#{USER} /var/log/php/uvdesk.mail.log")
                        PHP_FPM::fixConfigFileOverSSH(distroInfo, ssh)

                        target['User'] = USER unless target['User']
                        target['PHP-FPM'] ||= {}
                        target['PHP-FPM']['chdir'] = HOME_DIR unless target['PHP-FPM']['chdir']
                        name = 'uvdesk'
                        self.updateRemoteFile(ssh, PHP_FPM.configDir(distroInfo) + name + '.conf', options, false, ';') do |configLines|
                            PHP_FPM.writeConfig(name, target, distroInfo, configLines)
                        end


                        PHP_FPM.enableExtensionOverSSH('mysqli', distroInfo, ssh)
                        PHP_FPM.enableExtensionOverSSH('mbstring', distroInfo, ssh) # Needed by mailparse

                        imapPackage = 'imap'
                        imapPackage = 'imap-1.0.0' if distroInfo['Name'] == 'openSUSE Leap'
                        PHP_FPM.peclInstallOverSSH(imapPackage, ssh)
                        PHP_FPM.enableExtensionOverSSH('imap', distroInfo, ssh)

                        PHP_FPM.peclInstallOverSSH('mailparse', ssh)
                        PHP_FPM.enableExtensionOverSSH('mailparse', distroInfo, ssh)

                        Framework::LinuxApp.startServiceOverSSH(PHP_FPM::PHPFPM_SERVICE, ssh)

                        Framework::LinuxApp.ensurePackagesOverSSH([NGINX_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        self.writeNginxConfig(__dir__, 'UVdesk', id, target, state, context, options)
                        self.deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)
                    end
                else
                    # TODO
                end
            end

            def configureMariaDB(settings, ssh)
                password = SecureRandom.alphanumeric(20)
                # TODO
                password
            end

        end
    end
end

