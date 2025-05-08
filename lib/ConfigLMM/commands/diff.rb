# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Diff < ConfigsCommand
            def processConfig(config, options)
                configDiffs = {}
                config.each do |id, data|
                    next if shouldFilter?(id, data, nil, options)

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
                level = 4
                configDiffs.each do |id, diffs|
                    prompt.say(' ' + id + ':')
                    diffs.each do |name, diff|
                        outputDiff(name.to_s, ' ', diff.first, diff.last, level)
                    end
                end
            end

            def outputDiff(name, type, old, new, level)
                indent = ' ' * level
                if old.is_a?(Hash) || new.is_a?(Hash)
                    if type == '-'
                        prompt.say('-'+ indent + name + ':', :color => :red)
                    elsif type == '+'
                        prompt.say('+'+ indent + name + ':', :color => :green)
                    else
                        prompt.say(' '+ indent + name + ':')
                    end
                    if !old.nil?
                        old.each do |name, value|
                            if value.is_a?(Hash)
                                outputDiff(name.to_s, '-', value, nil, level + 4)
                            else
                                prompt.say('-' + (' ' * (level + 4)) + name.to_s + ': ' + value.to_s, :color => :red)
                            end
                        end
                    end
                    if !new.nil?
                        new.each do |name, value|
                            if value.is_a?(Hash)
                                outputDiff(name.to_s, '+', nil, value, level + 4)
                            else
                                prompt.say('+' + (' ' * (level + 4)) + name.to_s + ': ' + value.to_s, :color => :green)
                            end
                        end
                    end
                else
                    prompt.say('-' + indent + name + ': ' + old.to_s, :color => :red) unless old.nil?
                    prompt.say('+' + indent + name + ': ' + new.to_s, :color => :green) unless new.nil?
                end
            end
        end
    end
end
