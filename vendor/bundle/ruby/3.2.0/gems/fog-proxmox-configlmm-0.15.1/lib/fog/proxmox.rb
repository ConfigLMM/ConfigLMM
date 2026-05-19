# frozen_string_literal: true
# Copyright 2018 Tristan Robert

# This file is part of Fog::Proxmox.

# Fog::Proxmox is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Fog::Proxmox is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Fog::Proxmox. If not, see <http://www.gnu.org/licenses/>.

# frozen_string_literal: true

require 'fog/core'
require 'fog/json'

module Fog
  # Proxmox module
  module Proxmox
    require 'fog/proxmox/auth/token'

    autoload :Core, 'fog/proxmox/core'
    autoload :Errors, 'fog/proxmox/errors'
    autoload :Identity, 'fog/proxmox/identity'
    autoload :Compute, 'fog/proxmox/compute'
    autoload :Storage, 'fog/proxmox/storage'
    autoload :Network, 'fog/proxmox/network'

    extend Fog::Provider

    service(:identity, 'Identity')
    service(:compute, 'Compute')
    service(:storage, 'Storage')
    service(:network, 'Network')

    @token_cache = {}

    class << self
      attr_accessor :token_cache
    end

    def self.clear_token_cache
      Fog::Proxmox.token_cache = {}
    end
  end
end
