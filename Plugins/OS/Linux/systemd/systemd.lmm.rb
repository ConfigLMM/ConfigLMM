
module ConfigLMM
    module LMM
        class Systemd < Framework::LinuxApp

            SYSTEMD_CONFIG_PATH = '/etc/systemd/system/'
            USER_SERVICE_DIR = '/etc/systemd/system/user@.service.d/'

            def actionSystemdDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if target['UserCgroups']
                            linuxConnection.createDirs(options, USER_SERVICE_DIR)
                            linuxConnection.upload(__dir__ + '/user-0.slice', SYSTEMD_CONFIG_PATH, options)
                            linuxConnection.upload(__dir__ + '/user@.service.d/delegate.conf', USER_SERVICE_DIR, options)
                        end
                        if target['InstallServices']
                            target['InstallServices'].each do |file, data|
                                linuxConnection.upload(file, SYSTEMD_CONFIG_PATH, options)
                                linuxConnection.reloadServiceManager(options)
                                linuxConnection.ensureServiceAutoStart(File.basename(file), options)
                            end
                        end
                    end
                end
            end

            def self.parseCGroup(cgroup)
                return nil if cgroup.to_s.empty?
                info = { uid: nil, service: nil, specialService: nil }
                match = cgroup.match(/^[0-9]+:[^:]*:\/([^\/]+\.slice\/(.+?\/)?(user@(\d+)\.service\/)?(.+?\/)?)?([^\/]+)\.(service|scope)(\/.+?)?$/)
                return nil unless match
                info[:uid] = match[4]
                info[:service] = match[6] + '.service' if match[7] == 'service'
                info[:specialService] = 'user@' + info[:uid] + '.service' if match[7] != 'service' && info[:uid]
                return nil if !info[:service] && !info[:specialService]
                info
            end

            def self.removeRedundantServices(services)
                specialUsers = []
                services.each do |service|
                    if service[:specialService]
                        specialUsers << service[:uid]
                    end
                end
                services.select do |service|
                    service[:uid].nil? ||
                    !specialUsers.include?(service[:uid]) ||
                    service[:specialService]
                end
            end
        end
    end
end
