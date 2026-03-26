
require 'yaml'

module ConfigLMM
    module LMM
        module OS

            SYSLINUX_ID = 'syslinux'
            ARCH_ID = 'arch'
            SUSE_LEAP_ID = 'opensuse-leap'
            SUSE_MICROOS_ID = 'opensuse-microos'
            PROXMOXVE_ID = 'proxmox'
            PROXMOXVE_NAME = 'Proxmox VE'
            DEBIAN_ID = 'debian'
            ALMA_ID = 'almalinux'

            class Info
                def initialize

                    @OS = YAML.load_file(__dir__ + '/OS.yaml')
                    @OS.each do |id, info|
                        seenIds = Set.new([id])
                        @OS[id] = processInfo(info, seenIds)
                        @OS[id]['Id'] = id
                    end
                end

                def key?(id)
                    @OS.key?(id)
                end

                def [](id)
                    raise Framework::PluginProcessError.new("Unknown operating system ID: #{id}!") unless key?(id)
                    @OS[id]
                end

                def byName(name)
                    info = @OS.find { |id, info| info['Name'] == name }
                    info = info.last if info.is_a?(Array)
                    raise Framework::PluginProcessError.new("Unknown operating system: #{name}!") if info.nil?
                    info
                end

                private

                def processInfo(info, seenIds)
                    return info unless info['_INCLUDE_']
                    includes = info['_INCLUDE_']
                    includes = [includes] unless includes.is_a?(Array)
                    info.delete('_INCLUDE_')
                    includesInfo = {}
                    includes.each do |id|
                        next if seenIds.include?(id) || !@OS.key?(id)
                        seenIds << id
                        includesInfo.merge!(processInfo(@OS[id], seenIds))
                    end
                    includesInfo.merge(info)
                end

            end

            def self.info
                @@Info ||= Info.new
                @@Info
            end
        end
    end
end
