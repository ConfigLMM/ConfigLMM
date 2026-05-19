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
      # class Real get_server_config request
      class Real
        def get_server_config(path_params)
          node = path_params[:node]
          type = path_params[:type]
          vmid = path_params[:vmid]
          request(
            expects: [200],
            method: 'GET',
            path: "nodes/#{node}/#{type}/#{vmid}/config"
          )
        end
      end

      # class Mock get_server_config request
      class Mock
        def get_server_config(_path_params)
          {
            onboot: 0,
            memory: 512,
            ostype: 'l26',
            cores: 1,
            keyboard: 'en-us',
            digest: nil,
            smbios1: nil,
            vmgenid: nil,
            balloon: 0,
            kvm: 0,
            cpu: 'cputype=kvm64',
            sockets: 1,
            bootdisk: 'scsi0',
            vga: 'std'
          }
        end
      end
    end
  end
end
