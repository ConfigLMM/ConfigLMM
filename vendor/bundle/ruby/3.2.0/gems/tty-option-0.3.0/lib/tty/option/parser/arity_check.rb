# frozen_string_literal: true

module TTY
  module Option
    class Parser
      class ArityCheck
        def initialize(error_aggregator)
          @multiplies = []
          @error_aggregator = error_aggregator
        end

        def add(param)
          @multiplies << param
        end
        alias << add

        # Check if parameter matches arity
        #
        # @raise [InvalidArity]
        #
        # @api private
        def call(arities)
          @multiplies.each do |param|
            arity = arities[param.key]

            if arity < param.min_arity
              @error_aggregator.(InvalidArity.new(param, arity))
            end
          end
        end
      end # ArityCheck
    end # Parser
  end # Option
end # TTY
