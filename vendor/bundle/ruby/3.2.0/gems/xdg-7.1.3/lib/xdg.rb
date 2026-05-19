# frozen_string_literal: true

require "xdg/cache"
require "xdg/config"
require "xdg/data"
require "xdg/environment"
require "xdg/pair"
require "xdg/paths/combined"
require "xdg/paths/directory"
require "xdg/paths/home"
require "xdg/state"

# Main namespace.
module XDG
  DELIMITER = "="

  def self.new = Environment.new
end
