# frozen_string_literal: true

require "set"

module TTY
  module Option
    # A collection to hold all parameters
    class Parameters
      include Enumerable

      # Define a query for parameter types
      #
      # @api private
      def self.define_query(name)
        define_method(:"#{name}?") do
          !public_send(name).empty?
        end
      end

      # Define a predicate method to check if a parameter is supported
      #
      # @api private
      def self.define_param_query(name)
        define_method(:"#{name}?") do |param|
          public_send(:"#{name}s").map(&:key).include?(param)
        end
      end

      # A list of arguments
      attr_reader :arguments

      # A list of keywords
      attr_reader :keywords

      # A list of environments
      attr_reader :environments

      # A list of options
      attr_reader :options

      # A list of all parameters
      attr_reader :list

      define_query :arguments
      define_query :keywords
      define_query :options
      define_query :environments

      define_param_query :argument
      define_param_query :keyword
      define_param_query :option
      define_param_query :environment

      # A parameters list
      #
      # @api private
      def initialize
        @arguments = []
        @environments = []
        @keywords = []
        @options = []
        @list = []

        @registered_keys = Set.new
        @registered_shorts = Set.new
        @registered_longs = Set.new
      end

      # Add parameter
      #
      # @param [TTY::Option::Parameter] parameter
      #
      # @api public
      def <<(parameter)
        check_key_uniqueness!(parameter.key)

        if parameter.to_sym == :option
          check_short_option_uniqueness!(parameter.short_name)
          check_long_option_uniqueness!(parameter.long_name)
        end

        @list << parameter
        arr = instance_variable_get("@#{parameter.to_sym}s")
        arr.send :<<, parameter
        self
      end
      alias add <<

      # Delete a parameter from the list
      #
      # @example
      #   delete(:foo, :bar, :baz)
      #
      # @param [Array<Symbol>] keys
      #   the keys to delete
      #
      # @api public
      def delete(*keys)
        deleted = []
        @list.delete_if { |p| keys.include?(p.key) && (deleted << p) }
        deleted.each do |param|
          params_list = instance_variable_get("@#{param.to_sym}s")
          params_list.delete(param)
        end
        @registered_keys.subtract(keys)
        @registered_shorts.replace(@options.map(&:short))
        @registered_longs.replace(@options.map(&:long))
        deleted
      end

      # Enumerate all parameters
      #
      # @api public
      def each(&block)
        if block_given?
          @list.each(&block)
        else
          to_enum(:each)
        end
      end

      # Make a deep copy of the list of parameters
      #
      # @api public
      def dup
        super.tap do |params|
          params.instance_variables.each do |var|
            dupped = DeepDup.deep_dup(params.instance_variable_get(var))
            params.instance_variable_set(var, dupped)
          end
        end
      end

      private

      # @api private
      def check_key_uniqueness!(key)
        if @registered_keys.include?(key)
          raise ParameterConflict,
                "already registered parameter #{key.inspect}"
        else
          @registered_keys << key
        end
      end

      # @api private
      def check_short_option_uniqueness!(short_name)
        return if short_name.empty?

        if @registered_shorts.include?(short_name)
          raise ParameterConflict,
                "already registered short option #{short_name}"
        else
          @registered_shorts << short_name
        end
      end

      # @api private
      def check_long_option_uniqueness!(long_name)
        return if long_name.empty?

        if @registered_longs.include?(long_name)
          raise ParameterConflict,
                "already registered long option #{long_name}"
        else
          @registered_longs << long_name
        end
      end
    end # Parameters
  end # Option
end # TTY
