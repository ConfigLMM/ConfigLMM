

module ConfigLMM
    module LMM
        class PHPFPMConnection

            attr_reader :connection

            def initialize(connection)
                @connection = connection
            end

            def phpConfig
                if @connection.distroID == OS::SUSE_LEAP_ID
                    '/etc/php8/fpm/php.ini'
                else
                    '/etc/php/php.ini'
                end
            end

            def configFileDir
                if @connection.distroID == OS::SUSE_LEAP_ID
                    '/etc/php8/fpm/'
                else
                    '/etc/php/'
                end
            end

            def configDir
                if @connection.distroID == OS::SUSE_LEAP_ID
                    '/etc/php8/fpm/php-fpm.d/'
                else
                    '/etc/php/php-fpm.d/'
                end
            end

            def webappsDir
                if @connection.distroID == OS::SUSE_LEAP_ID
                    '/srv/www/htdocs/'
                else
                    '/usr/share/webapps/'
                end
            end

            def enableExtension(name, options = {})
                phpFile = self.phpConfig
                if @connection.fileContains?(phpFile, "extension=#{name}", options)
                    @connection.fileReplace(phpFile, "^;extension=#{name}", "extension=#{name}", options)
                else
                    @connection.fileReplace(phpFile, 'extension=zip', "extension=zip\\nextension=#{name}", { **options, escape: false })
                    #self.sshExec!(ssh, "sed -i 's|extension=zip|extension=zip\\nextension=#{name}|' #{phpFile}")
                end
            end

            def writeConfig(name, target, configLines)
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
                    group = 'nginx' if @connection.distroID == OS::SUSE_LEAP_ID
                    configLines << "listen.group = #{group}\n"
                end
                configLines << "pm = dynamic\n"
                configLines << "pm.max_children = 10\n"
                configLines << "pm.min_spare_servers = 1\n"
                configLines << "pm.max_spare_servers = 3\n"
                configLines << "pm.start_servers = 2\n"

                configLines << 'access.format = \'{"time_iso8601":"%{%Y-%m-%dT%H:%M:%S%z}T","time_received":"%{%Y-%m-%dT%H:%M:%S%z}t","pool":"%n","remote_addr":"%R","remote_user":"%u","method":"%m","host":"%{HTTP_HOST}e","uri":"%r","query_string":"%q","request":"%m %{REQUEST_URI}e %{SERVER_PROTOCOL}e","status":%s,"request_uri":"%{REQUEST_URI}e","server_protocol":"%{SERVER_PROTOCOL}e","body_bytes_sent":%l,"request_time":%d,"request_filename":"%f","http_x_forwarded_for":"%{HTTP_X_FORWARDED_FOR}e","http_x_real_ip":"%{HTTP_X_REAL_IP}e","http_referer":"%{HTTP_REFERER}e","http_user_agent":"%{HTTP_USER_AGENT}e","http_accept_language":"%{HTTP_ACCEPT_LANGUAGE}e","request_id":"%{HTTP_X_REQUEST_ID}e","content_type":"%{Content-Type}o","upstream_http_etag":"%{ETag}o","upstream_http_last_modified":"%{Last-Modified}o","cpu_time":%C,"memory":%M,"ppid":%P,"pid":%p}\'' + "\n"
                configLines << "access.log = /var/log/php/$pool.access.json\n"
                if target['PHP-FPM']['chdir']
                    configLines << "chdir = #{target['PHP-FPM']['chdir']}\n"
                else
                    configLines << "chdir = #{self.webappsDir}$pool\n"
                end
                configLines << "php_admin_value[error_log] = /var/log/php/$pool.errors.log\n"
                configLines << "php_admin_flag[log_errors] = on\n"
                configLines << "php_admin_value[memory_limit] = 1G\n"
                configLines << "php_admin_value[mail.log] = /var/log/php/$pool.mail.log\n"
            end

        end
    end
end
