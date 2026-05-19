# frozen_string_literal: true

require_relative "inflection"

module TTY
  module Option
    class ErrorAggregator
      include Inflection

      # Collected errors
      attr_reader :errors

      def initialize(errors = [], raise_on_parse_error: false)
        @errors = errors
        @raise_on_parse_error = raise_on_parse_error
      end

      # Record or raise an error
      #
      # @param [TTY::Option::Error] error
      # @param [String] message
      #
      # @api public
      def call(error, message = nil)
        if error.is_a?(Class)
          error = message.nil? ? error.new : error.new(message)
        end

        raise(error) if @raise_on_parse_error

        @errors << error
      end
    end # ErrorAggregator
  end # Option
end # TTY
