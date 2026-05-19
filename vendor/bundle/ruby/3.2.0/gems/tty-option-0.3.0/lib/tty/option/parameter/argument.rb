# frozen_string_literal: true

require_relative "../parameter"

module TTY
  module Option
    class Parameter
      class Argument < Parameter
        # Required by default unless the arity allows any
        #
        # @api public
        def required?
          @settings.fetch(:required) { arity != -1 }
        end
      end
    end # Parameter
  end # Option
end # TTY
