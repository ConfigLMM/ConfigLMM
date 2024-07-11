# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class List < ConfigsCommand
            def processConfig(config, options)
                config.each do |id, data|
                    prompt.say("#{data['Name']}: #{data['Type']}")
                end
            end
        end
    end
end
