# frozen_string_literal: true

module MultiJSON
  # Raised when an adapter cannot be loaded or is not recognized
  #
  # @api public
  class AdapterError < ArgumentError
    # Create a new AdapterError
    #
    # @api public
    # @param message [String, nil] error message
    # @param cause [Exception, nil] the original exception
    # @return [AdapterError] new error instance
    # @example
    #   AdapterError.new("Unknown adapter", cause: original_error)
    def initialize(message = nil, cause: nil)
      super(message)
      set_backtrace(cause.backtrace) if cause
    end

    # Build an AdapterError from an original exception
    #
    # The original exception's class name is included in the message
    # so a downstream consumer reading just the AdapterError can tell
    # whether the underlying failure was a `LoadError`, an
    # `ArgumentError` from the spec validator, or some other class
    # without having to look at `error.cause` separately.
    #
    # @api public
    # @param original_exception [Exception] the original load error
    # @return [AdapterError] new error with formatted message
    # @example
    #   AdapterError.build(LoadError.new("cannot load such file"))
    def self.build(original_exception)
      new(
        "Did not recognize your adapter specification " \
        "(#{original_exception.class}: #{original_exception.message}).",
        cause: original_exception
      )
    end
  end
end
