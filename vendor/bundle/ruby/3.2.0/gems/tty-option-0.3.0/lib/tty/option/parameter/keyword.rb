# frozen_string_literal: true

require_relative "../parameter"

module TTY
  module Option
    class Parameter
      class Keyword < Parameter
        def required?
          @settings.fetch(:required) { false }
        end
      end
    end # Parameter
  end # Option
end # TTY
