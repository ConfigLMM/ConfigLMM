
module ConfigLMM
    module LMM
        class MariaDBConnection

            attr_reader :connection

            def initialize(connection, settings)
                @connection = connection
                @settings = settings
            end

            def exec(sql, db = nil, allowFailure = false, options = {})
                cmd = "mariadb #{db ? db.shellescape : ''} --execute=#{sql.shellescape}"
                @connection.exec(cmd, allowFailure, options)
            end

            def createUserAndDB(user, password, host = nil, options = {})
                if host.is_a?(Hash) && options.empty?
                    options = host
                    host = nil
                end
                if host.nil?
                  if @settings['HostName'] == 'localhost'
                      host = 'localhost'
                  else
                      host = '%'
                  end
                end
                self.exec("CREATE USER '#{user}'@'#{host}'", nil, true, options)
                self.exec("ALTER USER '#{user}'@'#{host}' IDENTIFIED BY '#{password}'", nil, false, { **options, hide: true })
                self.exec("CREATE DATABASE #{user}", nil, true, options)
                self.exec("GRANT ALL PRIVILEGES ON #{user}.* TO '#{user}'@'#{host}'", nil, false, options)
            end

            def dropDB(db, options = {})
                self.exec("DROP DATABASE #{db}", nil, true, options)
            end

            def createAdmin(options = {})
                self.exec("CREATE USER 'admin'@'%'", nil, true, options)
                password = SecureRandom.alphanumeric(20)
                self.exec("ALTER USER 'admin'@'%' IDENTIFIED BY '#{password}'", nil, false, { **options, hide: true })
                self.exec("GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION", nil, false, options)
                password
            end

            def dropAdmin(options = {})
                self.exec("DROP USER 'admin'@'%'", nil, true, options)
            end

            def tableExist?(db, table, options = {})
                table = self.exec("SHOW TABLES LIKE '#{table}'", db, false, options).strip
                !table.empty?
            end

        end
    end
end
