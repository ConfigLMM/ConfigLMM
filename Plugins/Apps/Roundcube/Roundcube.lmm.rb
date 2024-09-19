
module ConfigLMM
    module LMM
        class Roundcube < Framework::NginxApp

            USER = 'roundcube'
            HOME_DIR = '/var/lib/roundcube'
            PACKAGE_NAME = 'Roundcube'

            def actionRoundcubeDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        Framework::LinuxApp.ensurePackages([PHP_FPM::PHPFPM_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(PHP_FPM::PHPFPM_SERVICE, ssh)
                        distroInfo = Framework::LinuxApp.ensurePackages([PACKAGE_NAME], ssh)
                        addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{HOME_DIR}' --create-home --comment 'Roundcube' #{USER}"
                        self.class.exec(addUserCmd, ssh, true)
                        self.class.exec("chmod o-rwx #{HOME_DIR}", ssh)

                        self.class.exec("touch /var/log/php/roundcube.errors.log", ssh)
                        self.class.exec("touch /var/log/php/roundcube.mail.log", ssh)
                        self.class.exec("chown #{USER}:#{USER} /var/log/php/roundcube.errors.log", ssh)
                        self.class.exec("chown #{USER}:#{USER} /var/log/php/roundcube.mail.log", ssh)
                        self.class.exec("chown -R #{USER}:#{USER} /var/log/roundcubemail /var/lib/roundcubemail", ssh)
                        PHP_FPM::fixConfigFileOverSSH(distroInfo, ssh)

                        roundcubeBaseDir = '/usr/share/webapps/roundcubemail'
                        if distroInfo['Name'] == 'openSUSE Leap'
                            roundcubeBaseDir = '/srv/www/roundcubemail'
                        end

                        self.class.exec("sed -i 's|$config\\[\\'des_key\\'\\].*|$config\\[\\'des_key\\'\\] = \\'#{SecureRandom.alphanumeric(24)}\\';|' #{roundcubeBaseDir}/config/config.inc.php", ssh)
                        self.class.exec("sed -i 's|$config\\[\\'product_name\\'\\].*|$config\\[\\'product_name\\'\\] = \\'Webmail\\';|' #{roundcubeBaseDir}/config/config.inc.php", ssh)

                        if target['IMAP']['Host']
                            protocol = ''
                            if target['IMAP']['Port'] == 993
                                protocol = 'ssl://'
                            end
                            self.class.exec("sed -i 's|$config\\[\\'imap_host\\'\\].*|$config\\[\\'imap_host\\'\\] = \\'#{protocol}#{target['IMAP']['Host']}:#{target['IMAP']['Port']}\\';|' #{roundcubeBaseDir}/config/config.inc.php", ssh)
                        end

                        if target['SMTP']['Host']
                            protocol = ''
                            if target['SMTP']['Port'] == 465
                                protocol = 'ssl://'
                            end
                            self.class.exec("sed -i 's|$config\\[\\'smtp_host\\'\\].*|$config\\[\\'smtp_host\\'\\] = \\'#{protocol}#{target['SMTP']['Host']}:#{target['SMTP']['Port']}\\';|' #{roundcubeBaseDir}/config/config.inc.php", ssh)
                        end

                        target['Database'] ||= {}
                        activeState['Database'] = target['Database']
                        if !target['Database']['Type'] || target['Database']['Type'] == 'pgsql'
                            password = SecureRandom.alphanumeric(20)
                            PostgreSQL.createRemoteUserAndDBOverSSH(target['Database'], USER, password, ssh)
                            self.class.exec("sed -i 's|$config\\[\\'db_dsnw\\'\\].*|$config\\[\\'db_dsnw\\'\\] = \\'pgsql://#{USER}:#{password}@#{target['Database']['HostName']}/#{USER}\\';|' #{roundcubeBaseDir}/config/config.inc.php", ssh)
                        end

                        self.updateRemoteFile(ssh, roundcubeBaseDir + '/config/config.inc.php', options, false, '//') do |configLines|
                            if target['Settings']
                                target['Settings'].each do |name, value|
                                    configLines << "$config['#{name}'] = '#{value}';\n"
                                end
                            end
                            configLines << "$config['login_lc'] = 0;\n"
                            configLines << "$config['enable_installer'] = true;\n"
                        end

                        target['User'] = USER unless target['User']
                        name = 'roundcube'
                        target['PHP-FPM'] ||= {}
                        if distroInfo['Name'] == 'openSUSE Leap'
                            target['PHP-FPM']['chdir'] = roundcubeBaseDir
                        end
                        self.updateRemoteFile(ssh, PHP_FPM.configDir(distroInfo) + name + '.conf', options, false, ';') do |configLines|
                            PHP_FPM.writeConfig(name, target, distroInfo, configLines)
                        end

                        Framework::LinuxApp.startServiceOverSSH(PHP_FPM::PHPFPM_SERVICE, ssh)

                        if !target.key?('Proxy') || target['Proxy']
                            self.class.ensurePackage(ssh)
                            self.class.prepareNginxConfig(target, ssh)
                            self.writeNginxConfig(__dir__, 'Roundcube', id, target, state, context, options)
                            if distroInfo['Name'] == 'openSUSE Leap'
                                nginxFile = options['output'] + '/nginx/servers-lmm/Roundcube.conf'
                                `sed -i 's|root .*|root #{roundcubeBaseDir}/public_html;|' #{nginxFile}`
                            end
                            self.deployNginxConfig(id, target, activeState, context, options)
                            Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)
                            self.class.reload(ssh)
                        end

                        self.class.exec("curl 'https://#{target['Domain']}/installer/index.php?_step=3' -X POST --data-raw 'initdb=Initialize+database'", ssh)
                        self.class.exec("rm -f #{roundcubeBaseDir}/public_html/installer", ssh)
                        self.class.exec("sed -i 's|$config\\[\\'enable_installer\\'\\].*|$config\\[\\'enable_installer\\'\\] = false;|' #{roundcubeBaseDir}/config/config.inc.php", ssh)
                    end
                else
                    # TODO
                end
                activeState['Status'] = State::STATUS_DEPLOYED
            end

            def cleanup(configs, state, context, options)
                items = state.selectType(:Roundcube)
                items.each do |id, item|
                    if !configs.key?(id) && item['Status'] != State::STATUS_DESTROYED && (item['Status'] != State::STATUS_DELETED || options[:destroy])
                        if item['Location'] == '@me'
                            cleanupConfig(item, id, state, context, options)
                        else
                            uri = Addressable::URI.parse(item['Location'])
                            self.class.sshStart(uri) do |ssh|
                                cleanupConfig(item, id, state, context, options, ssh)
                            end
                        end
                    end
                end
            end

            def cleanupConfig(item, id, state, context, options, ssh = nil)
                self.cleanupNginxConfig('Roundcube', id, state, context, options, ssh)
                self.class.reload(ssh, options[:dry])
                distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                rm(PHP_FPM.configDir(distroInfo) + 'roundcube.conf', options[:dry], ssh)
                Framework::LinuxApp.reloadService(PHP_FPM::PHPFPM_SERVICE, ssh, options[:dry])
                Framework::LinuxApp.removePackage(PACKAGE_NAME, ssh, options[:dry])
                state.item(id)['Status'] = State::STATUS_DELETED
                if options[:destroy]
                    item['Database'] ||= {}
                    if !item['Database']['Type'] || item['Database']['Type'] == 'pgsql'
                        PostgreSQL.dropUserAndDB(item['Database'], USER, ssh, options[:dry])
                    end
                    Framework::LinuxApp.deleteUserAndGroup(USER, ssh, options[:dry])
                    rm('/var/log/roundcubemail', options[:dry], ssh)
                    rm('/var/log/php/roundcube.access.log', options[:dry], ssh)
                    rm('/var/log/php/roundcube.errors.log', options[:dry], ssh)
                    rm('/var/log/php/roundcube.mail.log', options[:dry], ssh)
                    state.item(id)['Status'] = State::STATUS_DESTROYED
                end
            end

        end
    end
end
