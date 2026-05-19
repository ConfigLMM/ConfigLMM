# frozen_string_literal: true

module XDG
  # A convenience wrapper to all XDG functionality.
  class Environment
    def initialize home: Paths::Home, directories: Paths::Directory, environment: ENV
      @cache = Cache.new(home:, directories:, environment:)
      @config = Config.new(home:, directories:, environment:)
      @data = Data.new(home:, directories:, environment:)
      @state = State.new home:, directories:, environment:
    end

    def cache_home = cache.home

    def config_home = config.home

    def config_dirs = config.directories

    def data_home = data.home

    def data_dirs = data.directories

    def state_home = state.home

    def inspect = [cache, config, data, state].map(&:inspect).join " "

    private

    attr_reader :cache, :config, :data, :state
  end
end
