
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

        end
    end
end
