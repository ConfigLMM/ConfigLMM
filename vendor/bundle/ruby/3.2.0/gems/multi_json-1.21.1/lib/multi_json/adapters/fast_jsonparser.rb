# frozen_string_literal: true

require "fast_jsonparser"
require_relative "../adapter"
require_relative "../adapter_selector"

module MultiJSON
  module Adapters
    # Use the FastJsonparser library to load, and the fastest other
    # available adapter to dump.
    #
    # FastJsonparser only implements parsing, so the ``dump`` side of
    # the adapter is delegated to whichever adapter MultiJSON would
    # pick if FastJsonparser weren't installed (oj → yajl → jr_jackson
    # → json_gem → gson). The delegate is resolved lazily at the first
    # ``dump`` call, not at file load time, so load order doesn't lock
    # in the wrong delegate. Require any preferred dump backend before
    # the first ``dump`` call (typical applications already have ``oj``
    # loaded by then).
    class FastJsonparser < Adapter
      defaults :load, symbolize_names: false

      # Exception raised when JSON parsing fails
      ParseError = ::FastJsonparser::ParseError

      class << self
        # Serialize a Ruby object to JSON via the lazy delegate
        #
        # @api private
        # @param object [Object] object to serialize
        # @param options [Hash] serialization options
        # @return [String] JSON string
        # @example
        #   adapter.dump({key: "value"}) #=> '{"key":"value"}'
        def dump(object, options = {})
          dump_delegate.dump(object, options)
        end

        private

        # Resolve the dump delegate, caching it across calls
        #
        # @api private
        # @return [Class] delegate adapter class
        def dump_delegate
          MultiJSON::Concurrency.synchronize(:dump_delegate) do
            @dump_delegate ||= MultiJSON::AdapterSelector.default_adapter_excluding(:fast_jsonparser)
          end
        end
      end

      # Parse a JSON string into a Ruby object
      #
      # FastJsonparser.parse only accepts ``symbolize_keys`` and raises
      # on unknown keyword arguments, so the adapter explicitly forwards
      # MultiJSON's canonical ``:symbolize_names`` option as
      # FastJsonparser's native ``symbolize_keys:`` kwarg and silently
      # drops the rest. Pass other options through
      # ``MultiJSON.parse_options=`` and they'll apply to whichever
      # adapter MultiJSON selects when fast_jsonparser isn't installed.
      #
      # @api private
      # @param string [String] JSON string to parse
      # @param options [Hash] parsing options (only :symbolize_names is honored)
      # @return [Object] parsed Ruby object
      #
      # @example Parse JSON string
      #   adapter.load('{"key":"value"}') #=> {"key" => "value"}
      def load(string, options = {})
        ::FastJsonparser.parse(string, symbolize_keys: options[:symbolize_names])
      end
    end
  end
end
