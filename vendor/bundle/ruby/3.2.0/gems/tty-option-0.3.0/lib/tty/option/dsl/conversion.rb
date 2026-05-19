# frozen_string_literal: true

module TTY
  module Option
    module DSL
      module Conversion
        def map_of(type)
          :"#{type}_map"
        end

        def list_of(type)
          :"#{type}_list"
        end
      end # Convert
    end # DSL
  end # Option
end # TTY
