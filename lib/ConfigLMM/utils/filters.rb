require 'set'

module ConfigLMM
    module Utils

        class Filters

            def self.parseLocationsOption(filter, logger)
                self.parseFilters(filter.split(';'), logger)
            end

            def self.parseThingsOption(filter, logger)
                filters = {
                    includeIds: Set.new,
                    excludeIds: Set.new,
                    includeTypes: Set.new,
                    excludeTypes: Set.new,
                    includeLocations: Set.new,
                    excludeLocations: Set.new
                }
                userFilters = filter.split(';')
                userFilters.each do |filter|
                    next if filter.empty?
                    filter = filter.upcase
                    equal = filter.index('=')
                    negate = false
                    if equal.nil?
                        category = 'ID'
                        if filter[0] == '!'
                            negate = true
                            content = filter[1..]
                        else
                            content = filter
                        end
                    else
                        category = filter[0, equal]
                        if category[-1] == '!'
                            negate = true
                            category = category[0...-1]
                        end
                        content = filter[equal + 1..]
                    end
                    content = content.split(',')
                    case category
                    when 'ID'
                        filters[negate ? :excludeIds : :includeIds] += content
                    when 'TYPE'
                        filters[negate ? :excludeTypes : :includeTypes] += content
                    when 'LOCATION'
                        filters[negate ? :excludeLocations : :includeLocations] += content
                    else
                        raise "Unkown filter - '#{category}'"
                    end
                end
                filters
            end

            def self.shouldFilterThing?(id, type, target, thingFilters)
                return false if thingFilters[:includeIds].empty? &&
                                thingFilters[:excludeIds].empty? &&
                                thingFilters[:includeTypes].empty? &&
                                thingFilters[:excludeTypes].empty? &&
                                thingFilters[:includeLocations].empty? &&
                                thingFilters[:excludeLocations].empty?

                return true  if thingFilters[:excludeIds].include?(id)
                return false if thingFilters[:includeIds].include?(id)

                return true  if thingFilters[:excludeTypes].include?(type.to_s.upcase)

                thingFilters[:excludeLocations].each do |excludeLocation|
                    return true if target['Location'].to_s.upcase.include?(excludeLocation) ||
                                   target['AlternativeLocation'].to_s.upcase.include?(excludeLocation)
                end

                return true if !thingFilters[:includeIds].empty? &&
                                thingFilters[:includeTypes].empty? &&
                                thingFilters[:includeLocations].empty?

                return true if !thingFilters[:includeTypes].empty? && !thingFilters[:includeTypes].include?(type.to_s.upcase)

                return false if thingFilters[:includeLocations].empty?

                thingFilters[:includeLocations].each do |includeLocation|
                    return false if target['Location'].to_s.upcase.include?(includeLocation) ||
                                    target['AlternativeLocation'].to_s.upcase.include?(includeLocation)
                end

                true
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
