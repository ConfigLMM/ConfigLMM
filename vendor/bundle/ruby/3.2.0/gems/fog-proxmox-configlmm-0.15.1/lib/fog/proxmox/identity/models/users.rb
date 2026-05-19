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

require 'fog/proxmox/identity/models/user'

module Fog
  module Proxmox
    class Identity
      # class Users model collection
      class Users < Fog::Collection
        model Fog::Proxmox::Identity::User

        def all(filters = {})
          load service.list_users(filters)
        end

        def get(id)
          all.find { |user| user.identity == id }
        end

        def destroy(id)
          user = get(id)
          user.destroy
        end
      end
    end
  end
end
