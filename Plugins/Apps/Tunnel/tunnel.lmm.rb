
module ConfigLMM
    module LMM
        class Tunnel < Framework::NginxApp

            def actionTunnelDeploy(id, target, activeState, context, options)

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        Framework::LinuxApp.ensurePackage('socat', ssh)

                        port = target['Port']
                        activeState['Port'] = port
                        activeState['UDP'] = target['UDP']
                        if target['UDP']
                            name = "tunnelUDP-#{port}"
                            ssh.scp.upload!(__dir__ + '/tunnelUDP.service', "/etc/systemd/system/#{name}.service")
                            ssh.scp.upload!(__dir__ + '/tunnelUDP.socket', "/etc/systemd/system/#{name}.socket")
                            self.class.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.service", ssh)
                            self.class.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.socket", ssh)
                            self.class.exec("sed -i 's|$REMOTE|#{target['Remote']}|' /etc/systemd/system/#{name}.service", ssh)
                        else
                            name = "tunnelTCP-#{port}"
                            ssh.scp.upload!(__dir__ + '/tunnelTCP.service', "/etc/systemd/system/#{name}.service")
                            ssh.scp.upload!(__dir__ + '/tunnelTCP.socket', "/etc/systemd/system/#{name}.socket")
                            self.class.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.service", ssh)
                            self.class.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.socket", ssh)
                            self.class.exec("sed -i 's|$REMOTE|#{target['Remote']}|' /etc/systemd/system/#{name}.service", ssh)
                        end

                        Framework::LinuxApp.reloadServiceManager(ssh)
                        Framework::LinuxApp.ensureServiceAutoStart(name + '.socket', ssh)
                        Framework::LinuxApp.stopService(name + '.service', ssh)
                        Framework::LinuxApp.startService(name + '.socket', ssh)
                    end
                else
                    # TODO
                end
                activeState['Status'] = State::STATUS_DEPLOYED
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Tunnel, configs, state, context, options) do |item, id, state, context, options, ssh|
                    if item['UDP']
                        name = "tunnelUDP-#{item['Port']}"
                    else
                        name = "tunnelTCP-#{item['Port']}"
                    end
                    Framework::LinuxApp.stopService(name + '.socket', ssh)
                    Framework::LinuxApp.disableService(name + '.socket', ssh)
                    rm("/etc/systemd/system/#{name}.service", options[:dry], ssh)
                    rm("/etc/systemd/system/#{name}.socket", options[:dry], ssh)
                    state.item(id)['Status'] = State::STATUS_DESTROYED
                end
            end

        end
    end
end
