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

require 'fog/proxmox/compute/models/snapshot'

module Fog
  module Proxmox
    class Compute
      # class Snapshots Collection of snapshots
      class Snapshots < Fog::Collection
        model Fog::Proxmox::Compute::Snapshot
        attribute :server_id
        attribute :server_type
        attribute :node_id

        def new(new_attributes = {})
          super({ node_id: node_id, server_id: server_id, server_type: server_type }.merge(new_attributes))
        end

        def all
          path_params = { node: node_id, type: server_type, vmid: server_id }
          load service.list_snapshots(path_params)
        end

        def get(name)
          all.find { |snapshot| snapshot.identity == name }
        end
      end
    end
  end
end
