# frozen_string_literal: true

require_relative '../command'
require_relative '../Framework'
require 'set'
require 'yaml'

module ConfigLMM
    module Commands
        class Types < ConfigLMM::Command
              def initialize(options)
                logger do |config|
                    config.level = options[:level]
                end

                # Load all Plugin files
                Framework::Registrator.registerAll(logger)
            end

            def execute
                types = {}
                Framework::Store.plugins.each do |plugin|
                    plugin.instance_methods.each do |method|
                        if match = method.match('^action(\w+)(Validate|Build|Refresh|Diff|Deploy)$')
                            type = match[1]
                            types[type] ||= []
                            types[type] << match[2]
                        end
                    end
                end
                prompt.say(YAML.dump({ 'Types' => types.sort.to_h }))
            end
        end
    end
end
