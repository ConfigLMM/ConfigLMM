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
                        if diff.first.is_a?(Hash) || diff.last.is_a?(Hash)
                            prompt.say('     ' + name + ':')
                            if !diff.first.nil?
                                diff.first.each do |name, value|
                                    prompt.say('-      ' + name + ': ' + value, :color => :red)
                                end
                            end
                            if !diff.last.nil?
                                diff.last.each do |name, value|
                                    prompt.say('+      ' + name + ': ' + value, :color => :green)
                                end
                            end
                        else
                            prompt.say('-    ' + name + ': ' + diff.first, :color => :red) unless diff.first.nil?
                            prompt.say('+    ' + name + ': ' + diff.last, :color => :green) unless diff.last.nil?
                        end
                    end
                end
            end
        end
    end
end
