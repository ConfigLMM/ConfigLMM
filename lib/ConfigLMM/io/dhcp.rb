
require 'net/dhcp'
require 'socket'
require 'securerandom'
require 'zlib'

module ConfigLMM
    module IO
        class DHCP
            READ_SIZE = 1500
            MIN_SIZE = 300

            DHCP_BROADCAST_FLAG = 0x8000
            DHCP_CLIENTMACHINEID = 0x61 # Option 97 - Client Machine Identifier
            DHCP_UUID_IDENTIFIER = 0x00

            def initialize(logger)
                @Logger = logger
                @ServerSocket = UDPSocket.new
                @ServerSocket.do_not_reverse_lookup = true
                @ServerSocket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
                @ServerSocket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
                @ServerSocket.setsockopt(Socket::IPPROTO_IP, Socket::IP_PKTINFO, true)
                @ServerSocket.bind('0.0.0.0', 67)
                @Logger.debug('Listening on UDP port 67 (DHCP Server)')

                @ClientSocket = UDPSocket.new
                @ClientSocket.do_not_reverse_lookup = true
                @ClientSocket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
                @ClientSocket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
                @ClientSocket.setsockopt(Socket::IPPROTO_IP, Socket::IP_PKTINFO, true)
                @ClientSocket.bind('0.0.0.0', 68)
                @Logger.debug('Listening on UDP port 68 (DHCP Client)')

                @ProxyServerSocket = UDPSocket.new
                @ProxyServerSocket.do_not_reverse_lookup = true
                @ProxyServerSocket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
                @ProxyServerSocket.bind('0.0.0.0', 4011)
                @Logger.debug('Listening on UDP port 4011 (proxyDHCP Server)')
            end

            def sendDiscover(mac)
                discover = ::DHCP::Discover.new(flags: DHCP_BROADCAST_FLAG,
                                                chaddr: [mac + '00000000000000000000'].pack('H*').unpack('C16'))
                targetAddr = '<broadcast>'
                @ClientSocket.send(discover.pack, 0, targetAddr, 67)
                discover
            end

            def waitDiscover(timeout, useHTTP)
                @Logger.info('Waiting for DHCP Discover request')
                timeoutTime = Time.now + timeout
                msgs = {}
                loop do
                    return msgs if Time.now >= timeoutTime
                    data, sender_sockaddr, rflags, *controls = @ServerSocket.recvmsg_nonblock()
                    ipinfo = controls.find { |ancillary| ancillary.cmsg_is?(:IP, :PKTINFO) }.ip_pktinfo
                    if data.bytesize >= MIN_SIZE
                        message = ::DHCP::Message.from_udp_payload(data)
                        if isValidDiscover?(message, useHTTP)
                            msgs[ipinfo] = message
                            timeoutTime = Time.now + 0.0001
                        else
                            @Logger.debug("Ignoring unexpected DHCP request packet")
                        end
                    else
                        @Logger.debug("Ignoring too small DHCP packet")
                    end
                rescue ::IO::WaitReadable
                    ::IO.select([@ServerSocket], [], [], 0.0001)
                    retry
                end
                msgs
            end

            def waitOffer(discoverMessage, timeout)
                @Logger.info('Waiting for DHCP Offer response')
                timeoutTime = Time.now + timeout
                loop do
                    return false if Time.now >= timeoutTime
                    data, inetAddr  = @ClientSocket.recvfrom_nonblock(READ_SIZE)
                    if data.bytesize >= MIN_SIZE
                        message = ::DHCP::Message.from_udp_payload(data)
                        if message.xid == discoverMessage.xid && message.chaddr[0, message.hlen] == discoverMessage.chaddr[0, discoverMessage.hlen]
                            return message
                        else
                            @Logger.debug("Ignoring unexpected DHCP response packet")
                        end
                    else
                        @Logger.debug("Ignoring too small DHCP packet")
                    end
                rescue ::IO::WaitReadable
                    ::IO.select([@ClientSocket], [], [], 0.1)
                    retry
                end
                false
            end

            def packUUID(uuid)
                uuidParts = uuid.split('-')
                uuidParts[0, 3].map(&:reverse).pack('h*h*h*') + uuidParts[3, 2].pack('H*H*')
            end

            def sendOffer(discoverMessageInfo, isFullDHCP, networkOptions, bootFile, bootFileSize)
                ipinfo, discoverMessage = discoverMessageInfo
                fname = bootFile
                sname = networkOptions['IP']
                siaddr = networkOptions['IP'].split('.').map(&:to_i).pack('C4').unpack('N').first
                yiaddr = 0
                useHTTP = bootFile.start_with?('http://')
                etherboot = discoverMessage.options.find { |option| option.is_a?(::DHCP::PrivateOption) } # Etherboot
                # Etherboot won't HTTP boot as HTTPClient...
                vendorClass = useHTTP && !etherboot ? 'HTTPClient' : 'PXEClient'

                if isFullDHCP
                  yiaddr = networkOptions['ClientIP'].split('.').map(&:to_i).pack('C4').unpack('N').first
                end
                options = [
                    ::DHCP::MessageTypeOption.new(payload: [$DHCP_MSG_OFFER]),
                    ::DHCP::ServerIdentifierOption.new(payload: networkOptions['IP'].split('.').map(&:to_i)),
                    ::DHCP::Option.new(type: $DHCP_BOOTFILESIZE, payload: [(bootFileSize / 512.0).ceil].pack('n').unpack('C*')),
                    ::DHCP::Option.new(type: $DHCP_BOOTFILENAME, payload: bootFile.unpack('C*') + [0]),
                    ::DHCP::VendorClassIDOption.new(payload: vendorClass.unpack('C*'))
                ]

                if !useHTTP
                    options << ::DHCP::Option.new(type: $DHCP_TFTPSERVER, payload: networkOptions['IP'].unpack('C*') + [0])
                end

                clientMachineIdOption = discoverMessage.options.find { |option| option.type == DHCP_CLIENTMACHINEID }
                if clientMachineIdOption
                    options << clientMachineIdOption
                end
                if isFullDHCP
                    options << ::DHCP::RequestedIPAddressOption.new({ payload: networkOptions['ClientIP'].split('.').map(&:to_i) })
                    options << ::DHCP::IPAddressLeaseTimeOption.new()
                    options << ::DHCP::Option.new(type: $DHCP_RENEWTIME, payload: [3600].pack('N').unpack('C*'))
                    options << ::DHCP::Option.new(type: $DHCP_REBINDTIME, payload: [3600].pack('N').unpack('C*'))
                    options << ::DHCP::SubnetMaskOption.new(payload: networkOptions['Subnet'].split('.').map(&:to_i))
                    options << ::DHCP::BroadcastAddressOption.new(payload: networkOptions['Broadcast'].split('.').map(&:to_i))
                    options << ::DHCP::RouterOption.new(payload: networkOptions['Gateway'].split('.').map(&:to_i)) if networkOptions['Gateway']
                    options << ::DHCP::DomainNameServerOption.new(payload: networkOptions['DNS'].split('.').map(&:to_i)) if networkOptions['DNS']
                end

                offer = ::DHCP::Offer.new(xid: discoverMessage.xid,
                                          flags: discoverMessage.flags & DHCP_BROADCAST_FLAG,
                                          siaddr: siaddr,
                                          yiaddr: yiaddr,
                                          chaddr: discoverMessage.chaddr,
                                          sname: sname,
                                          fname: fname,
                                          options: options)
                targetAddr = '<broadcast>'
                #targetAddr = networkOptions['ClientIP'] if (discoverMessage.flags & DHCP_BROADCAST_FLAG).zero?
                sockaddr = Socket.sockaddr_in(68, targetAddr)
                @ServerSocket.sendmsg(offer.pack, 0, sockaddr, Socket::AncillaryData.ip_pktinfo(*ipinfo))
                offer
            end

            def sendRequest(discoverMessage, offerRequest)
                options = [::DHCP::MessageTypeOption.new({:payload=>[$DHCP_MSG_REQUEST]}), ::DHCP::ParameterRequestListOption.new]
                serverIdentifier = offerRequest.options.find { |opt| opt.is_a?(::DHCP::ServerIdentifierOption) }
                options << serverIdentifier if serverIdentifier
                options << ::DHCP::RequestedIPAddressOption.new(payload: [offerRequest.yiaddr].pack('N').unpack('C4'))
                request = ::DHCP::Request.new(
                    xid: discoverMessage.xid,
                    flags: DHCP_BROADCAST_FLAG,
                    chaddr: discoverMessage.chaddr,
                    options: options)
                targetAddr = '<broadcast>'
                @ClientSocket.send(request.pack, 0, targetAddr, 67)
                request
            end

            def waitRequest(offerRequest, timeout)
                @Logger.info('Waiting for DHCP Request response')
                timeoutTime = Time.now + timeout
                msgs = {}
                loop do
                    return msgs if Time.now >= timeoutTime
                    data, sender_sockaddr, rflags, *controls = @ServerSocket.recvmsg_nonblock()
                    ipinfo = controls.find { |ancillary| ancillary.cmsg_is?(:IP, :PKTINFO) }.ip_pktinfo
                    if data.bytesize >= MIN_SIZE
                        message = ::DHCP::Message.from_udp_payload(data)
                        if isValidRequest?(message, offerRequest)
                            msgs[ipinfo] = message
                            timeoutTime = Time.now + 0.1
                        elsif message.is_a?(::DHCP::Request)
                            @Logger.info("Some router received DHCP Request packet")
                        elsif message.is_a?(::DHCP::Discover)
                            @Logger.debug("Received DHCP Discover packet, resending DHCP Offer")
                            sockaddr = Socket.sockaddr_in(68, '<broadcast>')
                            @ServerSocket.sendmsg(offerRequest.pack, 0, sockaddr, Socket::AncillaryData.ip_pktinfo(*ipinfo))
                        else
                            @Logger.debug("Ignoring unexpected DHCP response packet")
                        end
                    else
                        @Logger.debug("Ignoring too small DHCP packet")
                    end
                rescue ::IO::WaitReadable
                    ::IO.select([@ServerSocket], [], [], 0.1)
                    retry
                end
                msgs
            end

            def createACK(requestMessage, offerRequest)
                options = offerRequest.options.dup
                options.delete_if { |option| option.is_a?(::DHCP::MessageTypeOption) }
                ack = ::DHCP::ACK.new(xid: requestMessage.xid,
                                      flags: requestMessage.flags,
                                      ciaddr: offerRequest.ciaddr,
                                      yiaddr: offerRequest.yiaddr,
                                      siaddr: offerRequest.siaddr,
                                      giaddr: offerRequest.giaddr,
                                      chaddr: offerRequest.chaddr,
                                      sname: offerRequest.sname,
                                      fname: offerRequest.fname,
                                      options: [::DHCP::MessageTypeOption.new(payload: [$DHCP_MSG_ACK])] + options)
                ack
            end

            def waitACK(discoverMessage, requestMessage, timeout)
                @Logger.info('Waiting for DHCP ACK response')
                timeoutTime = Time.now + timeout
                loop do
                    return false if Time.now >= timeoutTime
                    data, sender_sockaddr, rflags, *controls = @ClientSocket.recvmsg_nonblock()
                    ipinfo = controls.find { |ancillary| ancillary.cmsg_is?(:IP, :PKTINFO) }.ip_pktinfo
                    if data.bytesize >= MIN_SIZE
                        message = ::DHCP::Message.from_udp_payload(data)
                        if message.xid == discoverMessage.xid && message.chaddr[0, message.hlen] == discoverMessage.chaddr[0, discoverMessage.hlen]
                            return [ipinfo, message]
                        else
                            @Logger.debug("Ignoring unexpected DHCP response packet")
                        end
                    else
                        @Logger.debug("Ignoring too small DHCP packet")
                    end
                rescue ::IO::WaitReadable
                    ::IO.select([@ClientSocket], [], [], 0.1)
                    retry
                end
                false
            end

            def sendACK(requestMessageInfo, offerRequest)
                ipinfo, requestMessage = requestMessageInfo
                ack = createACK(requestMessage, offerRequest)
                targetAddr = '<broadcast>'
                #targetAddr = [offerRequest.yiaddr].pack('N').unpack('C4').join('.') if (offerRequest.flags & DHCP_BROADCAST_FLAG).zero?
                sockaddr = Socket.sockaddr_in(68, targetAddr)
                @ServerSocket.sendmsg(ack.pack, 0, sockaddr, Socket::AncillaryData.ip_pktinfo(*ipinfo))
            end

            def waitProxyRequest(timeout)
                @Logger.info('Waiting for proxyDHCP Request response')
                timeoutTime = Time.now + timeout
                loop do
                    return false if Time.now >= timeoutTime
                    data, inetAddr  = @ProxyServerSocket.recvfrom_nonblock(READ_SIZE)
                    if data.bytesize >= MIN_SIZE
                        message = ::DHCP::Message.from_udp_payload(data)
                        if isValidProxyRequest?(message)
                            return message
                        else
                            @Logger.debug("Ignoring unexpected DHCP response packet")
                        end
                    else
                        @Logger.debug("Ignoring too small DHCP packet")
                    end
                rescue ::IO::WaitReadable
                    ::IO.select([@ProxyServerSocket], [], [], 0.1)
                    retry
                end
                false
            end

            def sendProxyACK(proxyRequestMessage, offerRequest)
                ack = createACK(proxyRequestMessage, offerRequest)
                ack.ciaddr = proxyRequestMessage.ciaddr
                targetAddr = [proxyRequestMessage.ciaddr].pack('N').unpack('C4').join('.')
                @ProxyServerSocket.send(ack.pack, 0, targetAddr, 4011)
            end

            def isValidDiscover?(message, useHTTP)
                isValid = message.is_a?(::DHCP::Discover) &&
                message.htype == $DHCP_HTYPE_ETHERNET &&
                message.hlen == $DHCP_HLEN_ETHERNET &&
                message.giaddr.zero?
                return isValid unless isValid
                if useHTTP
                    clientArchOption = message.options.find { |option| option.is_a?(::DHCP::ClientSystemArchitectureOption) }
                    return true if clientArchOption && clientArchOption.payload.pack('C*').unpack('n').first == 0x0010 # x64 UEFI HTTP
                    return true if message.options.find { |option| option.is_a?(::DHCP::PrivateOption) } # Etherboot
                else
                    message.options.each do |option|
                        return true if option.is_a?(::DHCP::ParameterRequestListOption) &&
                                       option.payload.include?($DHCP_TFTPSERVER) &&
                                       option.payload.include?($DHCP_BOOTFILENAME)
                    end
                end
                false
            end

            def isValidRequest?(message, offerRequest)
                isValid = message.is_a?(::DHCP::Request) &&
                message.htype == $DHCP_HTYPE_ETHERNET &&
                message.hlen == $DHCP_HLEN_ETHERNET &&
                message.giaddr.zero? &&
                message.xid == offerRequest.xid &&
                message.chaddr[0, message.hlen] == offerRequest.chaddr[0, offerRequest.hlen]

                return isValid unless isValid
                message.options.each do |option|
                    return true if option.is_a?(::DHCP::ServerIdentifierOption) &&
                                   option.payload == offerRequest.options.find { |offerOption| offerOption.is_a?(::DHCP::ServerIdentifierOption) }.payload
                end
                false
            end

            def isValidProxyRequest?(message)
                isValid = message.is_a?(::DHCP::Request) &&
                message.htype == $DHCP_HTYPE_ETHERNET &&
                message.hlen == $DHCP_HLEN_ETHERNET &&
                message.giaddr.zero?
            end

        end
    end
end
