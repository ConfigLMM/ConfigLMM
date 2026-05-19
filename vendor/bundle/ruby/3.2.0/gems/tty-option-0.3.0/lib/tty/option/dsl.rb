# frozen_string_literal: true

require "forwardable"

require_relative "dsl/arity"
require_relative "dsl/conversion"
require_relative "inflection"
require_relative "parameter/argument"
require_relative "parameter/environment"
require_relative "parameter/keyword"
require_relative "parameter/option"
require_relative "parameters"
require_relative "usage"

module TTY
  module Option
    module DSL
      include Arity
      include Conversion
      include Inflection
      extend Forwardable

      def_delegators :usage, :command, :banner, :desc, :program,
                             :header, :footer, :example, :no_command

      # Holds the usage information
      #
      # @api public
      def usage(**properties, &block)
        @usage ||= Usage.create(**properties, &block).tap do |usage|
                     unless usage.command? || usage.no_command?
                       usage.command(dasherize(demodulize(self.name)))
                     end
                   end
      end

      # Specify an argument
      #
      # @api public
      def argument(name, **settings, &block)
        parameters << Parameter::Argument.create(name.to_sym, **settings, &block)
      end

      # Specify environment variable
      #
      # @example
      #   EDITOR=vim
      #
      # @api public
      def environment(name, **settings, &block)
        parameters << Parameter::Environment.create(name.to_sym, **settings, &block)
      end
      alias env environment

      # Specify a keyword
      #
      # @example
      #   foo=bar
      #
      # @api public
      def keyword(name, **settings, &block)
        parameters << Parameter::Keyword.create(name.to_sym, **settings, &block)
      end

      # A shortcut to specify flag option
      #
      # @example
      #   --foo
      #
      # @api public
      def flag(name, **settings, &block)
        defaults = {default: false}
        option(name, **defaults.merge(settings), &block)
      end

      # Specify an option
      #
      # @example
      #   -f
      #   --foo
      #   --foo bar
      #
      # @api public
      def option(name, **settings, &block)
        parameters << Parameter::Option.create(name.to_sym, **settings, &block)
      end
      alias opt option

      # Remove parameter from the parameters definitions list
      #
      # @api public
      def ignore(*names)
        parameters.delete(*names)
      end
      alias skip ignore

      # Holds all parameters
      #
      # @api public
      def parameters
        @parameters ||= Parameters.new
      end
    end # DSL
  end # Option
end # TTY
