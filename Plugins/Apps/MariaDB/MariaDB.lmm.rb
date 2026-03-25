require_relative '../../OS/Linux/Linux.lmm.rb'
require_relative 'Connection'

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

                        mycnf = '/etc/my.cnf'
                        servercnf = mycnf
                        if !linuxConnection.filePresent?(mycnf, options)
                            # Debian 13 (trixie)
                            mycnf = '/etc/mysql/mariadb.cnf'
                            servercnf = '/etc/mysql/mariadb.conf.d/50-server.cnf'
                            if !linuxConnection.filePresent?(mycnf, options)
                                raise 'Don\'t know how to configure MariaDB because /etc/my.cnf is not present!'
                            end
                        end
                        self.class.secureInstallation(connection)

                        linuxConnection.fileReplace(mycnf, '^log-error ', '#log-error ', options)
                        if target['Listen']
                            activeState['bind-address'] = target['Listen']
                            if !IO::Connection.ipAddr?(activeState['bind-address'])
                                activeState['bind-address'] = linuxConnection.resolve(activeState['bind-address'], options)
                            end

                            raise 'Don\'t know how to configure MariaDB!' unless linuxConnection.filePresent?(servercnf, options)
                            linuxConnection.fileReplace(servercnf, 'bind-address .*', "bind-address = #{activeState['bind-address']}", options)
                            linuxConnection.restartService(SERVICE_NAME, options)
                        else
                            activeState.delete('bind-address')
                        end
                    end
                end
            end

            def actionMariaDBBackup(id, activeState, context, options)
                target = activeState['Config'].to_h
                withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        filename = options['output'] + '/mariadb_all.sql.gz'
                        result = linuxConnection.downloadStream('mysqldump --all-databases --all-tablespaces --events --routines --flush-privileges | gzip', filename, options)
                        if result.downcase.include?('error')
                            prompt.error(result)
                            raise result
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

            # DEPRECATED
            def self.createRemoteUserAndDB(settings, user, password, ssh = nil)
                self.executeRemotely(settings, ssh) do |connection|
                    host = 'localhost'
                    host = '%' if settings['HostName'] != 'localhost'
                    self.createUserAndDB(user, password, host, connection)
                end
            end

            def self.withConnection(settings, linuxConnection)
                if settings['HostName'].nil? || settings['HostName'] == 'localhost'
                    settings['HostName'] = 'localhost'
                    yield(MariaDBConnection.new(linuxConnection, settings))
                else
                    IO::Connection.tunnel("ssh://#{settings['HostName']}/", {}, {}, {}, linuxConnection.prompt, linuxConnection.logger) do |connection|
                        yield(MariaDBConnection.new(connection, settings))
                    end
                end
            end

            # DEPRECATED
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

            # DEPRECATED
            def self.createUserAndDB(user, password, host, connectionOrSSH = nil)
                self.executeSQL("CREATE USER '#{user}'@'#{host}'", nil, connectionOrSSH, true)
                self.executeSQL("ALTER USER '#{user}'@'#{host}' IDENTIFIED BY '#{password}'", nil, connectionOrSSH)
                self.executeSQL("CREATE DATABASE #{user}", nil, connectionOrSSH, true)
                self.executeSQL("GRANT ALL PRIVILEGES ON #{user}.* TO '#{user}'@'#{host}'", nil, connectionOrSSH)
            end

            # DEPRECATED
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
