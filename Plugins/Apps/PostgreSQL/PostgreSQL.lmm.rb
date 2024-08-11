
require_relative '../../OS/Linux/Linux.lmm.rb'

module ConfigLMM
    module LMM
        class PostgreSQL < Framework::LinuxApp
            PACKAGE_NAME = 'PostgreSQL'
            SERVICE_NAME = 'postgresql'
            USER_NAME = 'postgres'

            HBA_FILE = 'data/pg_hba.conf'
            CONFIG_FILE = 'data/postgresql.conf'

            def actionPostgreSQLDeploy(id, target, activeState, context, options)
                self.ensurePackage(PACKAGE_NAME, target['Location'])
                self.ensureServiceAutoStart(SERVICE_NAME, target['Location'])

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.updateSettingsOverSSH(target, uri, options)

                    self.startService(SERVICE_NAME, target['Location'])

                    self.class.sshStart(uri) do |ssh|
                        self.class.createUsersOverSSH(target, ssh)
                        self.class.createDatabasesOverSSH(target, ssh)
                        self.class.createPublicationsOverSSH(target, ssh)
                        self.class.createSubscriptionsOverSSH(target, ssh)
                    end
                else
                    self.updateListenLocal(target)

                    self.startService(SERVICE_NAME, target['Location'])
                end

            end

            def updateListenLocal(target)
                dir = pgsqlDir(self.class.distroID)
                if target['ListenAll']
                    `sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             0.0.0.0/0            scram-sha-256|' #{dir + HBA_FILE}`
                    updateLocalFile(dir + CONFIG_FILE, options) do |configLines|
                        configLines << "listen_addresses = '*'\n"
                    end
                else
                    `sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            scram-sha-256|' #{dir + HBA_FILE}`
                end
            end

            def updateSettingsOverSSH(target, uri, options)
                dir = nil
                settingLines = []
                hbaLines = []
                if target['ListenAll']
                    cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             0.0.0.0/0               scram-sha-256|'"
                    dir = updateConfigOverSSH(uri, cmd)
                    settingLines << "listen_addresses = '*'\n"
                    Framework::LinuxApp.firewallAddPortOverSSH('5432/tcp', uri)
                elsif target['Listen'] && !target['Listen'].empty?
                    cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            scram-sha-256|'"
                    dir = updateConfigOverSSH(uri, cmd)

                    ips = target['Listen'].map { |addr| addr.split('/').first }.join(',')
                    settingLines << "listen_addresses = '#{ips}'\n"

                    target['Listen'].each do |addr|
                        if addr != 'localhost' && !addr.start_with?('127.0.0.1') && !addr.start_with?('::1')
                            hbaLines << "host    all             all             #{addr}            scram-sha-256\n"
                        end
                    end
                else
                    cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            scram-sha-256|'"
                    dir = updateConfigOverSSH(uri, cmd)
                end
                #if !target['Publications'].to_h.empty?
                #    target['Settings'] ||= {}
                #    target['Settings']['wal_level'] = 'logical'
                #end
                target['Settings'].to_h.each do |name, value|
                    settingLines << "#{name} = #{value}\n"
                end
                if !hbaLines.empty?
                    updateRemoteFile(uri, dir + HBA_FILE, options, false) do |configLines|
                        configLines += hbaLines
                    end
                end
                if !settingLines.empty?
                    updateRemoteFile(uri, dir + CONFIG_FILE, options, false) do |configLines|
                        configLines += settingLines
                    end
                end
            end

            def self.createUsersOverSSH(target, ssh)
                target['Users'].to_a.each do |user, info|
                    self.sshExec!(ssh, "su --login #{USER_NAME} --command 'createuser #{user}'", true)
                    if !info['Password'].to_s.empty?
                        password = self.loadVariable(info['Password'], target).to_s
                        if !password.empty?
                            sql = "ALTER USER #{user} WITH PASSWORD '#{password}'"
                            self.executeSQL(sql, nil, ssh)
                        end
                    end
                    if info['Replication'] && info['Replication'] != 'no'
                        self.executeSQL("ALTER USER #{user} REPLICATION", nil, ssh)
                        self.executeSQL("GRANT pg_read_all_data TO #{user}", nil, ssh)
                    end
                end
            end

            def self.createDatabasesOverSSH(target, ssh)
                target['Databases'].to_a.each do |db, info|
                    self.sshExec!(ssh, "su --login #{USER_NAME} --command 'createdb #{db}'", true)
                end
            end

            def self.createPublicationsOverSSH(target, ssh)
                return if target['Publications'].to_h.empty?

                target['Publications'].each do |name, data|
                    data['Database'] = name unless data['Database']
                    if data['Tables'].is_a?(Array)
                        # TODO
                    elsif data['Tables'] == 'All'
                        sql = "CREATE PUBLICATION #{name} FOR ALL TABLES"
                        self.executeSQL(sql, data['Database'], ssh, true)
                    else
                        raise "Invalid Tables field: #{data['Tables']}"
                    end
                end
            end

            def self.createSubscriptionsOverSSH(target, ssh)
                return if target['Subscriptions'].to_h.empty?

                target['Subscriptions'].each do |name, data|
                    data['Database'] = name unless data['Database']
                    data['Publication'] = name unless data['Publication']
                    connection = self.loadVariable(data['Connection'], target).to_s

                    authParams = '--host=' + connection.match('host=([^ ]+)')[1]
                    authParams += ' --username=' + connection.match('user=([^ ]+)')[1]
                    password = connection.match('password=([^ ]+)')[1]

                    self.importRemoteSchemaOverSSH(name, data['Database'], password, authParams, ssh)

                    sql = "CREATE SUBSCRIPTION #{name} CONNECTION '#{connection}' PUBLICATION #{data['Publication']}"
                    self.executeSQL(sql, data['Database'], ssh, true)
                end
            end

            def self.importRemoteSchemaOverSSH(sourceDB, targetDB, password, authParams, ssh)
                self.sshExec!(ssh, "su --login #{USER_NAME} --command 'createdb #{targetDB}'", true)
                cmd = " su --login #{USER_NAME} --command 'PGPASSWORD=#{password} pg_dump --schema-only --no-owner --dbname=#{sourceDB} #{authParams} | psql --dbname=#{targetDB}'"
                self.sshExec!(ssh, cmd)
            end

            def updateConfigOverSSH(uri, cmd)
                dir = ''
                self.class.sshStart(uri) do |ssh|
                    distroID = self.class.distroID(ssh)
                    dir = pgsqlDir(distroID)
                    self.class.sshExec!(ssh, cmd + ' ' + dir + HBA_FILE)
                end
                dir
            end

            def self.createRemoteUserAndDBOverSSH(settings, user, password, ssh)
                    self.executeRemotelyOverSSH(settings, ssh) do |ssh|
                        self.createUserAndDBOverSSH(user, password, ssh)
                    end
            end

            def self.executeRemotelyOverSSH(settings, ssh)
                settings['HostName'] = 'localhost' unless settings['HostName']
                if settings['HostName'] == 'localhost'
                    yield(ssh)
                else
                    self.sshStart("ssh://#{settings['HostName']}/") do |ssh|
                        yield(ssh)
                    end
                end
            end

            def self.createUserAndDBOverSSH(user, password, ssh)
                self.sshExec!(ssh, "su --login #{USER_NAME} --command 'createuser #{user}'", true)
                self.sshExec!(ssh, "su --login #{USER_NAME} --command 'createdb --owner=#{user} #{user}'", true)
                if password
                    sql = "ALTER USER #{user} WITH PASSWORD '#{password}'"
                    self.executeSQL(sql, nil, ssh)
                end
            end

            def self.importSQL(owner, db, sqlFile, ssh = nil)
                if ssh
                    self.sshExec!(ssh, "echo \"SET ROLE '#{owner}';\" > /tmp/postgres_import.sql")
                    self.sshExec!(ssh, "cat #{sqlFile} >> /tmp/postgres_import.sql")
                    cmd = "su --login #{USER_NAME} --command 'psql #{db} < /tmp/postgres_import.sql'"
                    self.sshExec!(ssh, cmd)
                else
                    # TODO
                end
            end

            def self.executeSQL(sql, db, ssh = nil, allowFailure = false)
                if ssh
                    db = 'postgres' unless db
                    cmd = " su --login #{USER_NAME} --command ' psql --dbname=#{db} --command=\"#{sql.gsub("'", "\\\\'")};\"'"
                    self.sshExec!(ssh, cmd, allowFailure)
                else
                    # TODO
                end
            end

            def pgsqlDir(distroID)
                if distroID == 'opensuse-leap'
                    '/var/lib/pgsql/'
                elsif distroID == 'arch'
                    '/var/lib/postgres/'
                else
                    raise Framework::PluginProcessError.new("Unknown Linux Distro: #{distroID}!")
                end
            end

        end

    end
end
