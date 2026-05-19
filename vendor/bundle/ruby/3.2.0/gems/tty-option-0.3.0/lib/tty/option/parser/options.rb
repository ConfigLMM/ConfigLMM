# frozen_string_literal: true

require_relative "arity_check"
require_relative "param_types"
require_relative "required_check"
require_relative "../error_aggregator"
require_relative "../pipeline"

module TTY
  module Option
    class Parser
      class Options
        include ParamTypes

        LONG_OPTION_RE = /^(--[^=]+)(\s+|=)?(.*)?$/.freeze

        SHORT_OPTION_RE = /^(-.)(.*)$/.freeze

        # Create a command line env variables parser
        #
        # @param [Array<Option>] options
        #   the list of options
        # @param [Hash] config
        #   the configuration settings
        #
        # @api public
        def initialize(options, check_invalid_params: true,
                       raise_on_parse_error: false)
          @options = options
          @check_invalid_params = check_invalid_params
          @error_aggregator =
            ErrorAggregator.new(raise_on_parse_error: raise_on_parse_error)
          @required_check = RequiredCheck.new(@error_aggregator)
          @arity_check = ArityCheck.new(@error_aggregator)
          @pipeline = Pipeline.new(@error_aggregator)
          @parsed = {}
          @remaining = []
          @shorts = {}
          @longs = {}
          @arities = Hash.new(0)

          setup_opts
        end

        # Configure list of returned options
        #
        # @api private
        def setup_opts
          @options.each do |opt|
            @shorts[opt.short_name] = opt
            @longs[opt.long_name] = opt
            @arity_check << opt if opt.multiple?

            if opt.default?
              case opt.default
              when Proc
                assign_option(opt, opt.default.())
              else
                assign_option(opt, opt.default)
              end
            elsif !(opt.argument_optional? || opt.argument_required?)
              assign_option(opt, false)
            elsif opt.required?
              @required_check << opt
            end
          end
        end

        # Read option(s) from command line
        #
        # @param [Array<String>] argv
        #
        # @api public
        def parse(argv)
          @argv = argv.dup

          loop do
            opt, value = next_option
            if !opt.nil?
              @required_check.delete(opt)
              @arities[opt.key] += 1

              if block_given?
                yield(opt, value)
              else
                assign_option(opt, value)
              end
            end
            break if @argv.empty?
          end

          @arity_check.(@arities)
          @required_check.()

          [@parsed, @remaining, @error_aggregator.errors]
        end

        private

        # Get next option
        #
        # @api private
        def next_option
          opt, value = nil, nil

          while !@argv.empty? && !option?(@argv.first)
            @remaining << @argv.shift
          end

          return if @argv.empty?

          argument = @argv.shift

          if (matched = argument.match(LONG_OPTION_RE))
            long, sep, rest = matched[1..-1]
            opt, value = *process_double_option(long, sep, rest)
          elsif (matched = argument.match(SHORT_OPTION_RE))
            short, other_singles = *matched[1..-1]
            opt, value = *process_single_option(short, other_singles)
          end

          [opt, value]
        end

        # Process a double option
        #
        # @return [Array<Option, Object>]
        #   a list of option and its value
        #
        # @api private
        def process_double_option(long, sep, rest)
          opt, value = nil, nil

          if (opt = @longs[long])
            if opt.argument_required?
              if !rest.empty? || sep.to_s.include?("=")
                value = rest
                if opt.multi_argument? &&
                   !(consumed = consume_arguments).empty?
                  value = [rest] + consumed
                end
              elsif !@argv.empty?
                value = opt.multi_argument? ? consume_arguments : @argv.shift
              else
                @error_aggregator.(MissingArgument.new(opt))
              end
            elsif opt.argument_optional?
              if !rest.empty?
                value = rest
                if opt.multi_argument? &&
                   !(consumed = consume_arguments).empty?
                  value = [rest] + consumed
                end
              elsif !@argv.empty?
                value = opt.multi_argument? ? consume_arguments : @argv.shift
              end
            else # boolean flag
              value = true
            end
          else
            # option stuck together with an argument or abbreviated
            matching_options = 0
            @longs.each_key do |key|
              if !key.to_s.empty? &&
                 (key.to_s.start_with?(long) || long.to_s.start_with?(key))
                opt = @longs[key]
                matching_options += 1
              end
            end

            if matching_options.zero?
              if @check_invalid_params
                @error_aggregator.(InvalidParameter.new("invalid option '#{long}'"))
              else
                @remaining << long
              end
            elsif matching_options == 1
              # option stuck together with the argument
              if sep.nil? && rest.empty?
                value = long[opt.long_name.size..-1]
              else
                value = rest
              end
            else
              @error_aggregator.(AmbiguousOption.new("option '#{long}' is ambiguous"))
            end
          end

          [opt, value]
        end

        # Process a single option
        #
        # @return [Array<Option, Object>]
        #   a list of option and its value
        #
        # @api private
        def process_single_option(short, other_singles)
          opt, value = nil, nil

          if (opt = @shorts[short])
            if opt.argument_required?
              if !other_singles.empty?
                value = other_singles
                if opt.multi_argument? &&
                   !(consumed = consume_arguments).empty?
                  value = [other_singles] + consumed
                end
              elsif !@argv.empty?
                value = opt.multi_argument? ? consume_arguments : @argv.shift
              else
                @error_aggregator.(MissingArgument.new(opt))
              end
            elsif opt.argument_optional?
              if !other_singles.empty?
                value = other_singles
                if opt.multi_argument? &&
                   !(consumed = consume_arguments).empty?
                  value = [other_singles] + consumed
                end
              elsif !@argv.empty?
                value = opt.multi_argument? ? consume_arguments : @argv.shift
              end
            else # boolean flag
              if !other_singles.empty?
                @argv.unshift("-#{other_singles}")
              end
              value = true
            end
          elsif @check_invalid_params
            @error_aggregator.(InvalidParameter.new("invalid option '#{short}'"))
          else
            @remaining << short
          end

          [opt, value]
        end

        # Consume multi argument
        #
        # @api private
        def consume_arguments(values: [])
          while (value = @argv.first) && !option?(value)
            val = @argv.shift
            parts = val.include?("&") ? val.split(/&/) : [val]
            parts.each { |part| values << part }
          end

          values.size == 1 ? values.first : values
        end

        # @api private
        def assign_option(opt, val)
          value = @pipeline.(opt, val)

          if opt.multiple?
            allowed = opt.arity < 0 || @arities[opt.key] <= opt.arity
            if allowed
              case value
              when Hash
                (@parsed[opt.key] ||= {}).merge!(value)
              else
                Array(value).each do |v|
                  (@parsed[opt.key] ||= []) << v
                end
              end
            else
              @remaining << opt.short_name
              @remaining << value
            end
          else
            @parsed[opt.key] = value
          end
        end
      end # Options
    end # Parser
  end # Option
end # TTY
