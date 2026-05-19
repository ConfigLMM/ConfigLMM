# frozen_string_literal: true

module MultiJSON
  # Mixin providing configurable parse/generate options
  #
  # Supports static hashes or dynamic callables (procs/lambdas).
  # Extended by both MultiJSON (global options) and Adapter classes.
  #
  # @api private
  module Options
    # Steep needs an inline `#:` annotation here because `{}.freeze`
    # would be inferred as `Hash[untyped, untyped]` and trip
    # `UnannotatedEmptyCollection`. The annotation requires
    # `Hash.new.freeze` (not the `{}.freeze` rubocop would prefer)
    # because the `#:` cast only applies to method-call results.
    EMPTY_OPTIONS = Hash.new.freeze #: options # rubocop:disable Style/EmptyLiteral

    # Set options for parse operations
    #
    # @api public
    # @param options [Hash, Proc] options hash or callable
    # @return [Hash, Proc] the options
    # @example
    #   MultiJSON.parse_options = {symbolize_keys: true}
    def parse_options=(options)
      OptionsCache.reset
      @parse_options = options
    end

    # Set options for generate operations
    #
    # @api public
    # @param options [Hash, Proc] options hash or callable
    # @return [Hash, Proc] the options
    # @example
    #   MultiJSON.generate_options = {pretty: true}
    def generate_options=(options)
      OptionsCache.reset
      @generate_options = options
    end

    # Get options for parse operations
    #
    # When `@parse_options` is a callable (proc/lambda), it's invoked
    # with `args` as positional arguments — typically the merged
    # options hash from `Adapter.merged_parse_options`. When it's a
    # plain hash, `args` is ignored.
    #
    # @api public
    # @param args [Array<Object>] forwarded to the callable, ignored otherwise
    # @return [Hash] resolved options hash
    # @example
    #   MultiJSON.parse_options  #=> {}
    def parse_options(*args)
      resolve_options(@parse_options, *args) || default_parse_options
    end

    # Get options for generate operations
    #
    # @api public
    # @param args [Array<Object>] forwarded to the callable, ignored otherwise
    # @return [Hash] resolved options hash
    # @example
    #   MultiJSON.generate_options  #=> {}
    def generate_options(*args)
      resolve_options(@generate_options, *args) || default_generate_options
    end

    # Get default parse options
    #
    # @api private
    # @return [Hash] frozen empty hash
    def default_parse_options
      Concurrency.synchronize(:default_options) { @default_parse_options ||= EMPTY_OPTIONS }
    end

    # Get default generate options
    #
    # @api private
    # @return [Hash] frozen empty hash
    def default_generate_options
      Concurrency.synchronize(:default_options) { @default_generate_options ||= EMPTY_OPTIONS }
    end

    # Set options for parse operations
    #
    # @api public
    # @deprecated Use {#parse_options=} instead. Will be removed in v2.0.
    # @param options [Hash, Proc] options hash or callable
    # @return [Hash, Proc] the options
    # @example
    #   MultiJSON.load_options = {symbolize_keys: true}
    def load_options=(options)
      MultiJSON.warn_deprecation_once(:load_options=,
        "MultiJSON.load_options= is deprecated and will be removed in v2.0. Use MultiJSON.parse_options= instead.")
      self.parse_options = options
    end

    # Set options for generate operations
    #
    # @api public
    # @deprecated Use {#generate_options=} instead. Will be removed in v2.0.
    # @param options [Hash, Proc] options hash or callable
    # @return [Hash, Proc] the options
    # @example
    #   MultiJSON.dump_options = {pretty: true}
    def dump_options=(options)
      MultiJSON.warn_deprecation_once(:dump_options=,
        "MultiJSON.dump_options= is deprecated and will be removed in v2.0. Use MultiJSON.generate_options= instead.")
      self.generate_options = options
    end

    # Get options for parse operations
    #
    # @api public
    # @deprecated Use {#parse_options} instead. Will be removed in v2.0.
    # @param args [Array<Object>] forwarded to the callable, ignored otherwise
    # @return [Hash] resolved options hash
    # @example
    #   MultiJSON.load_options  #=> {}
    def load_options(*args)
      MultiJSON.warn_deprecation_once(:load_options,
        "MultiJSON.load_options is deprecated and will be removed in v2.0. Use MultiJSON.parse_options instead.")
      parse_options(*args)
    end

    # Get options for generate operations
    #
    # @api public
    # @deprecated Use {#generate_options} instead. Will be removed in v2.0.
    # @param args [Array<Object>] forwarded to the callable, ignored otherwise
    # @return [Hash] resolved options hash
    # @example
    #   MultiJSON.dump_options  #=> {}
    def dump_options(*args)
      MultiJSON.warn_deprecation_once(:dump_options,
        "MultiJSON.dump_options is deprecated and will be removed in v2.0. Use MultiJSON.generate_options instead.")
      generate_options(*args)
    end

    # Get default parse options
    #
    # @api private
    # @deprecated Use {#default_parse_options} instead. Will be removed in v2.0.
    # @return [Hash] frozen empty hash
    def default_load_options
      default_parse_options
    end

    # Get default generate options
    #
    # @api private
    # @deprecated Use {#default_generate_options} instead. Will be removed in v2.0.
    # @return [Hash] frozen empty hash
    def default_dump_options
      default_generate_options
    end

    private

    # Resolves options from a hash or callable
    #
    # @api private
    # @param options [Hash, Proc, nil] options configuration
    # @param args [Array<Object>] arguments forwarded to a callable provider
    # @return [Hash, nil] resolved options hash
    def resolve_options(options, *args)
      if options.respond_to?(:call)
        # @type var options: options_proc
        return invoke_callable(options, *args)
      end

      options.to_hash if options.respond_to?(:to_hash)
    end

    # Invokes a callable options provider
    #
    # @api private
    # @param callable [Proc] options provider
    # @param args [Array<Object>] arguments forwarded when the callable is non-arity-zero
    # @return [Hash] options returned by the callable
    def invoke_callable(callable, *args)
      callable.arity.zero? ? callable.call : callable.call(*args)
    end
  end
end
