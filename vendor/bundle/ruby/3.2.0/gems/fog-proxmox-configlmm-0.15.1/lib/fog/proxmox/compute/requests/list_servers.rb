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
      # class Real list_servers request
      class Real
        def list_servers(options)
          node = options[:node]
          type = options[:type]
          request(
            expects: [200],
            method: 'GET',
            path: "nodes/#{node}/#{type}"
          )
        end
      end

      # class Mock list_servers request
      class Mock
        def list_servers(_options = {})
          if options[:type] == 'qemu'
            [
              {
                'vmid' => '100',
                'type' => 'qemu',
                'node_id' => 'proxmox',
                'config' => {
                  'vmid' => '100',
                  'description' => nil,
                  'smbios1' => nil,
                  'numa' => 0,
                  'kvm' => 0,
                  'vcpus' => nil,
                  'cores' => 1,
                  'bootdisk' => 'scsi0',
                  'onboot' => 0,
                  'boot' => nil,
                  'agent' => '0',
                  'scsihw' => nil,
                  'sockets' => 1,
                  'memory' => 512,
                  'min_memory' => nil,
                  'shares' => nil,
                  'balloon' => 0,
                  'cpu' => 'cputype=kvm64',
                  'cpulimit' => nil,
                  'cpuunits' => nil,
                  'keyboard' => 'en-us',
                  'vga' => 'std',
                  'storage' => nil,
                  'template' => '',
                  'arch' => nil,
                  'swap' => nil,
                  'hostname' => nil,
                  'nameserver' => nil,
                  'searchdomain' => nil,
                  'password' => nil,
                  'startup' => nil,
                  'console' => nil
                },
                'digest' => nil,
                'maxdisk' => 8_589_934_592,
                'disk' => 0,
                'diskwrite' => 0,
                'diskread' => 0,
                'uptime' => 0,
                'netout' => 0,
                'netin' => 0,
                'cpu' => 'cputype=kvm64',
                'cpus' => 1,
                'template' => '',
                'status' => 'stopped',
                'maxcpu' => nil,
                'mem' => 0,
                'maxmem' => 536_870_912,
                'qmpstatus' => 'stopped',
                'ha' => { 'managed' => 0 },
                'pid' => nil,
                'blockstat' => nil,
                'balloon' => 0,
                'ballooninfo' => nil,
                'vmgenid' => nil,
                'lock' => nil,
                'maxswap' => nil,
                'swap' => nil
              }
            ]
          else
            []
          end
        end
      end
    end
  end
end
