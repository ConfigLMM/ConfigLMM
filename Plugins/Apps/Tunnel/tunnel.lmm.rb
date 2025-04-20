
module ConfigLMM
    module LMM
        class Tunnel < Framework::NginxApp

            def actionTunnelDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage('socat', options)

                        port = target['Port']
                        if target['UDP']
                            name = "tunnelUDP-#{port}"
                            linuxConnection.upload(__dir__ + '/tunnelUDP.service', "/etc/systemd/system/#{name}.service", options)
                            linuxConnection.upload(__dir__ + '/tunnelUDP.socket', "/etc/systemd/system/#{name}.socket", options)
                            linuxConnection.fileReplace("/etc/systemd/system/#{name}.service", '\$PORT', port, options)
                            linuxConnection.fileReplace("/etc/systemd/system/#{name}.socket", '\$PORT', port, options)
                            linuxConnection.fileReplace("/etc/systemd/system/#{name}.service", '\$REMOTE', Addressable::IDNA.to_ascii(target['Remote']) , options)
                            linuxConnection.firewallAddPort("#{port}/udp", options)
                        else
                            name = "tunnelTCP-#{port}"
                            linuxConnection.upload(__dir__ + '/tunnelTCP.service', "/etc/systemd/system/#{name}.service", options)
                            linuxConnection.upload(__dir__ + '/tunnelTCP.socket', "/etc/systemd/system/#{name}.socket", options)
                            linuxConnection.fileReplace("/etc/systemd/system/#{name}.service", '\$PORT', port, options)
                            linuxConnection.fileReplace("/etc/systemd/system/#{name}.socket", '\$PORT', port, options)
                            linuxConnection.fileReplace("/etc/systemd/system/#{name}.service", '\$REMOTE', Addressable::IDNA.to_ascii(target['Remote']), options)
                            linuxConnection.firewallAddPort("#{port}/tcp", options)
                        end

                        linuxConnection.reloadServiceManager(options)
                        linuxConnection.ensureServiceAutoStart(name + '.socket', options)
                        linuxConnection.stopService(name + '.service', options)
                        linuxConnection.startService(name + '.socket', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Tunnel, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if item['Config']['UDP']
                            name = "tunnelUDP-#{item['Config']['Port']}"
                            linuxConnection.firewallRemovePort("#{item['Config']['Port']}/udp", options)
                        else
                            name = "tunnelTCP-#{item['Config']['Port']}"
                            linuxConnection.firewallRemovePort("#{item['Config']['Port']}/tcp", options)
                        end
                        linuxConnection.stopService(name + '.socket', options)
                        linuxConnection.disableService(name + '.socket', options)
                        linuxConnection.rm("/etc/systemd/system/#{name}.service", options[:dry])
                        linuxConnection.rm("/etc/systemd/system/#{name}.socket", options[:dry])
                        state.item(id)['Status'] = State::STATUS_DESTROYED
                    end
                end
            end

        end
    end
end
