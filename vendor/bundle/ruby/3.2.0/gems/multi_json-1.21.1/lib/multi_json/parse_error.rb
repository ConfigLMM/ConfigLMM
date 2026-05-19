# frozen_string_literal: true

module MultiJSON
  # Raised when JSON parsing fails
  #
  # Wraps the underlying adapter's parse error with the original input
  # data, plus best-effort line and column extraction from the adapter's
  # error message. Line/column are populated for adapters that include
  # them in their messages (Oj, the json gem) and remain nil for
  # adapters that don't (Yajl, fast_jsonparser).
  #
  # @api public
  class ParseError < StandardError
    # Regex that matches the "line N[, ]column M" fragment inside an
    # adapter error message. The separator between line and column is
    # permissive — Oj emits ``"line 1, column 3"`` while the json gem
    # emits ``"line 1 column 2"`` — so ``[,\s]+`` covers both. Column
    # is optional so messages like ``"at line 5"`` still yield a line.
    LOCATION_PATTERN = /line\s+(\d+)(?:[,\s]+column\s+(\d+))?/i
    private_constant :LOCATION_PATTERN

    # The input string that failed to parse
    #
    # @api public
    # @return [String, nil] the original input data
    # @example
    #   error.data  #=> "{invalid json}"
    attr_reader :data

    # The 1-based line number reported by the adapter
    #
    # @api public
    # @return [Integer, nil] line number, or nil if the adapter's message
    #   did not include one
    # @example
    #   error.line  #=> 1
    attr_reader :line

    # The 1-based column reported by the adapter
    #
    # @api public
    # @return [Integer, nil] column number, or nil if the adapter's message
    #   did not include one
    # @example
    #   error.column  #=> 3
    attr_reader :column

    # Create a new ParseError
    #
    # @api public
    # @param message [String, nil] error message
    # @param data [String, nil] the input that failed to parse
    # @param cause [Exception, nil] the original exception
    # @return [ParseError] new error instance
    # @example
    #   ParseError.new("unexpected token at line 1 column 2", data: "{}")
    def initialize(message = nil, data: nil, cause: nil)
      super(message)
      @data = data
      match = location_match(message)
      @line = match && Integer(match[1])
      @column = match && match[2] && Integer(match[2])
      set_backtrace(cause.backtrace) if cause
    end

    # Build a ParseError from an original exception
    #
    # @api public
    # @param original_exception [Exception] the adapter's parse error
    # @param data [String] the input that failed to parse
    # @return [ParseError] new error with formatted message
    # @example
    #   ParseError.build(JSON::ParserError.new("..."), "{bad json}")
    def self.build(original_exception, data)
      new(original_exception.message, data: data, cause: original_exception)
    end

    private

    # Match an adapter error message against the line/column pattern
    #
    # Adapter error messages sometimes embed bytes from the failing
    # input (e.g., the json gem's ``"invalid byte sequence in UTF-8"``
    # error). The pattern is pure ASCII so it's compatible with any
    # encoding, but a UTF-8 string with invalid bytes still trips the
    # regex engine — ``String#scrub`` replaces those bytes so the
    # match can proceed. Strings in binary (ASCII-8BIT) or any valid
    # encoding pass through scrub untouched.
    #
    # @api private
    # @param message [String, nil] the adapter's error message
    # @return [MatchData, nil] the regex match, or nil if no message or
    #   no location fragment was found
    def location_match(message)
      return unless message

      LOCATION_PATTERN.match(message.scrub)
    end
  end

  # Legacy aliases for backward compatibility
  DecodeError = LoadError = ParseError
end
