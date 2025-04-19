# frozen_string_literal: true

require_relative 'path'
require 'find'
require 'yaml'
require 'deep_merge'

module ConfigLMM
    module IO
        class ConfigList
            ConfigError = Class.new(RuntimeError)

            def self.create(targets, logger)
                targets = targets.uniq.select do |target|
                    exist = File.exist?(target)
                    logger.warn("'#{target}' doesn't exist, ignoring!") unless exist
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
                data['Type'] = data['Type'].to_s.gsub('.', '').to_sym
                data[:Parent] = parent
                data
            end

            def toConfig(context)
                config = {}
                @Sources.each do |source|
                    seenIncludes = Set.new
                    data = YAML.safe_load_file(source.to_s, permitted_classes: [Symbol])
                    next unless data.is_a?(Hash)
                    data = processIncludes(data, source.to_s, seenIncludes)
                    data.each do |id, data|
                        if id == '_CONTEXT_'
                            context.add(data)
                            next
                        end

                        self.class.processConfig(id, data, source.parent)

                        normalizedId = self.class.normalizeId(id)
                        if config.has_key?(normalizedId)
                            config[normalizedId].deep_merge!(data, :extend_existing_arrays => true)
                        else
                            config[normalizedId] = data
                        end
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

            private

            def processIncludes(data, source, seenIncludes)
                seenIncludes << source
                includes = data['_INCLUDE_']
                return data if includes.nil?
                includes = [includes] unless includes.is_a?(Array)
                includesData = {}
                includes.each do |file|
                    file = file.to_s
                    file += '.yaml' unless file.end_with?('.yaml')
                    file = File.expand_path(file, File.dirname(source))
                    next if seenIncludes.include?(file)
                    raise ConfigError.new("#{file} doesn't exist! - #{source}") unless File.exist?(file)
                    innerData = YAML.safe_load_file(file, permitted_classes: [Symbol])
                    next unless innerData.is_a?(Hash)
                    innerData = processIncludes(innerData, file, seenIncludes.dup)
                    includesData.deep_merge!(innerData, :extend_existing_arrays => true)
                end
                includesData.deep_merge!(data, :extend_existing_arrays => true)
                includesData.delete('_INCLUDE_')
                includesData
            end
        end
    end
end
