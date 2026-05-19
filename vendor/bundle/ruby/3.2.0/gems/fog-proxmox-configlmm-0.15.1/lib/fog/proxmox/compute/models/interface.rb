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

require 'fog/proxmox/helpers/nic_helper'

module Fog
  module Proxmox
    class Compute
      # class Interface model
      class Interface < Fog::Model
        identity  :id
        attribute :macaddr
        attribute :hwaddr
        attribute :model
        attribute :name
        attribute :ip
        attribute :ip6
        attribute :gw
        attribute :gw6
        attribute :bridge
        attribute :firewall
        attribute :link_down
        attribute :rate
        attribute :queues
        attribute :tag
        attribute :mtu
        attribute :trunks
        attribute :type

        def flatten
          Fog::Proxmox::NicHelper.flatten(attributes)
        end

        def to_s
          Fog::Proxmox::Hash.flatten(flatten)
        end
      end
    end
  end
end
