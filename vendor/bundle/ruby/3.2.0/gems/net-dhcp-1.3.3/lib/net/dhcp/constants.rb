=begin
**
** constants.rb
** 04/OCT/2007
** ETD-Software
**  - Daniel Martin Gomez <etd[-at-]nomejortu.com>
**
** Desc:
**   This file provides a set of classes to work with the DHCP protocol. They
** provide low level access to all the fields and internals of the protocol.
**
** See the provided rdoc comments for further information.
**
** More information in:
**   - rfc2131: Dynamic Host Configuration Protocol
**   - rfc2132: DHCP Options and BOOTP Vendor Extensions
**   - rfc2563: DHCP Option to Disable Stateless Auto-Configuration in
**              IPv4 Clients
**
** Version:
**  v1.0 [04/October/2007]: first released
**
** License:
**   Please see dhcp.rb or LICENSE.txt for copyright and licensing information.
**
=end

# --------------------------------------------------------------- dhcp messages

# operations ('op' field)
$DHCP_OP_REQUEST=      0x01
$DHCP_OP_REPLY=        0x02

# message types
$DHCP_MSG_DISCOVER=    0x01
$DHCP_MSG_OFFER=       0x02
$DHCP_MSG_REQUEST=     0x03
$DHCP_MSG_DECLINE=     0x04
$DHCP_MSG_ACK=         0x05
$DHCP_MSG_NACK=        0x06
$DHCP_MSG_RELEASE=     0x07
$DHCP_MSG_INFORM=      0x08
$DHCP_MSG_NAMES = [
  'DHCP Discover',
  'DHCP Offer',
  'DHCP Request',
  'DHCP Decline',
  'DHCP ACK',
  'DHCP NAK',
  'DHCP Release',
  'DHCP Inform'
]

# ---------------------------------------------------------------- other fields

# hardware types. see "Number Hardware Type (hrd)" in rfc 1700.
$DHCP_HTYPE_ETHERNET = 0x01
$DHCP_HLEN_ETHERNET = 0x06


$DHCP_MAGIC=          0x63825363
$BOOTP_MIN_LEN=       0x12c
$DHCP_PAD=            0x00

