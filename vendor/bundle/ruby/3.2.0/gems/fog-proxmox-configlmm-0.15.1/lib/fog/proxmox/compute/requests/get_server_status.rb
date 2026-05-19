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

module Fog
  module Proxmox
    class Compute
      # class Real get_server_status request
      class Real
        def get_server_status(path_params)
          node = path_params[:node]
          type = path_params[:type]
          vmid = path_params[:vmid]
          request(
            expects: [200],
            method: 'GET',
            path: "nodes/#{node}/#{type}/#{vmid}/status/current"
          )
        end
      end

      # class Mock get_server_status request
      class Mock
        def get_server_status(_path_params)
          {
            netout: 0,
            ha: { 'managed' => 0 },
            mem: 0,
            vmid: '100',
            maxdisk: 8_589_934_592,
            diskread: 0,
            template: '',
            qmpstatus: 'stopped',
            diskwrite: 0,
            maxmem: 536_870_912,
            pid: nil,
            uptime: 0,
            status: 'stopped',
            cpu: 'cputype=kvm64',
            cpus: 1,
            disk: 0,
            netin: 0
          }
        end
      end
    end
  end
end
