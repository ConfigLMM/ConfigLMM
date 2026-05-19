# frozen_string_literal: true
# Copyright 2018 Tristan Robert

# This file is part of Fog::Proxmox.

# Fog::Proxmox is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
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
    class Compute
      # class Node model of VMs
      class Node < Fog::Model
        identity  :node
        attribute :cpu
        attribute :level
        attribute :maxcpu
        attribute :maxmem
        attribute :mem
        attribute :maxdisk
        attribute :disk
        attribute :ssl_fingerprint
        attribute :status
        attribute :uptime
        attribute :tasks
        attribute :servers
        attribute :containers
        attribute :storages

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('node', attributes, new_attributes)
          requires :node
          initialize_tasks
          initialize_servers
          initialize_containers
          initialize_storages
          super(new_attributes)
        end

        def backup(options = {})
          service.backup({ node: node }, options)
        end

        def statistics(output = 'rrddata', options = { timeframe: 'hour', cf: 'AVERAGE' })
          path_params = { node: node, output: output }
          query_params = options
          service.get_node_statistics(path_params, query_params)
        end

        private

        def initialize_tasks
          attributes[:tasks] = Fog::Proxmox::Compute::Tasks.new(service: service, node_id: node)
        end

        def initialize_servers
          attributes[:servers] = Fog::Proxmox::Compute::Servers.new(service: service, node_id: node, type: 'qemu')
        end

        def initialize_containers
          attributes[:containers] = Fog::Proxmox::Compute::Servers.new(service: service, node_id: node, type: 'lxc')
        end

        def initialize_storages
          attributes[:storages] = Fog::Proxmox::Compute::Storages.new(service: service, node_id: node)
        end
      end
    end
  end
end
