# frozen_string_literal: true

module MultiJSON
  module OptionsCache
    # Thread-safe cache store backed by a Hash guarded by a Mutex
    #
    # Used on MRI and TruffleRuby, where a runtime dependency on
    # concurrent-ruby would be overkill: the GVL on MRI makes single
    # lookups atomic, and locking on both reads and writes keeps the
    # small perf cost predictable across engines without adding a
    # runtime dependency.
    #
    # @api private
    class Store
      # Create a new cache store
      #
      # @api private
      # @return [Store] new store instance
      def initialize
        @cache = {}
        @mutex = Mutex.new
      end

      # Clear all cached entries
      #
      # Held under the mutex because TruffleRuby (which also uses this
      # backend via the ruby-platform gem) has true parallelism: a
      # concurrent ``fetch`` racing with ``Hash#clear`` could corrupt
      # iteration in a way that MRI's GVL would otherwise prevent.
      #
      # @api private
      # @return [void]
      def reset
        @mutex.synchronize { @cache.clear }
      end

      # Fetch a value from cache or compute it
      #
      # When called with a block, returns the cached value or computes a
      # new one. When called without a block, returns the cached value or
      # the supplied default if the key is missing. Nil cached values are
      # preserved because ``Hash#fetch`` only falls through to the default
      # block when the key is truly missing. The ``block_given?`` check
      # is hoisted out of the mutex so the no-block read path runs the
      # check once per call instead of once inside the critical section.
      #
      # @api private
      # @param key [Object] cache key
      # @param default [Object] value to return when key is missing and no
      #   block is given
      # @yield block to compute value if not cached
      # @return [Object] cached, computed, or default value
      def fetch(key, default = nil)
        return @mutex.synchronize { @cache.fetch(key) { default } } unless block_given?

        @mutex.synchronize do
          @cache.fetch(key) do
            @cache.shift if @cache.size >= OptionsCache.max_cache_size
            @cache[key] = yield
          end
        end
      end
    end
  end
end
