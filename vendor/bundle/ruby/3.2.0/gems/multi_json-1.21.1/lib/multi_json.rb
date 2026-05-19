# frozen_string_literal: true

require_relative "multi_json/concurrency"
require_relative "multi_json/options"
require_relative "multi_json/version"
require_relative "multi_json/adapter_error"
require_relative "multi_json/parse_error"
require_relative "multi_json/options_cache"
require_relative "multi_json/adapter_selector"

# A unified interface for JSON libraries in Ruby
#
# MultiJSON allows swapping between JSON backends without changing your code.
# It auto-detects available JSON libraries and uses the fastest one available.
#
# ## Method-definition patterns
#
# The current public API uses two patterns, each chosen for a specific reason:
#
# 1. ``module_function`` creates both a class method and a private instance
#    method from a single ``def``. This is used for the hot-path API
#    (``adapter``, ``use``, ``adapter=``, ``parse``, ``generate``,
#    ``current_adapter``) so that both ``MultiJSON.parse(...)`` and legacy
#    ``Class.new { include MultiJSON }.new.send(:parse, ...)`` invocations
#    work through the same body. The instance versions are re-publicized
#    below so YARD renders them as part of the public API.
# 2. ``def self.foo`` creates only a singleton method, giving mutation
#    testing a single canonical definition to target. This is used for
#    {.with_adapter}, which needs precise mutation coverage of its
#    fiber-local save/restore logic.
#
# Deprecated public API (``decode``, ``encode``, ``engine``, ``load``,
# ``dump``, etc.) lives in {file:lib/multi_json/deprecated.rb} so this
# file stays focused on the current surface.
#
# @example Basic usage
#   MultiJSON.parse('{"foo":"bar"}')  #=> {"foo" => "bar"}
#   MultiJSON.generate({foo: "bar"})  #=> '{"foo":"bar"}'
#
# @example Specifying an adapter
#   MultiJSON.use(:oj)
#   MultiJSON.parse('{"foo":"bar"}', adapter: :json_gem)
#
# @api public
module MultiJSON
  extend Options
  extend AdapterSelector

  # Tracks which deprecation warnings have already been emitted so each one
  # fires at most once per process. Stored as a Set rather than a Hash so
  # presence checks have unambiguous semantics for mutation tests.
  DEPRECATION_WARNINGS_SHOWN = Set.new
  private_constant :DEPRECATION_WARNINGS_SHOWN

  # Emit a deprecation warning at most once per process for the given key
  #
  # Defined as a singleton method (rather than via module_function) so
  # there is exactly one definition for mutation tests to target.
  # Public so the deprecated ``load_options`` / ``dump_options``
  # aliases on the {Options} mixin can invoke it without routing
  # through ``MultiJSON.send(...)``.
  #
  # The warning is tagged with the ``:deprecated`` category so callers
  # can silence the whole set with ``Warning[:deprecated] = false`` or
  # surface it via ``ruby -W:deprecated`` — the standard Ruby idiom for
  # library deprecations since 2.7.
  #
  # @api private
  # @param key [Symbol] identifier for the deprecation (typically the method name)
  # @param message [String] warning message to emit on first call
  # @return [void]
  # @example
  #   MultiJSON.warn_deprecation_once(:foo, "MultiJSON.foo is deprecated")
  def self.warn_deprecation_once(key, message)
    Concurrency.synchronize(:deprecation_warnings) do
      return if DEPRECATION_WARNINGS_SHOWN.include?(key)

      Kernel.warn(message, category: :deprecated)
      DEPRECATION_WARNINGS_SHOWN.add(key)
    end
  end

  # Resolve the ``ParseError`` constant for an adapter class
  #
  # The result is memoized on the adapter class itself in a
  # ``@_multi_json_parse_error`` ivar so subsequent ``MultiJSON.load``
  # calls skip the constant lookup entirely. The lookup is performed
  # with ``inherit: false`` so a stray top-level ``::ParseError``
  # constant in the host process is correctly ignored on every
  # supported Ruby implementation — TruffleRuby's ``::`` operator
  # walks the ancestor chain and would otherwise pick up the top-level
  # constant. Custom adapters that don't define their own
  # ``ParseError`` get a clear {AdapterError} instead of the bare
  # ``NameError`` Ruby would raise from the rescue clause.
  #
  # @api private
  # @param adapter_class [Class] adapter class to inspect
  # @return [Class] the adapter's ParseError class
  # @raise [AdapterError] when the adapter doesn't define ParseError
  def self.parse_error_class_for(adapter_class)
    cached = adapter_class.instance_variable_get(:@_multi_json_parse_error)
    return cached if cached

    resolved = adapter_class.const_get(:ParseError, false)
    adapter_class.instance_variable_set(:@_multi_json_parse_error, resolved)
  rescue NameError
    raise AdapterError, "Adapter #{adapter_class} must define a ParseError constant"
  end

  # ===========================================================================
  # Public API (module_function: class + private instance method)
  # ===========================================================================

  # @!visibility private
  module_function

  # Returns the current adapter class
  #
  # Honors a fiber-local override set by {.with_adapter} so concurrent
  # blocks observe their own adapter without clobbering the process-wide
  # default. Falls back to the process default when no override is set.
  #
  # @api public
  # @return [Class] the current adapter class
  # @example
  #   MultiJSON.adapter  #=> MultiJSON::Adapters::Oj
  def adapter
    override = Fiber[:multi_json_adapter]
    return override if override

    @adapter ||= use(nil)
  end

  # Sets the adapter to use for JSON operations
  #
  # The merged-options cache is only reset when the new adapter loads
  # successfully. A failed ``use(:nonexistent)`` leaves the cache in
  # place so the previously-active adapter keeps its cached entries.
  #
  # @api public
  # @param new_adapter [Symbol, String, Module, nil] adapter specification
  # @return [Class] the loaded adapter class
  # @example
  #   MultiJSON.use(:oj)
  def use(new_adapter)
    loaded = load_adapter(new_adapter)
    Concurrency.synchronize(:adapter) do
      OptionsCache.reset
      @adapter = loaded
    end
  end

  # Sets the adapter to use for JSON operations
  #
  # @api public
  # @return [Class] the loaded adapter class
  # @example
  #   MultiJSON.adapter = :json_gem
  alias_method :adapter=, :use
  module_function :adapter=

  # Parses a JSON string into a Ruby object
  #
  # Returns ``nil`` for ``nil``, empty, and whitespace-only inputs
  # instead of raising. Pass an explicit non-blank string if you want
  # to surface a {ParseError} for empty payloads at the call site.
  #
  # @api public
  # @param string [String, #read] JSON string or IO-like object
  # @param options [Hash] parsing options (adapter-specific)
  # @return [Object, nil] parsed Ruby object, or nil for blank input
  # @raise [ParseError] if parsing fails
  # @raise [AdapterError] if the adapter doesn't define a ``ParseError`` constant
  # @example
  #   MultiJSON.parse('{"foo":"bar"}')  #=> {"foo" => "bar"}
  #   MultiJSON.parse("")               #=> nil
  #   MultiJSON.parse("   \n")          #=> nil
  def parse(string, options = {})
    adapter_class = current_adapter(options)
    parse_error_class = MultiJSON.parse_error_class_for(adapter_class)
    begin
      adapter_class.load(string, options)
    rescue parse_error_class => e
      raise ParseError.build(e, string)
    end
  end

  # Returns the adapter to use for the given options
  #
  # ``nil`` is accepted as a no-options sentinel — explicit
  # ``current_adapter(nil)`` calls fall through to the process default
  # adapter without raising.
  #
  # @api public
  # @param options [Hash, nil] options that may contain :adapter key, or
  #   nil to use the process default
  # @return [Class] adapter class
  # @example
  #   MultiJSON.current_adapter(adapter: :oj)  #=> MultiJSON::Adapters::Oj
  def current_adapter(options = {})
    options ||= Options::EMPTY_OPTIONS
    adapter_override = options[:adapter]
    adapter_override ? load_adapter(adapter_override) : adapter
  end

  # Serializes a Ruby object to a JSON string
  #
  # @api public
  # @param object [Object] object to serialize
  # @param options [Hash] serialization options (adapter-specific)
  # @return [String] JSON string
  # @example
  #   MultiJSON.generate({foo: "bar"})  #=> '{"foo":"bar"}'
  def generate(object, options = {})
    current_adapter(options).dump(object, options)
  end

  # Re-publicize the instance versions of the module_function methods so
  # YARD/yardstick render them as part of the public API and legacy
  # ``include MultiJSON`` consumers can call them without ``.send``.
  public :adapter, :use, :adapter=, :parse, :current_adapter, :generate

  # ===========================================================================
  # Public API (def self.foo: singleton-only, for mutation-test precision)
  # ===========================================================================

  # Executes a block using the specified adapter
  #
  # Defined as a singleton method so mutation testing has exactly one
  # definition to target. The override is stored in fiber-local storage
  # so concurrent fibers and threads each see their own adapter without
  # racing on a shared module variable; nested calls save and restore
  # the previous fiber-local value.
  #
  # @api public
  # @param new_adapter [Symbol, String, Module] adapter to use
  # @yield block to execute with the temporary adapter
  # @return [Object] result of the block
  # @example
  #   MultiJSON.with_adapter(:json_gem) { MultiJSON.dump({}) }
  def self.with_adapter(new_adapter)
    previous_override = Fiber[:multi_json_adapter]
    Fiber[:multi_json_adapter] = load_adapter(new_adapter)
    yield
  ensure
    Fiber[:multi_json_adapter] = previous_override
  end

  # ===========================================================================
  # Private instance-method delegates for the singleton-only methods above
  # ===========================================================================

  private

  # Instance-method delegate for {MultiJSON.with_adapter}
  #
  # @api private
  # @param new_adapter [Symbol, String, Module] adapter to use
  # @yield block to execute with the temporary adapter
  # @return [Object] result of the block
  # @example
  #   class Foo; include MultiJSON; end
  #   Foo.new.send(:with_adapter, :json_gem) { ... }
  def with_adapter(new_adapter, &)
    MultiJSON.with_adapter(new_adapter, &)
  end
