# frozen_string_literal: true

require_relative 'errors'

module ConfigLMM
    module Framework
        class Store

            @@AvailablePlugins = {}

            def self.registerPlugin(plugin)
                @@AvailablePlugins[plugin.id] = plugin
            end

            def self.plugins
                @@AvailablePlugins.values
            end

            def self.countPlugins
                @@AvailablePlugins.length
            end

            def self.plugin(pluginId)
                raise PluginMissingError.new("Couldn't find plugin '#{pluginId}'") unless @@AvailablePlugins.key?(pluginId)
                @@AvailablePlugins[pluginId]
            end

            def self.leafPlugins
                nonLeaves = Set.new
                @@AvailablePlugins.each do |id, plugin|
                    plugin.ancestors.each do |ancestor|
                        nonLeaves << ancestor if ancestor != plugin
                    end
                end
                @@AvailablePlugins.reject do |id, plugin|
                    nonLeaves.include?(plugin)
                end
            end

            def self.boot(logger, prompt, plugins)
                leafPlugins.each do |id, plugin|
                    self.initPlugin(id, logger, prompt, plugins)
                rescue PluginLoadError => error
                    logger.warn("Plugin '#{id}' failed to load!\n#{error.message}" + (error.cause ? '  - ' : ''), error.cause)
                end
                true
            end

            def self.initPlugin(pluginId, logger, prompt, plugins)
                pluginId = pluginId.to_sym
                raise 'Recursive/cyclic plugin' if plugins.key?(pluginId)
                plugins[pluginId] = @@AvailablePlugins[pluginId].new(logger, prompt, plugins)
            end

        end
    end
end
