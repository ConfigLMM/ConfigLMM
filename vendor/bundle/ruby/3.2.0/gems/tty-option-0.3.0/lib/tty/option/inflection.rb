# frozen_string_literal: true

module TTY
  module Option
    module Inflection
      # Remove all modules/class names
      #
      # @example
      #   demodulize("TTY::Option::ErrorAggregator")
      #   # => "ErrorAggregator"
      #
      # @return [String]
      #
      # @api public
      def demodulize(name)
        name.to_s.split("::").last
      end
      module_function :demodulize

      # Convert class name to underscore
      #
      # @example
      #   underscore("ErrorAggregator")
      #   # => "error_aggregator"
      #
      # @return [String]
      #
      # @api public
      def underscore(name)
        name.to_s
            .gsub(/([A-Z\d]+)([A-Z][a-z])/, "\\1_\\2")
            .gsub(/([a-z\d]+)([A-Z])/, "\\1_\\2")
            .downcase
      end
      module_function :underscore

      # Convert class name to dashed case
      #
      # @example
      #   dasherize("ErrorAggregator")
      #   # => "error-aggregator"
      #
      # @api public
      def dasherize(name)
        underscore(name).tr("_", "-")
      end
      module_function :dasherize
    end # Inflection
  end # Option
end # TTY
