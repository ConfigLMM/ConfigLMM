
require_relative 'XTerm'
require 'fog/proxmox'
require 'cgi'
require 'addressable/uri'
require 'ostruct'

module ConfigLMM
    module LMM
        class Proxmox < Framework::Plugin

            def self.buildURI(uri)
                uri = uri.dup
                uri.scheme = 'https'
                uri.host = Addressable::IDNA.to_ascii(uri.host)
                uri.port = 8006 if uri.port.nil?
                uri.path = '/api2/json' if uri.path.to_s.empty? || uri.path == '/'
                uri.query = nil
                uri
            end

            def self.getAuthParams(uri, context)
                uri = Addressable::URI.parse(uri) if uri.is_a?(String)
                raise 'Invalid Proxmox URL!' unless uri.scheme == 'proxmox'
                connectionOptions = { }
                parsedQuery = CGI.parse(uri.query)
                if parsedQuery['insecure']
                    connectionOptions[:ssl_verify_peer] = false
                end
                secretId = parsedQuery['proxmoxSecretId'].to_a.first || 'PROXMOX'
                uri = self.buildURI(uri)

                proxmoxUsername = context.secrets.load(secretId, 'PROXMOX_USER')
                proxmoxPassword = context.secrets.load(secretId, 'PROXMOX_PASSWORD')
                if !proxmoxPassword
                    proxmoxUsername = 'root@pam'
                    proxmoxPassword = context.secrets.load(secretId, 'ROOT_PASSWORD')
                end

                raise 'Missing Proxmox password!' unless proxmoxPassword

                authParams = {
                    proxmox_url: uri.to_s,
                    connection_options: connectionOptions,
                    proxmox_auth_method: 'access_ticket',
                    proxmox_username: proxmoxUsername,
                    proxmox_password: proxmoxPassword
                }
                authParams
            end

            def self.getNode(authParams)
                # For some reason Proxmox doesn't handle SSL shutdown correctly so we use this workaround
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF

                compute = Fog::Compute.new(provider: :proxmox, **authParams)
                node = compute.nodes.find { |node| node.node == 'pve' }
                raise 'Couldn\'t find pve node!' unless node
                [node, compute]
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def actionProxmoxDeploy(id, target, activeState, context, options)
                authParams = self.class.getAuthParams(target['Location'], context)
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF

                if !target['Storage'].to_h.empty?
                    storage = Fog::Storage.new(provider: :proxmox, **authParams)
                    all = storage.list
                    target['Storage'].each do |name, data|
                        if all.none? { |entry| entry['storage'] == name }
                            storage.create({ 'storage' => name, **data })
                        end
                    end
                end
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def createVM(serverName, serverInfo, targetUri, iso, activeState, context, options)
                authParams = self.class.getAuthParams(targetUri, context)
                node, compute = self.class.getNode(authParams)
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
                server = node.servers.find { |server| server.name == serverName }
                if server
                    if server.status != 'running'
                        if options[:dry]
                            prompt.say("Would start VM with name '#{serverName}'")
                        else
                            server.action('start')
                            server.wait_for { server.ready? }
                        end
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
                    serial0: 'socket',
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
                        nic.transform_keys!(&:downcase)
                        nic['model'] = 'virtio' unless nic['model']
                        if nic['mac']
                            nic['macaddr'] = nic['mac']
                            nic.delete('mac')
                        end
                        if nic['vlan']
                            nic['tag'] = nic['vlan']
                            nic.delete('vlan')
                        end
                        settings["net#{i}"] = nic.map { |name_value| name_value.join('=') }.join(',')
                    end
                elsif serverInfo['NetworkBridge']
                    settings['net0'] = "virtio,bridge=#{serverInfo['NetworkBridge']}"
                end

                if options[:dry]
                    prompt.say("Would create VM with name '#{serverName}'")
                else
                    server = node.servers.create(settings)
                end

                imageStorages = node.storages.list_by_content_type('images')
                imageStorageName = imageStorages.first.storage
                efidisk = { id: 'efidisk0', storage: imageStorageName, size: '528' }
                server.attach(efidisk, { efitype: '4m', 'pre-enrolled-keys': 1 }) unless options[:dry]

                if serverInfo['Storage']
                    disk = { id: 'virtio0', storage: imageStorageName, size: Filesize.from(serverInfo['Storage']).to_f('GiB').to_i }
                    server.attach(disk, { replicate: 0 }) unless options[:dry]
                end

                if options[:dry]
                    prompt.say("Would start VM with name '#{serverName}'")
                else
                    if server.status != 'running'
                        server.action('start')
                        server.wait_for { server.ready? }
                    end
                end

                true
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def createContainer(serverInfo, targetUri, flavourInfo, activeState, context, options)
                authParams = self.class.getAuthParams(targetUri, context)
                node, compute = self.class.getNode(authParams)
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF

                serverInfo['Domain'] = serverInfo['Name'] unless serverInfo['Domain']
                containerName = Addressable::IDNA.to_ascii(serverInfo['Domain'])
                container = node.containers.find { |container| container.name == containerName }
                if container
                    if container.status != 'running'
                        if options[:dry]
                            prompt.say("Would start container with name '#{containerName}'")
                        else
                            container.action('start')
                            container.wait_for { container.ready? }
                        end
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
                if options[:dry]
                    prompt.say("[#{node.node}] Would download '#{appliance['template']}' template to '#{templateStorageName}' storage")
                else
                    storage.download_appliance({ node: node.node }, { storage: templateStorageName, template: appliance['template'] })
                end

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
                    settings[:memory] = Filesize.from(serverInfo['RAM'].to_s).to_f('MiB').to_i
                end

                if serverInfo['Swap']
                    settings[:swap] = Filesize.from(serverInfo['Swap'].to_s).to_f('MiB').to_i
                end

                storageIsSubvolume = false
                storagePool = serverInfo['StoragePool']
                if serverInfo['Storage']
                    storageIsSubvolume = serverInfo['Storage'].to_s == '0'
                    if !storagePool
                        storages = node.storages.list_by_content_type('rootdir')
                        storagePool = storages.first.storage
                    end
                    settings[:rootfs] = storagePool + ':' + Filesize.from(serverInfo['Storage'].to_s).to_f('GiB').to_i.to_s
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
                        nic.transform_keys!(&:downcase)
                        nic['name'] = "eth#{i}" unless nic['name']
                        if nic['mac']
                            nic['hwaddr'] = nic['mac']
                            nic.delete('mac')
                        end
                        if nic['vlan']
                            nic['tag'] = nic['vlan']
                            nic.delete('vlan')
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

                if !serverInfo['Options'].to_h.empty?
                    if serverInfo['Options']['ConsoleMode']
                        settings[:cmode] = serverInfo['Options']['ConsoleMode']
                    end
                end

                if options[:dry]
                    prompt.say("Would create container with name '#{containerName}'")
                    container = OpenStruct.new(:vmid => settings[:vmid])
                else
                    container = node.containers.create(settings)
                end

                if serverInfo['LXC'].is_a?(Array) || storageIsSubvolume
                    self.withProxmoxConnection(targetUri, serverInfo, compute, node.node, context) do |connection|
                        if serverInfo['LXC'].is_a?(Array)
                            self.addLXCOptions(connection, serverInfo, container.vmid, context, options)
                        end

                        if storageIsSubvolume
                            vmid = container.vmid
                            storageInfo = storage.list.find { |info| info['storage'] == storagePool }
                            raise "Didn\'t find storage with name '#{storagePool}'" unless storageInfo
                            connection.exec("chmod +rx #{storageInfo['path']}/images/#{vmid}/subvol-#{vmid}-disk-0.subvol", false, options)
                        end
                    end
                end

                if options[:dry]
                    prompt.say("Would start container with name '#{containerName}'")
                else
                    if container.status != 'running'
                        container.action('start')
                        container.wait_for { container.ready? }
                    end
                end
                true
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def withProxmoxConnection(uri, serverInfo, compute, node, context)
                uri = Addressable::URI.parse(uri) if uri.is_a?(String)
                self.class.xtermTunnel(uri, serverInfo, compute, node, nil, nil, context, prompt, logger) do |xterm|
                    yield(IO::Connection.new(:Proxmox, xterm, prompt, logger))
                end
            end

            def addLXCOptions(connection, serverInfo, vmid, context, options)
                configs = serverInfo['LXC'].map { |config| 'lxc.' + config.map { |name, value| "#{name}: #{value}" }.first }.join("\n")
                connection.exec("echo \"#{configs}\" >> /etc/pve/lxc/#{vmid}.conf", false, options)
            end

            def self.withXTerm(targetUri, target, context, prompt, logger, &block)
                targetUri.scheme = 'proxmox'
                authParams = getAuthParams(targetUri, context)
                node, compute = getNode(authParams)
                name = nil
                name = CGI.parse(targetUri.query)['name'] if targetUri.query
                name = name.first if name

                lxc = target['LXC']
                if targetUri.query
                    parsedQuery = CGI.parse(targetUri.query)
                    name = parsedQuery['name']
                    name = name.first if name
                    lxc = true if parsedQuery['lxc'] && lxc.nil?
                end

                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF

                if lxc
                    unless name
                        name = target['Name']
                        name = Addressable::IDNA.to_ascii(target['Domain']) if target['Domain']
                    end
                    server = node.containers.find { |container| container.name == name }
                    type = 'lxc'
                else
                    name = target['Name'] unless name
                    server = node.servers.find { |server| server.name == name }
                    type = 'qemu'
                end
                raise "Couldn't find server with name #{name}" unless server
                raise IO::ConnectError.new("Server #{name} not running!") if server.status != 'running'

                self.xtermTunnel(targetUri, target, compute, node.node, type, server.vmid, context, prompt, logger, &block)
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

            def self.xtermTunnel(targetUri, target, compute, node, type, vmid, context, prompt, logger, &block)
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
                term = compute.create_term({ node: node, type: type, vmid: vmid }, {})

                parsedQuery = CGI.parse(targetUri.query)
                insecure = !!parsedQuery['insecure']

                secretId = parsedQuery['secretId'].to_a.first || target['SecretId']
                if target['Type'] == :Linux
                    username = 'root'
                    password = target['Users']['root']['Password']
                    password = context.secrets.load(secretId, 'ROOT_PASSWORD') if password.nil?
                else
                    username = context.secrets.load(secretId, 'ROOT_USER') || 'root'
                    password = context.secrets.load(secretId, 'ROOT_PASSWORD')
                end

                uri = self.buildURI(targetUri)
                uri.scheme = 'wss'
                if type.nil? && vmid.nil?
                    uri.path += "/nodes/#{node}/vncwebsocket"
                else
                    uri.path += "/nodes/#{node}/#{type}/#{vmid}/vncwebsocket"
                end
                uri.query = URI.encode_www_form({ port: term['port'], vncticket: term['ticket'] })

                ProxmoxXTerm.tunnel(uri.to_s, insecure, compute.token, term, username, password, prompt, logger, &block)
            ensure
                OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] &= ~OpenSSL::SSL::OP_IGNORE_UNEXPECTED_EOF
            end

        end
    end
end
