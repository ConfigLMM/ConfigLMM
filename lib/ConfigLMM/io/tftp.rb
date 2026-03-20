
require 'tftp'

module ConfigLMM
    module IO

        class TFTPHandler < ::TFTP::Handler::Base

            attr_reader :lastReadTime

            def initialize(dir, opts)
                @Dir = dir
                @lastReadTime = nil
                super(opts)
            end

            def processRequest(tag, req, sock, src)
                case req
                when ::TFTP::Packet::RRQ
                    if !req.filename.match?(/\w[\w\-\.\/]*/)
                        log :warn, "#{tag} #{req.filename} - File not found"
                        sock.send(::TFTP::Packet::ERROR.new(1, 'File not found.').encode, 0)
                        return false
                    end
                    path = req.filename
                    path = path.gsub('\\', '/')
                    loop do
                        path = path.gsub('//', '/')
                        break unless path.include?('//')
                    end
                    path = path.gsub('../', '')
                    path = path[1..] if path[0] == '/'
                    fullpath = @Dir + path
                    if !File.exist?(fullpath)
                        fullpath = fixInsensitiveCase(fullpath)
                    end
                    if File.file?(fullpath)
                        mode = 'r'
                        mode += 'b' if req.mode == :octet
                        io = File.open(fullpath, mode)
                        log :debug, "#{tag} Sending #{req.filename} - #{fullpath}"
                        options = {}
                        if req.options.key?('tsize')
                            options['tsize'] = io.stat.size
                        end
                        if req.options.key?('blksize')
                            @blksize = req.options['blksize'].to_i
                            options['blksize'] = @blksize
                        else
                            @blksize = 512
                        end
                        if req.options.key?('windowsize')
                            @windowsize = req.options['windowsize'].to_i
                            options['windowsize'] = @windowsize
                        else
                            @windowsize = 1
                        end
                        if !options.empty?
                            sendOACK(tag, sock, options)
                        end
                        send(tag, sock, io)
                        io.close
                        @lastReadTime = Time.now
                        return true
                    else
                        log :warn, "#{tag} #{req.filename} - File not found"
                        sock.send(::TFTP::Packet::ERROR.new(1, 'File not found.').encode, 0)
                    end
                when ::TFTP::Packet::WRQ
                    log :info, "#{tag} Denied write request for #{req.filename}"
                    sock.send(::TFTP::Packet::ERROR.new(2, 'Access denied.').encode, 0)
                end
                return false
            end

            # Handle a session.
            #
            # Has to close the socket (and any other resources).
            #
            # @param tag  [String]    Tag used for logging
            # @param req  [Packet]    The initial request packet
            # @param sock [UDPSocket] Connected socket
            # @param src  [UDPSource] Initial connection information
            def run!(tag, req, sock, src)
                processRequest(tag, req, sock, src)
                sock.close
            end

            def fixInsensitiveCase(path)
                originalPath = path
                parts = Pathname(path).each_filename.to_a
                current = Pathname(path).absolute? ? "/" : "."

                parts.each do |part|
                    item = Dir.children(current).find { |e| e.casecmp?(part) }
                    return originalPath unless item
                    current = File.join(current, item)
                end
                current
            end
        end

        class TFTP
            def initialize(dir, ip, logger, options = {})
                @Logger = logger
                @Handler = TFTPHandler.new(dir, { **options, logger: @Logger })
                @Server = ::TFTP::Server::Base.new(@Handler, { **options, logger: @Logger })
            end

            def start()
                Thread.new do
                    @Server.run!
                end
                @Logger.debug('Listening on UDP port 69 (TFTP Server)')
            end

            def stop()
                @Server.stop
            end

            def wait(timeout)
                timeoutTime = Time.now + timeout
                previousReadTime = @Handler.lastReadTime
                loop do
                    if previousReadTime != @Handler.lastReadTime
                        previousReadTime = @Handler.lastReadTime
                        timeoutTime = Time.now + timeout
                    end
                    return if Time.now >= timeoutTime
                    sleep(0.1)
                end
            end

            def hadRead?
                !@Handler.lastReadTime.nil?
            end
        end
    end
end
