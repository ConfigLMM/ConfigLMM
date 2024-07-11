# frozen_string_literal: true

module ConfigLMM
  class Command
    # Execute this command
    #
    # @api public
    def execute(*)
        raise(NotImplementedError, "#{self.class}##{__method__} must be implemented")
    end

    # A readable, structured and beautiful logging for the terminal
    #
    # @see http://www.rubydoc.info/gems/tty-logger
    #
    # @api public
    def logger
        if @Logger.nil?
            require 'tty-logger'
            @Logger = TTY::Logger.new do |config|
                yield(config)
            end
        end
        @Logger
    end

    # The external commands runner
    #
    # @see http://www.rubydoc.info/gems/tty-command
    #
    # @api public
    def command(**options)
        if @Command.nil?
            require 'tty-command'
            @Command = TTY::Command.new(options)
        end
        @Command
    end

    # The interactive prompt
    #
    # @see http://www.rubydoc.info/gems/tty-prompt
    #
    # @api public
    def prompt
        if @Prompt.nil?
            require 'tty-prompt'
            @Prompt = TTY::Prompt.new
        end
        @Prompt
    end
  end
end
