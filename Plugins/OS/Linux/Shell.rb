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
                cmd = "su --login #{@user.shellescape} --shell /usr/bin/sh --command #{command.shellescape}"
                if options[:hide]
                    cmd = ' ' + cmd
                end
                @connection.exec(cmd, allowFailure, options)
            end

            def rm(*args)
                @connection.rm(*args)
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
                hide = ''
                hide = ' ' if options[:hide]
                pattern = "s|#{placeholder}|#{result.gsub('\\', '\\\\\\').gsub('&', '\\\\&').gsub('|', '\\\\|')}|"
                self.exec("#{hide}sed -i #{pattern.shellescape} #{target}", false, options)
            end

            def createDirs(options, *paths)
                exec("mkdir -p #{paths.join(' ')}", false, options)
            end

            def self.escapeSingleQuotes(command)
                command.gsub("'", "'\"'\"'")
            end
        end
    end
end
