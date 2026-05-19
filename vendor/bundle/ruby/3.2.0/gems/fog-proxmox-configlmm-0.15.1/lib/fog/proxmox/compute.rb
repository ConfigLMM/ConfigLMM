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

require 'fog/proxmox/core'

module Fog
  module Proxmox
    # Proxmox compute service
    class Compute < Fog::Service
      requires :proxmox_url, :proxmox_auth_method
      recognizes :proxmox_token, :proxmox_tokenid, :proxmox_userid, :persistent, :proxmox_username, :proxmox_password

      # Models
      model_path 'fog/proxmox/compute/models'
      model :node
      collection :nodes
      model :server
      collection :servers
      model :interface
      collection :interfaces
      model :disk
      collection :disks
      model :server_config
      model :volume
      collection :volumes
      model :storage
      collection :storages
      model :task
      collection :tasks
      model :snapshot
      collection :snapshots

      # Requests
      request_path 'fog/proxmox/compute/requests'

      # Manage nodes cluster
      request :list_nodes
      request :get_node_statistics
      request :next_vmid
      # Manage servers
      request :list_servers
      request :create_server
      request :get_server_status
      request :get_server_config
      request :update_server
      request :delete_server
      request :action_server
      request :template_server
      request :clone_server
      request :migrate_server
      request :move_disk
      request :move_volume
      request :resize_server
      request :resize_container
      # Manage volumes
      request :list_volumes
      request :get_volume
      request :delete_volume
      # Manage backups
      request :create_backup
      # Manage storages
      request :list_storages
      # Tasks
      request :list_tasks
      request :get_task
      request :stop_task
      request :status_task
      request :log_task
      # CRUD snapshots
      request :list_snapshots
      request :get_snapshot_config
      request :create_snapshot
      request :update_snapshot
      request :delete_snapshot
      request :rollback_snapshot
      # Consoles
      request :create_term
      request :create_spice
      request :create_vnc
      request :get_vnc

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
          Fog::Proxmox::Compute::NotFound
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
