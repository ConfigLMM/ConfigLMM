# frozen_string_literal: true
# Copyright 2018 Tristan Robert

# This file is part of Fog::Proxmox.

# Fog::Proxmox is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
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

module Fog
  module Proxmox
    class Compute
      # class Storage model: https://pve.proxmox.com/pve-docs/api-viewer/index.html#/nodes/{node}/storage/{storage}
      class Storage < Fog::Model
        identity  :storage
        attribute :node_id, aliases: :node
        attribute :content
        attribute :type
        attribute :avail
        attribute :total
        attribute :used
        attribute :shared
        attribute :active
        attribute :enabled
        attribute :used_fraction
        attribute :volumes

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('node_id', attributes, new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('storage', attributes, new_attributes)
          requires :node_id, :storage
          initialize_volumes
          super(new_attributes)
        end

        private

        def initialize_volumes
          attributes[:volumes] =
            Fog::Proxmox::Compute::Volumes.new(service: service, node_id: node_id, storage_id: identity)
        end
      end
    end
  end
end
