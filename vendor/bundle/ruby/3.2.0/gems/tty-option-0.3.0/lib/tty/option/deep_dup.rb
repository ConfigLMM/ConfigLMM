# frozen_string_literal: true

module TTY
  module Option
    # Responsible for deep copying an object
    #
    # @api private
    module DeepDup
      NONDUPLICATABLE = [
        Symbol, TrueClass, FalseClass, NilClass, Numeric, Method, UnboundMethod
      ].freeze

      # Deep copy an object
      #
      # @example
      #   DeepDeup.deep_dup({foo: {bar: [1, 2]}})
      #
      # @param [Object] object
      #   the object to deep copy
      # @param [Hash] cache
      #   the cache of copied objects
      #
      # @return [Object]
      #
      # @api public
      def self.deep_dup(object, cache = {})
        cache[object.object_id] ||=
          case object
          when *NONDUPLICATABLE then object
          when Array then deep_dup_array(object, cache)
          when Hash  then deep_dup_hash(object, cache)
          else object.dup
          end
      end

      # Deep copy an array
      #
      # @param [Array] object
      #   the array object to deep copy
      # @param [Hash] cache
      #   the cache of copied objects
      #
      # @return [Array]
      #
      # @api private
      def self.deep_dup_array(object, cache)
        object.each_with_object(cache[object.object_id] = []) do |val, array|
          array << deep_dup(val, cache)
        end
      end
      private_class_method :deep_dup_array

      # Deep copy a hash
      #
      # @param [Hash] object
      #   the hash object to deep copy
      # @param [Hash] cache
      #   the cache of copied objects
      #
      # @return [Hash]
      #
      # @api private
      def self.deep_dup_hash(object, cache)
        object.each_with_object(cache[object.object_id] = {}) do |(k, v), hash|
          hash[deep_dup(k, cache)] = deep_dup(v, cache)
        end
      end
      private_class_method :deep_dup_hash
    end # DeepDup
  end # Option
end # TTY
