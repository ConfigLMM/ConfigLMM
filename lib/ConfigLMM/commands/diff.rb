# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Diff < ConfigsCommand
            def processConfig(config, options)
                configDiffs = {}
                config.each do |id, data|
                    found = false
                    plugins.each do |pluginId, plugin|
                        if plugin.hasAction?(data['Type'], :diff)
                            invokeDiffAction(id, plugin, data, options)
                            configDiffs[id] = plugin.diff unless plugin.diff.empty?
                            found = true
                        end
                    end
                    logger.debug("Couldn't find action Diff for type #{data['Type']}") unless found
                end
                showDiff(configDiffs)
            end

            def showDiff(configDiffs)
                configDiffs.each do |id, diffs|
                    prompt.say(' ' + id + ':')
                    diffs.each do |name, diff|
                        if diff.first.is_a?(Hash)
                            prompt.say('     ' + name + ':')
                            diff.first.each do |name, value|
                                prompt.say('-      ' + name + ': ' + value, :color => :red)
                            end
                            diff.last.each do |name, value|
                                prompt.say('+      ' + name + ': ' + value, :color => :green)
                            end
                        else
                            prompt.say('-    ' + name + ': ' + diff.first, :color => :red)
                            prompt.say('+    ' + name + ': ' + diff.last, :color => :green)
                        end
                    end
                end
            end
        end
    end
end
