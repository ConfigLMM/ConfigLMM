# frozen_string_literal: true

require 'addressable/uri'
require_relative 'local'
require_relative 'ssh'

module ConfigLMM
    module IO
        ConnectionError = Class.new(Framework::PluginProcessError)
        ConnectError = Class.new(ConnectionError)

        class ExecError < ConnectionError
            attr_reader :command, :stdout, :stderr, :status

            def initialize(message, command, stdout, stderr, status)
                super(message)
                @command = command
                @stdout = stdout
                @stderr = stderr
                @status = status
            end

            def to_s
                str = super + "\n"
                str += stdout.to_s + "\n" if stdout
                str += stderr.to_s if stdout != stderr
                str
            end
        end

        class Connection

            attr_reader :type
            attr_reader :tunnel
            attr_reader :local
            attr_reader :prompt
            attr_reader :logger

            def initialize(type, tunnel, prompt, logger)
                @type = type
                @tunnel = tunnel
                @local = Local.new(prompt, logger)
                @prompt = prompt
                @logger = logger
            end

            def rm(path, dry)
                @tunnel.rm(path, dry)
            end

            def exec(command, allowFailure = false, options = {})
                @tunnel.exec(command, allowFailure, options)
            end

            def adminExec(command, allowFailure = false, options = {})
                @tunnel.adminExec(command, allowFailure, options)
            end

            def filePresent?(file, options = {})
                self.exec("stat #{file}", true, options) if options['dry']
                result = self.exec("stat #{file}", true, { **options, 'dry' => false })
                !result.start_with?('stat: cannot')
            end

            def fileLink?(file, options = {})
                self.exec("stat #{file}", true, options) if options['dry']
                result = self.exec("stat #{file}", true, { **options, 'dry' => false })
                return false if result.start_with?('stat: cannot')
                result.include?('symbolic link') && !result.include?('regular file')
            end

            def updateFile(file, options, atTop = false, comment = '#', &block)
                @tunnel.updateFile(file, options, atTop, comment, &block)
            end

            def download(source, target, options = {})
                @tunnel.download(source, target, options)
            end

            def downloadStream(command, target, options = {})
                @tunnel.downloadStream(command, target, local, options)
            end

            def upload(source, target, options = {})
                @tunnel.upload(source, target, options)
            end

            def uploadFolder(folder, target, options = {})
                @tunnel.uploadFolder(folder, target, options)
            end

            def self.exec(command, ssh = nil, allowFailure = false, options = {})
                if ssh.nil?
                    Local.exec(command, allowFailure, options)
                else
                    SSH.exec!(ssh, command, allowFailure, options)
                end
            end

            def self.cmdSuccess?(command, ssh = nil)
                if ssh.nil?
                    system(command, :out => File::NULL)
                else
                    SSH.sshSuccess?(ssh, command)
                end
            end

            # `connect': No route to host - connect(2) for 192.168.1.3:22 (Errno::EHOSTUNREACH)
            # `connect': Connection refused - connect(2) for 192.168.1.3:22 (Errno::ECONNREFUSED)
            def self.tunnel(uri, target, context, prompt, logger, &block)
                scheme, uri = self.processURI(uri)
                case scheme
                when 'local'
                    yield(Connection.new(:Local, Local.new(prompt, logger), prompt, logger))
                when 'ssh'
                    SSH.tunnel(uri) do |ssh|
                        yield(Connection.new(:SSH, SSH.new(prompt, logger, ssh), prompt, logger))
                    end
                when 'proxmox+xterm'
                    LMM::Proxmox.withXTerm(uri, target, context, prompt, logger) do |xterm|
                        yield(Connection.new(:Proxmox, xterm, prompt, logger))
                    end
                else
                    raise ConnectionError.new("Unsupported protocol: #{scheme}!")
                end
            end

            def self.ping(uri, target, context, prompt, logger)
                scheme, uri = self.processURI(uri)
                case scheme
                when 'local'
                    return true
                when 'ssh'
                    SSH.ping(uri, prompt, logger)
                else
                    raise ConnectionError.new("Unimplemented protocol: #{scheme}!")
                end
            end

            def self.processURI(uri)
                return 'local' if uri.nil? || uri.to_s.empty? || uri == '@me'
                uri = Addressable::URI.parse(uri) if uri.is_a?(String)
                [uri.scheme, uri]
            end

            def self.cacheKey(uri, target)
                scheme, uri = self.processURI(uri)
                if scheme == 'proxmox+xterm'
                    # Special case for XTerm
                    name = target['Name']
                    name = target['Domain'] if target['Domain']
                    return uri.to_s + ';' + name
                end
                uri.to_s
            end

        end
    end
end
