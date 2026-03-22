
require 'yaml'

module ConfigLMM
    module LMM
        module OS

            class Packages

                def initialize
                    @Packages = YAML.load_file(__dir__ + '/Packages.yaml')
                    @Packages.each do |id, info|
                        seenIds = Set.new([id])
                        @Packages[id] = processInfo(info, seenIds)
                        @Packages[id]['Id'] = id
                    end
                end

                def key?(id)
                    @Packages.key?(id)
                end

                def [](id)
                    raise Framework::PluginProcessError.new("Unknown operating system ID: #{id}!") unless key?(id)
                    @Packages[id]
                end

                def convert(packages, distroID)
                    names = []
                    distroPackages = self[distroID].to_h
                    packages.to_a.each do |pkg|
                        packageName = distroPackages[pkg]
                        if packageName
                            if packageName.is_a?(Array)
                                names += packageName
                            else
                                names << packageName
                            end
                        else
                            names << pkg.downcase
                        end
                    end
                    names
                end

                private

                def processInfo(info, seenIds)
                    return info unless info['_INCLUDE_']
                    includes = info['_INCLUDE_']
                    includes = [includes] unless includes.is_a?(Array)
                    info.delete('_INCLUDE_')
                    includesInfo = {}
                    includes.each do |id|
                        next if seenIds.include?(id) || !@Packages.key?(id)
                        seenIds << id
                        includesInfo.merge!(processInfo(@Packages[id], seenIds))
                    end
                    includesInfo.merge(info)
                end

            end

            def self.packages
                @@Packages ||= Packages.new
                @@Packages
            end
        end
    end
end
