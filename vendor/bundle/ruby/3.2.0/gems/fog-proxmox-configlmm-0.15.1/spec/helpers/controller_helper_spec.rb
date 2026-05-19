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
require 'fog/proxmox/helpers/controller_helper'

describe Fog::Proxmox::ControllerHelper do
  let(:net) do
    { net0: 'virtio=66:89:C5:59:AA:96,bridge=vmbr0,firewall=1,link_down=1,queues=1,rate=1,tag=1' }
  end
  let(:net_no_options) do
    { net0: 'virtio=66:89:C5:59:AA:96' }
  end
  let(:net_lxc) do
    { net0: 'virtio=66:89:C5:59:AA:96,bridge=vmbr0,firewall=1,link_down=1,queues=1,rate=1,tag=1,ip=192.168.56.100/31,ip6=2001:0000:1234:0000:0000:C1C0:ABCD:0876/31' }
  end
  let(:scsi) do
    { scsi10: 'local-lvm:1,cache=none' }
  end
  let(:cdrom) do
    { ide2: 'none,media=cdrom' }
  end
  let(:mp) do
    { mp0: 'local-lvm:1,mp=/opt/path' }
  end
  let(:rootfs) do
    { rootfs: 'local-lvm:1' }
  end

  describe '#extract' do
    it 'returns bridge' do
      bridge = Fog::Proxmox::ControllerHelper.extract('bridge', net[:net0])
      assert_equal 'vmbr0', bridge
    end

    it 'returns nil' do
      bridge = Fog::Proxmox::ControllerHelper.extract('bridge', net_no_options[:net0])
      assert !bridge
    end

    it 'returns firewall' do
      firewall = Fog::Proxmox::ControllerHelper.extract('firewall', net[:net0])
      assert_equal '1', firewall
    end

    it 'returns cache' do
      cache = Fog::Proxmox::ControllerHelper.extract('cache', scsi[:scsi10])
      assert_equal 'none', cache
    end

    it 'returns mp' do
      path = Fog::Proxmox::ControllerHelper.extract('mp', mp[:mp0])
      assert_equal '/opt/path', path
    end

    it 'returns cidr ip' do
      path = Fog::Proxmox::ControllerHelper.extract('ip', net_lxc[:net0])
      assert_equal '192.168.56.100/31', path
    end

    it 'returns cidr ip6' do
      path = Fog::Proxmox::ControllerHelper.extract('ip6', net_lxc[:net0])
      assert_equal '2001:0000:1234:0000:0000:C1C0:ABCD:0876/31', path
    end
  end

  describe '#extract_index' do
    it 'net0 returns 0' do
      index = Fog::Proxmox::ControllerHelper.extract_index('net', :net0)
      assert index == 0
    end

    it 'scsi10 returns 10' do
      index = Fog::Proxmox::ControllerHelper.extract_index('scsi', :scsi10)
      assert index == 10
    end
  end

  describe '#last_index' do
    it 'returns -1' do
      last = Fog::Proxmox::ControllerHelper.last_index('net', {})
      assert last == -1
    end

    it 'returns 0' do
      last = Fog::Proxmox::ControllerHelper.last_index('net', net)
      assert last == 0
    end

    it 'returns 10' do
      last = Fog::Proxmox::ControllerHelper.last_index('scsi', scsi)
      assert last == 10
    end
  end

  describe '#valid?' do
    it 'returns true' do
      assert Fog::Proxmox::ControllerHelper.valid?('net', 'net0')
    end

    it 'returns false' do
      assert !Fog::Proxmox::ControllerHelper.valid?('net', 'sdfdsf')
    end
  end

  describe '#select' do
    it 'returns scsi10' do
      controllers = Fog::Proxmox::ControllerHelper.select(scsi, 'scsi')
      assert controllers.has_key?(:scsi10)
      assert controllers.has_value?(scsi[:scsi10])
    end

    it 'returns empty' do
      controllers = Fog::Proxmox::ControllerHelper.select(net, 'scsi')
      assert controllers.empty?
    end
  end

  describe '#collect_controllers' do
    it 'returns scsi0 and ide2' do
      controllers = Fog::Proxmox::ControllerHelper.collect_controllers(scsi.merge(cdrom))
      assert controllers.has_key?(:scsi10)
      assert controllers.has_value?(scsi[:scsi10])
      assert controllers.has_key?(:ide2)
      assert controllers.has_value?(cdrom[:ide2])
    end

    it 'returns rootfs and mp0' do
      controllers = Fog::Proxmox::ControllerHelper.collect_controllers(rootfs.merge(mp))
      assert controllers.has_key?(:mp0)
      assert controllers.has_value?(mp[:mp0])
      assert controllers.has_key?(:rootfs)
      assert controllers.has_value?(rootfs[:rootfs])
    end

    it 'returns empty' do
      controllers = Fog::Proxmox::ControllerHelper.collect_controllers(net)
      assert controllers.empty?
    end
  end
end
