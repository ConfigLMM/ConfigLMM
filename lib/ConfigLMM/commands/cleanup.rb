# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Cleanup < ConfigsCommand

            def processConfig(config, options)
                plugins.each do |pluginId, plugin|
                    configs = {}
                    loadConfigs(plugin, config, configs)
                    plugin.cleanup(configs, state, context, options)
                end
                prompt.ok('Cleanup successful!')
            end

            def loadConfigs(plugin, config, configs)
                config.each do |id, target|
                    loadConfigs(plugin, target['Resources'], configs) if target['Resources']
                    if plugin.hasAction?(target['Type'], :deploy)
                        configs[id] = target
                    end
                end
                configs
            end

        end
    end
end
