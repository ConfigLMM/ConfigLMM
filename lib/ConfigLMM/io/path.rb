# frozen_string_literal: true

require 'pathname'
require_relative 'source'

module ConfigLMM
    module IO
        class Path < Source
            def initialize(path, parent = nil)
                @Path = path.is_a?(Pathname) ? path : Pathname.new(path)
                super(parent)
            end

            def name
                @Path.basename.to_s
            end

            def basename
                @Path.basename(@Path.extname).to_s
            end

            def dirname
                parent.basename unless parent.nil?
            end

            def self.isConfig?(path)
                return false unless File.extname(path) == '.yaml'
                File.basename(path, '.yaml').end_with?('.mm')
            end

            def to_s
                @Path.to_s
            end

            def ==(other)
                self.to_s == other.to_s
            end

            def lookupParent(path)
                if path.start_with?(self.to_s)
                    self
                else
                    parent&.lookupParent(path) or raise "Didn't find parent for #{path}"
                end
            end
        end
    end
end
