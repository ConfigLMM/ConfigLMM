# frozen_string_literal: true

require_relative "result"

module TTY
  module Option
    module ParamPermitted
      # Convert parameter value to another type
      #
      # @example
      #   param = Parameter::Argument.create(:foo, permit: %w[11 12 13])
      #   ParamPermitted[param, "12"] # => 12
      #
      # @api public
      def call(param, value)
        return Result.success(value) if !param.permit? || value.nil?

        unpermitted = Array(value) - Array(param.permit)

        if unpermitted.empty?
          Result.success(value)
        else
          Result.failure(unpermitted.map do |val|
            UnpermittedArgument.new(param, val)
          end)
        end
      end
      module_function :call

      alias [] call
      module_function :[]
    end # ParamPermitted
  end # Option
end # TTY
