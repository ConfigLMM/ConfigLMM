# frozen_string_literal: true

# Deprecated public API kept around for one major release
#
# Each method here emits a one-time deprecation warning on first call and
# delegates to its current-API counterpart. The whole file is loaded by
# {MultiJSON} so the deprecation surface stays out of the main module
# definition.
#
# @api private
module MultiJSON
  class << self
    private

    # Define a deprecated alias that delegates to a new method name
    #
    # The generated singleton method emits a one-time deprecation
    # warning naming the replacement, then forwards all positional and
    # keyword arguments plus any block to ``replacement``. Used for the
    # ``load`` / ``dump`` / ``decode`` / ``encode`` / ``engine*`` /
    # ``with_engine`` / ``default_engine`` aliases that are scheduled
    # for removal in v2.0.
    #
    # @api private
    # @param name [Symbol] deprecated method name
    # @param replacement [Symbol] current-API method to delegate to
    # @return [Symbol] the defined method name
    # @example
    #   deprecate_alias :load, :parse
    def deprecate_alias(name, replacement)
      message = "MultiJSON.#{name} is deprecated and will be removed in v2.0. Use MultiJSON.#{replacement} instead."
      define_singleton_method(name) do |*args, **kwargs, &block|
        warn_deprecation_once(name, message)
        public_send(replacement, *args, **kwargs, &block)
      end
    end

    # Define a deprecated method whose body needs custom delegation
    #
    # Used for the ``default_options`` / ``default_options=`` pair
    # whose body fans out to multiple replacement methods, and for the
    # ``cached_options`` / ``reset_cached_options!`` no-op stubs that
    # have no current-API counterpart at all. The block runs in its
    # own lexical ``self``, which is the ``MultiJSON`` module since
    # every call site sits inside ``module MultiJSON`` below.
    #
    # @api private
    # @param name [Symbol] deprecated method name
    # @param message [String] warning to emit on first call
    # @yield body to evaluate after the warning
    # @return [Symbol] the defined method name
    # @example
    #   deprecate_method(:cached_options, "...") { nil }
    def deprecate_method(name, message, &body)
      define_singleton_method(name) do |*args, **kwargs|
        warn_deprecation_once(name, message)
        body.call(*args, **kwargs)
      end
    end
  end

  deprecate_alias :load, :parse
  deprecate_alias :dump, :generate
  deprecate_alias :decode, :parse
  deprecate_alias :encode, :generate
  deprecate_alias :engine, :adapter
  deprecate_alias :engine=, :adapter=
  deprecate_alias :default_engine, :default_adapter
  deprecate_alias :with_engine, :with_adapter

  deprecate_method(
    :default_options=,
    "MultiJSON.default_options setter is deprecated\n" \
    "Use MultiJSON.parse_options and MultiJSON.generate_options instead"
  ) { |value| self.parse_options = self.generate_options = value }

  deprecate_method(
    :default_options,
    "MultiJSON.default_options is deprecated\n" \
    "Use MultiJSON.parse_options or MultiJSON.generate_options instead"
  ) { parse_options }

  %i[cached_options reset_cached_options!].each do |name|
    deprecate_method(name, "MultiJSON.#{name} method is deprecated and no longer used.") { nil }
  end

  private

  # Instance-method delegate for the deprecated default_options setter
  #
  # @api private
  # @deprecated Use {MultiJSON.load_options=} and {MultiJSON.dump_options=} instead
  # @param value [Hash] options hash
  # @return [Hash] the options hash
  # @example
  #   class Foo; include MultiJSON; end
  #   Foo.new.send(:default_options=, symbolize_keys: true)
  def default_options=(value)
    MultiJSON.default_options = value
  end

  # Instance-method delegate for the deprecated default_options getter
  #
  # @api private
  # @deprecated Use {MultiJSON.load_options} or {MultiJSON.dump_options} instead
  # @return [Hash] the current load options
  # @example
  #   class Foo; include MultiJSON; end
  #   Foo.new.send(:default_options)
  def default_options
    MultiJSON.default_options
  end
end
