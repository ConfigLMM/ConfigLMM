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

require 'fog/proxmox/attributes'

module Fog
  module Proxmox
    class Identity
      # class User model
      class User < Fog::Model
        identity :userid
        attribute :firstname
        attribute :lastname
        attribute :password
        attribute :email
        attribute :expire
        attribute :comment
        attribute :enable
        attribute :groups
        attribute :keys
        attribute :tokens

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('userid', attributes, new_attributes)
          requires :userid
          initialize_tokens
          super(new_attributes)
        end

        def save(options = {})
          service.create_user((attributes.reject { |attribute| [:tokens].include? attribute }).merge(options))
          reload
        end

        def destroy
          requires :userid
          service.delete_user(userid)
          true
        end

        def update
          requires :userid
          service.update_user(userid, attributes.reject { |attribute| %i[userid tokens].include? attribute })
          reload
        end

        def change_password
          requires :userid, :password
          service.change_password(userid, password)
        end

        def permissions(path = nil)
          requires :userid
          attributes[:permissions] = service.list_user_permissions(userid, path)
        end

        private

        def initialize_tokens
          attributes[:tokens] = Fog::Proxmox::Identity::Tokens.new(service: service, userid: userid)
        end
      end
    end
  end
end
