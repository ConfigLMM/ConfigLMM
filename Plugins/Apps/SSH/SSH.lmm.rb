
module ConfigLMM
    module LMM
        class SSH < Framework::LinuxApp

            CONFIG_FILE = '/etc/ssh/sshd_config'

            def actionSSHDeploy(id, target, activeState, context, options)

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        if target['Port']
                            self.class.sshExec!(ssh, "sed -i 's|^Port |#Port |' #{CONFIG_FILE}")
                        end
                        if target['ListenAddress']
                            self.class.sshExec!(ssh, "sed -i 's|^ListenAddress |#ListenAddress |' #{CONFIG_FILE}")
                        end
                        target['Settings'].to_h.each do |name, value|
                            self.class.sshExec!(ssh, "sed -i 's|^#{name} |##{name} |' #{CONFIG_FILE}")
                        end
                        updateRemoteFile(ssh, CONFIG_FILE, options) do |configLines|
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
                          Framework::LinuxApp.firewallAddPortOverSSH(target['Port'].to_s + '/tcp', uri)
                        end
                    end
                else
                    # TODO
                end

            end

        end

    end
end
