# frozen_string_literal: true

module TTY
  module Option
    # A monad that respresents success and failure conditions
    class Result
      # Wrap a value in a success monad
      #
      # @api public
      def self.success(value)
        Success.new(value)
      end

      # Wrap a value in a failure monad
      #
      # @api public
      def self.failure(value)
        Failure.new(value)
      end

      # Wrapped value
      #
      # @api public
      attr_reader :value

      # Reason for failure
      #
      # @api public
      attr_reader :error

      # Check whether or not a result is a success monad
      #
      # @return [Boolean]
      #
      # @api public
      def success?
        is_a?(Success)
      end

      # Check whether or not a result is a failure class
      #
      # @return [Boolean]
      #
      # @api public
      def failure?
        is_a?(Failure)
      end

      # Success monad containing a value
      #
      # @api private
      class Success < Result
        def initialize(value)
          @value = value
        end
      end

      # Failure monad containing an error
      #
      # @api private
      class Failure < Result
        def initialize(error)
          @error = error
        end
      end
    end # Result
  end # Option
end # TTY
