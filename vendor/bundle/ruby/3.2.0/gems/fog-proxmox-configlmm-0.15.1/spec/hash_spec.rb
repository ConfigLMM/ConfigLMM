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

require 'spec_helper'
require 'fog/proxmox/hash'

describe Fog::Proxmox::Hash do
  let(:net_vm) do
    { net0: 'virtio=66:89:C5:59:AA:96,bridge=vmbr0,firewall=1,link_down=1,queues=1,rate=1,tag=1' }
  end
  let(:net) do
    { id: 'net0', model: 'virtio', macaddr: '66:89:C5:59:AA:96', z: nil }
  end

  describe '#flatten' do
    it 'returns string net_vm' do
      assert_equal 'net0: virtio=66:89:C5:59:AA:96,bridge=vmbr0,firewall=1,link_down=1,queues=1,rate=1,tag=1',
                   Fog::Proxmox::Hash.flatten(net_vm)
    end
  end

  describe '#stringify' do
    it 'returns stringify hash' do
      assert_equal 'id=net0,model=virtio,macaddr=66:89:C5:59:AA:96', Fog::Proxmox::Hash.stringify(net)
    end
  end
end
