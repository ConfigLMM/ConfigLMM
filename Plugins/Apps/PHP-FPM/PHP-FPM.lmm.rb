
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

                configLines << 'access.format = \'{"time_iso8601":"%{%Y-%m-%dT%H:%M:%S%z}T","time_received":"%{%Y-%m-%dT%H:%M:%S%z}t","pool":"%n","remote_addr":"%R","remote_user":"%u","method":"%m","host":"%{HTTP_HOST}e","uri":"%r","query_string":"%q","request":"%m %{REQUEST_URI}e %{SERVER_PROTOCOL}e","status":%s,"request_uri":"%{REQUEST_URI}e","server_protocol":"%{SERVER_PROTOCOL}e","body_bytes_sent":%l,"request_time":%d,"request_filename":"%f","http_x_forwarded_for":"%{HTTP_X_FORWARDED_FOR}e","http_x_real_ip":"%{HTTP_X_REAL_IP}e","http_referer":"%{HTTP_REFERER}e","http_user_agent":"%{HTTP_USER_AGENT}e","http_accept_language":"%{HTTP_ACCEPT_LANGUAGE}e","request_id":"%{HTTP_X_REQUEST_ID}e","content_type":"%{Content-Type}o","upstream_http_etag":"%{ETag}o","upstream_http_last_modified":"%{Last-Modified}o","cpu_time":%C,"memory":%M,"ppid":%P,"pid":%p}\'' + "\n"
                configLines << "access.log = /var/log/php/$pool.access.json\n"
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
