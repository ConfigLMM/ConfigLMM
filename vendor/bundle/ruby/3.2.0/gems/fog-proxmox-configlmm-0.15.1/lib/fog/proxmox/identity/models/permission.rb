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

module Fog
  module Proxmox
    class Identity
      # class Permission
      class Permission < Fog::Model
        identity :type
        identity :roleid
        identity :path
        identity :ugid
        attribute :propagate

        def save
          service.update_permissions(to_update)
        end

        def destroy
          service.update_permissions(to_update.merge(delete: 1))
        end

        private

        def initialize_roles(new_attributes = {})
          roles = new_attributes.delete(:roleid)
          new_attributes.store(:roles, roles)
        end

        def initialize_ugid(new_attributes = {})
          ugs = new_attributes.delete(:ugid)
          case type
          when 'user'
            new_attributes.store(:users, ugs)
          when 'group'
            new_attributes.store(:groups, ugs)
          end
          new_attributes.delete(:type)
        end

        def to_update
          new_attributes = attributes.clone
          initialize_roles(new_attributes)
          initialize_ugid(new_attributes)
          new_attributes
        end
      end
    end
  end
end
