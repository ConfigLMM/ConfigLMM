# frozen_string_literal: true

require_relative "../adapter"
require "json"

module MultiJSON
  module Adapters
    # Use the JSON gem to dump/load.
    class JsonGem < Adapter
      # Exception raised when JSON parsing fails
      ParseError = ::JSON::ParserError

      defaults :load, create_additions: false, quirks_mode: true

      PRETTY_STATE_PROTOTYPE = {
        indent: "  ",
        space: " ",
        object_nl: "\n",
        array_nl: "\n"
      }.freeze
      private_constant :PRETTY_STATE_PROTOTYPE

      # Parse a JSON string into a Ruby object
      #
      # Non-UTF-8 strings are re-labeled via ``force_encoding`` (not
      # transcoded) and then validated. This handles the dominant
      # real-world case: Ruby HTTP libraries return response bodies
      # tagged as ``ASCII-8BIT`` even when the bytes are valid UTF-8.
      # ``encode(Encoding::UTF_8)`` would raise on any multi-byte
      # sequence in that scenario because it tries to transcode each
      # byte individually from ASCII-8BIT to UTF-8.
      #
      # @api private
      # @param string [String] JSON string to parse
      # @param options [Hash] parsing options
      # @return [Object] parsed Ruby object
      # @raise [::JSON::ParserError] when the input is not valid UTF-8
      #
      # @example Parse JSON string
      #   adapter.load('{"key":"value"}') #=> {"key" => "value"}
      def load(string, options = {})
        if string.encoding != Encoding::UTF_8
          string = string.dup.force_encoding(Encoding::UTF_8)
          raise ::JSON::ParserError, "Invalid UTF-8 byte sequence in JSON input" unless string.valid_encoding?
        end

        ::JSON.parse(string, options)
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
        json_object = object.respond_to?(:as_json) ? object.as_json : object
        return ::JSON.dump(json_object) if options.empty?
        return ::JSON.generate(json_object, options) unless options.key?(:pretty)

        # Common case: ``pretty: true`` is the only option, so the merge
        # would just produce a copy of PRETTY_STATE_PROTOTYPE.
        return ::JSON.pretty_generate(json_object, PRETTY_STATE_PROTOTYPE) if options.size == 1

        ::JSON.pretty_generate(json_object, PRETTY_STATE_PROTOTYPE.merge(options.except(:pretty)))
      end
    end
  end
end
