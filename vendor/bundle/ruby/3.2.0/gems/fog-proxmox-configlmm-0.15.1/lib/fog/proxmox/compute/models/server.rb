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

require 'fog/compute/models/server'
require 'fog/proxmox/helpers/disk_helper'
require 'fog/proxmox/hash'
require 'fog/proxmox/errors'

module Fog
  module Proxmox
    class Compute
      # Server model
      # rubocop:disable ClassLength
      class Server < Fog::Compute::Server
        identity  :vmid
        attribute :type
        attribute :node_id
        attribute :config
        attribute :digest
        attribute :name
        attribute :maxdisk
        attribute :disk
        attribute :diskwrite
        attribute :diskread
        attribute :uptime
        attribute :netout
        attribute :netin
        attribute :cpu
        attribute :cpus
        attribute :template
        attribute :status
        attribute :maxcpu
        attribute :mem
        attribute :maxmem
        attribute :qmpstatus
        attribute :ha
        attribute :pid
        attribute :blockstat
        attribute :balloon
        attribute :ballooninfo
        attribute :snapshots
        attribute :tasks
        attribute :vmgenid
        attribute :lock
        attribute :maxswap
        attribute :swap

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('node_id', attributes, new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('type', attributes, new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('vmid', attributes, new_attributes)
          requires :node_id, :type, :vmid
          initialize_config(new_attributes)
          initialize_snapshots
          initialize_tasks
          super(new_attributes)
        end

        def to_s
          name
        end

        def container?
          type == 'lxc'
        end

        def persisted?
          service.next_vmid(vmid: vmid)
          false
        rescue Excon::Error::InternalServerError
          false
        rescue Excon::Error::BadRequest
          true
        end

        # request with async task
        def request(name, body_params = {}, path_params = {})
          requires :node_id, :type
          path = path_params.merge(node: node_id, type: type)
          task_upid = service.send(name, path, body_params)
          tasks.wait_for(task_upid)
        end

        def save(new_attributes = {})
          body_params = new_attributes.merge(vmid: vmid)
          body_params = body_params.merge(config.flatten) unless persisted?
          request(:create_server, body_params)
          reload
        end

        def update(new_attributes = {})
          if container?
            path_params = { node: node_id, type: type, vmid: vmid }
            body_params = new_attributes
            service.update_server(path_params, body_params)
          else
            request(:update_server, new_attributes, vmid: vmid)
          end
          reload
        end

        def destroy(options = {})
          request(:delete_server, options, vmid: vmid)
        end

        def action(action, options = {})
          action_known = %w[start stop resume suspend shutdown reset].include? action
          message = "Action #{action} not implemented"
          raise Fog::Errors::Error, message unless action_known

          request(:action_server, options, action: action, vmid: vmid)
          reload
        end

        def ready?
          status == 'running'
        end

        def backup(options = {})
          request(:create_backup, options.merge(vmid: vmid))
          reload
        end

        def restore(backup, options = {})
          attr_hash = if container?
                        options.merge(ostemplate: backup.volid, force: 1, restore: 1)
                      else
                        options.merge(archive: backup.volid, force: 1)
                      end
          save(attr_hash)
        end

        def clone(newid, options = {})
          request(:clone_server, options.merge(newid: newid), vmid: vmid)
          reload
        end

        def create_template(options = {})
          service.template_server({ node: node_id, type: type, vmid: vmid }, options)
          reload
        end

        def migrate(target, options = {})
          request(:migrate_server, options.merge(target: target), vmid: vmid)
        end

        def extend(disk, size, options = {})
          if container?
            request(:resize_container, options.merge(disk: disk, size: size), vmid: vmid)
          else
            service.resize_server({ vmid: vmid, node: node_id }, options.merge(disk: disk, size: size))
          end
          reload
        end

        def move(volume, storage, options = {})
          if container?
            request(:move_volume, options.merge(volume: volume, storage: storage), vmid: vmid)
          else
            request(:move_disk, options.merge(disk: volume, storage: storage), vmid: vmid)
          end
          reload
        end

        def attach(disk, options = {})
          disk_hash = Fog::Proxmox::DiskHelper.flatten(disk.merge(options: options))
          update(disk_hash)
        end

        def detach(diskid)
          update(delete: diskid)
        end

        def start_console(options = {})
          unless ready?
            raise ::Fog::Proxmox::Errors::ServiceError,
                  'Unable to start console because server not running.'
          end

          if container?
            type_console = options[:console]
            options.delete_if { |option| [:console].include? option }
            unless type_console
              raise ::Fog::Proxmox::Errors::ServiceError,
                    'Unable to start console because console container config is not set or unknown.'
            end
          else
            type_console = config.type_console
            unless type_console
              raise ::Fog::Proxmox::Errors::ServiceError,
                    'Unable to start console because VGA display server config is not set or unknown.'
            end
          end
          requires :vmid, :node_id, :type
          path_params = { node: node_id, type: type, vmid: vmid }
          body_params = options
          data = service.send(('create_' + type_console).to_sym, path_params, body_params)
          task_upid = data['upid']
          if task_upid
            task = tasks.get(task_upid)
            task.wait_for { running? }
          end
          data
        end

        def connect_vnc(options = {})
          path_params = { node: node_id, type: type, vmid: vmid }
          query_params = { port: options['port'], vncticket: options['ticket'] }
          service.get_vnc(path_params, query_params)
        end

        def backups
          list 'backup'
        end

        def images
          list 'images'
        end

        def list(content)
          storages = node.storages.list_by_content_type content
          volumes = []
          storages.each { |storage| volumes += storage.volumes.list_by_content_type_and_by_server(content, identity) }
          volumes
        end

        protected

        def initialize_config(new_attributes = {})
          options = { service: service, vmid: vmid }
          attributes[:config] = Fog::Proxmox::Compute::ServerConfig.new(options.merge(new_attributes))
        end

        private

        def initialize_snapshots
          attributes[:snapshots] =
            Fog::Proxmox::Compute::Snapshots.new(service: service, server_id: vmid, server_type: type, node_id: node_id)
        end

        def initialize_tasks
          attributes[:tasks] = Fog::Proxmox::Compute::Tasks.new(service: service, node_id: node_id).select do |task|
            task.id == vmid
          end
        end

        def node
          Fog::Proxmox::Compute::Node.new(service: service, node: node_id)
        end
      end
      # rubocop:enable ClassLength
    end
  end
end
