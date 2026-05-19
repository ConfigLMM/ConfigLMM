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
    class Identity
      # class TokenInfo model
      class TokenInfo < Fog::Model
        identity  :tokenid
        identity  :userid
        attribute :fulltokenid
        attribute :info
        attribute :value

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('tokenid', attributes, new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('userid', attributes, new_attributes)
          requires :userid, :tokenid
          super(new_attributes)
        end
      end
    end
  end
end
