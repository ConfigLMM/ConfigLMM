# frozen_string_literal: true

module TTY
  module Option
    class Parser
      module ParamTypes
        # Positional argument pattern
        ARGUMENT_PARAMETER = /^[^-][^=]*\z/.freeze

        # Environment variable pattern
        ENV_VAR_PARAMETER = /^[\p{Lu}_\-\d]+=/.freeze

        # Keyword pattern
        KEYWORD_PARAMETER = /^([^-=][\p{Ll}_\-\d]*)=([^=]+)/.freeze

        # Option and flag pattern
        OPTION_PARAMETER = /^-./.freeze

        # Check if value looks like an argument
        #
        # @param [String] value
        #
        # @return [Boolean]
        #
        # @api public
        def argument?(value)
          !value.match(ARGUMENT_PARAMETER).nil?
        end

        # Check if value is an environment variable
        #
        # @param [String] value
        #
        # @return [Boolean]
        #
        # @api public
        def env_var?(value)
          !value.match(ENV_VAR_PARAMETER).nil?
        end

        # Check to see if value is a keyword
        #
        # @return [Boolean]
        #
        # @api public
        def keyword?(value)
          !value.to_s.match(KEYWORD_PARAMETER).nil?
        end

        # Check if value looks like an option
        #
        # @param [String] value
        #
        # @return [Boolean]
        #
        # @api public
        def option?(value)
          !value.match(OPTION_PARAMETER).nil?
        end
      end # ParamTypes
    end # Parser
  end # Option
end # TTY
