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

# frozen_string_literal: true

require 'fog/core'
require 'fog/proxmox/string'

module Fog
  module Proxmox
    # Identity and authentication proxmox class
    class Identity < Fog::Service
      requires :proxmox_url, :proxmox_auth_method
      recognizes :proxmox_token, :proxmox_tokenid, :proxmox_userid, :persistent, :proxmox_username, :proxmox_password

      model_path 'fog/proxmox/identity/models'
      model :principal
      model :user
      collection :users
      model :token
      collection :tokens
      model :group
      collection :groups
      model :pool
      collection :pools
      model :role
      collection :roles
      model :domain
      model :domain_type
      collection :domains
      model :permission
      collection :permissions

      request_path 'fog/proxmox/identity/requests'

      # Manage permissions
      request :check_permissions
      request :list_permissions
      request :list_user_permissions
      request :update_permissions
      request :read_version

      # Manage users
      request :list_users
      request :get_user
      request :create_user
      request :update_user
      request :delete_user
      request :change_password

      # Manage user tokens
      request :list_tokens
      request :get_token_info
      request :create_token
      request :update_token
      request :delete_token

      # CRUD groups
      request :list_groups
      request :get_group
      request :create_group
      request :update_group
      request :delete_group

      # CRUD roles
      request :list_roles
      request :get_role
      request :create_role
      request :update_role
      request :delete_role

      # CRUD domains
      request :list_domains
      request :get_domain
      request :create_domain
      request :update_domain
      request :delete_domain

      # CRUD pools
      request :list_pools
      request :get_pool
      request :create_pool
      request :update_pool
      request :delete_pool

      # Mock class
      class Mock
        attr_reader :config

        def initialize(options = {})
          @proxmox_uri = URI.parse(options[:proxmox_url])
          @proxmox_auth_method = options[:proxmox_auth_method]
          @proxmox_tokenid = options[:proxmox_tokenid]
          @proxmox_userid = options[:proxmox_userid]
          @proxmox_username = options[:proxmox_username]
          @proxmox_password = options[:proxmox_password]
          @proxmox_token = options[:proxmox_token]
          @proxmox_path = @proxmox_uri.path
          @config = options
        end
      end

      # Real class
      class Real
        include Fog::Proxmox::Core

        def self.not_found_class
          Fog::Proxmox::Identity::NotFound
        end

        def config
          self
        end

        def config_service?
          true
        end

        private

        def configure(source)
          source.instance_variables.each do |v|
            instance_variable_set(v, source.instance_variable_get(v))
          end
        end
      end
    end
  end
end
