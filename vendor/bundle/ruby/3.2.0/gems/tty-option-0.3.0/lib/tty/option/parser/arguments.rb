# frozen_string_literal: true

require_relative "../error_aggregator"
require_relative "../pipeline"
require_relative "param_types"
require_relative "required_check"

module TTY
  module Option
    class Parser
      class Arguments
        include ParamTypes

        # Create a command line arguments parser
        #
        # @param [Array<Argument>] arguments
        #   the list of arguments
        # @param [Hash] config
        #   the configuration settings
        #
        # @api public
        def initialize(arguments, check_invalid_params: true,
                       raise_on_parse_error: false)
          @arguments = arguments
          @error_aggregator =
            ErrorAggregator.new(raise_on_parse_error: raise_on_parse_error)
          @required_check = RequiredCheck.new(@error_aggregator)
          @pipeline = Pipeline.new(@error_aggregator)
          @parsed = {}
          @remaining = []

          @defaults = {}
          @arguments.each do |arg|
            if arg.default?
              case arg.default
              when Proc
                @defaults[arg.key] = arg.default.()
              else
                @defaults[arg.key] = arg.default
              end
            elsif arg.required?
              @required_check << arg
            end
          end
        end

        # Read positional arguments from the command line
        #
        # @param [Array<String>] argv
        #
        # @return [Array<Hash, Array, Hash>]
        #   a list of parsed and unparsed arguments and errors
        #
        # @api private
        def parse(argv)
          @argv = argv.dup

          @arguments.each do |arg|
            values = next_argument(arg)
            @required_check.delete(arg) unless values.empty?

            assign_argument(arg, values)
          end

          while (val = @argv.shift)
            @remaining << val
          end

          @required_check.()

          [@parsed, @remaining, @error_aggregator.errors]
        end

        private

        # @api private
        def next_argument(arg)
          if arg.arity >= 0
            process_exact_arity(arg)
          else
            process_infinite_arity(arg)
          end
        end

        def process_exact_arity(arg)
          values = []
          arity = arg.arity

          while arity > 0
            break if @argv.empty?
            value = @argv.shift
            if argument?(value)
              values << value
              arity -= 1
            else
              @remaining << value
            end
          end

          if 0 < values.size && values.size < arg.arity &&
              Array(@defaults[arg.key]).size < arg.arity
            @error_aggregator.(InvalidArity.new(arg, values.size))
          end

          values
        end

        def process_infinite_arity(arg)
          values = []
          arity = arg.arity.abs - 1

          arity.times do
            break if @argv.empty?
            value = @argv.shift
            if argument?(value)
              values << value
            else
              @remaining << value
            end
          end

          # consume remaining
          while (value = @argv.shift)
            if argument?(value)
              values << value
            else
              @remaining << value
            end
          end

          if values.size < arity && Array(@defaults[arg.key]).size < arity
            @error_aggregator.(InvalidArity.new(arg, values.size))
          end

          values
        end

        # Assign argument to the parsed
        #
        # @param [Argument] arg
        # @param [Array] values
        #
        # @api private
        def assign_argument(arg, values)
          val = case values.size
                when 0
                  if arg.default?
                    case arg.default
                    when Proc
                      @defaults[arg.key]
                    else
                      @defaults[arg.key]
                    end
                  end
                when 1
                  values.first
                else
                  values
                end

          @parsed[arg.key] = @pipeline.(arg, val)
        end
      end # Arguments
    end # Parser
  end # Option
end # TTY
