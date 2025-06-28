
module ConfigLMM
    module LMM
        class SSH < Framework::LinuxApp

            CONFIG_FILE = '/etc/ssh/sshd_config'
            SSHD_SERVICE = :sshd

            def actionSSHDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if target['Port']
                            linuxConnection.fileReplace(CONFIG_FILE, '^Port ', '#Port ', options)
                        end
                        if target['ListenAddress']
                            linuxConnection.fileReplace(CONFIG_FILE, '^ListenAddress ', '#ListenAddress ', options)
                        end
                        target['Settings'].to_h.each do |name, value|
                            linuxConnection.fileReplace(CONFIG_FILE, "^#{name} ", "##{name} ", options)
                        end
                        linuxConnection.updateFile(CONFIG_FILE, options) do |configLines|
                            if target['Port']
                                configLines << "Port #{target['Port']}\n"
                            end
                            if target['ListenAddress']
                                configLines << "ListenAddress #{target['ListenAddress']}\n"
                            end
                            target['Settings'].to_h.each do |name, value|
                                value = 'yes' if value.is_a?(TrueClass)
                                value = 'no' if value.is_a?(FalseClass)
                                configLines << "#{name} #{value}\n"
                            end
                            configLines
                        end
                        if target['Port']
                            linuxConnection.firewallAddPort(target['Port'].to_s + '/tcp', options)
                            SELinux.addPort(linuxConnection, 'ssh', 'tcp', target['Port'], context, options)
                        end
                        linuxConnection.reloadService(SSHD_SERVICE, options)
                    end
                end
            end

        end
    end
end
