# frozen_string_literal: true

module TTY
  module Option
    module Converter
      # Store conversions
      #
      # @api public
      def conversions
        @conversions ||= {}
      end

      # Check if conversion is available
      #
      # @param [String] name
      #
      # @return [Boolean]
      #
      # @api public
      def contain?(name)
        conv_name = name.to_s.downcase.to_sym
        conversions.key?(conv_name)
      end

      # Register a new conversion type
      #
      # @example
      #   convert(:int) { |val| Float(val).to_i }
      #
      # @api public
      def convert(*names, &block)
        names.each do |name|
          if contain?(name)
            raise ConversionAlreadyDefined,
                  "conversion #{name.inspect} is already defined"
          end
          conversions[name] = block
        end
      end

      # Retrieve a conversion type
      #
      # @param [String] name
      #
      # @return [Proc]
      #
      # @api public
      def [](name)
        conv_name = name.to_s.downcase.to_sym
        conversions.fetch(conv_name) { raise_unsupported_error(conv_name) }
      end
      alias fetch []

      # Raise an error for unknown conversion type
      #
      # @api public
      def raise_unsupported_error(conv_name)
        raise UnsupportedConversion,
              "unsupported conversion type #{conv_name.inspect}"
      end
    end # Converter
  end # Option
end # TTY
