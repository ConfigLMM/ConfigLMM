# frozen_string_literal: true

require "pathname"

module XDG
  module Paths
    # The combined home and directory paths.
    class Combined
      def initialize initial_home, initial_directories
        @initial_home = initial_home
        @initial_directories = initial_directories
      end

      def home = initial_home.dynamic

      def directories = initial_directories.dynamic

      def all = directories.prepend(*home)

      def inspect = [initial_home.inspect, initial_directories.inspect].reject(&:empty?).join " "

      private

      attr_reader :initial_home, :initial_directories
    end
  end
end
