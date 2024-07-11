require 'set'

module ConfigLMM
    module Utils

        class Filters

            def self.parseLocationsOption(filter, logger)
                self.parseFilters(filter.split(';'), logger)
            end

            def self.parseThingsOption(filter, logger)
                self.parseFilters(filter.split(';'), logger)
            end

            def self.parseFilters(userFilters, logger)
                filters = {
                    mode: :all # no filter
                }
                userFilters.each do |filter|
                    next if filter.empty?
                    filter = filter.downcase
                    colon = filter.index(':')
                    # TODO FIXME
                end
                filters
=begin
                filters = {
                    mode: :all,
                    includeLocations: Set.new,
                    excludeLocations: Set.new,
                }
                warned = false
                userFilters.each do |filter|
                    next if filter.empty?
                    filter = filter.downcase
                    colon = filter.index(':')
                    negate = false

                    if colon.nil?
                        category = 'tag'
                        if filter[0] == '!'
                            negate = true
                            content = filter[1..]
                        else
                            content = filter
                        end
                    else
                        category = filter[0, colon]
                        if category[0] == '!'
                            negate = true
                            category = category[1..]
                        end
                        content = filter[colon + 1..]
                    end

                    if content.empty?
                        logger.warn('Invalid filter, ignoring!')
                        next
                    end
                    content = Regexp.new(content[1..]) if content[0] == '/'

                    case category
                    when 'name'
                        filters[negate ? :excludeNames : :includeNames] << content
                        filters[:namesMode] = negate ? :exclude : :include if filters[:namesMode] == :all
                    when 'ext'
                        content = '.' + content if !content.is_a?(Regexp) && content[0] != '.'
                        filters[negate ? :excludeExtensions : :includeExtensions] << content
                        filters[:namesMode] = negate ? :exclude : :include if filters[:namesMode] == :all
                    when 'dir'
                        filters[negate ? :excludeDirectories : :includeDirectories] << content
                        filters[:namesMode] = negate ? :exclude : :include if filters[:namesMode] == :all
                    else
                        filters[negate ? :excludeTags : :includeTags] << content
                        filters[:tagsMode] = negate ? :exclude : :include if filters[:tagsMode] == :all
                    end
=end
            end


            def self.matches?(str, patterns)
                return false if patterns.empty?
                patterns.each do |pattern|
                    if pattern.is_a?(Regexp) && pattern.match?(str.downcase) ||
                       !pattern.is_a?(Regexp) && str.downcase == pattern
                        return true
                    end
                end
                false
            end

            def self.includePath?(path, inputFilters)
                if inputFilters[:mode] == :include
                    # TODO FIXME
                    raise 'Unimplemented'
=begin
                    shouldInclude = self.matches?(path.extname, inputFilters[:includeExtensions])
                    shouldInclude = self.matches?(path.basename, inputFilters[:includeNames]) unless shouldInclude
                    shouldInclude = self.matches?(path.dirname.basename, inputFilters[:includeDirectories]) unless shouldInclude

                    shouldInclude = false if shouldInclude && self.matches?(path.extname, inputFilters[:excludeExtensions])
                    shouldInclude = false if shouldInclude && self.matches?(path.basename, inputFilters[:excludeNames])
                    shouldInclude = false if shouldInclude && self.matches?(path.dirname.basename, inputFilters[:excludeDirectories])
=end
                elsif inputFilters[:mode] == :exclude
                    # TODO FIXME
                    raise 'Unimplemented'
=begin
                    shouldInclude = !self.matches?(path.extname, inputFilters[:excludeExtensions])
                    shouldInclude = !self.matches?(path.basename, inputFilters[:excludeNames]) if shouldInclude
                    shouldInclude = !self.matches?(path.dirname.basename, inputFilters[:excludeDirectories]) if shouldInclude

                    shouldInclude = true if !shouldInclude && self.matches?(path.extname, inputFilters[:includeExtensions])
                    shouldInclude = true if !shouldInclude && self.matches?(path.basename, inputFilters[:includeNames])
                    shouldInclude = true if !shouldInclude && self.matches?(path.dirname.basename, inputFilters[:includeDirectories])
=end
                else # :mode == :all
                    shouldInclude = true
                end
                shouldInclude
            end

        end
    end
end
