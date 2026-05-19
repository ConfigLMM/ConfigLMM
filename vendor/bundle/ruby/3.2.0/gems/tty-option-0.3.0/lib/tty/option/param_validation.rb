# frozen_string_literal: true

require_relative "result"

module TTY
  module Option
    # Responsible for parameter validation
    #
    # @api private
    module ParamValidation
      # Validate parameter value against validation rule
      #
      # @example
      #   param = TTY::Option::Parameter::Option.create(:foo, validate: "\d+")
      #   TTY::Option::ParamValidation[param, "12"] # => "12"
      #
      # @param [TTY::Option::Parameter] param
      #   the parameter with a validation rule
      # @param [Object] value
      #   the value to validate
      #
      # @return [TTY::Option::Result]
      #
      # @api public
      def call(param, value)
        return Result.success(value) if !param.validate? || value.nil?

        errors = []
        result = validate_object(param, value) do |error|
          errors << error
        end

        if errors.empty?
          Result.success(result)
        else
          Result.failure(errors)
        end
      end
      module_function :call

      alias [] call
      module_function :[]

      # Validate an object
      #
      # @param [TTY::Option::Parameter] param
      #   the parameter with a validation rule
      # @param [Object] value
      #   the value to validate
      #
      # @yield [TTY::Option::InvalidArgument]
      #
      # @return [Object, nil]
      #
      # @api private
      def validate_object(param, value, &block)
        case value
        when Array
          validate_array(param, value, &block)
        when Hash
          validate_hash(param, value, &block)
        else
          error = valid_or_error(param, value)
          error ? block.(error) && return : value
        end
      end
      module_function :validate_object
      private_class_method :validate_object

      # Validate array values
      #
      # @param [TTY::Option::Parameter] param
      #   the parameter with a validation rule
      # @param [Object] values
      #   the values in an array to validate
      #
      # @yield [TTY::Option::InvalidArgument]
      #
      # @return [Array]
      #
      # @api private
      def validate_array(param, values)
        values.each_with_object([]) do |value, acc|
          error = valid_or_error(param, value)
          error ? yield(error) : acc << value
        end
      end
      module_function :validate_array
      private_class_method :validate_array

      # Validate hash values
      #
      # @param [TTY::Option::Parameter] param
      #   the parameter with a validation rule
      # @param [Object] values
      #   the values in a hash to validate
      #
      # @yield [TTY::Option::InvalidArgument]
      #
      # @return [Hash]
      #
      # @api private
      def validate_hash(param, values)
        values.each_with_object({}) do |value, acc|
          error = valid_or_error(param, value)
          error ? yield(error) : acc[value[0]] = value[1]
        end
      end
      module_function :validate_hash
      private_class_method :validate_hash

      # Create an error for an invalid parameter value
      #
      # @param [TTY::Option::Parameter] param
      #   the parameter with a validation rule
      # @param [Object] value
      #   the value to validate
      #
      # @return [TTY::Option::InvalidArgument, nil]
      #
      # @api private
      def valid_or_error(param, value)
        return if valid?(param, value)

        TTY::Option::InvalidArgument.new(param, value)
      end
      module_function :valid_or_error
      private_class_method :valid_or_error

      # Check whether a parameter value is valid or not
      #
      # @param [TTY::Option::Parameter] param
      #   the parameter with a validation rule
      # @param [Object] value
      #   the value to validate
      #
      # @return [Boolean]
      #
      # @api private
      def valid?(param, value)
        case param.validate
        when Proc
          param.validate.(value)
        when Regexp
          !param.validate.match(value.to_s).nil?
        end
      end
      module_function :valid?
      private_class_method :valid?
    end # ParamValidation
  end # Option
end # TTY
