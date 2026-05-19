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

require 'fog/proxmox/network/models/node'

module Fog
  module Proxmox
    class Network
      # class Networks Collection of nodes of cluster
      class Networks < Fog::Collection
        model Fog::Proxmox::Network::Network
        attribute :node_id

        def new(attributes = {})
          requires :node_id
          super({ node_id: node_id }.merge(attributes))
        end

        def all(filters = {})
          requires :node_id
          path_params = { node: node_id }
          query_params = filters
          load service.list_networks(path_params, query_params)
        end

        def get(id)
          all.find { |network| network.identity == id }
        end
      end
    end
  end
end
