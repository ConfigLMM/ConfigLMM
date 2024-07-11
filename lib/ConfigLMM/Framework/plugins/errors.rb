# frozen_string_literal: true

module ConfigLMM
    module Framework
        PluginMissingError = Class.new(RuntimeError)

        class PluginError < RuntimeError
            def initialize(message, cause = nil)
                super(message)
                @cause = cause
            end

            def cause
                @cause
            end
        end

        PluginLoadError = Class.new(PluginError)
        PluginProcessError = Class.new(PluginError)
        PluginAuthError = Class.new(PluginError)
        PluginPrerequisite = Class.new(PluginError)
    end
end
