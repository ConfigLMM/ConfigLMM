# frozen_string_literal: true

require_relative 'errors'
require_relative 'store'
require 'http'
require 'fileutils'

module ConfigLMM
    module Framework

        class Plugin


            def self.inherited(plugin)
                Store.registerPlugin(plugin)
            end

            def self.id
                @ID ||= self.normalizeId(self.className.to_s)
            end

            def self.addMeta(*fields)
                fields.each do |field|
                    self.define_singleton_method(field) do |value|
                        @Meta ||= {}
                        @Meta[field] = value
                    end
                end
            end

            def self.persistBuildDir
                @PersistBuildDir = true
            end

            def self.persistBuildDir?
                @PersistBuildDir == true
            end

            class << self
                alias :className :name
            end

            addMeta :name, :description

            attr_accessor :state

            def initialize(logger, prompt, plugins)
                @Logger = logger
                @Prompt = prompt
                @Plugins = plugins
                @Diff = {}
            end

            def id
                self.class.id
            end

            def self.actionMethod(type, action)
                name = type.to_s
                name[0] = name[0].upcase
                ('action' + name + action.to_s.capitalize).to_sym
            end

            def hasAction?(type, action)
                self.methods.include?(self.class.actionMethod(type, action))
            end

            def diff
                @Diff
            end

            def cleanup(configs, state, context, options)
                # Do nothing
            end

            protected

            def logger
                @Logger
            end

            def prompt
                @Prompt
            end

            def plugins
                @Plugins
            end

            def shouldMatch(id, targetKey, stateKey, target, activeState)
                if target[targetKey] != activeState[stateKey]
                    @Diff.update({targetKey => [target[targetKey], activeState[stateKey]]})
                end
            end

            def fileWrite(target, data, dry)
                if dry
                    prompt.say('Would write file ' + target)
                else
                    File.write(target, data)
                end
            end

            def copy(source, target, dry)
                if dry
                    prompt.say('Would copy ' + source + ' to ' + target)
                else
                    FileUtils.cp_r(source, target, noop: dry)
                end
            end

            def copyNotPresent(source, target, dry)
                if !File.exist?(target + File.basename(source))
                    if dry
                        prompt.say('Would copy ' + source + ' to ' + target)
                    else
                        FileUtils.cp_r(source, target, noop: dry)
                    end
                end
            end

            def rm(path, dry)
                if dry
                    prompt.say('Would remove ' + path)
                else
                    FileUtils.rm_r(path, noop: dry)
                end
            end

            def mkdir(target, dry)
                if dry
                    prompt.say('Would create ' + target)
                else
                    FileUtils.mkdir_p(target)
                end
            end

            def chown(user, group, target, dry)
                if dry
                    prompt.say("Would chown #{target} as #{user}:#{group}")
                else
                    FileUtils.chown_R(user, group, target)
                end
            end

            def renderTemplate(template, target, outputPath, options)
                variables = {
                    config: target,
                }
                result = template.result_with_hash(variables)
                mkdir(File.dirname(outputPath), options['dry'])
                if options['dry']
                    prompt.say('Would write to ' + outputPath)
                else
                    File.write(outputPath, result)
                end
            end

            def self.normalizeId(id)
                id = id.split('::').last
                if id.downcase.end_with?('plugin')
                    id = id[0...-6]
                end
                id.to_sym
            end

        end
    end
end
