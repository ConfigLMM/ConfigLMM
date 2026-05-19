# frozen_string_literal: true

require_relative "param_conversion"
require_relative "param_permitted"
require_relative "param_validation"

module TTY
  module Option
    class Pipeline
      PROCESSORS = [
        ParamConversion,
        ParamPermitted,
        ParamValidation
      ].freeze

      # Create a param processing pipeline
      #
      # @api private
      def initialize(error_aggregator)
        @error_aggregator = error_aggregator
      end

      # Process param value through conditions
      #
      # @api public
      def call(param, value)
        result = Result.success(value)
        PROCESSORS.each do |processor|
          result = processor[param, result.value]
          if result.failure?
            Array(result.error).each { |err| @error_aggregator.(err) }
          end
        end
        result.value
      end
    end # Pipeline
  end # Option
end # TTY
