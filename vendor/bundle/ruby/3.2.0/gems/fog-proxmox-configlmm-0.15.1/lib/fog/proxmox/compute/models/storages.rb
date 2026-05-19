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

require 'fog/proxmox/compute/models/storage'

module Fog
  module Proxmox
    class Compute
      # class Storages Collection of storages
      class Storages < Fog::Collection
        model Fog::Proxmox::Compute::Storage
        attribute :node_id

        def new(new_attributes = {})
          super({ node_id: node_id }.merge(new_attributes))
        end

        def all(filters = {})
          requires :node_id
          load service.list_storages(node_id, filters)
        end

        def list_by_content_type(content)
          requires :node_id
          all.select { |storage| storage.content.include? content }
        end

        def get(id)
          requires :node_id
          all.find { |storage| storage.identity == id }
        end
      end
    end
  end
end
