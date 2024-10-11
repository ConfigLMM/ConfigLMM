
require 'fog/proxmox'

module ConfigLMM
    module LMM
        class Proxmox < Framework::Plugin

            def getNode(targetUri)
                uri = Addressable::URI.parse(targetUri)
                raise 'Invalid Proxmox URL!' unless uri.scheme == 'proxmox'
                uri.scheme = 'https'
                uri.port = 8006 if uri.port.nil?
                uri.path = '/api2/json' if uri.path.to_s.empty? || uri.path == '/'
                connectionOptions = { }
                if uri.query.to_s.include?('insecure')
                    connectionOptions[:ssl_verify_peer] = false
                end
                uri.query = nil

                # For some reason Proxmox doesn't handle SSL shutdown correctly so we use this workaround
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF

                authParams = {
                    proxmox_url: uri.to_s,
                    connection_options: connectionOptions,
                    proxmox_auth_method: 'access_ticket',
                    proxmox_username: ENV['PROXMOX_USER'] || 'root@pam',
                    proxmox_password: ENV['PROXMOX_PASSWORD']
                }

                compute = Fog::Compute.new(provider: :proxmox, **authParams)
                node = compute.nodes.find { |node| node.node == 'pve' }
                raise 'Couldn\'t find pve node!' unless node
                [node, authParams]
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def createVM(serverName, serverInfo, targetUri, iso, activeState)
                node, authParams = getNode(targetUri)
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
                server = node.servers.find { |server| server.name == serverName }
                if server
                    if server.status != 'running'
                        server.action('start')
                        server.wait_for { server.ready? }
                    end
                    return false
                end

                isoStorages = node.storages.list_by_content_type('iso')
                isoStorageName = isoStorages.first.storage

                storage = Fog::Storage.new(provider: :proxmox, **authParams)
                file = File.open(iso, 'rb')
                filename = File.basename(iso)
                storage.upload({
                                   node: node.node,
                                   storage: isoStorageName
                               },
                               {
                                   content: 'iso',
                                   file: file,
                                   filename: filename
                               }
                )

                settings = {
                    vmid: node.servers.next_id,
                    name: serverName,
                    bios: 'ovmf',
                    boot: 'order=virtio0;scsi0;net0',
                    cpu: 'cputype=host',
                    machine: 'q35',
                    onboot: 1,
                    ostype: 'l26',
                    scsi0: "#{isoStorageName}:iso/#{filename},media=cdrom",
                    scsihw: 'virtio-scsi-pci',
                    vga: 'qxl'
                }

                if serverInfo['CPU']
                    settings[:cores] = serverInfo['CPU']
                end
                if serverInfo['RAM']
                    settings[:memory] = Filesize.from(serverInfo['RAM']).to_f('MiB').to_i
                end

                if serverInfo['NIC']
                    nics = serverInfo['NIC']
                    nics = [nics] unless nics.is_a?(Array)
                    nics.each_with_index do |nic, i|
                        nic['model'] = 'virtio' unless nic['model']
                        if nic['mac']
                            nic['macaddr'] = nic['mac']
                            nic.delete('mac')
                        end
                        settings["net#{i}"] = nic.map { |name_value| name_value.join('=') }.join(',')
                    end
                elsif serverInfo['NetworkBridge']
                    settings['net0'] = "virtio,bridge=#{serverInfo['NetworkBridge']}"
                end

                server = node.servers.create(settings)

                imageStorages = node.storages.list_by_content_type('images')
                imageStorageName = imageStorages.first.storage
                efidisk = { id: 'efidisk0', storage: imageStorageName, size: '528' }
                server.attach(efidisk, { efitype: '4m', 'pre-enrolled-keys': 1 })

                if serverInfo['Storage']
                    disk = { id: 'virtio0', storage: imageStorageName, size: Filesize.from(serverInfo['Storage']).to_f('GiB').to_i }
                    server.attach(disk, { replicate: 0 })
                end

                if server.status != 'running'
                    server.action('start')
                    server.wait_for { server.ready? }
                end
                true
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def createContainer(serverInfo, targetUri, flavourInfo, activeState)
                node, authParams = getNode(targetUri)
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF

                serverInfo['Domain'] = serverInfo['Name'] unless serverInfo['Domain']
                container = node.containers.find { |container| container.name == Addressable::IDNA.to_ascii(serverInfo['Domain']) }
                if container
                    if container.status != 'running'
                        container.action('start')
                        container.wait_for { container.ready? }
                    end
                    return false
                end

                raise Framework::PluginProcessError.new("Don't have LXC template!") unless flavourInfo['LXC']

                storage = Fog::Storage.new(provider: :proxmox, **authParams)
                appliances = storage.list_appliances({ node: node.node })
                appliance = appliances.find { |appliance| appliance['package'] == flavourInfo['LXC'] }
                raise "Couldn't find LXC template #{flavourInfo['LXC']}" unless appliance
                templateStorages = node.storages.list_by_content_type('vztmpl')
                templateStorageName = templateStorages.first.storage
                storage.download_appliance({ node: node.node }, { storage: templateStorageName, template: appliance['template'] })

                settings = {
                    vmid: node.servers.next_id,
                    ostemplate: "#{templateStorageName}:vztmpl/#{appliance['template']}",
                    onboot: 1,
                    unprivileged: 1
                }

                if serverInfo['CPU']
                    settings[:cores] = serverInfo['CPU']
                end

                if serverInfo['RAM']
                    settings[:memory] = Filesize.from(serverInfo['RAM']).to_f('MiB').to_i
                end

                if serverInfo['Storage']
                    storages = node.storages.list_by_content_type('rootdir')
                    settings[:rootfs] = storages.first.storage + ':' + Filesize.from(serverInfo['Storage']).to_f('GiB').to_i.to_s
                end

                if serverInfo['Domain']
                    settings[:hostname] = Addressable::IDNA.to_ascii(serverInfo['Domain'])
                end

                if serverInfo['Network'].is_a?(Hash) && serverInfo['Network']['DNS']
                    settings[:nameserver] = serverInfo['Network']['DNS']
                end

                if serverInfo['NIC']
                    nics = serverInfo['NIC']
                    nics = [nics] unless nics.is_a?(Array)
                    nics.each_with_index do |nic, i|
                        nic['name'] = "eth#{i}" unless nic['name']
                        if nic['mac']
                            nic['hwaddr'] = nic['mac']
                            nic.delete('mac')
                        end
                        nic[:ip] = 'dhcp'
                        if serverInfo['Network'].is_a?(Hash)
                            if nic['name'] == 'eth0'
                                if serverInfo['Network'].key?('IP')
                                    nic[:ip] = serverInfo['Network']['IP']
                                end
                                if serverInfo['Network'].key?('Gateway')
                                    nic[:gw] = serverInfo['Network']['Gateway']
                                end
                            else
                                interface = serverInfo['Network']['Interfaces'][nic['name']]
                                nic[:ip] = interface['IP'] if interface
                            end
                        end
                        settings["net#{i}"] = nic.map { |name_value| name_value.join('=') }.join(',')
                    end
                elsif serverInfo['NetworkBridge']
                    nic = {
                        name: 'eth0',
                        bridge: serverInfo['NetworkBridge'],
                        ip: 'dhcp'
                    }

                    if serverInfo['Network'].is_a?(Hash)
                        if serverInfo['Network'].key?('IP')
                            nic[:ip] = serverInfo['Network']['IP']
                        end
                        if serverInfo['Network'].key?('Gateway')
                            nic[:gw] = serverInfo['Network']['Gateway']
                        end
                    end
                    settings['net0'] = nic.map { |name_value| name_value.join('=') }.join(',')
                end

                if flavourInfo['Type']
                    settings[:ostype] = flavourInfo['Type']
                end

                if serverInfo['Users']['root'].key?('Password')
                    settings[:password] = serverInfo['Users']['root']['Password']
                end

                if !serverInfo['Users']['root']['AuthorizedKeys'].to_a.empty?
                    settings['ssh-public-keys'] = serverInfo['Users']['root']['AuthorizedKeys'].join("\n")
                end

                if serverInfo['Features']
                    settings[:features] = serverInfo['Features'].map { |feature| "#{feature}=1" }.join(',')
                end

                container = node.containers.create(settings)

                if container.status != 'running'
                    container.action('start')
                    container.wait_for { container.ready? }
                end
                true
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def self.getLocation(location)
                uri = Addressable::URI.parse(location)
                uri.hostname
            end

        end
    end
end
