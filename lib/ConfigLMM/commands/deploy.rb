# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Deploy < ConfigsCommand
            def processConfig(config, options)
                config.each do |id, target|

                    target['Resources'].to_h.each do |id, config|
                        IO::ConfigList.processConfig(id, config, target[:Parent])
                        processDeploy(IO::ConfigList.normalizeId(id), config, options)
                    end

                    processDeploy(id, target, options)
                end
                prompt.ok('Deploy successful!')
            end

            def processDeploy(id, target, options)
                providers = []
                self.plugins.each do |pluginId, plugin|
                    if plugin.hasAction?(target['Type'], :deploy)
                        providers << plugin
                    end
                end
                message = "Couldn't find action Build for #{target['Type']}"
                if providers.empty?
                    logger.debug(message)
                    return
                end

                bestProvider = self.findBestProvider(providers)
                invokeDeployAction(id, bestProvider, target, options)
            end
        end
    end
end
