# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Build < ConfigsCommand
            def processConfig(config, options)

                config.each do |id, target|

                    target['Resources'].to_h.each do |id, target|
                        IO::ConfigList.processConfig(id, target, target[:Parent])
                        processBuild(IO::ConfigList.normalizeId(id), target, options)
                    end

                    processBuild(id, target, options)
                end
                prompt.ok('Build successful, artifacts are in ' + options['output'])
            end

            def processBuild(id, target, options)
                providers = []
                self.plugins.each do |pluginId, plugin|
                    if plugin.hasAction?(target['Type'], :build)
                        providers << plugin
                    end
                end

                if providers.empty?
                    logger.debug("Skipping ID=#{id} - Type=#{target['Type']}")
                    return
                end

                bestProvider = self.findBestProvider(providers)
                invokeBuildAction(id, bestProvider, target, options)
            end

        end
    end
end
