# frozen_string_literal: true

module TTY
  module Option
    class Parameter
      class Option < Parameter
        # Matches "-f string"
        SHORT_ARGUMENT_REQUIRED_RE = /^-.(\s*?|\=)[^\[]+$/.freeze

        # Matches "--foo string"
        LONG_ARGUMENT_REQUIRED_RE = /^--\S+(\s+|\=)([^\[])+?$/.freeze

        # Matches "-f [string]"
        SHORT_ARGUMENT_OPTIONAL_RE = /^-.\s*\[\S+\]\s*$/.freeze

        # Matches "--foo [string]"
        LONG_ARGUMENT_OPTIONAL_RE = /^--\S+\s*\[\S+\]\s*$/.freeze

        # Return long name if present, otherwise short name
        #
        # @api private
        def default_name
          [long_name, short_name].reject(&:empty?).first
        end

        def short(value = (not_set = true))
          if not_set
            @settings[:short]
          else
            @settings[:short] = value
          end
        end

        def short?
          @settings.key?(:short) && !@settings[:short].nil?
        end

        # Extract short flag name
        #
        # @api public
        def short_name
          short.to_s.sub(/^(-.).*$/, "\\1")
        end

        def long(value = (not_set = true))
          if not_set
            @settings.fetch(:long) { default_long }
          else
            @settings[:long] = value
          end
        end

        def default_long
          "--#{key.to_s.gsub("_", "-")}" unless short?
        end

        def long?
          !long.nil?
        end

        # Extract long flag name
        #
        # @api public
        def long_name
          long.to_s.sub(/^(--.+?)(\s+|\=|\[).*$/, "\\1")
        end

        # Check if argument is required
        #
        # @return [Boolean]
        #
        # @api public
        def argument_required?
          !short.to_s.match(SHORT_ARGUMENT_REQUIRED_RE).nil? ||
            !long.to_s.match(LONG_ARGUMENT_REQUIRED_RE).nil?
        end

        # Check if argument is optional
        #
        # @return [Boolean]
        #
        # @api public
        def argument_optional?
          !short.to_s.match(SHORT_ARGUMENT_OPTIONAL_RE).nil? ||
            !long.to_s.match(LONG_ARGUMENT_OPTIONAL_RE).nil?
        end

        # Compare this option short and long names
        #
        # @api public
        def <=>(other)
          left = long? ? long_name : short_name
          right = other.long? ? other.long_name : other.short_name
          left <=> right
        end
      end # Option
    end # Parameter
  end # Option
end # TTY
