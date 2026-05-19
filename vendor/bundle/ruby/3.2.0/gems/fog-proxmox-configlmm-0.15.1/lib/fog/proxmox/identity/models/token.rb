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

require 'fog/proxmox/identity/models/token_info'

module Fog
  module Proxmox
    class Identity
      # class Token model
      class Token < Fog::Model
        identity  :tokenid
        identity  :userid
        attribute :privsep
        attribute :comment
        attribute :expire
        attribute :info

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('tokenid', attributes, new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('userid', attributes, new_attributes)
          requires :userid, :tokenid
          initialize_info
          super(new_attributes)
        end

        def save(options = {})
          requires :tokenid, :userid
          token_hash = (attributes.reject { |attribute| %i[userid tokenid info].include? attribute }).merge(options)
          service.create_token(userid, tokenid, token_hash)
          reload
        end

        def destroy
          requires :tokenid, :userid
          service.delete_token(userid, tokenid)
          true
        end

        def update
          requires :tokenid, :userid
          service.update_token(userid, tokenid, attributes.reject do |attribute|
                                                  %i[userid tokenid info].include? attribute
                                                end)
          reload
        end

        private

        def initialize_info
          attributes[:info] = Fog::Proxmox::Identity::TokenInfo.new(service: service, tokenid: tokenid, userid: userid)
        end
      end
    end
  end
end
