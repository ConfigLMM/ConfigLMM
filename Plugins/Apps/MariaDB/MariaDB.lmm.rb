require_relative '../../OS/Linux/Linux.lmm.rb'

module ConfigLMM
    module LMM
        class MariaDB < Framework::LinuxApp
            PACKAGE_NAME = 'MariaDB'
            SERVICE_NAME = :mariadb
            USER_NAME = 'mariadb'

            def actionMariaDBDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)
                        linuxConnection.startService(SERVICE_NAME, options)

                        self.class.secureInstallation(connection)
                        linuxConnection.exec("sed -i 's|^log-error |#log-error |' /etc/my.cnf", false, options)
                        if target['Listen']
                            linuxConnection.exec("sed -i 's|bind-address .*|bind-address = #{target['Listen']}|' /etc/my.cnf", false, options)
                            linuxConnection.restartService(SERVICE_NAME, options)
                        end
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:MariaDB, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.stopService(SERVICE_NAME, options)
                        linuxConnection.disableService(SERVICE_NAME, options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)
                    end
                    state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]
                end
            end

            def self.secureInstallation(connection)
                status = {}
                output = ''
                # TODO: FIXME to work with non-ssh connection aswell
                channel = connection.tunnel.ssh.exec("mariadb-secure-installation", status: status) do |channel, stream, data|
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
                self.executeRemotely(settings, ssh) do |connection|
                    host = 'localhost'
                    host = '%' if settings['HostName'] != 'localhost'
                    self.createUserAndDB(user, password, host, connection)
                end
            end

            def self.executeRemotely(settings, connectionOrSSH = nil)
                prompt = TTY::Prompt.new
                logger = TTY::Logger.new
                settings['HostName'] = 'localhost' unless settings['HostName']
                if settings['HostName'] == 'localhost'
                    connection = connectionOrSSH
                    if connectionOrSSH.nil?
                        connection = IO::Connection.new(:Local, IO::Local.new(prompt, logger), prompt, logger)
                    elsif !connectionOrSSH.is_a?(IO::Connection)
                        connection = IO::Connection.new(:SSH, SSH.new(prompt, logger, connectionOrSSH), prompt, logger)
                    end
                    yield(connection)
                else
                    self.sshStart("ssh://#{settings['HostName']}/") do |ssh|
                        yield(IO::Connection.new(:SSH, SSH.new(prompt, logger, ssh), prompt, logger))
                    end
                end
            end

            def self.createUserAndDB(user, password, host, connectionOrSSH = nil)
                self.executeSQL("CREATE USER '#{user}'@'#{host}'", nil, connectionOrSSH, true)
                self.executeSQL("ALTER USER '#{user}'@'#{host}' IDENTIFIED BY '#{password}'", nil, connectionOrSSH)
                self.executeSQL("CREATE DATABASE #{user}", nil, connectionOrSSH, true)
                self.executeSQL("GRANT ALL PRIVILEGES ON #{user}.* TO '#{user}'@'#{host}'", nil, connectionOrSSH)
            end

            def self.createAdmin(connectionOrSSH)
                self.executeSQL("CREATE USER 'admin'@'%'", nil, connectionOrSSH, true)
                password = SecureRandom.alphanumeric(20)
                self.executeSQL("ALTER USER 'admin'@'%' IDENTIFIED BY '#{password}'", nil, connectionOrSSH)
                self.executeSQL("GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION", nil, connectionOrSSH)
                password
            end

            def self.dropAdmin(connectionOrSSH)
                self.executeSQL("DROP USER 'admin'@'%'", nil, connectionOrSSH, true)
            end

            def self.tableExist?(db, table, connectionOrSSH)
                table = self.executeSQL("SHOW TABLES LIKE '#{table}'", db, connectionOrSSH).strip
                !table.empty?
            end

            def self.executeSQL(sql, db = nil, connectionOrSSH = nil, allowFailure = false, dry = false)
                db = '' unless db
                cmd = " mariadb #{db} --execute=\"#{sql.gsub('"', '\\"')};\""
                if connectionOrSSH.is_a?(IO::Connection)
                    connectionOrSSH.exec(cmd, allowFailure, dry)
                else
                    self.exec(cmd, connectionOrSSH, allowFailure, dry)
                end
            end

        end

    end
end
