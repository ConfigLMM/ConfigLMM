# frozen_string_literal: true

require_relative 'errors'
require_relative 'store'
require 'addressable/uri'
require 'http'
require 'fileutils'
require 'net/ssh'
require 'net/scp'

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

            CONFIGLMM_SECTION_BEGIN = "# -----BEGIN CONFIGLMM-----\n"
            CONFIGLMM_SECTION_END   = "# -----END CONFIGLMM-----\n"

            def updateLocalFile(file, options, atTop = false)
                fileLines = File.read(file).lines
                sectionBeginIndex = fileLines.index(CONFIGLMM_SECTION_BEGIN)
                sectionEndIndex = fileLines.index(CONFIGLMM_SECTION_END)
                if sectionBeginIndex.nil?
                    linesBefore = []
                    linesBefore = fileLines unless atTop
                    linesBefore << "\n"
                    linesBefore << CONFIGLMM_SECTION_BEGIN
                    linesAfter = [CONFIGLMM_SECTION_END]
                    linesAfter << "\n"
                    linesAfter += fileLines if atTop
                else
                    linesBefore = fileLines[0..sectionBeginIndex]
                    if sectionEndIndex.nil?
                        linesAfter = [CONFIGLMM_SECTION_END]
                        linesAfter << "\n"
                    else
                        linesAfter = fileLines[sectionEndIndex..fileLines.length]
                    end
                end

                fileLines = linesBefore
                fileLines = yield(fileLines)
                fileLines += linesAfter

                fileWrite(file, fileLines.join(), options[:dry])
            end

            def updateRemoteFile(locationOrSSH, file, options, atTop = false, &block)

                closure = Proc.new do |ssh|
                    localFile = options['output'] + '/' + SecureRandom.alphanumeric(10)
                    File.write(localFile, '')
                    self.class.sshExec!(ssh, "touch #{file}")
                    ssh.scp.download!(file, localFile)
                    updateLocalFile(localFile, options, atTop, &block)
                    ssh.scp.upload!(localFile, file)
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

            def self.toSSHparams(locationUri)
                server = locationUri.hostname
                params = {}
                params[:port] = locationUri.port if locationUri.port
                params[:user] = locationUri.user if locationUri.user
                [server, params]
            end

            def self.sshStart(uri)
                uri = Addressable::URI.parse(uri) if uri.is_a?(String)
                server, sshParams = self.toSSHparams(uri)
                Net::SSH.start(server, nil, sshParams) do |ssh|
                    yield(ssh)
                end
            end

            def self.sshExec!(ssh, command, allowFailure = false)
                status = {}
                output = ''
                channel = ssh.exec(command, status: status) do |channel, stream, data|
                    output += data
                end
                channel.wait
                if !allowFailure && !status[:exit_code].zero?
                    $stderr.puts(output)
                    raise Framework::PluginProcessError.new("Failed '#{command}'")
                end
                output
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
