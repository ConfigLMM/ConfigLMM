# frozen_string_literal: true

require "forwardable"
require "xdg/pair"

module XDG
  # Provides configuration support.
  class Config
    extend Forwardable

    HOME_PAIR = Pair["XDG_CONFIG_HOME", ".config"].freeze
    DIRS_PAIR = Pair["XDG_CONFIG_DIRS", "/etc/xdg"].freeze

    delegate %i[home directories all inspect] => :combined

    def initialize home: Paths::Home, directories: Paths::Directory, environment: ENV
      @combined = Paths::Combined.new home.new(HOME_PAIR, environment),
                                      directories.new(DIRS_PAIR, environment)
    end

    private

    attr_reader :combined
  end
end
