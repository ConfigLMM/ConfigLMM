# frozen_string_literal: true

require 'fileutils'
require 'open3'

module ConfigLMM
    module IO
        class Local

            attr_reader :prompt
            attr_reader :logger
            attr_reader :local

            def initialize(prompt, logger)
                @prompt = prompt
                @logger = logger
                @local = self
                @execOptions = {}
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

            def updateFile(file, options, atTop = false, comment = '#')
                File.write(file, '') unless File.exist?(file)
                sectionBegin = CONFIGLMM_SECTION_BEGIN.gsub('#', comment)
                sectionEnd = CONFIGLMM_SECTION_END.gsub('#', comment)
                fileLines = File.read(file).lines
                sectionBeginIndex = fileLines.index(sectionBegin)
                sectionEndIndex = fileLines.index(sectionEnd)
                if sectionBeginIndex.nil?
                    linesBefore = []
                    linesBefore = fileLines unless atTop
                    linesBefore << "\n"
                    linesBefore << sectionBegin
                    linesAfter = [sectionEnd]
                    linesAfter << "\n"
                    linesAfter += fileLines if atTop
                else
                    linesBefore = fileLines[0..sectionBeginIndex]
                    if sectionEndIndex.nil?
                        linesAfter = [sectionEnd]
                        linesAfter << "\n"
                    else
                        linesAfter = fileLines[sectionEndIndex..fileLines.length]
                    end
                end

                fileLines = linesBefore
                newLines = yield(fileLines)
                fileLines = newLines if newLines && newLines.is_a?(Array)
                fileLines += linesAfter

                fileWrite(file, fileLines.join(), options[:dry])
            end

            def exec(command, allowFailure = false, options = {})
                opts = {}
                opts['dry'] = options['dry'] || options[:dry]
                opts[:hide] = options['hide'] || options[:hide]
                opts['exec'] = @execOptions.merge(options['exec'] || {})
                self.class.exec(command, allowFailure, opts, self.prompt, self.logger)
            end

            def filePresent?(file, options = {})
                result = self.exec("stat #{file}", true, options)
                !result.start_with?('stat: cannot')
            end

            def fileReplace(target, placeholder, result, options = {})
                if options['dry']
                    prompt.say("Would replace /#{placeholder}/ with '#{result}' in #{target}")
                else
                    content = File.read(target).to_s
                    content.gsub!(Regexp.new(placeholder), result)
                    File.write(target, content)
                end
            end

            def adminExec(command, allowFailure = false, options = {})
                if `echo $EUID`.strip == '0'
                    self.exec(command, allowFailure, options)
                else
                    if options['dry']
                        prompt.say("Would execute: sudo #{command} >/dev/null")
                    else
                        self.exec('sudo ' + command, false, options)
                    end
                end
            end

            def download(target, source, options = {})
                copy(source, target, options[:dry])
            end

            def downloadStream(command, target, local, options = {})
                command += ' > ' + target
                self.exec(command, false, options)
            end

            def upload(source, target, options = {})
                copy(source, target, options[:dry])
            end

            def uploadFolder(folder, target, options = {})
                upload(folder, target, options)
            end

            def remoteDownload(url, targetDir, options = {})
                filename = File.basename(Addressable::URI.parse(url).path)
                targetFile = File.expand_path(targetDir + filename)
                if !File.exist?(targetFile)
                    mkdir(File.expand_path(targetDir), false)
                    prompt.say('Downloading... ' + url)
                    response = ::HTTP.follow.get(url)
                    raise "Failed to download file: #{response.status}" unless response.status.success?
                    File.open(targetFile, 'wb') do |file|
                        response.body.each do |chunk|
                            file.write(chunk)
                        end
                    end
                end
                targetFile
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

            def inDir(dir, &block)
                opts = @execOptions.dup
                @execOptions[:chdir] = File.expand_path(dir)
                yield
                self
            ensure
                @execOptions = opts
            end

            def self.exec(command, allowFailure = false, options = {}, prompt = nil, logger = nil)
                if options['dry']
                    message = "Would execute: #{command}"
                    if prompt
                        prompt.say(message)
                    else
                        puts message
                    end
                    return ''
                end
                if options[:hide]
                    command = ' ' + command
                    if logger
                        logger.debug("# **HIDDEN**")
                    end
                else
                    if logger
                        logger.debug("# #{command}")
                    end
                end
                execOptions = options['exec'] || {}
                stdout, stdeerr, status = Open3.capture3(command, execOptions)
                if !allowFailure && !status.success?
                    $stderr.puts(stdout)
                    $stderr.puts(stdeerr)
                    raise ExecError.new("Failed '#{command}'", command, stdout, stdeerr, status)
                end
                if logger
                    dir = ''
                    dir = '[' + execOptions[:chdir] + ']' if execOptions[:chdir]
                    logger.debug("#{dir}(#{status.exitstatus})> #{stdout + stdeerr}")
                end
                stdout + stdeerr
            rescue Errno::ENOENT => error
                if !allowFailure
                    raise ExecError.new("Failed '#{command}'", command, error, nil, nil)
                end
                ''
            end

        end
    end
end
