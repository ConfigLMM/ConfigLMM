# frozen_string_literal: true

require 'net/ssh'
require 'net/scp'
require 'securerandom'

module ConfigLMM
    module IO
        class SSH

            attr_reader :prompt
            attr_reader :logger
            attr_reader :ssh

            def initialize(prompt, logger, ssh)
                @prompt = prompt
                @logger = logger
                @ssh = ssh
            end

            def rm(path, dry)
                if dry
                    prompt.say("Would remove ssh://#{ssh.transport.host}:#{ssh.transport.port}" + path)
                else
                    self.class.exec!(ssh, "rm -rf #{path}", false, {}, self.prompt, self.logger)
                end
            end

            def exec(command, allowFailure = false, options = {})
                self.class.exec!(ssh, command, allowFailure, options, self.prompt, self.logger)
            end

            def adminExec(command, allowFailure = false, options = {})
                self.exec(command, allowFailure, options)
            end

            def updateFile(file, options, atTop = false, comment = '#', &block)
                localFile = options['output'] + '/' + SecureRandom.alphanumeric(10)
                File.write(localFile, '')
                self.exec("touch #{file}", false, options)
                self.download(file, localFile, options)
                Local.new(self.prompt, self.logger).updateFile(localFile, options, atTop, comment, &block)
                self.upload(localFile, file, options)
            end

            def download(source, target, options = {})
                if options['dry']
                    prompt.say("Would download scp -P #{ssh.transport.port} #{ssh.transport.host}:#{source} #{target}")
                else
                    ssh.scp.download!(source, target)
                end
            end

            def upload(source, target, options = {})
                if options['dry']
                    prompt.say("Would upload scp -P #{ssh.transport.port} #{source} #{ssh.transport.host}:#{target}")
                else
                    ssh.scp.upload!(source, target)
                end
            end

            def uploadFolder(folder, target, options = {})
                target += '/' + File.basename(folder) + '/'
                Dir[folder + '/*'].each do |file|
                    if options['dry']
                        prompt.say("Would upload scp -P #{ssh.transport.port} #{file} #{ssh.transport.host}:#{target + File.basename(file)}")
                    else
                        ssh.scp.upload!(file, target + File.basename(file), recursive: true)
                    end
                end
            end

            def shell(user)
                Shell.new(self, user)
            end

            def self.tunnel(uri, &block)
                uri = Addressable::URI.parse(uri) if uri.is_a?(String)
                server, params = self.toParams(uri)
                Net::SSH.start(server, nil, params, &block)
            end

            def self.ping(uri, prompt, logger)
                server, params = self.toParams(uri)
                options = Net::SSH.configuration_for(server, true).merge(params)
                server = options[:host_name] || server
                options[:timeout] = 3 unless options.key?(:timeout)
                Net::SSH::Transport::Session.new(server, options)
                true
            rescue Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::ConnectionTimeout
                false
            end

            def self.toParams(locationUri)
                server = locationUri.hostname
                params = {}
                params[:port] = locationUri.port if locationUri.port
                params[:user] = locationUri.user if locationUri.user
                [server, params]
            end

            def self.exec!(ssh, command, allowFailure = false, options = {}, prompt = nil, logger = nil)
                if options['dry']
                    message = "Would execute: ssh #{ssh.transport.host} -p #{ssh.transport.port} '#{command}'"
                    if prompt
                        prompt.say(message)
                    else
                        puts message
                    end
                    return ''
                end
                status = {}
                output = ''
                if options[:hide]
                    command = ' ' + command
                end
                channel = ssh.exec(command, status: status) do |channel, stream, data|
                    output += data
                end
                channel.wait
                if !allowFailure && (status[:exit_code].nil? || !status[:exit_code].zero?) && status[:exit_signal].to_i != 4 # SIGILL... Sometimes this happens for unknown reason
                    raise ExecError.new("Failed '#{command}'", command, output, output, status)
                end
                output
            end

            def self.cmd(uri)
                uri = Addressable::URI.parse(uri) if uri.is_a?(String)
                server, sshParams = self.toParams(uri)
                cmd = 'ssh '
                cmd += '-p ' + sshParams[:port] if sshParams[:port]
                cmd += sshParams[:user] + '@' if sshParams[:port]
                cmd + server
            end

            def self.sshSuccess?(ssh, command)
                status = {}
                ssh.exec!(command, status)
                status[:exit_code].zero?
            end

        end
    end
end
