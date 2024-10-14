
module ConfigLMM
    module LMM
        class SSH < Framework::LinuxApp

            CONFIG_FILE = '/etc/ssh/sshd_config'
            SSHD_SERVICE = :sshd

            def actionSSHDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    if target['Port']
                        connection.exec("sed -i 's|^Port |#Port |' #{CONFIG_FILE}")
                    end
                    if target['ListenAddress']
                        connection.exec("sed -i 's|^ListenAddress |#ListenAddress |' #{CONFIG_FILE}")
                    end
                    target['Settings'].to_h.each do |name, value|
                        connection.exec("sed -i 's|^#{name} |##{name} |' #{CONFIG_FILE}")
                    end
                    connection.updateFile(CONFIG_FILE, options) do |configLines|
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
                        Framework::LinuxApp.firewallAddPortOverSSH(target['Port'].to_s + '/tcp', connection)
                    end
                    self.class.reloadService(SSHD_SERVICE, connection)
                end
            end

        end
    end
end
