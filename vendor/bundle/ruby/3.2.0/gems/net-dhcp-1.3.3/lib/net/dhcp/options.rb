=begin
**
** options.rb
** 29/OCT/2007
** ETD-Software
**  - Daniel Martin Gomez <etd[-at-]nomejortu.com>
**
** Desc:
**   This file provides a set of classes to work with the DHCP protocol.
** Here are defined the classes to work with the different options of the
** protocol as defined in rfc2131, rfc2132 and rfc2563.
**
**   See the provided rdoc comments for further information.
**
** Version:
**  v1.0 [29/October/2007]: first released
**
** License:
**   Please see dhcp.rb or LICENSE.txt for copyright and licensing information.
**
=end

module DHCP

  # General object to capture DHCP options. Every option of the protocol has
  # three fields: an option *type*, a defined *length* and a *payload*
  class Option
    attr_accessor :type, :len, :payload

    # Create a DHCP option object with the given *type* and *payload*. +params+
    # must be an array containing at least these two keys: :*type* and :*payload*
    # The length is calculated with the size of the payload
    def initialize(params = {})
      # We need a type, and a payload
      if (([:type, :payload] & params.keys).size != 2)
        raise ArgumentError, 'you need to specify values for :type and :payload'
      end

      self.type = params[:type]
      self.payload = params[:payload]
      self.len = params.fetch(:len, self.payload.size)
    end

    # Return the option packed as an array of bytes. The first two elements
    # are the type and length of this option. The payload follows afterwards.
    def to_a
      return [self.type, self.len] + self.payload
    end

    # Return the option packed as a binary string.
    def pack
      (self.to_a).pack('C*')
    end

    # Check wether a given option is equivalent (protocol level) to this one.
    def eql?(obj)
      return false unless (self.class == obj.class)

      vars = self.instance_variables
      # check all the other instance vairables
      vars.each do |var|
        return false unless (self.instance_variable_get(var) == obj.instance_variable_get(var))
      end
      return true
    end
    alias == eql?

    def to_s
      "to_s NOT implemented for option type: #{self.type}"
    end
  end


  # The subnet mask option specifies the client's subnet mask as per RFC
  # 950 [5].
  #
  # If both the subnet mask and the router option are specified in a DHCP
  # reply, the subnet mask option MUST be first.
  #
  # The code for the subnet mask option is 1, and its length is 4 octets.
  #
  # The default value for this option is 255.255.255.255
  class SubnetMaskOption < Option
    def initialize(params={})
      params[:type] = $DHCP_SUBNETMASK
      params[:payload] = params.fetch(:payload, [255, 255, 255, 255])
      super(params)
    end

    def to_s()
      "Subnet Mask = #{self.payload.join('.')}"
    end
  end


  # The router option specifies a list of IP addresses for routers on the
  # client's subnet.  Routers SHOULD be listed in order of preference.
  #
  # The code for the router option is 3.  The minimum length for the
  # router option is 4 octets, and the length MUST always be a multiple
  # of 4.
  #
  # The default value for this option is 0.0.0.0
  class RouterOption < Option
    def initialize(params={})
      params[:type] = $DHCP_ROUTER
      params[:payload] = params.fetch(:payload, [0, 0, 0, 0])
      super(params)
    end

    def to_s()
      "Router = #{self.payload.join('.')}"
    end
  end

  # The domain name server option specifies a list of Domain Name System
  # (STD 13, RFC 1035 [8]) name servers available to the client.  Servers
  # SHOULD be listed in order of preference.
  #
  # The code for the domain name server option is 6.  The minimum length
  # for this option is 4 octets, and the length MUST always be a multiple
  # of 4.
  #
  # The default value for this option is 0.0.0.0
  class DomainNameServerOption < Option
    def initialize(params={})
      params[:type] = $DHCP_DNS
      params[:payload] = params.fetch(:payload, [0, 0, 0, 0])
      super(params)
    end

    def to_s()
      "Domain Name Server = #{self.payload.join('.')}"
    end
  end

  # This option specifies the name of the client.  The name may or may
  # not be qualified with the local domain name (see section 3.17 for the
  # preferred way to retrieve the domain name).  See RFC 1035 for
  # character set restrictions.
  #
  # The code for this option is 12, and its minimum length is 1.
  #
  # The default value for this option is 'caprica'
  class HostNameOption < Option
    def initialize(params={})
      params[:type] = $DHCP_HOSTNAME
      params[:payload] = params.fetch(:payload, 'caprica'.unpack('C*'))
      super(params)
    end

    def to_s()
      "Host Name = #{self.payload.pack('C*')}"
    end
  end

  # This option specifies the domain name that client should use when
  # resolving hostnames via the Domain Name System.
  #
  # The code for this option is 15.  Its minimum length is 1.
  #
  # The default value for this option is "nomejortu.com"
  class DomainNameOption < Option
    def initialize(params={})
      params[:type] = $DHCP_DOMAINNAME
      params[:payload] = params.fetch(:payload, 'nomejortu.com'.unpack('C*'))
      super(params)
    end

    def to_s()
      "Domain Name = #{self.payload.pack('C*')}"
    end
  end

  # This option specifies the broadcast address in use on the client's
  # subnet.  Legal values for broadcast addresses are specified in
  # section 3.2.1.3 of [4].
  #
  # The code for this option is 28, and its length is 4.
  #
  # The default value for this option is 255.255.255.255
  class BroadcastAddressOption < Option
    def initialize(params={})
      params[:type] = $DHCP_BROADCASTADDR
      params[:payload] = params.fetch(:payload, [255, 255, 255, 255])
      super(params)
    end

    def to_s()
      "Broadcast Adress = #{self.payload.join('.')}"
    end
  end

  # This option is used in a client request (DHCPDISCOVER) to allow the
  # client to request that a particular IP address be assigned.
  #
  # The code for this option is 50, and its length is 4.
  #
  # The default value for this option is 0.0.0.0
  class RequestedIPAddressOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_DISCOVERADDR
      params[:payload] = params.fetch(:payload, [0, 0, 0, 0])
      super(params)
    end

    def to_s
      "Requested IP address = #{self.payload.join('.')}"
    end
  end

  # This option is used in a client request (DHCPDISCOVER or DHCPREQUEST)
  # to allow the client to request a lease time for the IP address.  In a
  # server reply (DHCPOFFER), a DHCP server uses this option to specify
  # the lease time it is willing to offer.
  #
  # The time is in units of seconds, and is specified as a 32-bit
  # unsigned integer.
  #
  # The code for this option is 51, and its length is 4.
  #
  # The default value is 7200 (2h)
  class IPAddressLeaseTimeOption < Option
    def initialize(params={})
      params[:type] = $DHCP_LEASETIME
      params[:payload] = params.fetch(:payload, [7200].pack('N').unpack('C*'))
      super(params)
    end

    def to_s()
      value = self.payload.pack('C*').unpack('N').first
      value = "infinite" if value == 0xffffffff

      "IP Address Lease Time = #{value} seg"
    end
  end

  # This option is used to convey the type of the DHCP message.  The code
  # for this option is 53, and its length is 1.  Legal values for this
  # option are:
  #
  #         Value   Message Type
  #         -----   ------------
  #           1     DHCPDISCOVER
  #           2     DHCPOFFER
  #           3     DHCPREQUEST
  #           4     DHCPDECLINE
  #           5     DHCPACK
  #           6     DHCPNAK
  #           7     DHCPRELEASE
  #           8     DHCPINFORM
  #
  # The default value is 1 (DHCPDISCOVER)
  class MessageTypeOption < Option
    #DEBUG
    def initialize(params={})
      params[:type] = $DHCP_MESSAGETYPE
      params[:payload] = params.fetch(:payload, [$DHCP_MSG_DISCOVER])
      super(params)
    end

    def to_s
      "DHCP Message Type = #{$DHCP_MSG_NAMES[self.payload[0]-1]} (#{self.payload[0]})"
    end
  end


  # This option is used in DHCPOFFER and DHCPREQUEST messages, and may
  # optionally be included in the DHCPACK and DHCPNAK messages.  DHCP
  # servers include this option in the DHCPOFFER in order to allow the
  # client to distinguish between lease offers.  DHCP clients use the
  # contents of the 'server identifier' field as the destination address
  # for any DHCP messages unicast to the DHCP server.  DHCP clients also
  # indicate which of several lease offers is being accepted by including
  # this option in a DHCPREQUEST message.
  #
  # The identifier is the IP address of the selected server.
  #
  # The code for this option is 54, and its length is 4.
  #
  # The default value is 0.0.0.0
  class ServerIdentifierOption < Option
    def initialize(params={})
      params[:type] = $DHCP_SERVIDENT
      params[:payload] = params.fetch(:payload, [0, 0, 0, 0])
      super(params)
    end

    def to_s
      "Server Identifier = #{self.payload.join('.')}"
    end
  end

  # This option is used by a DHCP client to request values for specified
  # configuration parameters.  The list of requested parameters is
  # specified as n octets, where each octet is a valid DHCP option code
  # as defined in this document.
  #
  # The client MAY list the options in order of preference.  The DHCP
  # server is not required to return the options in the requested order,
  # but MUST try to insert the requested options in the order requested
  # by the client.
  #
  # The code for this option is 55.  Its minimum length is 1.
  #
  # The default value is: $DHCP_SUBNETMASK | $DHCP_ROUTER | $DHCP_DNS | $DHCP_DOMAINNAME
  class ParameterRequestListOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_PARAMREQUEST
      params[:payload] = params.fetch(:payload, [$DHCP_SUBNETMASK, $DHCP_ROUTER, $DHCP_DNS, $DHCP_DOMAINNAME])
      super(params)
    end

    def to_s
      "Parameter Request List = #{self.payload.join(',')}"
    end
  end

  # This option is used by DHCP clients to optionally identify the vendor
  # type and configuration of a DHCP client.  The information is a string
  # of n octets, interpreted by servers.  Vendors may choose to define
  # specific vendor class identifiers to convey particular configuration
  # or other identification information about a client.  For example, the
  # identifier may encode the client's hardware configuration.  Servers
  # not equipped to interpret the class-specific information sent by a
  # client MUST ignore it (although it may be reported). Servers that
  #
  # respond SHOULD only use option 43 to return the vendor-specific
  # information to the client.
  #
  # The code for this option is 60, and its minimum length is 1.
  #
  # The default value is: 'etdsoft'
  class VendorClassIDOption < Option
    def initialize(params={})
      params[:type] = $DHCP_CLASSSID
      params[:payload] = params.fetch(:payload, 'etdsoft'.unpack('C*'))
      super(params)
    end

    def to_s()
      "Vendor class identifier = #{self.payload.pack('C*')}"
    end
  end


  # This option is used by DHCP clients to specify their unique
  # identifier.  DHCP servers use this value to index their database of
  # address bindings.  This value is expected to be unique for all
  # clients in an administrative domain.
  #
  # Identifiers SHOULD be treated as opaque objects by DHCP servers.
  #
  # The client identifier MAY consist of type-value pairs similar to the
  # 'htype'/'chaddr' fields defined in [3]. For instance, it MAY consist
  # of a hardware type and hardware address. In this case the type field
  # SHOULD be one of the ARP hardware types defined in STD2 [22].  A
  # hardware type of 0 (zero) should be used when the value field
  # contains an identifier other than a hardware address (e.g. a fully
  # qualified domain name).
  #
  # For correct identification of clients, each client's client-
  # identifier MUST be unique among the client-identifiers used on the
  # subnet to which the client is attached.  Vendors and system
  # administrators are responsible for choosing client-identifiers that
  # meet this requirement for uniqueness.
  #
  # The code for this option is 61, and its minimum length is 2.
  #
  # The default value is: 0x6969
  class ClientIdentifierOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_CLIENTID
      params[:payload] = params.fetch(:payload, [0x69, 0x69])
      super(params)
    end

    def to_s
      "Client Identifier = #{self.payload}"
    end
  end

  # Option that can be used to exchange information about a
  # DHCPv4 client's fully qualified domain name and about responsibility
  # for updating the DNS RR related to the client's address assignment.
  #
  # See rfc4702 for full details
  #
  # The code for this option is 81, and its minimun length is 3.
  #
  # The default payload for this option is 'etd'
  class ClientFQDNOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_CLIENTFQDN
      params[:payload] = params.fetch(:payload, 'etd'.unpack('C*'))
      super(params)
    end

    def to_s
      "Client Fully Qualified Domain Name = #{self.payload.pack('C*')}"
    end
  end

  # Octet "n" gives the number of octets containing "architecture types"
  # (not including the code and len fields).  It MUST be an even number
  # greater than zero.  Clients that support more than one architecture
  # type MAY include a list of these types in their initial DHCP and PXE
  # boot server packets.  The list of supported architecture types MAY be
  # reduced in any packet exchange between the client and server(s).
  # Octets "n1" and "n2" encode a 16-bit architecture type identifier
  # that describes the pre-boot runtime environment(s) of the client
  # machine.
  #
  # See rfc4578 for full details
  #
  # The code for this option is 93, and its length must be an even number
  # greater than zero.
  #
  # The default payload for this option is $DHCP_CLIENTARCH_I386
  class ClientSystemArchitectureOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_CLIENTARCH
      params[:payload] = params.fetch(:payload, [$DHCP_CLIENTARCH_I386].pack('n').unpack('C*'))
      super(params)
    end
    def to_s
      arch_id = self.payload.pack('C*').unpack('n').first
      if (arch_id > ($DHCP_CLIENTARCH_NAMES.size-1))
        arch = 'unknown'
      else
        arch = $DHCP_CLIENTARCH_NAMES[arch_id]
      end

      "Client System Architecture = #{arch}"
    end
  end

  # Octet "t" encodes a network interface type.  For now the only
  # supported value is 1 for Universal Network Device Interface (UNDI).
  # Octets "M" and "m" describe the interface revision.  To encode the
  # UNDI revision of 2.11, "M" would be set to 2, and "m" would be set to
  # 11 (0x0B).
  #
  # See rfc4578 for full details
  #
  # The code for this option is 94, and its length is 3.
  #
  # The default payload for this option is 0,0x69,0x69
  class ClientNetworkDeviceInterfaceOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_CLIENTNDI
      params[:payload] = params.fetch(:payload, [0]+[0x69]*2)
      super(params)
    end
    def to_s
      uuid = self.payload.pack('n').unpack('C*')
      "Client Network Device Interface = #{uuid}"
    end
  end

  # Octet "t" describes the type of the machine identifier in the
  # remaining octets in this option. 0 (zero) is the only value defined
  # for this octet at the present time, and it describes the remaining
  # octets as a 16-octet Globally Unique Identifier (GUID).  Octet "n" is
  # 17 for type 0.  (One definition of GUID can be found in Appendix A of
  # the EFI specification [4].)
  #
  # See rfc4578 for full details
  #
  # The code for this option is 97, and its length is 17: 1 for the type of
  # identifier and 16 for a Globally Unique Identifier.
  #
  # The default payload for this option is 0, [0x69]*16
  class UUIDGUIDOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_UUIDGUID
      params[:payload] = params.fetch(:payload, [0]+[0x69]*16)
      super(params)
    end
    def to_s
      "UUID/GUID Client Identifier = #{self.payload}"
    end
  end


  # from rfc2132:
  # This option specifies the maximum length DHCP message that it is
  # willing to accept.  The length is specified as an unsigned 16-bit
  # integer.  A client may use the maximum DHCP message size option in
  # DHCPDISCOVER or DHCPREQUEST messages, but should not use the option
  # in DHCPDECLINE messages.
  class MaximumMsgSizeOption < Option
    def initialize(params={})
      params[:type] = $DHCP_MAXMSGSIZE
      params[:payload] = params.fetch(:payload, [1024].pack('n').unpack('C*'))
      super(params)
    end

    def to_s
      "Maximum Message Size = #{self.payload}"
    end
  end

  # see: rfc3004
  class UserClassInformationOption < Option
    def initialize(params={})
      params[:type] = $DHCP_USERCLASS
      params[:payload] = params.fetch(:payload, [0x67, 0x50, 0x58, 0x45] )
      super(params)
    end

    def to_s
      "UserClassInformation = #{self.payload.pack('C*')}"
    end
  end

  class PrivateOption < Option
    def initialize(params={})
      params[:type]    = params.fetch(:private_type_num, $DHCP_PRIVATE)
      params[:payload] = params.fetch(:payload, [0x00] )
      super(params)
    end

    def to_s
      "Private = #{self.payload}"
    end
  end

  # Operating Systems are now attempting to support ad-hoc networks of
  # two or more systems, while keeping user configuration at a minimum.
  # To accommodate this, in the absence of a central configuration
  # mechanism (DHCP), some OS's are automatically choosing a link-local
  # IP address which will allow them to communicate only with other hosts
  # on the same link.  This address will not allow the OS to communicate
  # with anything beyond a router.  However, some sites depend on the
  # fact that a host with no DHCP response will have no IP address.  This
  # document describes a mechanism by which DHCP servers are able to tell
  # clients that they do not have an IP address to offer, and that the
  # client should not generate an IP address it's own.
  #
  # See rfc2563 for full details
  #
  # The code for this option is 116, and its length is 1.
  #
  # The default payload for this option is $DHCP_AUTOCONF_YES
  class AutoConfigurationOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_AUTOCONF
      params[:payload] = params.fetch(:payload, [$DHCP_AUTOCONF_YES])
      super(params)
    end

    def to_s
      "DHCP Auto-Configuration = #{self.payload == $DHCP_AUTOCONF_YES ? 'Yes' :  'No' }"
    end
  end

  # The subnet selection option is a DHCP option.  The option contains a
  # single IPv4 address that is the address of a subnet.  The value for
  # the subnet address is determined by taking any IPv4 address on the
  # subnet and ANDing that address with the subnet mask (i.e.: the
  # network and subnet bits are left alone and the remaining (address)
  # bits are set to zero).  When the DHCP server is configured to respond
  # to this option, is allocating an address, and this option is present
  # then the DHCP server MUST allocate the address on either:
  #  - the subnet specified in the subnet selection option, or;
  #
  #  - a subnet on the same network segment as the subnet specified in the
  #          subnet selection option.
  #
  # The code for this option is 118, and its length is 4.
  #
  class SubnetSelectionOption < Option
    def initialize(params={})
      params[:type] =  $DHCP_SUBNET_SELECTION
      params[:payload] = params.fetch(:payload)
      super(params)
    end
    
    def to_s()
      "Subnet Selection = #{self.payload.join('.')}"
    end
  end

  $DHCP_MSG_OPTIONS = {
    $DHCP_SUBNETMASK => SubnetMaskOption,
    $DHCP_TIMEOFFSET => Option,
    $DHCP_ROUTER => RouterOption,
    $DHCP_TIMESERVER => Option,
    $DHCP_NAMESERVER => Option,
    $DHCP_DNS => DomainNameServerOption,
    $DHCP_LOGSERV => Option,
    $DHCP_COOKIESERV => Option,
    $DHCP_QUOTESSERV => Option,
    $DHCP_LPRSERV => Option,
    $DHCP_IMPSERV => Option,
    $DHCP_RESSERV => Option,
    $DHCP_HOSTNAME => HostNameOption,
    $DHCP_BOOTFILESIZE => Option,
    $DHCP_DUMPFILE => Option,
    $DHCP_DOMAINNAME => DomainNameOption,
    $DHCP_SWAPSERV => Option,
    $DHCP_ROOTPATH => Option,
    $DHCP_EXTENPATH => Option,
    $DHCP_IPFORWARD => Option,
    $DHCP_SRCROUTE => Option,
    $DHCP_POLICYFILTER => Option,
    $DHCP_MAXASMSIZE => Option,
    $DHCP_IPTTL => Option,
    $DHCP_MTUTIMEOUT => Option,
    $DHCP_MTUTABLE => Option,
    $DHCP_MTUSIZE => Option,
    $DHCP_LOCALSUBNETS => Option,
    $DHCP_BROADCASTADDR => BroadcastAddressOption,
    $DHCP_DOMASKDISCOV => Option,
    $DHCP_MASKSUPPLY => Option,
    $DHCP_DOROUTEDISC => Option,
    $DHCP_ROUTERSOLICIT => Option,
    $DHCP_STATICROUTE => Option,
    $DHCP_TRAILERENCAP => Option,
    $DHCP_ARPTIMEOUT => Option,
    $DHCP_ETHERENCAP => Option,
    $DHCP_TCPTTL => Option,
    $DHCP_TCPKEEPALIVE => Option,
    $DHCP_TCPALIVEGARBAGE => Option,
    $DHCP_NISDOMAIN => Option,
    $DHCP_NISSERVERS => Option,
    $DHCP_NISTIMESERV => Option,
    $DHCP_VENDSPECIFIC => Option,
    $DHCP_NBNS => Option,
    $DHCP_NBDD => Option,
    $DHCP_NBTCPIP => Option,
    $DHCP_NBTCPSCOPE => Option,
    $DHCP_XFONT => Option,
    $DHCP_XDISPLAYMGR => Option,
    $DHCP_DISCOVERADDR => RequestedIPAddressOption,
    $DHCP_LEASETIME => IPAddressLeaseTimeOption,
    $DHCP_OPTIONOVERLOAD => Option,
    $DHCP_MESSAGETYPE => MessageTypeOption,
    $DHCP_SERVIDENT => ServerIdentifierOption,
    $DHCP_PARAMREQUEST => ParameterRequestListOption,
    $DHCP_MESSAGE => Option,
    $DHCP_MAXMSGSIZE => MaximumMsgSizeOption,
    $DHCP_RENEWTIME => Option,
    $DHCP_REBINDTIME => Option,
    $DHCP_CLASSSID => VendorClassIDOption,
    $DHCP_CLIENTID => ClientIdentifierOption,
    $DHCP_NISPLUSDOMAIN => Option,
    $DHCP_NISPLUSSERVERS => Option,
    $DHCP_MOBILEIPAGENT => Option,
    $DHCP_SMTPSERVER => Option,
    $DHCP_POP3SERVER => Option,
    $DHCP_NNTPSERVER => Option,
    $DHCP_WWWSERVER => Option,
    $DHCP_FINGERSERVER => Option,
    $DHCP_IRCSERVER => Option,
    $DHCP_STSERVER => Option,
    $DHCP_STDASERVER => Option,
    $DHCP_USERCLASS => UserClassInformationOption,
    $DHCP_PRIVATE => PrivateOption,

    $DHCP_CLIENTFQDN => ClientFQDNOption,
    $DHCP_CLIENTARCH => ClientSystemArchitectureOption,
    $DHCP_CLIENTNDI => ClientNetworkDeviceInterfaceOption,
    $DHCP_LDAP => Option,
    $DHCP_UUIDGUID => UUIDGUIDOption,
    $DHCP_AUTOCONF => AutoConfigurationOption,
    $DHCP_SUBNET_SELECTION => SubnetSelectionOption,
  }

end