# as defined in rfc2132
$DHCP_SUBNETMASK=     0x01
$DHCP_TIMEOFFSET=     0x02
$DHCP_ROUTER=         0x03
$DHCP_TIMESERVER=     0x04
$DHCP_NAMESERVER=     0x05
$DHCP_DNS=            0x06
$DHCP_LOGSERV=        0x07
#$DHCP_COOKIESERV=     0x08
$DHCP_QUOTESSERV=     0x08
$DHCP_LPRSERV=        0x09
$DHCP_IMPSERV=        0x0a
$DHCP_RESSERV=        0x0b
$DHCP_HOSTNAME=       0x0c
$DHCP_BOOTFILESIZE=   0x0d
$DHCP_DUMPFILE=       0x0e
$DHCP_DOMAINNAME=     0x0f
$DHCP_SWAPSERV=       0x10
$DHCP_ROOTPATH=       0x11
$DHCP_EXTENPATH=      0x12
$DHCP_IPFORWARD=      0x13
$DHCP_SRCROUTE=       0x14
$DHCP_POLICYFILTER=   0x15
$DHCP_MAXASMSIZE=     0x16
$DHCP_IPTTL=          0x17
$DHCP_MTUTIMEOUT=     0x18
$DHCP_MTUTABLE=       0x19
$DHCP_MTUSIZE=        0x1a
$DHCP_LOCALSUBNETS=   0x1b
$DHCP_BROADCASTADDR=  0x1c
$DHCP_DOMASKDISCOV=   0x1d
$DHCP_MASKSUPPLY=     0x1e
$DHCP_DOROUTEDISC=    0x1f
$DHCP_ROUTERSOLICIT=  0x20
$DHCP_STATICROUTE=    0x21
$DHCP_TRAILERENCAP=   0x22
$DHCP_ARPTIMEOUT=     0x23
$DHCP_ETHERENCAP=     0x24
$DHCP_TCPTTL=         0x25
$DHCP_TCPKEEPALIVE=   0x26
$DHCP_TCPALIVEGARBAGE=0x27
$DHCP_NISDOMAIN=      0x28
$DHCP_NISSERVERS=     0x29
$DHCP_NISTIMESERV=    0x2a
$DHCP_VENDSPECIFIC=   0x2b
$DHCP_NBNS=           0x2c
$DHCP_NBDD=           0x2d
$DHCP_NBTCPIP=        0x2e
$DHCP_NBTCPSCOPE=     0x2f
$DHCP_XFONT=          0x30
$DHCP_XDISPLAYMGR=    0x31
$DHCP_DISCOVERADDR=   0x32
$DHCP_LEASETIME=      0x33
$DHCP_OPTIONOVERLOAD= 0x34
$DHCP_MESSAGETYPE=    0x35
$DHCP_SERVIDENT=      0x36
$DHCP_PARAMREQUEST=   0x37
$DHCP_MESSAGE=        0x38
$DHCP_MAXMSGSIZE=     0x39
$DHCP_RENEWTIME=      0x3a
$DHCP_REBINDTIME=     0x3b
$DHCP_CLASSSID=       0x3c
$DHCP_CLIENTID=       0x3d
$DHCP_NISPLUSDOMAIN=  0x40
$DHCP_NISPLUSSERVERS= 0x41
$DHCP_TFTPSERVER=     0x42
$DHCP_BOOTFILENAME=   0x43
$DHCP_MOBILEIPAGENT=  0x44
$DHCP_SMTPSERVER=     0x45
$DHCP_POP3SERVER=     0x46
$DHCP_NNTPSERVER=     0x47
$DHCP_WWWSERVER=      0x48
$DHCP_FINGERSERVER=   0x49
$DHCP_IRCSERVER=      0x4a
$DHCP_STSERVER=       0x4b
$DHCP_STDASERVER=     0x4c
$DHCP_USERCLASS=      0x4d
$DHCP_PRIVATE=        0xaf
$DHCP_END=            0xff
# / as defined in rfc2132

# see http://www.bind9.net/bootp-dhcp-parameters

$DHCP_CLIENTFQDN=     0x51 #rfc4702


$DHCP_CLIENTARCH=         0x5d #rfc4578
$DHCP_CLIENTARCH_I386=    0x0000
$DHCP_CLIENTARCH_PC98=    0x0001
$DHCP_CLIENTARCH_ITANIUM= 0x0002
$DHCP_CLIENTARCH_ALPHA=   0x0003
$DHCP_CLIENTARCH_X86=     0x0004
$DHCP_CLIENTARCH_ILC=     0x0005
$DHCP_CLIENTARCH_IA32=    0x0006
$DHCP_CLIENTARCH_BC=      0x0007
$DHCP_CLIENTARCH_XSCALE=  0x0008
$DHCP_CLIENTARCH_X8664=   0x0009
$DHCP_CLIENTARCH_NAMES = [
      'Intel x86PC',
      'NEC/PC98',
      'EFI Itanium',
      'DEC Alpha',
      'Arc x86',
      'Intel Lean Client',
      'EFI IA32',
      'EFI BC',
      'EFI Xscale',
      'EFI x86-64',
      ]

$DHCP_CLIENTNDI=        0x5e #rfc4578
#$DHCP_LDAP=            0x5f
$DHCP_UUIDGUID=         0x61 #rfc4578

$DHCP_AUTOCONF=         0x74 #rfc2563
$DHCP_SUBNET_SELECTION= 0x76 #rfc3011
$DHCP_AUTOCONF_NO=      0x00 #rfc2563
$DHCP_AUTOCONF_YES=     0x01 #rfc2563
