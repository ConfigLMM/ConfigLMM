require_relative '../../OS/Linux/Linux.lmm.rb'

module ConfigLMM
    module LMM
        class MariaDB < Framework::LinuxApp
            PACKAGE_NAME = 'MariaDB'
            SERVICE_NAME = 'mariadb'
            USER_NAME = 'mariadb'

            def actionMariaDBDeploy(id, target, activeState, context, options)
                self.ensurePackage(PACKAGE_NAME, target['Location'])
                self.ensureServiceAutoStart(SERVICE_NAME, target['Location'])
                self.startService(SERVICE_NAME, target['Location'])

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        self.class.secureInstallation(ssh)
                    end
                else
                    # TODO
                end

            end

            def self.secureInstallation(ssh)
                status = {}
                output = ''
                channel = ssh.exec("mariadb-secure-installation", status: status) do |channel, stream, data|
                    output += data
                    channel.send_data("\n")  # Empty root password
                    channel.send_data("Y\n") # unix_socket authentication
                    channel.send_data("N\n") # change the root password
                    channel.send_data("Y\n") # remove anonymous users
                    channel.send_data("Y\n") # disallow root login remotely
                    channel.send_data("Y\n") # remove test database
                    channel.send_data("Y\n") # reload privileges
                end
                channel.wait
                if !status[:exit_code].zero?
                    $stderr.puts(output)
                    raise Framework::PluginProcessError.new("mariadb-secure-installation failed!")
                end
            end

            def self.createRemoteUserAndDB(settings, user, password, ssh = nil)
                self.executeRemotely(settings, ssh) do |ssh|
                    host = 'localhost'
                    host = '%' if settings['HostName'] != 'localhost'
                    self.createUserAndDB(user, password, host, ssh)
                end
            end

            def self.executeRemotely(settings, ssh = nil)
                settings['HostName'] = 'localhost' unless settings['HostName']
                if settings['HostName'] == 'localhost'
                    yield(ssh)
                else
                    self.sshStart("ssh://#{settings['HostName']}/") do |ssh|
                        yield(ssh)
                    end
                end
            end

            def self.createUserAndDB(user, password, host, ssh = nil)
                self.executeSQL("CREATE USER '#{user}'@'#{host}'", nil, ssh, true)
                self.executeSQL("ALTER USER '#{user}'@'#{host}' IDENTIFIED BY '#{password}'", nil, ssh)
                self.executeSQL("CREATE DATABASE #{user}", nil, ssh, true)
                self.executeSQL("GRANT ALL PRIVILEGES ON #{user}.* TO '#{user}'@'#{host}'", nil, ssh)
            end

            def self.createAdmin(ssh)
                self.executeSQL("CREATE USER 'admin'@'%'", nil, ssh, true)
                password = SecureRandom.alphanumeric(20)
                self.executeSQL("ALTER USER 'admin'@'%' IDENTIFIED BY '#{password}'", nil, ssh)
                self.executeSQL("GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION", nil, ssh)
                password
            end

            def self.dropAdmin(ssh)
                self.executeSQL("DROP USER 'admin'@'%'", nil, ssh, true)
            end

            def self.tableExist?(db, table, ssh)
                table = self.executeSQL("SHOW TABLES LIKE '#{table}'", db, ssh).strip
                !table.empty?
            end

            def self.executeSQL(sql, db = nil, ssh = nil, allowFailure = false)
                db = '' unless db
                cmd = " mariadb #{db} --execute=\"#{sql.gsub('"', '\\"')};\""
                self.exec(cmd, ssh, allowFailure)
            end

        end

    end
end
