# frozen_string_literal: true

module TTY
  module Option
    class Parser
      class RequiredCheck
        def initialize(error_aggregator)
          @required = []
          @error_aggregator = error_aggregator
        end

        def add(param)
          @required << param
        end
        alias << add

        def delete(param)
          @required.delete(param)
        end

        # Check if required options are provided
        #
        # @raise [MissingParameter]
        #
        # @api public
        def call
          return if @required.empty?

          @required.each do |param|
            @error_aggregator.(MissingParameter.new(param))
          end
        end
      end # RequiredCheck
    end # Parser
  end # Option
end # TTY
