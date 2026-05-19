# frozen_string_literal: true

module TTY
  module Option
    module DSL
      module Arity
        # @api public
        def one
          1
        end

        # @api public
        def two
          2
        end

        # Zero or more arity
        #
        # @api public
        def zero_or_more
          -1
        end
        alias any zero_or_more
        alias any_args zero_or_more

        # One or more arity
        #
        # @api public
        def one_or_more
          -2
        end

        # Two or more arity
        #
        # @api public
        def two_or_more
          -3
        end

        # At last number values for arity
        #
        # @api public
        def at_least(number)
          -number.to_i - 1
        end
      end # Arity
    end # DSL
  end # Option
end # TTY
