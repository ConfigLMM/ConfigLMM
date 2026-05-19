# frozen_string_literal: true

module MultiJSON
  # Thread-safe bounded cache for merged options hashes
  #
  # Caches are separated for load and dump operations. Each cache is
  # bounded to prevent unbounded memory growth when options are
  # generated dynamically. The ``Store`` backend is chosen at load time
  # based on ``RUBY_ENGINE``: JRuby uses Concurrent::Map (shipped as a
  # runtime dependency of the java-platform gem); MRI and TruffleRuby
  # use a Hash guarded by a Mutex.
  #
  # @api private
  module OptionsCache
    # Default bound on the number of cached entries per store. Applications
    # that dynamically generate many distinct option hashes can raise this
    # via {.max_cache_size=}.
    DEFAULT_MAX_CACHE_SIZE = 1000

    class << self
      # Get the dump options cache
      #
      # @api private
      # @return [Store] dump cache store
      attr_reader :dump

      # Get the load options cache
      #
      # @api private
      # @return [Store] load cache store
      attr_reader :load

      # Maximum number of entries per cache store
      #
      # Applies to both the dump and load caches. Existing entries are
      # left in place until normal eviction trims them below a lowered
      # limit; call {.reset} if you need to evict immediately.
      #
      # @api public
      # @return [Integer] current cache size limit
      # @example
      #   MultiJSON::OptionsCache.max_cache_size = 5000
      #   MultiJSON::OptionsCache.max_cache_size  #=> 5000
      attr_reader :max_cache_size

      # Set the maximum number of entries per cache store
      #
      # @api public
      # @param value [Integer] positive entry cap
      # @return [Integer] the validated value
      # @raise [ArgumentError] when value is not a positive Integer
      # @example
      #   MultiJSON::OptionsCache.max_cache_size = 5000
      def max_cache_size=(value)
        raise ArgumentError, "max_cache_size must be a positive Integer, got #{value.inspect}" unless Integer === value && value.positive? # rubocop:disable Style/CaseEquality

        @max_cache_size = value
      end

      # Reset both caches
      #
      # @api private
      # @return [void]
      def reset
        @dump = Store.new
        @load = Store.new
      end
    end

    self.max_cache_size = DEFAULT_MAX_CACHE_SIZE
  end
end

module MultiJSON
  module OptionsCache
    # Dynamic require path so MRI (mutex_store) and JRuby
    # (concurrent_store) execute the same physical line, avoiding a
    # dead-branch ``require_relative`` that would otherwise drop
    # JRuby's line coverage below 100%.
    BACKENDS = {"jruby" => "concurrent_store"}.freeze
    private_constant :BACKENDS
  end
end

require_relative "options_cache/#{MultiJSON::OptionsCache.send(:const_get, :BACKENDS).fetch(RUBY_ENGINE, "mutex_store")}"
MultiJSON::OptionsCache.reset
