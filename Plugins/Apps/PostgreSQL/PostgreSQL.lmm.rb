
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
                    if target['ListenAll']
                        cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             0.0.0.0/0               scram-sha-256|'"
                        dir = updateConfigOverSSH(uri, cmd)
                        updateRemoteFile(uri, dir + CONFIG_FILE, options, false) do |configLines|
                            configLines << "listen_addresses = '*'\n"
                        end
                    else
                        cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            scram-sha-256|'"
                        updateConfigOverSSH(uri, cmd)
                    end
                else
                    dir = pgsqlDir(self.class.distroID)
                    if target['ListenAll']
                        `sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             0.0.0.0/0            scram-sha-256|' #{dir + HBA_FILE}`
                        updateLocalFile(dir + CONFIG_FILE, options) do |configLines|
                            configLines << "listen_addresses = '*'"
                        end
                    else
                        `sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             127.0.0.1/32            scram-sha-256|' #{dir + HBA_FILE}`
                    end
                end

                self.startService(SERVICE_NAME, target['Location'])
            end

            def updateConfigOverSSH(uri, cmd)
                dir = ''
                self.class.sshStart(uri) do |ssh|
                    distroID = self.class.distroIDfromSSH(ssh)
                    dir = pgsqlDir(distroID)
                    self.class.sshExec!(ssh, cmd + ' ' + dir + HBA_FILE)
                end
                dir
            end

            def self.createUserAndDBOverSSH(user, password, ssh)
                self.sshExec!(ssh, "su --login #{USER_NAME} --command 'createuser #{user}'", true)
                self.sshExec!(ssh, "su --login #{USER_NAME} --command 'createdb --owner=#{user} #{user}'", true)
                cmd = " su --login #{USER_NAME} --command ' psql -c \"ALTER USER #{user} WITH PASSWORD \\'#{password}\\';\"'"
                self.sshExec!(ssh, cmd)
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
