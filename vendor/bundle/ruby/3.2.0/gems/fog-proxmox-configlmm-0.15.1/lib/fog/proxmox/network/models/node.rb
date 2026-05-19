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

module Fog
  module Proxmox
    class Network
      # class Node model of VMs
      class Node < Fog::Model
        identity  :node
        attribute :status
        attribute :wait
        attribute :uptime
        attribute :proxmoxversion
        attribute :ksm
        attribute :kversion
        attribute :loadavg
        attribute :rootfs
        attribute :cpu
        attribute :cpuinfo
        attribute :memory
        attribute :idle
        attribute :swap
        attribute :networks

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          attributes[:node] = new_attributes['node'] unless new_attributes['node'].nil?
          attributes[:node] = new_attributes[:node] unless new_attributes[:node].nil?
          requires :node
          initialize_networks
          super(new_attributes)
        end

        def power(action)
          action_known = %w[reboot shutdown].include? action
          message = "Action #{action} not implemented"
          raise Fog::Errors::Error, message unless action_known

          service.power_node({ node: node }, command: action)
        end

        private

        def initialize_networks
          attributes[:networks] = Fog::Proxmox::Network::Networks.new(service: service, node_id: node)
        end
      end
    end
  end
end
