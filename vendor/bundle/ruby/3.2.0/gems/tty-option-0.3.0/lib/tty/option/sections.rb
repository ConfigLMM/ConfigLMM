# frozen_string_literal: true

require "forwardable"

require_relative "section"

module TTY
  module Option
    class Sections
      include Enumerable
      extend Forwardable

      def_delegators :@sections, :size, :to_a

      def initialize
        @sections = []
      end

      def [](name)
        @sections.find { |s| s.name == name }
      end

      def add(name, content)
        @sections << Section.new(name, content)
      end

      def add_before(name, sect_name, sect_content)
        @sections.insert(find_index(name), Section.new(sect_name, sect_content))
      end

      def add_after(name, sect_name, sect_content)
        @sections.insert(find_index(name) + 1, Section.new(sect_name, sect_content))
      end

      def replace(name, content)
        self[name].content = content
      end

      def delete(*names)
        @sections.delete_if { |s| names.include?(s.name) }
      end

      def each(&block)
        @sections.each(&block)
      end

      private

      def find_index(name)
        index = @sections.index { |sect| sect.name == name }
        return index if index
        raise ArgumentError, "There is no section named: #{name.inspect}"
      end
    end # Section
  end # Option
end # TTY
