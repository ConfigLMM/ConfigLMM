
require_relative '../../OS/Linux/Linux.lmm.rb'
require_relative 'Connection'

module ConfigLMM
    module LMM
        class PostgreSQL < Framework::LinuxApp
            PACKAGE_NAME = 'PostgreSQL'
            SERVICE_NAME = :postgresql
            USER_NAME = 'postgres'
            PORT = '5432'

            HBA_FILE = 'data/pg_hba.conf'
            CONFIG_FILE = 'data/postgresql.conf'

            def actionPostgreSQLDeploy(id, target, activeState, context, options)
                target['Deploy'] = !!(target['ListenAll'] || target['Listen'] || target['Settings']) unless target.key?('Deploy')

                withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        self.class.withConnection({}, linuxConnection) do |postgres|
                            if target['Deploy']
                                linuxConnection.ensurePackage(PACKAGE_NAME, options)
                                linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                                # So that OpenTelemetry can read logs
                                linuxConnection.createDirs(options, '/var/log/postgresql')
                                linuxConnection.exec("chown postgres:postgres /var/log/postgresql", false, options)
                                linuxConnection.exec("chmod 750 /var/log/postgresql", false, options)

                                replicate(target, linuxConnection, postgres, context, options)
                                setupData(linuxConnection, postgres, context, options)
                                linuxConnection.startService(SERVICE_NAME, options)

                                updateSettings(target, linuxConnection, postgres, options)

                                if activeState['Status'] == State::STATUS_DEPLOYED
                                    linuxConnection.withUserShell(USER_NAME) do |shellConnection|
                                        shellConnection.exec("pg_ctl reload -D #{postgres.pgsqlDir}data", false, options)
                                    end
                                else
                                    # Restart only on first deploy
                                    linuxConnection.restartService(SERVICE_NAME, options)
                                end
                            end

                            createUsers(target, postgres, context, options)
                            createDatabases(target, postgres, context, options)
                            createPublications(target, postgres, context, options)
                            createSubscriptions(target, postgres, context, options)
                        end
                    end
                end
            end

            def actionPostgreSQLBackup(id, activeState, context, options)
                target = activeState['Config'].to_h
                withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.withUserShell(USER_NAME) do |shellConnection|
                            filename = options['output'] + '/postgres_all.psql.gz'
                            shellConnection.downloadStream('pg_dumpall | gzip', filename, options)
                        end
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:PostgreSQL, configs, state, context, options) do |item, id, state, context, options, connection|
                    withConnection(item['Config']['Location'], item['Config']) do |connection|
                        Linux.withConnection(connection) do |linuxConnection|
                            if item['Deploy']
                                linuxConnection.stopService(SERVICE_NAME, options)
                                linuxConnection.disableService(SERVICE_NAME, options)
                                linuxConnection.removePackage(PACKAGE_NAME, options)

                                state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                                if options[:destroy]
                                    linuxConnection.deleteUserAndGroup(USER_NAME, options)

                                    state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                                end
                            end
                        end
                    end
                end
            end

            def replicate(target, linuxConnection, postgres, context, options)
                if target['Replicate']
                    if !linuxConnection.filePresent?(postgres.pgsqlDir + "data")
                        linuxConnection.withUserShell(USER_NAME) do |shellConnection|
                            connection = Framework::Variables.stringEval(target['Replicate']['Connection'], context)
                            extra = ''
                            if target['Replicate']['Slot']
                                extra = "--create-slot --slot=#{target['Replicate']['Slot'].downcase}"
                            end
                            shellConnection.exec("pg_basebackup --dbname=#{connection.shellescape} --write-recovery-conf #{extra} --pgdata #{postgres.pgsqlDir}data", false, options)
                        end
                    end
                end
            end

            def setupData(linuxConnection, postgres, context, options)
                if !linuxConnection.filePresent?(postgres.pgsqlDir + 'data/PG_VERSION')
                    if linuxConnection.hasBinaries?('postgresql-setup', options)
                        linuxConnection.exec('postgresql-setup --initdb', false, options)
                    end
                end
            end

            def updateSettings(target, linuxConnection, postgres, options)
                settingLines = []
                hbaLines = []
                if target['ListenAll']
                    cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             0.0.0.0/0               scram-sha-256|'"
                    postgres.connection.exec(cmd + ' ' + postgres.pgsqlDir + HBA_FILE, false, options)
                    settingLines << "listen_addresses = '*'\n"
                    postgres.connection.firewallAddPort('5432/tcp', options)
                elsif target['Listen'] && !target['Listen'].empty?
                    cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            scram-sha-256|'"
                    postgres.connection.exec(cmd + ' ' + postgres.pgsqlDir + HBA_FILE, false, options)

                    ips = target['Listen'].map { |addr| addr.split('/').first }.join(',')
                    settingLines << "listen_addresses = '#{ips}'\n"

                    target['Listen'].each do |addr|
                        if addr != 'localhost' && !addr.start_with?('127.0.0.1') && !addr.start_with?('::1')
                            addr += '/0' if addr == '0.0.0.0'
                            addr += '/32' if addr =~ /^\d+\.\d+\.\d+\.\d+$/
                            hbaLines << "host    all             all             #{addr}            scram-sha-256\n"
                        end
                    end
                else
                    cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            scram-sha-256|'"
                    postgres.connection.exec(cmd + ' ' + postgres.pgsqlDir + HBA_FILE, false, options)
                end
                if target['AllowReplication']
                    addresses = target['AllowReplication']
                    addresses = [addresses] unless addresses.is_a?(Array)
                    addresses.each do |addr|
                        addr += '/0' if addr == '0.0.0.0'
                        addr += '/32' if addr =~ /^\d+\.\d+\.\d+\.\d+$/
                        hbaLines << "host    replication     all             #{addr}            scram-sha-256\n"
                    end
                end

                postgres.connection.exec('sed -i "s|^logging_collector|#logging_collector|" ' + postgres.pgsqlDir + CONFIG_FILE, false, options)
                postgres.connection.exec('sed -i "s|^log_directory|#log_directory|" ' + postgres.pgsqlDir + CONFIG_FILE, false, options)
                postgres.connection.exec('sed -i "s|^log_file_mode|#log_file_mode|" ' + postgres.pgsqlDir + CONFIG_FILE, false, options)

                settingLines << "logging_collector = on\n"
                settingLines << "log_directory = '/var/log/postgresql'\n"
                settingLines << "log_file_mode = 0640\n"

                if postgres.version >= 15.0
                    postgres.connection.exec('sed -i "s|^log_destination|#log_destination|" ' + postgres.pgsqlDir + CONFIG_FILE, false, options)
                    settingLines << "log_destination = 'jsonlog'\n"
                end

                #if !target['Publications'].to_h.empty?
                #    target['Settings'] ||= {}
                #    target['Settings']['wal_level'] = 'logical'
                #end
                target['Settings'].to_h.each do |name, value|
                    settingLines << "#{name} = #{value}\n"
                end
                if !hbaLines.empty?
                    postgres.connection.updateFile(postgres.pgsqlDir + HBA_FILE, options, false) do |configLines|
                        configLines += hbaLines
                    end
                end
                if !settingLines.empty?
                    postgres.connection.updateFile(postgres.pgsqlDir + CONFIG_FILE, options, false) do |configLines|
                        configLines += settingLines
                    end
                end
            end

            def createUsers(target, postgres, context, options)
                target['Users'].to_a.each do |user, info|
                    password = info['Password'].to_s
                    if !password.empty?
                        password = Framework::Variables.parse(info['Password'], context).to_s
                    end
                    postgres.createUser(user, password, options)

                    if info['Replication']
                        postgres.grantReplication(user)
                    end
                end
            end

            def createDatabases(target, postgres, context, options)
                target['Databases'].to_a.each do |db, info|
                    owner = info['Owner'] ? info['Owner'] : nil
                    postgres.createDB(db, owner, options)
                end
            end

            def createPublications(target, postgres, context, options)
                return if target['Publications'].to_h.empty?

                target['Publications'].each do |name, data|
                    data['Database'] = name unless data['Database']
                    if data['Tables'].is_a?(Array)
                        # TODO
                    elsif data['Tables'] == 'All'
                        sql = "CREATE PUBLICATION #{name} FOR ALL TABLES"
                        postgres.exec(sql, data['Database'], true, [], options)
                    else
                        raise "Invalid Tables field: #{data['Tables']}"
                    end
                end
            end

            def createSubscriptions(target, postgres, context, options)
                return if target['Subscriptions'].to_h.empty?

                target['Subscriptions'].each do |name, data|
                    data['Database'] = name unless data['Database']
                    data['Publication'] = name unless data['Publication']
                    connection = Framework::Variables.stringEval(data['Connection'], context)

                    authParams = '--host=' + connection.match('host=([^ ]+)')[1]
                    authParams += ' --username=' + connection.match('user=([^ ]+)')[1]
                    password = connection.match('password=([^ ]+)')[1]

                    importRemoteSchema(name, data['Database'], password, authParams, postgres, options)

                    sql = "CREATE SUBSCRIPTION #{name} CONNECTION '#{connection}' PUBLICATION #{data['Publication']}"
                    message = postgres.exec(sql, data['Database'], true, [], options)
                    # 'ERROR:  subscription "$NAME" already exists' - is fine
                    # but other errors aren't like ERROR:  could not create replication slot "$NAME": ERROR:  replication slot "$NAME" already exists
                    if message.include?('ERROR') && !(message.include?('subscription') && message.include?('already exists'))
                        raise message
                    end
                end
            end

            def importRemoteSchema(sourceDB, targetDB, password, authParams, postgres, options)
                postgres.createDB(targetDB, nil, options)
                postgres.connection.exec(" PGPASSWORD=#{password} pg_dump --schema-only --no-owner --dbname=#{sourceDB} #{authParams} | psql --dbname=#{targetDB}", false, { **options, hide: true })
            end

            def self.defaults(settings)
                settings['HostName'] = 'localhost' unless settings['HostName']
                settings['Port'] = PORT unless settings['Port']
            end

            def self.withConnection(settings, linuxConnection)
                if settings.nil? || settings['HostName'].nil? || settings['HostName'] == 'localhost' || settings['HostName'].start_with?('/')
                    settings ||= {}
                    settings = settings.dup
                    settings.delete('HostName')
                    settings.delete('Port')
                    linuxConnection.withUserShell(USER_NAME) do |shellConnection|
                        yield(PostgreSQLConnection.new(shellConnection, settings))
                    end
                else
                    IO::Connection.tunnel("ssh://#{settings['HostName']}/", {}, {}, {}, linuxConnection.prompt, linuxConnection.logger) do |connection|
                        Linux.withConnection(connection) do |linuxConnection|
                            linuxConnection.withUserShell(USER_NAME) do |shellConnection|
                                yield(PostgreSQLConnection.new(shellConnection, settings))
                            end
                        end
                    end
                end
            end

            # DEPRECATED
            def self.createRemoteUserAndDB(settings, user, password, connection)
                self.executeRemotely(settings, connection) do |connection|
                    self.createUserAndDB(user, password, connection)
                end
            end

            # DEPRECATED
            def self.createRemoteUserAndDBOverSSH(settings, user, password, ssh)
                self.executeRemotely(settings, ssh) do |connection|
                    self.createUserAndDBOverSSH(user, password, connection)
                end
            end

            # DEPRECATED
            def self.dropUserAndDB(settings, user, connection, dry)
                self.executeRemotely(settings, connection) do |connection|
                    connection.exec("su --login #{USER_NAME} --command 'dropdb #{user}'", true, dry)
                    connection.exec("su --login #{USER_NAME} --command 'dropuser #{user}'", true, dry)
                end
            end

            # DEPRECATED
            def self.createExtensions(settings, db, extensions, connectionOrSSH)
                self.executeRemotely(settings, ssh) do |connection|
                    extensions.each do |extension|
                        self.executeSQL("CREATE EXTENSION #{extension}", db, connection, true)
                    end
                end
            end

            # DEPRECATED
            def self.executeRemotely(settings, connectionOrSSH = nil)
                prompt = TTY::Prompt.new
                logger = TTY::Logger.new
                self.defaults(settings)
                if settings['HostName'] == 'localhost'
                    connection = connectionOrSSH
                    if connectionOrSSH.nil?
                        connection = IO::Connection.new(:Local, IO::Local.new(prompt, logger), prompt, logger)
                    elsif !connectionOrSSH.is_a?(IO::Connection)
                        connection = IO::Connection.new(:SSH, IO::SSH.new(prompt, logger, connectionOrSSH), prompt, logger)
                    end
                    yield(connection)
                else
                    self.sshStart("ssh://#{settings['HostName']}/") do |ssh|
                        yield(IO::Connection.new(:SSH, IO::SSH.new(prompt, logger, ssh), prompt, logger))
                    end
                end
            end

            # DEPRECATED
            def self.createUserAndDB(user, password, connection)
                self.createUserAndDBOverSSH(user, password, connection)
            end

            # DEPRECATED
            def self.createUserAndDBOverSSH(user, password, connectionOrSSH)
                if connectionOrSSH.is_a?(IO::Connection)
                    connectionOrSSH.exec("su --login #{USER_NAME} --command 'createuser #{user}'", true)
                    connectionOrSSH.exec("su --login #{USER_NAME} --command 'createdb --locale=C --template=template0 --owner=#{user} #{user}'", true)
                else
                    self.sshExec!(connectionOrSSH, "su --login #{USER_NAME} --command 'createuser #{user}'", true)
                    self.sshExec!(connectionOrSSH, "su --login #{USER_NAME} --command 'createdb --locale=C --template=template0 --owner=#{user} #{user}'", true)
                end
                if password
                    sql = "ALTER USER #{user} WITH PASSWORD '#{password}'"
                    self.executeSQL(sql, nil, connectionOrSSH)
                end
            end

            # DEPRECATED
            def self.executeSQL(sql, db, connectionOrSSH = nil, allowFailure = false, options = [], dry = false)
                db = 'postgres' unless db
                cmd = " su --login #{USER_NAME} --command ' psql #{options.join(' ')} --dbname=#{db} --command=\"#{sql.gsub("'", "'\"'\"'")};\"'"
                if connectionOrSSH.is_a?(IO::Connection)
                    connectionOrSSH.exec(cmd, allowFailure, dry)
                else
                    self.exec(cmd, connectionOrSSH, allowFailure, dry)
                end
            end

        end
    end
end
