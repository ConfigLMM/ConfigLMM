
require_relative 'dhcp'
require_relative 'http'
require_relative 'tftp'

require 'socket'

module ConfigLMM
    module IO
        class PXE

            def self.createMac(id)
                '000101' + Zlib.crc32(id).to_s(16).ljust(8, '0')[2, 6]
            end

            def self.fillNetworkInfo(networkOptions, dhcp)
                discoverMessage = dhcp.sendDiscover(self.createMac(networkOptions['ID']))
                offerMessage = dhcp.waitOffer(discoverMessage, 10)
                raise 'Didn\'t receive DHCP Offer' unless offerMessage
                requestMessage = dhcp.sendRequest(discoverMessage, offerMessage)
                ipinfo, ackMessage = dhcp.waitACK(discoverMessage, requestMessage, 5)
                raise 'Didn\'t receive DHCP ACK' unless ackMessage

                networkOptions['IP'] = ipinfo.last.ip_address
                networkOptions['ClientIP'] = [ackMessage.yiaddr].pack('N').unpack('C4').join('.')

                networkOptions['Subnet'] = '255.255.255.0'
                subnet = ackMessage.options.find { |opt| opt.is_a?(::DHCP::SubnetMaskOption) }
                networkOptions['Subnet'] = subnet.payload.join('.') if subnet

                broadcast = ackMessage.options.find { |opt| opt.is_a?(::DHCP::BroadcastAddressOption) }
                networkOptions['Broadcast'] = broadcast.payload.join('.') if broadcast

                dns = ackMessage.options.find { |opt| opt.is_a?(::DHCP::DomainNameServerOption) }
                networkOptions['DNS'] = dns.payload.join('.') if dns

                router = ackMessage.options.find { |opt| opt.is_a?(::DHCP::RouterOption) }
                networkOptions['Gateway'] = dns.payload.join('.') if router
            end

            def self.findMessageByIP(messages, ip)
                if messages.length > 1
                    keys = messages.keys.select { |ipinfo| ipinfo.last.ip_address == ip }
                    raise "Couldn't match DHCP Discover message to respective interface" if keys.empty?
                else
                    keys = [messages.keys.first]
                end
                [keys.first, messages[keys.first]]
            end

            def self.boot(dir, uri, networkOptions, bootFileResolver, options, logger)
                dhcp = DHCP.new(logger)
                if networkOptions['IP'].nil?
                    self.fillNetworkInfo(networkOptions, dhcp)
                end

                useHTTP = uri.scheme == 'pxe+http'
                server = useHTTP ? HTTP.new(dir, networkOptions['IP'], options, logger) : TFTP.new(dir, networkOptions['IP'], logger)
                server.start

                discoverMessages = dhcp.waitDiscover(5 * 60, useHTTP)
                raise 'Timeout while waiting for valid DHCP Discover request!' if discoverMessages.empty?
                discoverMessageInfo = self.findMessageByIP(discoverMessages, networkOptions['IP'])
                #offerMessage = dhcp.waitOffer(discoverMessageInfo, 5)
                isFullDHCP = true #offerMessage.nil?

                clientArch = 0x0000
                clientArchOption = discoverMessageInfo.last.options.find { |option| option.is_a?(::DHCP::ClientSystemArchitectureOption) }
                clientArch = clientArchOption.payload.pack('C*').unpack('n').first if clientArchOption
                bootFile = bootFileResolver.call(clientArch)
                bootFileSize = File.size(dir + bootFile)
                bootFile = server.url(bootFile) if useHTTP

                offerRequest = dhcp.sendOffer(discoverMessageInfo, isFullDHCP, networkOptions, bootFile, bootFileSize)
                if isFullDHCP
                    requestMessages = dhcp.waitRequest(offerRequest, 10)
                    requestMessageInfo = self.findMessageByIP(requestMessages, networkOptions['IP'])
                    raise 'Timeout while waiting for valid DHCP Request!' if requestMessages.empty?
                    dhcp.sendACK(requestMessageInfo, offerRequest)
                end
                if clientArch != 0x0000 && !useHTTP
                    proxyRequestMessage = dhcp.waitProxyRequest(20)
                    raise 'Timeout while waiting for valid proxyDHCP Request!' unless proxyRequestMessage
                    dhcp.sendProxyACK(proxyRequestMessage, offerRequest)
                end
                logger.info('Sent DHCP ACK response, now waiting for system to boot')
                server.wait(3 * 60)
                raise 'Didn\'t receive boot file read!' unless server.hadRead?
                server.stop()
            end
        end
    end
end
