# frozen_string_literal: true

require_relative 'configsCommand'
require_relative 'backup'
require 'date'

module ConfigLMM
    module Commands
        class Update < Backup

            def configsRequired
                false
            end

            def processConfig(config, options)
                any = false
                filter = config.keys
                state.eachItem(filter) do |id, item|
                    next if [State::STATUS_DELETED, State::STATUS_DESTROYED].include?(item['Status'])
                    next if shouldFilter?(id, nil, item, options)

                    type = item[:Type]
                    self.plugins.each do |pluginId, plugin|
                        if plugin.hasAction?(type, :update)
                            if plugin.hasAction?(type, :backup)
                                invokeBackupAction(id, item, plugin, type, options)
                            else
                                loadOutputFolder(id, options)
                            end
                            any = true
                            invokeUpdateAction(id, item, plugin, type, options)
                        end
                    end
                end

                if any
                    prompt.ok('Update successful!') unless options[:dry]
                else
                    prompt.error('Nothing to update!')
                end
            end

            def invokeUpdateAction(id, item, plugin, type, options)
                if options[:dry]
                    prompt.warn("Would update #{id}: #{type.to_s}")
                else
                    prompt.warn("Updating #{id}: #{type.to_s}")
                end
                actionMethod = plugin.class.actionMethod(type, 'Update')

                plugin.send(actionMethod, id, item, context, options)
            end
        end
    end
end
