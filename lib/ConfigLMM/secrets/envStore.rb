# frozen_string_literal: true

module ConfigLMM
    module Secrets
        class EnvStore

            def initialize(logger, prompt)
                @Secrets = {}
                @Logger = logger
                @Prompt = prompt
            end

            def getID(id, name)
                "#{id.upcase}_#{name.upcase.tr('@.', '_')}"
            end

            def load(id, name)
                raise "Invalid id! #{id.inspect}" unless id
                id = getID(id, name)
                if @Secrets.key?(id)
                    @Secrets[id]
                else
                    ENV[id]
                end
            end

            def store(id, name, value)
                raise "Invalid secret #{value.inspect}!" if !value.is_a?(String) || value.include?("\n")
                id = getID(id, name)
                @Secrets[id] = value
            end

            def print(message, value)
                @Prompt.say(message + ': ' + value, :color => :magenta)
            end

        end
    end
end
