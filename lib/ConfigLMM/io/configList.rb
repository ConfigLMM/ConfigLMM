# frozen_string_literal: true

require_relative 'path'
require 'find'
require 'yaml'

module ConfigLMM
    module IO
        class ConfigList
            ConfigError = Class.new(RuntimeError)

            def self.create(targets, logger)
                targets = targets.uniq.select do |target|
                    exist = File.exist?(target)
                    logger.warn("'#{path}' doesn't exist, ignoring!") unless exist
                    exist
                end
                self.new(targets)
            end

            def initialize(targets)
                @Sources = targets.map do |target|
                    Path.new(target)
                end
            end

            def expand!(locationFilter)
                sources = []
                @Sources.each do |source|
                    basePath = source.to_s
                    if File.file?(basePath)
                        parent = Path.new(File.dirname(File.expand_path(basePath)))
                        sources << Path.new(basePath, parent)
                    else
                        parent = source
                        ::Find.find(basePath) do |path|
                            next unless Path.isConfig?(path)
                            parent = parent.lookupParent(path)
                            if File.directory?(path)
                                parent = Path.new(path, parent)
                                next
                            end
                            path = Path.new(path, parent)
                            sources << path if Utils::Filters.includePath?(path, locationFilter)
                        end
                    end
                end
                @Sources = sources
            end

            def self.normalizeId(id)
                # Remove all non-letters but allow Unicode
                id.gsub(/[[:space:]]/, '').upcase
            end

            def self.processConfig(id, data, parent)
                data['ID'] = id
                if data['Type'].nil?
                    raise ConfigError.new("Missing 'Type' field: #{id}!")
                end
                data['Name'] = id unless data.has_key?('Name')
                data['Type'] = data['Type'].to_sym
                data[:Parent] = parent
                data
            end

            def toConfig(context)
                config = {}
                @Sources.each do |source|
                    YAML.safe_load_file(source.to_s, permitted_classes: [Symbol]).each do |id, data|
                        normalizedId = self.class.normalizeId(id)
                        if id == '_CONTEXT_'
                            context.add(data)
                            next
                        end

                        self.class.processConfig(id, data, source.parent)

                        # TODO FIXME we should deep merge them instead
                        raise ConfigError.new("Duplicate ID: #{id} (#{normalizedId}) - #{source}") if config.has_key?(normalizedId)
                        config[normalizedId] = data
                    end
                #rescue YAML::SyntaxError => error
                #    raise ConfigError.new(error)
                end
                config
            end

            def count
                @Sources.length
            end

            def to_a
                @Sources
            end
        end
    end
end
