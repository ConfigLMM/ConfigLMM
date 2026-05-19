# frozen_string_literal: true

module TTY
  module Option
    class Section
      attr_accessor :name, :content

      def initialize(name, content = [])
        @name = name
        @content = content
      end

      def to_a
        [name, content]
      end

      def empty?
        content.empty?
      end

      def to_s
        content
      end
    end # Section
  end # Option
end # TTY
