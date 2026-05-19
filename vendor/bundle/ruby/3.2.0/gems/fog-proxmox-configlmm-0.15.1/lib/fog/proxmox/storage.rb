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

module Fog
  module Proxmox
    # Procmox storage service
    class Storage < Fog::Service
      requires :proxmox_url, :proxmox_auth_method
      recognizes :proxmox_token, :proxmox_tokenid, :proxmox_userid, :persistent, :proxmox_username, :proxmox_password

      # Models
      model_path 'fog/proxmox/storage/models'

      request_path 'fog/proxmox/storage/requests'

      request :upload
      request :list_appliances
      request :download_appliance
      request :create
      request :list

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
          Fog::Proxmox::Storage::NotFound
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
