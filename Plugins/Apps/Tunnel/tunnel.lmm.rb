
module ConfigLMM
    module LMM
        class Tunnel < Framework::NginxApp

            def actionTunnelDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Framework::LinuxApp.ensurePackage('socat', connection)

                    port = target['Port']
                    if target['UDP']
                        name = "tunnelUDP-#{port}"
                        connection.upload(__dir__ + '/tunnelUDP.service', "/etc/systemd/system/#{name}.service")
                        connection.upload(__dir__ + '/tunnelUDP.socket', "/etc/systemd/system/#{name}.socket")
                        connection.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.service")
                        connection.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.socket")
                        connection.exec("sed -i 's|$REMOTE|#{Addressable::IDNA.to_ascii(target['Remote'])}|' /etc/systemd/system/#{name}.service")
                        Framework::LinuxApp.firewallAddPort("#{port}/udp", connection)
                    else
                        name = "tunnelTCP-#{port}"
                        connection.upload(__dir__ + '/tunnelTCP.service', "/etc/systemd/system/#{name}.service")
                        connection.upload(__dir__ + '/tunnelTCP.socket', "/etc/systemd/system/#{name}.socket")
                        connection.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.service")
                        connection.exec("sed -i 's|$PORT|#{port}|' /etc/systemd/system/#{name}.socket")
                        connection.exec("sed -i 's|$REMOTE|#{Addressable::IDNA.to_ascii(target['Remote'])}|' /etc/systemd/system/#{name}.service")
                        Framework::LinuxApp.firewallAddPort("#{port}/tcp", connection)
                    end

                    Framework::LinuxApp.reloadServiceManager(connection)
                    Framework::LinuxApp.ensureServiceAutoStart(name + '.socket', connection)
                    Framework::LinuxApp.stopService(name + '.service', connection)
                    Framework::LinuxApp.startService(name + '.socket', connection)
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Tunnel, configs, state, context, options) do |item, id, state, context, options, connection|
                    if item['UDP']
                        name = "tunnelUDP-#{item['Port']}"
                        Framework::LinuxApp.firewallRemovePort("#{item['Port']}/udp", connection)
                    else
                        name = "tunnelTCP-#{item['Port']}"
                        Framework::LinuxApp.firewallRemovePort("#{item['Port']}/tcp", connection)
                    end
                    Framework::LinuxApp.stopService(name + '.socket', connection)
                    Framework::LinuxApp.disableService(name + '.socket', connection)
                    connection.rm("/etc/systemd/system/#{name}.service", options[:dry])
                    connection.rm("/etc/systemd/system/#{name}.socket", options[:dry])
                    state.item(id)['Status'] = State::STATUS_DESTROYED
                end
            end

        end
    end
end
