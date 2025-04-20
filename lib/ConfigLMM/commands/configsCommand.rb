# frozen_string_literal: true

require_relative '../command'
require_relative '../utils/filters'
require_relative '../context'
require_relative '../state'
require_relative '../Framework'
require_relative '../LMM'
require_relative '../io'
require 'xdg'
require 'tmpdir'

module ConfigLMM
    module Commands
        class ConfigsCommand < ConfigLMM::Command

            def initialize(configPaths, options)
                @ConfigPaths = configPaths
                @Options = options
                @Plugins = {}

                logger do |config|
                    config.level = @Options[:level]
                end

                @Context = Context.new(logger, prompt, ::XDG.new, @Options)
                @State = State.new(logger, prompt)
                @Diff = {}

                # Load all Plugin files
                Framework::Registrator.registerAll(logger)

                # Create Plugin instances
                Framework::Store.boot(@Context, logger, prompt, @Plugins)
                @Plugins.each do |id, plugin|
                    plugin.state = @State
                end
            end

            def execute
                raise ConfigLMM::CLI::MissingArgument.new("ERROR: No configs specified!\n\n") if @ConfigPaths.empty?

                options = @Options.dup
                options.delete(:locations)
                options.delete(:things)
                options[:locationFilter] = Utils::Filters.parseLocationsOption(@Options[:locations], logger)
                #options[:thingFilter] = Utils::Filters.parseThingsOption(@Options[:things], logger)

                configList = IO::ConfigList.create(@ConfigPaths, logger)
                configList.expand!(options[:locationFilter])

                @State.load!(configList, options)

                self.processConfig(configList.toConfig(@Context), options)
            end

            def plugins
                @Plugins
            end

            def state
                @State
            end

            def context
                @Context
            end

            def findBestProvider(plugins)
                raise 'No providers!' if plugins.empty?
                # TODO FIXME
                # In case of multiple providers that match
                # We should chose best one and save it in state
                plugins.first
            end

            protected

            def invokeValidateAction(id, plugin, singleTarget, options)
                actionMethod = plugin.class.actionMethod(singleTarget['Type'], 'Validate')
                plugin.send(actionMethod, id, singleTarget, state, context, options)
            end

            def invokeRefreshAction(id, plugin, singleTarget, options)
                state.create!
                activeState = state.item(id)
                if activeState[:Type].nil?
                    activeState[:Type] = singleTarget['Type'].to_s
                elsif activeState[:Type] != singleTarget['Type'].to_s
                    raise Framework::PluginError.new("Unexpected Type #{activeState[:Type].inspect}! Wanted #{singleTarget['Type']}")
                end

                singleTarget['Location'] = '@me' unless singleTarget['Location']
                singleTarget['SecretId'] = (singleTarget['SecretId'] || id).upcase

                actionMethod = plugin.class.actionMethod(singleTarget['Type'], 'Refresh')
                if plugin.methods.include?(:authenticate)
                    result = plugin.authenticate(actionMethod, singleTarget, state, context, options)
                    raise Framework::PluginAuthError.new('Failed to authenticate!') unless result
                end
                plugin.send(actionMethod, id, singleTarget, activeState, context, options)
                state.save
            end

            def invokeDiffAction(id, plugin, singleTarget, options)
                state.create!
                activeState = state.item(id)
                if activeState[:Type].nil?
                    activeState[:Type] = singleTarget['Type'].to_s
                elsif activeState[:Type] != singleTarget['Type'].to_s
                    raise Framework::PluginError.new("Unexpected Type #{activeState[:Type].inspect}! Wanted #{singleTarget['Type']}")
                end
                actionMethod = plugin.class.actionMethod(singleTarget['Type'], 'Diff')
                plugin.send(actionMethod, id, singleTarget, activeState, context, options)
            end

            def invokeBuildAction(id, plugin, singleTarget, options)
                actionMethod = plugin.class.actionMethod(singleTarget['Type'], 'Build')
                plugin.send(actionMethod, id, singleTarget, state, context, options)
            end

            def invokeDeployAction(id, plugin, singleTarget, options)
                prompt.warn("Deploying #{singleTarget['ID']}: #{singleTarget['Type'].to_s}")
                state.create!
                activeState = state.item(id)
                if activeState[:Type].nil?
                    activeState[:Type] = singleTarget['Type'].to_s
                elsif activeState[:Type] != singleTarget['Type'].to_s
                    raise Framework::PluginError.new("Unexpected Type #{activeState[:Type].inspect}! Wanted #{singleTarget['Type']}")
                end

                singleTarget['Location'] = '@me' unless singleTarget['Location']
                singleTarget['SecretId'] = (singleTarget['SecretId'] || id).upcase

                actionMethod = plugin.class.actionMethod(singleTarget['Type'], 'Deploy')
                if plugin.methods.include?(:authenticate)
                    result = plugin.authenticate(actionMethod, singleTarget, state, context, options)
                    raise Framework::PluginAuthError.new('Failed to authenticate!') unless result
                end

                Dir.mktmpdir do |outputDir|

                    if plugin.class.persistBuildDir?
                        if options['output'] == '/tmp or ./build'
                            options = options.dup
                            options['output'] = './build'
                            if !options['dry']
                                FileUtils.mkdir_p(options['output'])
                            end
                        end
                    else
                        options = options.dup
                        options['output'] = outputDir
                    end

                    if !options['dry']
                        # Prevent others accessing it
                        FileUtils.chmod(0750, options['output'])
                    end

                    if plugin.hasAction?(singleTarget['Type'], :build)
                        invokeBuildAction(id, plugin, singleTarget, options)
                    end

                    plugin.send(actionMethod, id, singleTarget, activeState, context, options)
                end
                activeState['Config'] = self.class.sanitizeConfig(singleTarget)
                activeState['Config'].delete(:Parent)
                activeState['Config'].delete('Resources')
                activeState['Config'] = activeState['Config'].sort.to_h
                activeState['Status'] = State::STATUS_DEPLOYED if !activeState['Status'] || [State::STATUS_DELETED, State::STATUS_DESTROYED].include?(activeState['Status'])
                state.save
            end

            def self.sanitizeConfig(config)
                return config unless config.is_a?(Hash)
                newConfig = config.dup
                config.each do |key, value|
                    lowerkey = key.to_s.downcase
                    if lowerkey.include?('password') || lowerkey.include?('privatekey') || lowerkey.include?('sharedkey')
                        newConfig.delete(key)
                    elsif value.is_a?(Hash)
                        newConfig[key] = self.sanitizeConfig(value)
                    elsif value.is_a?(Array)
                        newValue = value
                        value.each_with_index do |v, i|
                            newValue[i] = self.sanitizeConfig(v)
                        end
                        newConfig[key] = newValue
                    end
                end
                newConfig
            end


            def checkDiff(id, targetName, stateName, target, activeState)
                if target[targetName] != activeState[stateName]
                    @Diff[id] = target
                end
            end
        end
    end
end
