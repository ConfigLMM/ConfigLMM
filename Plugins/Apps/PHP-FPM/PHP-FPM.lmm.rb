
module ConfigLMM
    module LMM
        class PHP_FPM < Framework::LinuxApp

            PHPFPM_PACKAGE = 'PHP-FPM'
            PHPFPM_SERVICE = 'php-fpm'

            def self.writeConfig(name, target, distroInfo, configLines)
                target['PHP-FPM'] ||= {}

                configLines << "[#{name}]\n"
                configLines << "user = #{target['User']}\n"
                configLines << "group = #{target['User']}\n"
                if target['Listen']
                    configLines << "listen = #{target['Listen']}\n"
                else
                    configLines << "listen = /run/php-fpm/#{name}.sock\n"
                    configLines << "listen.owner = #{target['User']}\n"
                    group = 'http'
                    group = 'nginx' if distroInfo['Name'] == 'openSUSE Leap'
                    configLines << "listen.group = #{group}\n"
                end
                configLines << "pm = dynamic\n"
                configLines << "pm.max_children = 5\n"
                configLines << "pm.min_spare_servers = 1\n"
                configLines << "pm.max_spare_servers = 3\n"
                configLines << "pm.start_servers = 2\n"
                configLines << "access.log = /var/log/php/$pool.access.log\n"
                if target['PHP-FPM']['chdir']
                    configLines << "chdir = #{target['PHP-FPM']['chdir']}\n"
                else
                    configLines << "chdir = #{self.webappsDir(distroInfo)}$pool\n"
                end
                configLines << "php_admin_value[error_log] = /var/log/php/$pool.errors.log\n"
                configLines << "php_admin_flag[log_errors] = on\n"
                configLines << "php_admin_value[memory_limit] = 1G\n"
                configLines << "php_admin_value[mail.log] = /var/log/php/$pool.mail.log\n"
            end

            def self.phpConfig(distroInfo)
                if distroInfo['Name'] == 'openSUSE Leap'
                    '/etc/php8/fpm/php.ini'
                else
                    '/etc/php/php.ini'
                end
            end

            def self.peclInstallOverSSH(name, ssh)
                self.sshExec!(ssh, "printf \"\\n\" | pecl install #{name}", true)
            end

            def self.enableExtensionOverSSH(name, distroInfo, ssh)
                phpFile = self.phpConfig(distroInfo)
                if self.remoteFileContains?(phpFile, "extension=#{name}", ssh)
                    self.sshExec!(ssh, "sed -i 's|^;extension=#{name}|extension=#{name}|' #{phpFile}")
                else
                    self.sshExec!(ssh, "sed -i 's|extension=zip|extension=zip\\nextension=#{name}|' #{phpFile}")
                end
            end

            def self.configFileDir(distroInfo)
                if distroInfo['Name'] == 'openSUSE Leap'
                    '/etc/php8/fpm/'
                else
                    '/etc/php/'
                end
            end

            def self.configDir(distroInfo)
                if distroInfo['Name'] == 'openSUSE Leap'
                    '/etc/php8/fpm/php-fpm.d/'
                else
                    '/etc/php/php-fpm.d/'
                end
            end

            def self.webappsDir(distroInfo)
                if distroInfo['Name'] == 'openSUSE Leap'
                    '/srv/www/htdocs/'
                else
                    '/usr/share/webapps/'
                end
            end

            def self.fixConfigFileOverSSH(distroInfo, ssh)
                dir = self.configFileDir(distroInfo)
                if !self.remoteFilePresent?(dir + 'php-fpm.conf', ssh)
                    self.sshExec!(ssh, "cp #{dir}php-fpm.conf.default #{dir}php-fpm.conf")
                end
            end

        end
    end
end
