# After https://www.ietf.org/rfc/rfc1350.txt
#

require 'socket'

module TFTP
  # TFTP-specific errors.
  class Error < Exception; end
  # Packet parsing exception.
  class ParseError < Error; end

  # Packet can parse a binary string into a lightweight object representation.
  module Packet
    # Base is a thin layer over a Struct.
    class Base < Struct
      # Encode the packet back to binary string.
      # It uses the #to_str method to properly format each packet, and then forces
      # 8bit encoding.
      def encode; to_str.force_encoding('ascii-8bit'); end
    end

    # Read Request
    RRQ = Base.new(:filename, :mode)
    class RRQ
      # Convert to binary string.
      def to_str; "\x00\x01" + self.filename + "\x00" + self.mode.to_s + "\x00"; end
    end

    # Write Request
    WRQ = Base.new(:filename, :mode)
    class WRQ
      def to_str; "\x00\x02" + self.filename + "\x00" + self.mode.to_s + "\x00"; end
    end

    # Data
    DATA = Base.new(:seq, :data)
    class DATA
      def to_str; "\x00\x03" + [self.seq].pack('n') + self.data; end
      # Check if this is the last data packet for this session.
      def last?; self.data.length < 512; end
    end

    # Acknowledgement
    ACK = Base.new(:seq)
    class ACK
      def to_str; "\x00\x04" + [self.seq].pack('n'); end
    end

    # Error
    ERROR = Base.new(:code, :msg)
    class ERROR
      def to_str; "\x00\x05" + [self.code].pack('n') + self.msg + "\x00"; end
    end

    # Parse a binary string into a packet.
    # Does some sanity checking, can raise a ParseError.
    def self.parse(data)
      data = data.force_encoding('ascii-8bit')

      opcode = data.unpack('n').first
      if opcode < 1 || opcode > 5
        raise ParseError, "Unknown packet opcode '#{opcode.inspect}'"
      end

      payload = data.slice(2, data.length - 2)
      case opcode
      when 1, 2 # rrq, wrq
        raise ParseError, 'Not null terminated' if payload.slice(payload.length - 1) != "\x00"
        xs = payload.split("\x00")
        raise ParseError, "Not enough elements: #{xs.inspect}" if xs.length < 2
        filename = xs[0]
        mode = xs[1].downcase.to_sym
        raise ParseError, "Unknown mode '#{xs[1].inspect}'" unless [:netascii, :octet].member? mode
        return RRQ.new(filename, mode) if opcode == 1
        return WRQ.new(filename, mode)
      when 3 # data
        seq = payload.unpack('n').first
        block = payload.slice(2, payload.length - 2) || ''
        raise ParseError, "Exceeded block length with #{block.length} bytes" if block.length > 512
        return DATA.new(seq, block)
      when 4 # ack
        raise ParseError, "Wrong payload length with #{payload.length} bytes" if payload.length != 2
        seq = payload.unpack('n').first
        return ACK.new(seq)
      when 5 # error
        raise ParseError, 'Not null terminated' if payload.slice(payload.length - 1) != "\x00"
        code = payload.unpack('n').first
        raise ParseError, "Unknown error code '#{code.inspect}'" if code < 0 || code > 7
        msg = payload.slice(2, payload.length - 3) || ''
        return ERROR.new(code, msg)
      end
    end
  end

  # Handlers implement session-handling logic.
  module Handler
    # Base handler contains the common methods for real handlers.
    class Base
      # Initialize the handler.
      #
      # Options:
      #
      #  - :logger  => logger object (e.g. a Logger instance)
      #  - :timeout => used while waiting for next DATA/ACK packets (default: 5s)
      #
      # All given options are saved in @opts.
      #
      # @param opts [Hash] Options
      def initialize(opts = {})
        @logger = opts[:logger]
        @timeout = opts[:timeout] || 5
        @opts = opts
      end

      # Send data over an established connection.
      #
      # Doesn't close neither sock nor io.
      #
      # @param tag  [String]    Tag used for logging
      # @param sock [UDPSocket] Connected socket
      # @param io   [IO]        Object to send data from
      def send(tag, sock, io)
        seq = 1
        begin
          while not io.eof?
            block = io.read(512)
            sock.send(Packet::DATA.new(seq, block).encode, 0)
            unless IO.select([sock], nil, nil, @timeout)
              log :warn, "#{tag} Timeout at block ##{seq}"
              return
            end
            msg, _ = sock.recvfrom(4, 0)
            pkt = Packet.parse(msg)
            if pkt.class != Packet::ACK
              log :warn, "#{tag} Expected ACK but got: #{pkt.class}"
              return
            end
            if pkt.seq != seq
              log :warn, "#{tag} Seq mismatch: #{seq} != #{pkt.seq}"
              return
            end
            # Increment with wrap around at 16 bit boundary,
            # because of tftp block number field size limit.
            seq = (seq + 1) & 0xFFFF
          end
          sock.send(Packet::DATA.new(seq, '').encode, 0) if io.size % 512 == 0
        rescue ParseError => e
          log :warn, "#{tag} Packet parse error: #{e.to_s}"
          return
        end
        log :info, "#{tag} Sent file"
      end

      # Receive data over an established connection.
      #
      # Doesn't close neither sock nor io.
      # Returns true if whole file has been received, false otherwise.
      #
      # @param tag  [String]    Tag used for logging
      # @param sock [UDPSocket] Connected socket
      # @param io   [IO]        Object to write data to
      # @return [Boolean]
      def recv(tag, sock, io)
        sock.send(Packet::ACK.new(0).encode, 0)
        seq = 1
        begin
          loop do
            unless IO.select([sock], nil, nil, @timeout)
              log :warn, "#{tag} Timeout at block ##{seq}"
              return false
            end
            msg, _ = sock.recvfrom(516, 0)
            pkt = Packet.parse(msg)
            if pkt.class != Packet::DATA
              log :warn, "#{tag} Expected DATA but got: #{pkt.class}"
              return false
            end
            if pkt.seq != seq
              log :warn, "#{tag} Seq mismatch: #{seq} != #{pkt.seq}"
              return false
            end
            io.write(pkt.data)
            sock.send(Packet::ACK.new(seq).encode, 0)
            break if pkt.last?
            seq = (seq + 1) & 0xFFFF
          end
        rescue ParseError => e
          log :warn, "#{tag} Packet parse error: #{e.to_s}"
          return false
        end
        log :info, "#{tag} Received file"
        true
      end

      private
      def log(level, msg)
        @logger.send(level, msg) if @logger
      end
    end

    # Basic read-write session over a 'physical' directory.
    class RWSimple < Base
      # Initialize the handler.
      #
      # Options:
      #
      #  - :no_read  => deny read access if true
      #  - :no_write => deny write access if true
      #
      # @param path [String]  Path to serving root directory
      # @param opts [Hash]    Options
      def initialize(path, opts = {})
        @path = path
        super(opts)
      end

      # Handle a session.
      #
      # Has to close the socket (and any other resources).
      # Note that the current version 'guards' against path traversal by a simple
      # substitution of '..' with '__'.
      #
      # @param tag  [String]    Tag used for logging
      # @param req  [Packet]    The initial request packet
      # @param sock [UDPSocket] Connected socket
      # @param src  [UDPSource] Initial connection information
      def run!(tag, req, sock, src)
        name = req.filename.gsub('..', '__')
        path = File.join(@path, name)

        case req
        when Packet::RRQ
          if @opts[:no_read]
            log :info, "#{tag} Denied read request for #{req.filename}"
            sock.send(Packet::ERROR.new(2, 'Access denied.').encode, 0)
            sock.close
            return
          end
          log :info, "#{tag} Read request for #{req.filename} (#{req.mode})"
          unless File.exist? path
            log :warn, "#{tag} File not found"
            sock.send(Packet::ERROR.new(1, 'File not found.').encode, 0)
            sock.close
            return
          end
          mode = 'r'
          mode += 'b' if req.mode == :octet
          io = File.open(path, mode)
          send(tag, sock, io)
          sock.close
          io.close
        when Packet::WRQ
          if @opts[:no_write]
            log :info, "#{tag} Denied write request for #{req.filename}"
            sock.send(Packet::ERROR.new(2, 'Access denied.').encode, 0)
            sock.close
            return
          end
          log :info, "#{tag} Write request for #{req.filename} (#{req.mode})"
          mode = 'w'
          mode += 'b' if req.mode == :octet
          io = File.open(path, mode)
          ok = recv(tag, sock, io)
          sock.close
          io.close
          unless ok
            log :warn, "#{tag} Removing partial file #{req.filename}"
            File.delete(path)
          end
        end
      end
    end
  end

  # Servers customize the Basic server and perhaps combine it with a handler.
  module Server
    # Basic server utilizing threads for handling sessions.
    #
    # It lacks a mutex around access to @clients, in case you'd want to stress
    # test it for 10K or something.
    #
    # @attr handler [Handler] Session handler
    # @attr address [String]  Address to listen to
    # @attr port    [Integer] Session dispatcher port
    # @attr clients [Hash]    Current sessions
    class Base
      attr_reader :handler, :address, :port, :clients

      # Initialize the server.
      #
      # Options:
      # 
      #  - :address => address to listen to (default: '0.0.0.0')
      #  - :port    => dispatcher port (default: 69)
      #  - :logger  => logger instance
      #
      # @param handler  [Handler]  Initialized session handler
      # @param opts     [Hash]     Options
      def initialize(handler, opts = {})
        @handler = handler

        @address = opts[:address] || '0.0.0.0'
        @port    = opts[:port] || 69
        @logger  = opts[:logger]

        @clients = Hash.new
        @run = false
      end

      # Run the main server loop.
      #
      # This is obviously blocking.
      def run!
        log :info, "UDP server loop at #{@address}:#{@port}"
        @run = true
        Socket.udp_server_loop(@address, @port) do |msg, src|
          break unless @run

          addr = src.remote_address
          tag = "[#{addr.ip_address}:#{addr.ip_port.to_s.ljust(5)}]"
          log :info, "#{tag} New initial packet received"

          begin
            pkt = Packet.parse(msg)
          rescue ParseError => e
            log :warn, "#{tag} Packet parse error: #{e.to_s}"
            next
          end

          log :debug, "#{tag} -> PKT: #{pkt.inspect}"
          tid = get_tid
          tag = "[#{addr.ip_address}:#{addr.ip_port.to_s.ljust(5)}:#{tid.to_s.ljust(5)}]"
          sock = addr.connect_from(@address, tid)
          @clients[tid] = tag

          unless pkt.is_a?(Packet::RRQ) || pkt.is_a?(Packet::WRQ)
            log :warn, "#{tag} Bad initial packet: #{pkt.class}"
            sock.send(Packet::ERROR.new(4, 'Illegal TFTP operation.').encode, 0)
            sock.close
            next
          end

          Thread.new do
            @handler.run!(tag, pkt, sock, src)
            @clients.delete(tid)
            log :info, "#{tag} Session ended"
          end
        end
        log :info, 'UDP server loop has stopped'
      end

      # Stop the main server loop.
      #
      # This will allow the currently pending sessions to finish.
      def stop
        log :info, 'Stopping UDP server loop'
        @run = false
        UDPSocket.new.send('break', 0, @address, @port)
      end

      private
      # Get the server's TID.
      #
      # The TID is basically a random port number we will use for a session.
      # This actually tries to get a unique TID per session.
      # It uses only ports 1024 - 65535 as not to require root.
      def get_tid
        tid = 1024 + rand(64512)
        tid = 1024 + rand(64512) while @clients.has_key? tid
        tid
      end

      def log(level, msg)
        @logger.send(level, msg) if @logger
      end
    end

    # Basic read-write TFTP server.
    #
    # This is what most other TFTPd implementations give you.
    class RWSimple < Base
      def initialize(path, opts = {})
        handler = Handler::RWSimple.new(path, opts)
        super(handler, opts)
      end
    end
  end
end
