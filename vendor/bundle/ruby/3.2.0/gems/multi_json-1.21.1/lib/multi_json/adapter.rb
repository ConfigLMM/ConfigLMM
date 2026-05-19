# frozen_string_literal: true

require "singleton"
require_relative "options"

module MultiJSON
  # Base class for JSON adapter implementations
  #
  # Each adapter wraps a specific JSON library (Oj, JSON gem, etc.) and
  # provides a consistent interface. Uses Singleton pattern so each adapter
  # class has exactly one instance.
  #
  # Subclasses must implement:
  # - #load(string, options) -> parsed object
  # - #dump(object, options) -> JSON string
  #
  # @api private
  class Adapter
    extend Options
    include Singleton

    class << self
      BLANK_PATTERN = /\A\s*\z/
      VALID_DEFAULTS_ACTIONS = %i[load dump].freeze
      private_constant :BLANK_PATTERN, :VALID_DEFAULTS_ACTIONS

      # Get default parse options, walking the superclass chain
      #
      # Returns the closest ancestor's `@default_load_options` ivar so a
      # parent class calling {.defaults} after a subclass has been
      # defined still propagates to the subclass. Falls back to the
      # shared frozen empty hash when no ancestor has defaults set.
      #
      # @api private
      # @return [Hash] frozen options hash
      def default_parse_options
        walk_default_options(:@default_load_options)
      end

      # Get default generate options, walking the superclass chain
      #
      # @api private
      # @return [Hash] frozen options hash
      def default_generate_options
        walk_default_options(:@default_dump_options)
      end

      # Get default parse options, walking the superclass chain
      #
      # @api private
      # @deprecated Use {.default_parse_options} instead. Will be removed in v2.0.
      # @return [Hash] frozen options hash
      def default_load_options
        default_parse_options
      end

      # Get default generate options, walking the superclass chain
      #
      # @api private
      # @deprecated Use {.default_generate_options} instead. Will be removed in v2.0.
      # @return [Hash] frozen options hash
      def default_dump_options
        default_generate_options
      end

      # DSL for setting adapter-specific default options
      #
      # ``action`` must be ``:load`` or ``:dump``; ``value`` must be a
      # Hash. Both arguments are validated up front so a typo at the
      # adapter's class definition fails fast instead of producing a
      # silent no-op default that crashes later in the merge path.
      #
      # @api private
      # @param action [Symbol] :load or :dump
      # @param value [Hash] default options for the action
      # @return [Hash] the frozen options hash
      # @raise [ArgumentError] when action is anything other than :load
      #   or :dump, or when value isn't a Hash
      # @example Set load defaults for an adapter
      #   class MyAdapter < MultiJSON::Adapter
      #     defaults :load, symbolize_keys: false
      #   end
      def defaults(action, value)
        raise ArgumentError, "expected action to be :load or :dump, got #{action.inspect}" unless VALID_DEFAULTS_ACTIONS.include?(action)
        raise ArgumentError, "expected value to be a Hash, got #{value.class}" unless value.is_a?(Hash)

        instance_variable_set(:"@default_#{action}_options", value.freeze)
      end

      # Parse a JSON string into a Ruby object
      #
      # @api private
      # @param string [String, #read] JSON string or IO-like object
      # @param options [Hash] parsing options
      # @return [Object, nil] parsed object or nil for blank input
      def load(string, options = {})
        string = string.read if string.respond_to?(:read)
        return nil if blank?(string)

        instance.load(string, merged_load_options(options))
      end

      # Serialize a Ruby object to JSON
      #
      # @api private
      # @param object [Object] object to serialize
      # @param options [Hash] serialization options
      # @return [String] JSON string
      def dump(object, options = {})
        instance.dump(object, merged_dump_options(options))
      end

      private

      # Walk the superclass chain looking for a default options ivar
      #
      # Stops at the first ancestor whose ``ivar`` is set and returns
      # that value. Returns {Options::EMPTY_OPTIONS} when no ancestor
      # has the ivar set, so adapters without defaults always observe a
      # frozen empty hash instead of nil.
      #
      # @api private
      # @param ivar [Symbol] ivar name (`:@default_load_options` or `:@default_dump_options`)
      # @return [Hash] frozen options hash
      def walk_default_options(ivar)
        # @type var klass: Class?
        klass = self
        while klass
          return klass.instance_variable_get(ivar) if klass.instance_variable_defined?(ivar)

          klass = klass.superclass
        end
        Options::EMPTY_OPTIONS
      end

      # Checks if the input is blank (nil, empty, or whitespace-only)
      #
      # The dominant call path arrives with a non-blank string starting
      # with ``{`` or ``[`` (the JSON object/array sigils), so a
      # ``start_with?`` short-circuit skips the regex entirely on the
      # hot path. Falls through to the full check for everything else
      # — strings, numbers, booleans, ``null``, whitespace-prefixed
      # input — at which point ``String#scrub`` is only invoked when
      # the input has invalid encoding so the common valid-UTF-8 path
      # doesn't allocate a scrubbed copy on every call. Scrubbing
      # replaces invalid bytes with U+FFFD before the regex runs so a
      # string with bad bytes is still treated as non-blank without a
      # broad rescue.
      #
      # @api private
      # @param input [String, nil] input to check
      # @return [Boolean] true if input is blank
      def blank?(input)
        return true if input.nil? || input.empty?
        return false if input.start_with?("{", "[")

        BLANK_PATTERN.match?(input.valid_encoding? ? input : input.scrub)
      end

      # Merges generate options from adapter, global, and call-site
      #
      # @api private
      # @param options [Hash] call-site options
      # @return [Hash] merged options hash
      def merged_dump_options(options)
        cache_key = strip_adapter_key(options)
        OptionsCache.dump.fetch(cache_key) do
          generate_options(cache_key).merge(MultiJSON.generate_options(cache_key)).merge!(cache_key)
        end
      end

      # Merges parse options from adapter, global, and call-site
      #
      # Each layer is normalized first so a deprecated ``:symbolize_keys``
      # key in any source becomes the canonical ``:symbolize_names`` —
      # done per-layer rather than post-merge so the expected override
      # semantics (call-site > global > adapter default) still apply
      # when a caller mixes the deprecated and canonical names across
      # layers.
      #
      # @api private
      # @param options [Hash] call-site options
      # @return [Hash] merged options hash
      def merged_load_options(options)
        cache_key = strip_adapter_key(options)
        OptionsCache.load.fetch(cache_key) do
          adapter = normalize_symbolize_option(parse_options(cache_key))
          global = normalize_symbolize_option(MultiJSON.parse_options(cache_key))
          call_site = normalize_symbolize_option(cache_key)
          adapter.merge(global).merge!(call_site)
        end
      end

      # Translate the deprecated ``:symbolize_keys`` option to ``:symbolize_names``
      #
      # Matches Ruby stdlib's ``JSON.parse`` naming. Emits a one-time
      # deprecation warning on first encounter of ``:symbolize_keys``.
      # When both names appear in the same layer (unusual — only
      # possible if the caller explicitly set both), the canonical
      # ``:symbolize_names`` value wins and ``:symbolize_keys`` is
      # silently dropped.
      #
      # @api private
      # @param options [Hash] options layer to normalize
      # @return [Hash] hash with ``:symbolize_keys`` translated, or the
      #   original hash when no translation is needed
      def normalize_symbolize_option(options)
        return options unless options.key?(:symbolize_keys)

        MultiJSON.warn_deprecation_once(:symbolize_keys_option,
          "The :symbolize_keys option is deprecated and will be removed in v2.0. Use :symbolize_names instead.")

        new_opts = options.except(:symbolize_keys)
        new_opts[:symbolize_names] = options[:symbolize_keys] unless new_opts.key?(:symbolize_names)
        new_opts
      end

      # Removes the :adapter key from options for cache key
      #
      # Returns a shared frozen empty hash for the common no-options call
      # path so the hot path avoids allocating a fresh hash on every call.
      #
      # @api private
      # @param options [Hash, #to_h] original options (may be JSON::State or similar)
      # @return [Hash] frozen options without :adapter key
      def strip_adapter_key(options)
        options = options.to_h unless options.is_a?(Hash)
        return Options::EMPTY_OPTIONS if options.empty? || (options.size == 1 && options.key?(:adapter))

        options.except(:adapter).freeze
      end
    end
  end
end
