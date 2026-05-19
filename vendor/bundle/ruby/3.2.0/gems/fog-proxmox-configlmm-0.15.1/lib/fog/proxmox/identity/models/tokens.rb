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
      # class Tokens model collection
      class Tokens < Fog::Collection
        model Fog::Proxmox::Identity::Token
        attribute :userid

        def new(new_attributes = {})
          super({ userid: userid }.merge(new_attributes))
        end

        def get(tokenid)
          all.find { |token| token.tokenid == tokenid && token.userid == userid }
        end

        def all(_options = {})
          load service.list_tokens(userid)
        rescue Excon::Error::InternalServerError => e
          raise e unless e.response.status_line.include? 'no such user'

          []
        end

        def create(new_attributes = {})
          object = new(new_attributes.select { |key, _value| %i[userid tokenid].include? key.to_sym })
          object.save(new_attributes.reject { |key, _value| %i[userid tokenid].include? key.to_sym })
          object
        end
      end
    end
  end
end
