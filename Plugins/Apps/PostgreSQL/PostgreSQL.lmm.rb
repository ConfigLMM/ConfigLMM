
require_relative '../../OS/Linux/Linux.lmm.rb'

module ConfigLMM
    module LMM
        class PostgreSQL < Framework::LinuxApp
            PACKAGE_NAME = 'PostgreSQL'
            SERVICE_NAME = 'postgresql'

            HBA_FILE = 'data/pg_hba.conf'
            CONFIG_FILE = 'data/postgresql.conf'

            def actionPostgreSQLDeploy(id, target, activeState, context, options)
                self.ensurePackage(PACKAGE_NAME, target['Location'])
                self.ensureServiceAutoStart(SERVICE_NAME, target['Location'])

                if target['Location'] && target['Location'] != '@me'
                    if target['ListenAll']
                        uri = Addressable::URI.parse(target['Location'])
                        raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                        dir = ''
                        self.class.sshStart(uri) do |ssh|
                            distroID = self.class.distroIDfromSSH(ssh)
                            dir = pgsqlDir(distroID)
                            cmd = "sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             0.0.0.0/0               scram-sha-256|' #{dir + HBA_FILE}"
                            self.class.sshExec!(ssh, cmd)
                        end
                        updateRemoteFile(uri, dir + CONFIG_FILE, options, false) do |configLines|
                            configLines << "listen_addresses = '*'\n"
                        end
                    end
                else
                    if target['ListenAll']
                        dir = pgsqlDir(self.class.distroID)
                        `sed -i 's|^host    all             all             127.0.0.1/32            ident|host    all             all             0.0.0.0/0            scram-sha-256|' #{dir + HBA_FILE}`
                        updateLocalFile(dir + CONFIG_FILE, options) do |configLines|
                            configLines << "listen_addresses = '*'"
                        end
                    end
                end

                self.startService(SERVICE_NAME, target['Location'])
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
