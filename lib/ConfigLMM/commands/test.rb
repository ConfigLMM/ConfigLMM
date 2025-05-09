# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Test < ConfigsCommand

            def configsRequired
                false
            end

            def processConfig(config, options)
                filter = config.keys
                state.eachItem(filter) do |id, item|
                    next if [State::STATUS_DELETED, State::STATUS_DESTROYED].include?(item['Status'])
                    next if shouldFilter?(id, nil, item, options)

                    type = item[:Type]
                    self.plugins.each do |pluginId, plugin|
                        if plugin.hasAction?(type, :test)
                            invokeTestAction(id, item, plugin, type, options)
                        end
                    end
                end
            end

        end
    end
end
