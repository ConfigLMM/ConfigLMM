# frozen_string_literal: true

require "forwardable"

require_relative "usage_wrapper"

module TTY
  module Option
    class AggregateErrors
      include Enumerable
      include UsageWrapper
      extend Forwardable

      def_delegators :@errors, :size, :empty?, :any?, :clear

      # Create an intance from the passed error objects
      #
      # @api public
      def initialize(errors = [])
        @errors = errors
      end

      # Add error
      #
      # @api public
      def add(error)
        @errors << error
        error
      end

      # Enumerate each error
      #
      # @example
      #   errors = AggregateErrors.new
      #   errors.each do |error|
      #     # instance of TTY::Option::Error
      #   end
      #
      # @api public
      def each(&block)
        @errors.each(&block)
      end

      # All error messages
      #
      # @example
      #   errors = AggregateErrors.new
      #   errors.add TTY::OptionInvalidArgument.new("invalid argument")
      #   errors.messages
      #   # => ["invalid argument"]
      #
      # @api public
      def messages
        map(&:message)
      end

      # Format errors for display in terminal
      #
      # @example
      #   errors = AggregateErrors.new
      #   errors.add TTY::OptionInvalidArgument.new("invalid argument")
      #   errors.summary
      #   # =>
      #   # Error: invalid argument
      #
      # @param [Integer] :width
      # @param [Integer] :indent
      #
      # @return [String]
      #
      # @api public
      def summary(width: 80, indent: 0)
        return "" if count.zero?

        output = []
        space_indent = " " * indent
        if messages.count == 1
          msg = messages.first
          label = "Error: "
          output << "#{space_indent}#{label}" \
                    "#{wrap(msg, indent: indent + label.length, width: width)}"
        else
          output << "#{space_indent}Errors:"
          messages.each_with_index do |message, num|
            entry = "  #{num + 1}) "
            output << "#{space_indent}#{entry}" \
                      "#{wrap(message.capitalize, indent: indent + entry.length,
                                                  width: width)}"
          end
        end
        output.join("\n")
      end
    end # AggregateErrors
  end # Option
end # TTY
