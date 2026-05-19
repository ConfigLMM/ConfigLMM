# frozen_string_literal: true

module TTY
  module Option
    class Parameter
      class Environment < Parameter
        def default_name
          key.to_s.tr("-", "_").upcase
        end

        # Compare this env var to another
        #
        # @api public
        def <=>(other)
          name <=> other.name
        end
      end
    end # Parameter
  end # Option
end # TTY
