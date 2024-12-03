
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
                    filename = req.filename
                    loop do
                        filename = filename.gsub('//', '/')
                        break unless filename.include?('//')
                    end
                    filename = filename.gsub('../', '')
                    path = @Dir + filename
                    if File.file?(path)
                        mode = 'r'
                        mode += 'b' if req.mode == :octet
                        io = File.open(path, mode)
                        log :debug, "#{tag} Sending #{req.filename} - #{path}"
                        if req.options.key?('tsize')
                            sendOACK(tag, sock, { 'tsize' => io.stat.size })
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
