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
      # class Real list_snapshots request
      class Real
        def list_snapshots(path_params)
          node = path_params[:node]
          type = path_params[:type]
          vmid = path_params[:vmid]
          request(
            expects: [200],
            method: 'GET',
            path: "nodes/#{node}/#{type}/#{vmid}/snapshot"
          )
        end
      end

      # class Mock list_snapshots request
      class Mock
        def list_snapshots(_path_params)
          [
            {
              'name' => 'snapshot1',
              'description' => 'latest snapshot',
              'snaptime' => 1_578_057_452,
              'vmstate' => 0,
              'node_id' => 'proxmox',
              'server_id' => '100',
              'server_type' => 'qemu',
              'vmgenid' => nil
            },
            {
              'name' => 'snapshot2',
              'description' => 'latest snapshot2',
              'snaptime' => 1_578_058_452,
              'vmstate' => 0,
              'node_id' => 'proxmox',
              'server_id' => '100',
              'server_type' => 'qemu',
              'vmgenid' => nil
            }
          ]
        end
      end
    end
  end
end
