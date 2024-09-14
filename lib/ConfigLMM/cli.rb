# encoding: UTF-8
# frozen_string_literal: true

require 'thor'
require_relative 'LMM'

module ConfigLMM
    # Handle the application command line parsing
    # and the dispatch to various command objects
    #
    # @api public
    class CLI < Thor
        ArgumentError = Class.new(RuntimeError)
        MissingArgument = Class.new(ArgumentError)
        InvalidOption = Class.new(ArgumentError)

        class_option :locations, type: :string, default: '', group: :configs, desc: 'Filter by config file locations'
        #class_option :things, type: :string, default: '', group: :configs, desc: 'Filter things to use'
        class_option :level, type: :string, enum: ['debug', 'info', 'warn', 'error'], default: 'info', desc: 'Logging level to use'
        class_option :dry,  aliases: '-n', type: :boolean, desc: 'Only show actions without performing'

        desc 'version', 'Show program\'s version'
        def version
            require_relative 'version'
            puts "v" + ConfigLMM::VERSION
        end
        map %w[--version -v] => :version


        desc 'list [CONFIGS...]', 'List things'
        method_option :help,  aliases: '-h', type: :boolean,
                              desc: 'Display usage information'
        def list(*configPaths)
            handleCommand(:list, configPaths, options)
        end


        desc 'validate [CONFIGS...]', 'Check whether the configuration is valid'
        method_option :help, aliases: '-h', type: :boolean,
                             desc: 'Display usage information'
        def validate(*configPaths)
            handleCommand(:validate, configPaths, options)
        end

        desc 'refresh [CONFIGS...]', 'Update local state to match deployed things'
        method_option :help,    aliases: '-h', type: :boolean,
                                desc: 'Display usage information'
        method_option :state,   aliases: '-s', type: :string,
                                desc: 'Path to the state file'
        method_option :context, aliases: '-c', type: :string,
                                desc: 'Path to context file'
        def refresh(*configPaths)
            handleCommand(:refresh, configPaths, options)
        end


        desc 'diff [CONFIGS...]', 'Show changes that will be applied with next deploy'
        method_option :help,    aliases: '-h', type: :boolean,
                                desc: 'Display usage information'
        method_option :state,   aliases: '-s', type: :string,
                                desc: 'Path to the state file'
        method_option :context, aliases: '-c', type: :string,
                                desc: 'Path to context file'
        def diff(*configPaths)
            handleCommand(:diff, configPaths, options)
        end


        desc 'build [CONFIGS...]', 'Build configuration in deployable form'
        method_option :help,    aliases: '-h', type: :boolean,
                                desc: 'Display usage information'
        method_option :context, aliases: '-c', type: :string,
                                desc: 'Path to context file'
        method_option :output,  aliases: '-o', type: :string,
                                default: './build',
                                desc: 'Output folder'
        def build(*configPaths)
            handleCommand(:build, configPaths, options)
        end


        desc 'deploy [CONFIGS...]', 'Deploy configuration'
        method_option :help,    aliases: '-h', type: :boolean,
                                desc: 'Display usage information'
        method_option :state,   aliases: '-s', type: :string,
                                desc: 'Path to the state file'
        method_option :context, aliases: '-c', type: :string,
                                desc: 'Path to context file'
        method_option :output,  aliases: '-o', type: :string,
                                default: '/tmp or ./build',
                                desc: 'Output folder'
        def deploy(*configPaths)
            handleCommand(:deploy, configPaths, options)
        end


        desc 'cleanup [CONFIGS...]', 'In deployed infrastructure cleanup/delete unused things (eg. deployment leftover junk) (note this can be risky due to mistakes)'
        method_option :help,  aliases: '-h', type: :boolean,
                              desc: 'Display usage information'
        method_option :state, aliases: '-s', type: :string,
                              desc: 'Path to the state file'
        def cleanup(*configPaths)
            handleCommand(:cleanup, configPaths, options)
        end

        desc 'types', 'List available types/plugins'
        method_option :help,  aliases: '-h', type: :boolean,
                              desc: 'Display usage information'
        def types
            handleCommand(:types, options)
        end

=begin
        # TODO
        desc 'test [CONFIGS...]', 'Test whether deployed things work as expected'
        method_option :help,      aliases: '-h', type: :boolean,
                                  desc: 'Display usage information'
        method_option :load,      aliases: '-l', type: :boolean,
                                  desc: 'Run performance/load tests (might be dangerous as it can affect live users)'
        method_option :chaos,     aliases: '-c', type: :boolean,
                                  desc: 'Test whether systems keep working while random things die (might be dangerous as it can affect live users due to injecting real faults)'
        method_option :alerts,    aliases: '-a', type: :boolean,
                                  desc: 'Test failure conditions and whether alerts work (might be dangerous as it can affect live users due to injecting real faults)'
        method_option :tools,     aliases: '-t', type: :string, desc: 'Filter tools to use for testing'

        def test(*configPaths)
            handleCommand(:test, configPaths, options)
        end

        desc 'compare [CONFIGS...]', 'Show changes between local state and deployed things'
        method_option :help,  aliases: '-h', type: :boolean,
                              desc: 'Display usage information'
        method_option :state, aliases: '-s', type: :string,
                              desc: 'Path to state file'
        def compare(*configPaths)
            handleCommand(:compare, configPaths, options)
        end

=end

        private

        def handleCommand(name, *params)
            if options[:help]
                invoke :help, [name.to_s]
            else
                require_relative('commands/' + name.to_s)
                Object.const_get('ConfigLMM::Commands::' + name.to_s.capitalize).new(*params).execute
            end
        rescue ArgumentError => e
            $stderr.puts(e)
            invoke :help, [name.to_s]
            exit 1
        end


        def self.exit_on_failure?
            true
        end
    end
end