end

require_relative "multi_json/deprecated"

# Backward-compatible alias for the legacy ``MultiJson`` constant name
#
# Downstream code that still writes ``MultiJson.parse(...)`` or
# ``rescue MultiJson::ParseError`` continues to work, but emits a
# one-time deprecation warning pointing at ``MultiJSON``. Each public
# method on {MultiJSON} gets an explicit forwarder defined on this
# module, and constant access resolves via {.const_missing}, so both
# dotted calls and ``::`` constant lookups (including rescue clauses)
# route through the canonical module.
#
# @api public
# @deprecated Use {MultiJSON} (all-caps) instead. Will be removed in v2.0.
module MultiJson
  # Forward every public method MultiJSON exposes through an explicit
  # singleton method on the legacy MultiJson module, so callers that
  # capture the method as a Method object (``MultiJson.method(:load)``)
  # find this forwarder instead of falling back to inherited methods like
  # ``Kernel#load``. The earlier ``method_missing``-based shim left
  # ``MultiJson.method(:load)`` resolving to ``Kernel#load`` (because
  # ``Module#method`` doesn't consult ``method_missing``) and broke
  # libraries (Sawyer, Octokit, Danger) that capture decoders as Method
  # objects. Forwarding eagerly fixes the capture path while preserving
  # the one-time deprecation warning each call emits.
  (::MultiJSON.public_methods - ::Module.public_methods).each do |forwarded|
    define_singleton_method(forwarded) do |*args, **kwargs, &block|
      ::MultiJSON.warn_deprecation_once(:multi_json_constant,
        "The MultiJson constant is deprecated and will be removed in v2.0. Use MultiJSON instead.")
      ::MultiJSON.public_send(forwarded, *args, **kwargs, &block)
    end
  end

  class << self
    # Resolve missing constants to their {MultiJSON} counterparts
    #
    # Enables ``rescue MultiJson::ParseError`` and
    # ``MultiJson::Adapters::Oj`` to keep working during the
    # deprecation cycle.
    #
    # @api public
    # @param name [Symbol] constant name
    # @return [Object] the resolved constant from {MultiJSON}
    # @example
    #   MultiJson::ParseError  # returns MultiJSON::ParseError
    def const_missing(name)
      ::MultiJSON.warn_deprecation_once(:multi_json_constant,
        "The MultiJson constant is deprecated and will be removed in v2.0. Use MultiJSON instead.")
      ::MultiJSON.const_get(name)
    end
  end
end
