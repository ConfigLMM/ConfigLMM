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

            def invokeTestAction(id, item, plugin, type, options)
                actionMethod = plugin.class.actionMethod(type, 'Test')

                if options[:dry]
                    prompt.warn("Would check health - #{id}: #{type.to_s}")
                end
                begin
                    result = plugin.send(actionMethod, id, item, context, options)
                rescue StandardError => error
                    if IO.error?(error)
                        result = false
                    else
                        raise error
                    end
                end
                if !options[:dry]
                    if result
                        prompt.ok("Health check - #{id}: #{type.to_s} - Healthy")
                    else
                        prompt.error("Health check - #{id}: #{type.to_s} - FAILURE")
                    end
                end
                result
            end

        end
    end
end
