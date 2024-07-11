# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Refresh < ConfigsCommand
            def processConfig(config, options)
                errors = 0
                config.each do |id, target|

                    target['Resources'].to_h.each do |id, target|
                        IO::ConfigList.processConfig(id, target, target[:Parent])
                        processRefresh(IO::ConfigList.normalizeId(id), target, options)
                    end

                    errors += processRefresh(id, target, options)
                end
                if errors.zero?
                    prompt.ok('Refresh successful!')
                else
                    prompt.error('Encountered issue while refreshing state!')
                end
            end

            def processRefresh(id, target, options)
                errors = 0
                found = false
                self.plugins.each do |pluginId, plugin|
                    if plugin.hasAction?(target['Type'], :refresh)
                        begin
                            invokeRefreshAction(id, plugin, target, options)
                        rescue Framework::PluginError => e
                            logger.error(e)
                            errors += 1
                        end
                        found = true
                    end
                end
                # We allow plugins without refresh action
                logger.debug("Couldn't find action Refresh for type #{target['Type']}") unless found
                errors
            end
        end
    end
end
