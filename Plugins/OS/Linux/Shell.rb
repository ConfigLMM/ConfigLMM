# frozen_string_literal: true

require 'fileutils'
require 'open3'

module ConfigLMM
    module LMM
        class LinuxShell

            attr_reader :connection
            attr_reader :user

            def initialize(connection, user)
                @connection = connection
                @user = user
            end

            def distroID
                @connection.distroID
            end

            def updateFile(*args, &block)
                @connection.updateFile(*args, &block)
            end

            def exec(command, allowFailure = false, options = {})
                cmd = self.class.cmd(@user, command, options)
                @connection.exec(cmd, allowFailure, options)
            end

            def downloadStream(command, target, options = {})
                cmd = self.class.cmd(@user, command, options)
                @connection.downloadStream(cmd, target, options)
            end

            def rm(*args)
                @connection.rm(*args)
            end

            def escapePath(path)
                self.class.escapePath(path)
            end

            def self.escapePath(path)
                escaped = path.shellescape
                escaped = escaped[1..] if escaped.start_with?('\~')
                escaped
            end

            def fileWrite(target, data, options = {})
                hide = ''
                hide = ' ' if options[:hide]
                self.exec("#{hide}echo #{data.shellescape} > #{target}", false, options)
            end

            def fileAppend(target, data, options = {})
                hide = ''
                hide = ' ' if options[:hide]
                self.exec("#{hide}echo #{data.shellescape} >> #{target}", false, options)
            end

            def fileMerge(target, file, options = {})
                self.exec("cat #{file.shellescape} >> #{target}", false, options)
            end

            def fileReplace(target, placeholder, result, options = {})
                self.class.fileReplace(self, target, placeholder, result, options)
            end

            def self.fileReplace(connection, target, placeholder, result, options = {})
                hide = ''
                hide = ' ' if options[:hide]

                if placeholder.is_a?(Regexp)
                    placeholder = placeholder.source
                else
                    placeholder = Regexp.escape(placeholder)
                end

                result = result.to_s.gsub('\\', '\\\\\\') if options[:escape] != false
                pattern = "s;#{placeholder.gsub(';', '\\;')};#{result.to_s.gsub('&', '\\\\&').gsub(';', '\\\\;')};"
                connection.exec("#{hide}sed -Ei #{pattern.shellescape} #{connection.escapePath(target)}", false, options)
            end

            def createDirs(options, *paths)
                exec("mkdir -p #{paths.join(' ')}", false, options)
            end

            def self.cmd(user, command, options)
                cmd = "su --login #{user.shellescape} --shell /usr/bin/sh --command #{command.shellescape}"
                if options[:hide]
                    cmd = ' ' + cmd
                end
                cmd
            end

            def self.escapeSingleQuotes(command)
                command.gsub("'", "'\"'\"'")
            end
        end
    end
end
