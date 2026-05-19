=begin
**
** dhcp.rb
** 31/OCT/2007
** ETD-Software
**  - Daniel Martin Gomez <etd[-at-]nomejortu.com>
**
** Desc:
**   This package provides a set of classes to work with the DHCP protocol. They
** provide low level access to all the fields and internals of the protocol.
**
** See the provided rdoc comments for further information.
**
** More information in:
**   - rfc2131: Dynamic Host Configuration Protocol
**   - rfc2132: DHCP Options and BOOTP Vendor Extensions
**   - rfc2563: DHCP Option to Disable Stateless Auto-Configuration in
**              IPv4 Clients
**   - rfc4578: DHCP Options for the Intel Preboot eXecution Environment (PXE)
**   - rfc4702: The DHCP Client Fully Qualified Domain Name (FQDN) Option
**
** Version:
**  v1.0 [31/October/2007]: first released
**
** License:
**    This program is free software: you can redistribute it and/or modify
**  it under the terms of the GNU General Public License as published by
**  the Free Software Foundation, either version 3 of the License, or
**  (at your option) any later version.
**
**  This program is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
**  GNU General Public License for more details.
**
**  You should have received a copy of the GNU General Public License
**  along with this program.  If not, see <http://www.gnu.org/licenses/>.
**
=end

# constants defining the values in the different fields of the protocols
require 'net/dhcp/constants'

# DHCP options as defined in rfc2132 and rfc2563
require 'net/dhcp/options'

# DHCP messages as defined in rfc2131
require 'net/dhcp/core'
