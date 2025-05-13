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
                        if options[:check]
                            if plugin.hasAction?(type, :updates?)
                                if options[:dry]
                                    prompt.warn("Would check for updates #{id}: #{type.to_s}")
                                end
                                any = true
                                actionMethod = plugin.class.actionMethod(type, 'Updates?')
                                hasUpdates = plugin.send(actionMethod, id, item, context, options)
                                if !options[:dry]
                                    if hasUpdates == true
                                        prompt.ok("#{id}: #{type.to_s} - Updates available")
                                    elsif hasUpdates == false
                                        prompt.warn("#{id}: #{type.to_s} - No updates")
                                    end
                                end
                            end
                        else
                            if plugin.hasAction?(type, :update)
                                healthy = true
                                if plugin.hasAction?(type, :test)
                                    healthy = invokeTestAction(id, item, plugin, type, options)
                                end
                                if !options[:dry] && !healthy
                                    prompt.error("Aborting update because health check failed for #{id}: #{type.to_s}")
                                    raise 'Update aborted because health check failure!'
                                end
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
                end

                if any
                    if options[:check]
                        prompt.ok('Update check successful!') unless options[:dry]
                    else
                        prompt.ok('Update successful!') unless options[:dry]
                    end
                else
                    if options[:check]
                        prompt.error('Nothing to check!')
                    else
                        prompt.error('Nothing to update!')
                    end
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
