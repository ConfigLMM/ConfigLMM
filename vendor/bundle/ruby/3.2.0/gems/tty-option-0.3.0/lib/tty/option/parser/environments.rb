# frozen_string_literal: true

require_relative "arity_check"
require_relative "param_types"
require_relative "required_check"
require_relative "../error_aggregator"
require_relative "../pipeline"

module TTY
  module Option
    class Parser
      class Environments
        include ParamTypes

        ENV_VAR_RE = /([\p{Lu}_\-\d]+)=([^=]+)/.freeze

        # Create a command line env variables parser
        #
        # @param [Array<Environment>] environments
        #   the list of environment variables
        # @param [Hash] config
        #   the configuration settings
        #
        # @api public
        def initialize(environments, check_invalid_params: true,
                       raise_on_parse_error: false)
          @environments = environments
          @check_invalid_params = check_invalid_params
          @error_aggregator =
            ErrorAggregator.new(raise_on_parse_error: raise_on_parse_error)
          @required_check = RequiredCheck.new(@error_aggregator)
          @arity_check = ArityCheck.new(@error_aggregator)
          @pipeline = Pipeline.new(@error_aggregator)
          @parsed = {}
          @remaining = []
          @names = {}
          @arities = Hash.new(0)

          @environments.each do |env_arg|
            @names[env_arg.name] = env_arg
            @arity_check << env_arg if env_arg.multiple?

            if env_arg.default?
              case env_arg.default
              when Proc
                assign_envvar(env_arg, env_arg.default.())
              else
                assign_envvar(env_arg, env_arg.default)
              end
            elsif env_arg.required?
              @required_check << env_arg
            end
          end
        end

        # Read environment variable(s) from command line or ENV hash
        #
        # @param [Array<String>] argv
        # @param [Hash<String,Object>] env
        #
        # @api public
        def parse(argv, env)
          @argv = argv.dup
          @env = env

          loop do
            env_var, value = next_envvar
            if !env_var.nil?
              @required_check.delete(env_var)
              @arities[env_var.key] += 1

              if block_given?
                yield(env_var, value)
              end
              assign_envvar(env_var, value)
            end
            break if @argv.empty?
          end

          @environments.each do |env_arg|
            if (value = env[env_arg.name])
              @required_check.delete(env_arg)
              @arities[env_arg.key] += 1
              assign_envvar(env_arg, value)
            end
          end

          @arity_check.(@arities)
          @required_check.()

          [@parsed, @remaining, @error_aggregator.errors]
        end

        private

        def next_envvar
          env_var, value = nil, nil

          while !@argv.empty? && !env_var?(@argv.first)
            @remaining << @argv.shift
          end

          if @argv.empty?
            return
          else
            environment = @argv.shift
          end

          if (match = environment.match(ENV_VAR_RE))
            _, name, val = *match.to_a

            if (env_var = @names[name])
              if env_var.multi_argument? &&
                  !(consumed = consume_arguments).empty?
                value = [val] + consumed
              else
                value = val
              end
            elsif @check_invalid_params
              @error_aggregator.(InvalidParameter.new("invalid environment #{match}"))
            else
              @remaining << match.to_s
            end
          end

          [env_var, value]
        end

        # Consume multi argument
        #
        # @api private
        def consume_arguments(values: [])
          while (value = @argv.first) &&
            !option?(value) && !keyword?(value) && !env_var?(value)

            val = @argv.shift
            parts = val.include?("&") ? val.split(/&/) : [val]
            parts.each { |part| values << part }
          end

          values
        end

        # @api private
        def assign_envvar(env_arg, val)
          value = @pipeline.(env_arg, val)

          if env_arg.multiple?
            allowed = env_arg.arity < 0 || @arities[env_arg.key] <= env_arg.arity
            if allowed
              case value
              when Hash
                (@parsed[env_arg.key] ||= {}).merge!(value)
              else
                Array(value).each do |v|
                  (@parsed[env_arg.key] ||= []) << v
                end
              end
            else
              @remaining << "#{env_arg.name}=#{value}"
            end
          else
            @parsed[env_arg.key] = value
          end
        end
      end # Environments
    end # Parser
  end # Option
end # TTY
