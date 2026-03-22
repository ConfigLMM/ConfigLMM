# frozen_string_literal: true

require_relative 'errors'
require_relative 'store'
require 'addressable/uri'

module ConfigLMM
    module Framework

        class Plugin

            REPOS_CACHE = '~/.cache/configlmm/repos'

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

            def initialize(context, logger, prompt, plugins)
                @Context = context
                @Logger = logger
                @Prompt = prompt
                @Plugins = plugins
                @Diff = {}
                @Local = IO::Local.new(prompt, logger)
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

            def withCache(type, id, item, options, &block)
                name = type.to_s
                name[0] = name[0].upcase
                methodName = ('cache' + name + 'Connection').to_sym
                if self.methods.include?(methodName)
                    nestedProcs = lambda { block.call }
                    target = item['Config'].to_h
                    connectionInfos = self.send(methodName, id, target, context, options)
                    if !connectionInfos.empty? && !connectionInfos.last.is_a?(Array)
                        connectionInfos = [connectionInfos]
                    end
                    connectionInfos.each do |connectionInfo|
                        current = proc do |nestedProcs|
                            key, connectionLambda, innerLambda = connectionInfo
                            connectionLambda.call do |connection|
                                context.withConnectionCache(key, connection) do
                                    if innerLambda
                                        innerLambda.call(connection) do |result|
                                            context.withConnectionCache(connection, result) do
                                                nestedProcs.call
                                            end
                                        end
                                    else
                                        nestedProcs.call
                                    end
                                end
                            end
                        end
                        previous = nestedProcs
                        nestedProcs = proc { current.call(previous) }
                    end
                    nestedProcs.call
                else
                    yield
                end
            end

            def diff
                @Diff
            end

            def cleanup(configs, state, context, options)
                # Do nothing
            end

            protected

            def context
                @Context
            end

            def logger
                @Logger
            end

            def prompt
                @Prompt
            end

            def plugins
                @Plugins
            end

            def local
                @Local
            end

            def shouldMatch(id, activeState, stateKey, target, targetKey)
                data = nil
                data = activeState[stateKey] if activeState.is_a?(Hash)
                if target[targetKey] != data
                    @Diff.update({targetKey => [data, target[targetKey]]})
                end
            end

            def fileWrite(target, data, dry)
                local.fileWrite(target, data, dry)
            end

            def copy(source, target, dry)
                local.copy(source, target, dry)
            end

            def copyNotPresent(source, target, dry)
                local.copyNotPresent(source, target, dry)
            end

            def rm(path, dry, ssh = nil)
                if ssh
                    IO::SSH.new(prompt, logger, ssh).rm(path, dry)
                else
                    local.rm(path, dry)
                end
            end

            def mkdir(target, dry)
                local.mkdir(target, dry)
            end

            def chown(user, group, target, dry)
                local.chown(user, group, target, dry)
            end

            def updateLocalFile(file, options, atTop = false, comment = '#', &block)
                local.updateFile(file, options, atTop, comment, &block)
            end

            # DEPRECATED
            def updateRemoteFile(locationOrSSH, file, options, atTop = false, comment = '#', &block)
                closure = Proc.new do |ssh|
                    IO::SSH.new(prompt, logger, ssh).updateFile(file, options, atTop, comment, &block)
                end

                if locationOrSSH.is_a?(String) || locationOrSSH.is_a?(Addressable::URI)
                    uri = Addressable::URI.parse(locationOrSSH)
                    raise Framework::PluginProcessError.new("Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        closure.call(ssh)
                    end
                else
                    closure.call(locationOrSSH)
                end
            end

            # DEPRECATED
            def self.filePresent?(file, ssh = nil)
                result = self.exec("stat #{file}", ssh, true)
                !result.start_with?('stat: cannot')
            end

            # DEPRECATED - use filePresent()
            def self.remoteFilePresent?(file, ssh)
                self.filePresent?(file, ssh)
            end

            def self.uploadFolder(folder, target, ssh)
                target += '/' + File.basename(folder) + '/'
                IO::SSH.exec!(ssh, "mkdir -p #{target}")
                Dir[folder + '/*'].each do |file|
                    ssh.scp.upload!(file, target + File.basename(file), recursive: true)
                end
            end

            def withConnection(uri, target, options = {}, &block)
                if options['disableCache']
                    IO::Connection.tunnel(uri, target, self.context, options, self.prompt, self.logger, &block)
                else
                    self.context.useConnectionCache(IO::Connection.cacheKey(uri, target), block) do
                        IO::Connection.tunnel(uri, target, self.context, options, self.prompt, self.logger, &block)
                    end
                end
            end

            def buildConnectionCache(uri, target, &block)
                [IO::Connection.cacheKey(uri, target), lambda { |&block| self.withConnection(uri, target, &block) }]
            end

            def ping(uri, target, options, &block)
                IO::Connection.ping(uri, target, options, self.context, self.prompt, self.logger, &block)
            end

            def try(timeout, options, &block)
                return yield if options['dry']
                wait = options['wait'] || 10
                endTime = Time.now + timeout
                loop do
                    result = yield
                    return result if result
                    return false if Time.now >= endTime
                    sleep(wait)
                end
            end

            # DEPRECATED
            def self.exec(command, ssh = nil, allowFailure = false, dry = false)
                IO::Connection.exec(command, ssh, allowFailure, { dry: dry })
            end

            # DEPRECATED
            def self.sshStart(uri, &block)
                IO::SSH.tunnel(uri, &block)
            end

            # DEPRECATED
            def self.sshExec!(ssh, command, allowFailure = false, dry = false)
                IO::SSH.exec!(ssh, command, allowFailure, { dry: dry })
            end

            # DEPRECATED
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

            def cleanupType(type, configs, state, context, options)
                items = state.selectType(type)
                items.each do |id, item|
                    if !configs.key?(id) && item['Status'] != State::STATUS_DESTROYED && (item['Status'] != State::STATUS_DELETED || options[:destroy])
                        begin
                            self.withConnection(item['Config']['Location'], item) do |connection|
                                yield(item, id, state, context, options, connection)
                            end
                        rescue SystemCallError => error
                            if error.errno == Errno::EHOSTUNREACH::Errno
                                prompt.say("#{id}: #{item[:Type].to_s} failed to connect #{item['Config'].to_h['Location'].to_s}", color: :red)
                                prompt.say(error, color: :red)
                                prompt.say("Skipping!", color: :red)
                            else
                                raise
                            end
                        end
                    end
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
