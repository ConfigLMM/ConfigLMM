
module ConfigLMM
    module LMM
        class PostgreSQLConnection

            attr_reader :connection

            def initialize(connection, settings)
                @connection = connection
                @settings = settings
                @pgsqlDir = nil
            end

            def exec(sql, db, allowFailure = false, queryOptions = [], options = {})
                db = 'postgres' unless db
                cmd = "psql #{queryOptions.join(' ')} --dbname=#{db} --command=\"#{LinuxShell.escapeSingleQuotes(sql)};\""
                if options[:hide]
                    cmd = ' ' + cmd
                end
                connection.exec(cmd, allowFailure, options)
            end

            def createUser(user, password = nil, options = {})
                connection.exec("createuser #{user.shellescape}", true)
                if !password.nil?
                    sql = " ALTER USER #{user} WITH PASSWORD '#{LinuxShell.escapeSingleQuotes(password)}'"
                    exec(sql, nil, false, [], { **options, hide: true })
                end
            end

            def createDB(db, owner = nil, options = {})
                ownerSQL = owner ? "--owner=#{owner.shellescape}" : ''
                connection.exec("createdb #{ownerSQL} #{db.shellescape}", true, options)
            end

            def createUserAndDB(user, password, options = {})
                createUser(user, password, options)
                createDB(user, user, options)
            end

            def dropUserAndDB(user, options = {})
                connection.exec("dropdb #{user.shellescape}", true, options)
                connection.exec("dropuser #{user.shellescape}", true, options)
            end

            def grantReplication(user, options = {})
                 exec("ALTER USER #{user} REPLICATION", nil, false, [], options)
                 exec("GRANT pg_read_all_data TO #{user}", nil, false, [], options)
            end

            def pgsqlDir
                return @pgsqlDir if @pgsqlDir
                distroID = connection.distroID
                if distroID == 'opensuse-leap'
                    @pgsqlDir = '/var/lib/pgsql/'
                elsif distroID == 'arch'
                    @pgsqlDir = '/var/lib/postgres/'
                else
                    raise Framework::PluginProcessError.new("Unsupported Linux Distro: #{distroID}!")
                end
                @pgsqlDir
            end
        end
    end
end
