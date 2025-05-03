# frozen_string_literal: true

require_relative 'configsCommand'
require 'date'

module ConfigLMM
    module Commands
        class Backup < ConfigsCommand

            def configsRequired
                false
            end

            def processConfig(config, options)
                any = false
                backupFolder = options['output'] + '/' + Date.today.strftime("%G-W%W")
                filter = config.keys
                state.eachItem(filter) do |id, item|
                    next if [State::STATUS_DELETED, State::STATUS_DESTROYED].include?(item['Status'])
                    type = item[:Type]
                    self.plugins.each do |pluginId, plugin|
                        if plugin.hasAction?(type, :backup)
                            any = true
                            invokeBackupAction(id, item, plugin, type, backupFolder, options)
                        end
                    end
                end

                if any
                    prompt.ok('Backup successful!')
                else
                    prompt.error('Nothing to backup!')
                end
            end

            def invokeBackupAction(id, item, plugin, type, backupFolder, options)
                prompt.warn("Backing up #{id}: #{type.to_s}")
                actionMethod = plugin.class.actionMethod(type, 'Backup')

                options['output'] = backupFolder + '/' + id + '/' + Time.now.to_i.to_s
                FileUtils.mkdir_p(options['output'])

                plugin.send(actionMethod, id, item, context, options)
            end
        end
    end
end
