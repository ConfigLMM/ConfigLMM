# frozen_string_literal: true

module ConfigLMM
    module Framework
        module Registrator

            @BasePaths = []

            def self.addPath(basePath)
                @BasePaths << basePath
            end

            def self.registerAll(logger)
                @BasePaths.each do |basePath|
                    self.register(basePath, logger)
                end
            end

            protected

            def self.register(basePath, logger)
                Dir.glob(basePath + 'Plugins/**/**.lmm.rb').each do |file|
                    require file
                rescue ScriptError => error
                    logger.error("Failed to load #{File.realdirpath(file)}\n", error)
                    raise error
                end
            end

        end
    end
end
