
module ConfigLMM
    module LMM
        class PostgreSQLConnection

            attr_reader :connection

            def initialize(connection, settings)
                @connection = connection
                @settings = settings
                @pgsqlDir = nil
                @version = nil
            end

            def version
                @version ||= connection.exec('postmaster --version | cut -d " " -f 3', false).strip.to_f
            end

            def exec(sql, db, allowFailure = false, queryOptions = [], options = {})
                db = 'postgres' unless db
                cmd = "psql #{queryOptions.join(' ')} --dbname=#{db} --command=#{sql.shellescape}"
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
                connection.exec("createdb --locale=C --template=template0 #{ownerSQL} #{db.shellescape}", true, options)
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
                 if version >= 14.0
                    exec("GRANT pg_read_all_data TO #{user}", nil, false, [], options)
                 end
            end

            def createExtensions(db, extensions, options)
                extensions.each do |extension|
                    exec("CREATE EXTENSION #{extension}", db, true, [], options)
                end
            end

            def importSQL(owner, db, sqlFile, options = {})
                cmd = "psql #{db} < #{sqlFile}"
                output = connection.exec(cmd, false, options)
                raise output if output.include?('ERROR:') && !output.include?('already exists')
            end

            def updateOwner(db, owner, options = {})
                sql = "SELECT tablename FROM pg_tables WHERE NOT schemaname IN ('pg_catalog', 'information_schema')"
                tables = self.exec(sql, db, false, ['--csv', '--tuples-only']).strip.lines
                tables.each do |table|
                    self.exec("ALTER TABLE public.#{table} OWNER TO #{owner};", db, false, [], options)
                end

                sql = "SELECT sequence_name FROM information_schema.sequences WHERE NOT sequence_schema IN ('pg_catalog', 'information_schema')"
                sequences = self.exec(sql, db, false, ['--csv', '--tuples-only']).strip.lines
                sequences.each do |sequence|
                    self.exec("ALTER SEQUENCE public.#{sequence} OWNER TO #{owner};", db, false, [], options)
                end

                sql = "SELECT table_name FROM information_schema.views WHERE NOT table_schema IN ('pg_catalog', 'information_schema')"
                views = self.exec(sql, db, false, ['--csv', '--tuples-only']).strip.lines
                views.each do |view|
                    self.exec("ALTER VIEW public.#{view} OWNER TO #{owner};", db, false, [], options)
                end
            end

            def pgsqlDir
                return @pgsqlDir if @pgsqlDir
                distroID = connection.distroID
                if ['opensuse-leap', 'almalinux'].include?(distroID)
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
