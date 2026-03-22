# frozen_string_literal: true

require 'ipaddr'

module ConfigLMM
    module IO
        class ICMP
            ICMP_ECHOREPLY      =   0
            ICMP_ECHO           =   8
            ICMPV6_ECHO_REQUEST = 128
            ICMPV6_ECHO_REPLY   = 129

            def self.ping(uri, options, prompt, logger)
                addrs = Addrinfo.getaddrinfo(uri.hostname, nil, :UNSPEC, :DGRAM)
                addrs.each do |ai|
                    next unless [Socket::AF_INET, Socket::AF_INET6].include?(ai.afamily)
                    return true if self.pingAddr(ai)
                end
                false
            rescue StandardError => error
                return false if IO.error?(error)
                raise error
            end

            def self.pingAddr(ai)
                socket = nil

                ipv6 = ai.afamily == Socket::AF_INET6
                protocol = ipv6 ? Socket::IPPROTO_ICMPV6 : Socket::IPPROTO_ICMP

                socket = Socket.new(ai.afamily, Socket::SOCK_DGRAM, protocol)
                socket.bind(Socket.sockaddr_in(0, ipv6 ? "::" : "0.0.0.0"))
                socket.connect(ai)

                id = (Thread.current.object_id ^ Process.pid) & 0xffff
                seq = 1
                payload = 'ConfigLMM Ping!'
                packet = buildPacket(ipv6, id, seq, payload)
                if ipv6
                    src = IPAddr.new(socket.local_address.ip_address).hton
                    dst = IPAddr.new(ai.ip_address).hton
                    csum = checksumV6(src, dst, packet)
                else
                    csum = checksum(packet)
                end

                packet[2, 2] = [csum].pack("n")

                socket.send(packet, 0, ai)

                deadline = Time.now + 5
                data = nil
                begin
                    remaining = deadline - Time.now
                    data, _ = socket.recvfrom_nonblock(1500)
                    type, code, _, rid, rseq = data.unpack("C2 n3")
                    etype = ipv6 ? ICMPV6_ECHO_REPLY : ICMP_ECHOREPLY
                    return true if type == etype && rseq == seq
                rescue ::IO::WaitReadable
                    return false unless ::IO.select([socket], nil, nil, remaining)
                    retry
                end
                false
            ensure
                socket.close if socket
            end

            def self.buildPacket(ipv6, id, seq, payload)
                type = ipv6 ? ICMPV6_ECHO_REQUEST : ICMP_ECHO
                code = 0
                checksum = 0

                header = [type, code, checksum, id, seq].pack("C2 n3")
                header + payload
            end

            def self.checksum(data)
                data += "\x00" if data.bytesize.odd?
                sum = data.unpack("n*").sum
                sum = (sum >> 16) + (sum & 0xffff)
                sum += (sum >> 16)
                (~sum) & 0xffff
            end

            def self.checksumV6(src, dst, payload)
                pseudo = [
                    src, dst,
                    payload.bytesize,
                    0, 0, 0,
                    Socket::IPPROTO_ICMPV6
                ].pack("a16 a16 N C3 C")

                checksum(pseudo + payload)
            end

        end
    end
end
