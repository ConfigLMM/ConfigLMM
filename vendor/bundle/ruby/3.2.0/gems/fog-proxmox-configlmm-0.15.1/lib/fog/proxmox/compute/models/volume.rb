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

require 'fog/proxmox/helpers/disk_helper'

module Fog
  module Proxmox
    class Compute
      # class Volume model: https://pve.proxmox.com/pve-docs/api-viewer/index.html#/nodes/{node}/storage/{storage}/content/{volume}
      # size is in bytes
      class Volume < Fog::Model
        identity  :volid
        attribute :content
        attribute :size
        attribute :format
        attribute :node_id
        attribute :storage_id
        attribute :vmid

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('node_id', attributes, new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('storage_id', attributes, new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('volid', attributes, new_attributes)
          requires :node_id, :storage_id, :volid
          super(new_attributes)
        end

        def destroy
          service.delete_volume(node_id, storage_id, volid)
        end

        def restore(vmid, options = {})
          service.create_server(node_id, options.merge(archive: volid, storage: storage_id, vmid: vmid))
        end

        def template?
          Fog::Proxmox::DiskHelper.template?(volid)
        end
      end
    end
  end
end
