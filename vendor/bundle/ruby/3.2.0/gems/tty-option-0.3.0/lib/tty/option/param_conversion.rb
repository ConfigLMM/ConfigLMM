# frozen_string_literal: true

require_relative "conversions"
require_relative "result"

module TTY
  module Option
    module ParamConversion
      # Convert parameter value to another type
      #
      # @example
      #   param = Parameter::Argument.create(:foo, convert: :int)
      #   result = ParamConversion[param, "12"]
      #   result.value # => 12
      #
      # @api public
      def call(param, value)
        return Result.success(value) if !param.convert? || value.nil?

        cast = param.convert
        cast = cast.is_a?(Proc) ? cast : Conversions[cast]
        converted = cast.(value)

        if converted == Const::Undefined
          Result.failure(InvalidConversionArgument.new(param, value))
        else
          Result.success(converted)
        end
      end
      module_function :call

      alias [] call
      module_function :[]
    end # ParamConversion
  end # Option
end # TTY
