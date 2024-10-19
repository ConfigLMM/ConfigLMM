
# encoding: UTF-8
# frozen_string_literal: true

require_relative 'secrets/envStore'
require_relative 'secrets/fileStore'

require 'yaml'

module ConfigLMM
    class Context
        CONTEXT_FILE = 'configlmm/context.yaml'

        def initialize(logger, prompt, xdg, options)
            @Logger = logger
            @Prompt = prompt
            contextFile = options[:context]
            secretsProvider = options[:secrets]
            load!(xdg.config_home, contextFile, secretsProvider)
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

        def secrets
            @Secrets
        end

        private

        def load!(configHome, contextFile, secretsProvider)
            @Context = {}
            @Secrets = Secrets::EnvStore.new(@Logger, @Prompt)
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

            if secretsProvider
                url = Addressable::URI.parse(secretsProvider)
                if url.scheme.nil?
                    @Secrets = Secrets::FileStore.new(@Logger, @Prompt, url.path)
                else
                    raise 'Only file secret provider is implemented!'
                end
            end
        end

    end
end
