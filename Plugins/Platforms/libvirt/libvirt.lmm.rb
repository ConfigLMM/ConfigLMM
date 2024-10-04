
require 'fog/libvirt'
require 'filesize'

module ConfigLMM
    module LMM
        class Libvirt < Framework::Plugin

            DEFAULT_IMAGE_PATH = '~/.local/share/libvirt/images/'
            DEFAULT_VRAM = 16 * 1024 # 16 MiB

            def actionLibvirtDeploy(id, target, activeState, context, options)
                if !target['Location']
                    target['Location'] = 'qemu:///session'
                end
                compute = Fog::Compute.new(provider: :libvirt, libvirt_uri: target['Location'])
                createPools(target, compute, self.class.isLocal?(target['Location']))
            end

            def createPools(target, compute, isLocal)
                if target['Pools']
                    allPools = compute.pools.all
                    target['Pools'].each do |name, location|
                        next if allPools.find { |pool| pool.name == name }
                        location = DEFAULT_IMAGE_PATH unless location
                        location = File.expand_path(location) if isLocal
                        xml = dirPoolXML(name, location)
                        pool = compute.pools.create(persistent: true, autostart: true, xml: xml)
                        pool.build
                        pool.start
                    end
                end
            end

            def createVM(serverName, serverInfo, targetUri, iso, activeState)
                compute = Fog::Compute.new(provider: :libvirt, libvirt_uri: targetUri)
                server = compute.servers.all.find { |server| server.name == serverName }
                if server
                    server.start
                    return false
                end
                settings = {
                    name: serverName,
                    cpu: {
                        mode: 'host-passthrough'
                    },
                    video: { type: 'qxl', vram: DEFAULT_VRAM }
                }
                if serverInfo['CPU']
                    settings[:cpus] = serverInfo['CPU']
                end
                if serverInfo['RAM']
                    settings[:memory_size] = Filesize.from(serverInfo['RAM']).to_f('KiB').to_i
                end
                volumeName = serverName + '.img'
                volume = compute.volumes.all.find { |volume| volume.name == volumeName }
                if volume
                    settings[:volumes] = [volume]
                elsif serverInfo['Storage']
                    storage = Filesize.from(serverInfo['Storage']).to_f('GiB').to_i
                    volume = compute.volumes.create(
                        name: volumeName,
                        pool_name: compute.pools.first.name,
                        capacity: storage
                    )
                    settings[:volumes] = [volume]
                end
                if serverInfo['NetworkBridge']
                    nic = {
                        bridge: serverInfo['NetworkBridge'],
                    }
                    settings[:nics] = [nic]
                end
                server = compute.servers.new(**settings)
                if iso
                    server.iso_dir = File.dirname(iso)
                    server.iso_file = File.basename(iso)
                end
                server.save
                activeState['Status'] = State::STATUS_CREATED
                state.save
                server.start
                true
            end

            def dirPoolXML(name, path)
                xml  = '<pool type="dir">'
                xml += "    <name>#{name.encode(:xml => :text)}</name>"
                xml += "<target><path>#{path.encode(:xml => :text)}</path></target>"
                xml += '</pool>'
                xml
            end

            def self.isLocal?(location)
                self.getLocation(location).empty?
            end

            def self.getLocation(location)
                uri = Addressable::URI.parse(location)
                uri.hostname
            end
        end
    end
end
