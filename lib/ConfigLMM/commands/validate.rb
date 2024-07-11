# frozen_string_literal: true

require_relative 'configsCommand'

module ConfigLMM
    module Commands
        class Validate < ConfigsCommand
            def processConfig(config, options)

                errors = 0
                config.each do |id, target|
                    target['Resources'].to_h.each do |id, target|
                        IO::ConfigList.processConfig(id, target, target[:Parent])
                        processValidate(IO::ConfigList.normalizeId(id), target, options)
                    end

                    errors += 1 unless processValidate(id, target, options)
                end
                if errors.zero?
                    prompt.ok('Validation successful, no issues were found!')
                else
                    prompt.error('Validation failed, we found some issues!')
                end
            end

            def processValidate(id, target, options)
                providers = []
                self.plugins.each do |pluginId, plugin|
                    if plugin.hasAction?(target['Type'], :validate)
                        providers << plugin
                    end
                end
                if providers.empty?
                    # We allow for validation function to not exist
                    true
                else
                    errors = []
                    providers.each do |provider|
                        errors += invokeValidateAction(id, provider, target, options)
                    end
                    errors.each do |error|
                        prompt.error(error)
                    end
                    errors.empty?
                end
            end
        end
    end
end
