# frozen_string_literal: true

require "oj"
require_relative "../adapter"
require_relative "oj_common"

module MultiJSON
  # Namespace for JSON adapter implementations
  #
  # Each adapter wraps a specific JSON library and provides a consistent
  # interface for loading and dumping JSON data.
  module Adapters
    # Use the Oj library to dump/load.
    class Oj < Adapter
      include OjCommon

      defaults :load, mode: :strict, symbolize_names: false
      defaults :dump, mode: :compat, time_format: :ruby, use_to_json: true

      # In certain cases the Oj gem may throw a ``JSON::ParserError``
      # exception instead of its own class. Neither ``::JSON::ParserError``
      # nor ``::Oj::ParseError`` is guaranteed to be defined, so we can't
      # reference them directly — match by walking the exception's
      # ancestry by class name instead. This will not catch subclasses
      # of those classes, which shouldn't be a problem since neither
      # library is known to subclass them.
      class ParseError < ::SyntaxError
        WRAPPED_CLASSES = %w[Oj::ParseError JSON::ParserError].freeze
        private_constant :WRAPPED_CLASSES

        # Case equality for exception matching in rescue clauses
        #
        # @api private
        # @param exception [Exception] exception to check
        # @return [Boolean] true if exception is a parse error
        #
        # @example Match parse errors in rescue
        #   rescue ParseError => e
        def self.===(exception)
          exception.class.ancestors.any? { |ancestor| WRAPPED_CLASSES.include?(ancestor.to_s) }
        end
      end

      # Parse a JSON string into a Ruby object
      #
      # @api private
      # @param string [String] JSON string to parse
      # @param options [Hash] parsing options
      # @return [Object] parsed Ruby object
      #
      # @example Parse JSON string
      #   adapter.load('{"key":"value"}') #=> {"key" => "value"}
      def load(string, options = {})
        ::Oj.load(string, translate_load_options(options))
      end

      # Serialize a Ruby object to JSON
      #
      # @api private
      # @param object [Object] object to serialize
      # @param options [Hash] serialization options
      # @return [String] JSON string
      #
      # @example Serialize object to JSON
      #   adapter.dump({key: "value"}) #=> '{"key":"value"}'
      def dump(object, options = {})
        ::Oj.dump(object, prepare_dump_options(options))
      end

      private

      # Translate ``:symbolize_names`` into Oj's ``:symbol_keys``
      #
      # Returns a new hash without mutating the input.
      # ``:symbol_keys`` is always set (true or false) so MultiJSON's
      # behavior is independent of any global ``Oj.default_options``
      # the host application may have set. The input is the cached hash
      # returned from {Adapter.merged_load_options}, so in-place edits
      # would pollute the cache.
      #
      # @api private
      # @param options [Hash] merged load options
      # @return [Hash] options with ``:symbolize_names`` translated
      def translate_load_options(options)
        options.except(:symbolize_names).merge(symbol_keys: options[:symbolize_names] == true)
      end
    end
  end
end
