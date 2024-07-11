
# encoding: UTF-8
# frozen_string_literal: true

require 'yaml'

module ConfigLMM
    class Context
        CONTEXT_FILE = 'configlmm/context.yaml'

        def initialize(logger, prompt, xdg, contextFile)
            @Logger = logger
            @Prompt = prompt
            load!(xdg.config_home, contextFile)
        end

        def likes?(name)
            @Context['Likes'].include?(name)
        end

        def dislikes?(name)
            @Context['Dislikes'].include?(name)
        end

        def add(context)
            return unless context
            context['Likes'] ||= []
            context['Dislikes'] ||= []
            @Context['Likes'] += context['Likes']
            @Context['Dislikes'] += context['Dislikes']
        end

        private

        def load!(configHome, contextFile)
            @Context = {}
            if (contextFile && !File.exist?(contextFile))
                @Logger.error("Provided Context file doesn't exist: #{contextFile}")
                raise 'Missing Context!'
            end
            if !contextFile
                contextFile = configHome / CONTEXT_FILE
            end
            if (File.exist?(contextFile))
                @Context = YAML.safe_load_file(contextFile, permitted_classes: [Symbol])
            end
            @Context['Likes'] ||= []
            @Context['Dislikes'] ||= []
        end

    end
end
