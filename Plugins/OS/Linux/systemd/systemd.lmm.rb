
module ConfigLMM
    module LMM
        class Systemd < Framework::LinuxApp

            SYSTEMD_CONFIG_PATH = '/etc/systemd/system/'
            USER_SERVICE_DIR = '/etc/systemd/system/user@.service.d/'

            def actionSystemdDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if target['UserCgroups']
                            self.class.enableUserCgroups(linuxConnection, options)
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

            def self.enableUserCgroups(linuxConnection, options)
                # You need to enable this if you see error like:
                # Failed to open cgroups file: /sys/fs/cgroup/user.slice/.../memory.events
                linuxConnection.createDirs(options, USER_SERVICE_DIR)
                linuxConnection.upload(__dir__ + '/user@.service.d/delegate.conf', USER_SERVICE_DIR, options)
                linuxConnection.reloadServiceManager(options)
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

            def self.restart(linuxConnection, options)
                linuxConnection.exec("systemctl daemon-reexec", false, options)
            end

            def self.serviceArgs(service)
                if service[:service] && !service[:uid]
                    args = service[:service].shellescape
                elsif service[:service] && service[:uid]
                    args = '--user --machine=' + service[:uid].to_s.shellescape + '@ ' + service[:service].shellescape
                elsif service[:specialService]
                    args = service[:specialService].shellescape
                else
                    raise 'This shouldn\'t happen!'
                end
                args
            end

            def self.serviceProperty(service, property, linuxConnection, options)
                args = self.serviceArgs(service)
                linuxConnection.exec("systemctl show --property=#{property.to_s.shellescape} #{args} | cut -d '=' -f 2", true, options).strip
            end

            def self.restartService(service, linuxConnection, options)
                options = options.dup
                options[:commandTimeout] = 20*60 # 20min timeout
                service = { service: service } unless service.is_a?(Hash)
                args = self.serviceArgs(service)
                linuxConnection.exec("systemctl restart #{args}", false, options)
            end

        end
    end
end
