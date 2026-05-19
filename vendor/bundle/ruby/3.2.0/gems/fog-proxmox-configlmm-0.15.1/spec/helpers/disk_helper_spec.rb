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
require 'fog/proxmox/helpers/disk_helper'

describe Fog::Proxmox::DiskHelper do
  let(:scsi0) do
    { id: 'scsi0', storage: 'local-lvm', size: 1, options: { cache: 'none' } }
  end

  let(:scsi0_image) do
    { id: 'scsi0', volid: 'local-lvm:vm-100-disk-1', storage: 'local-lvm', size: 1, options: { cache: 'none' } }
  end

  let(:scsi) do
    { scsi0: 'local-lvm:vm-100-disk-1,size=8,cache=none' }
  end

  let(:virtio1) do
    { id: 'virtio1', volid: 'local:108/vm-108-disk-1.qcow2,size=2G' }
  end

  let(:virtio) do
    { virtio1: 'local:108/vm-108-disk-1.qcow2,size=2' }
  end

  let(:ide2) do
    { id: 'ide2' }
  end

  let(:ide2_image) do
    { id: 'ide2', volid: 'local:iso/alpine-virt-3.7.0-x86_64.iso' }
  end

  let(:cdrom_none) do
    { ide2: 'none,media=cdrom' }
  end

  let(:cdrom_iso) do
    { ide2: 'local:iso/alpine-virt-3.7.0-x86_64.iso,media=cdrom' }
  end

  let(:template) do
    { virtio0: 'local:100/base-100-disk-0.qcow2' }
  end

  let(:cloudinit) do
    { ide0: 'local-lvm:vm-100-cloudinit,media=cdrom' }
  end

  let(:rootfs) do
    { id: 'rootfs', storage: 'local-lvm', size: 1 }
  end

  describe '#flatten' do
    it 'returns creation string' do
      disk = Fog::Proxmox::DiskHelper.flatten(scsi0)
      assert_equal({ scsi0: 'local-lvm:1,cache=none' }, disk)
    end

    it 'returns image string' do
      disk = Fog::Proxmox::DiskHelper.flatten(scsi0_image)
      assert_equal({ scsi0: 'local-lvm:vm-100-disk-1,size=1,cache=none' }, disk)
    end

    it 'returns cdrom none string' do
      disk = Fog::Proxmox::DiskHelper.flatten(ide2)
      assert_equal(cdrom_none, disk)
    end

    it 'returns cdrom image string' do
      disk = Fog::Proxmox::DiskHelper.flatten(ide2_image)
      assert_equal(cdrom_iso, disk)
    end
  end

  describe '#extract_controller' do
    it 'returns virtio controller' do
      controller = Fog::Proxmox::DiskHelper.extract_controller(virtio1[:id])
      assert_equal('virtio', controller)
    end

    it 'returns scsi controller' do
      controller = Fog::Proxmox::DiskHelper.extract_controller(scsi0[:id])
      assert_equal('scsi', controller)
    end
  end

  describe '#extract_device' do
    it 'returns device' do
      device = Fog::Proxmox::DiskHelper.extract_device(scsi0[:id])
      assert_equal(0, device)
    end
  end

  describe '#extract_storage_volid_size' do
    it 'returns scsi get storage and volid' do
      storage, volid, size = Fog::Proxmox::DiskHelper.extract_storage_volid_size(scsi[:scsi0])
      assert_equal('local-lvm', storage)
      assert_equal('local-lvm:vm-100-disk-1', volid)
      assert_equal('8', size)
    end

    it 'returns virtio get local storage volid and size' do
      storage, volid, size = Fog::Proxmox::DiskHelper.extract_storage_volid_size(virtio[:virtio1])
      assert_equal('local', storage)
      assert_equal('local:108/vm-108-disk-1.qcow2', volid)
      assert_equal('2', size)
    end

    it 'returns virtio1 get local storage volid and size' do
      storage, volid, size = Fog::Proxmox::DiskHelper.extract_storage_volid_size(virtio1[:volid])
      assert_equal('local', storage)
      assert_equal('local:108/vm-108-disk-1.qcow2', volid)
      assert_equal('2', size)
    end

    it 'returns scsi0 creation storage and volid' do
      disk = Fog::Proxmox::DiskHelper.flatten(scsi0)
      storage, volid, size = Fog::Proxmox::DiskHelper.extract_storage_volid_size(disk[:scsi0])
      assert_equal('local-lvm', storage)
      assert_nil volid
      assert_equal(1, size)
    end

    it 'returns cdrom storage and volid none' do
      storage, volid, size = Fog::Proxmox::DiskHelper.extract_storage_volid_size(cdrom_none[:ide2])
      assert_nil storage
      assert_equal('none', volid)
      assert_nil size
    end

    it 'returns cdrom storage and volid iso' do
      storage, volid, size = Fog::Proxmox::DiskHelper.extract_storage_volid_size(cdrom_iso[:ide2])
      assert_equal('local', storage)
      assert_equal('local:iso/alpine-virt-3.7.0-x86_64.iso', volid)
      assert_nil size
    end
  end

  describe '#extract_size' do
    it 'size=8 returns size 8' do
      size = Fog::Proxmox::DiskHelper.extract_size(scsi[:scsi0])
      assert_equal('8', size)
    end

    it 'size=2 returns size 2' do
      size = Fog::Proxmox::DiskHelper.extract_size(virtio[:virtio1])
      assert_equal('2', size)
    end

    it 'size=2G returns size 2' do
      size = Fog::Proxmox::DiskHelper.extract_size(virtio1[:volid])
      assert_equal('2', size)
    end
  end

  describe '#disk?' do
    it 'rootfs returns true' do
      assert Fog::Proxmox::DiskHelper.disk?('rootfs')
    end

    it 'mp0 returns true' do
      assert Fog::Proxmox::DiskHelper.disk?('mp0')
    end

    it 'scsi0 returns true' do
      assert Fog::Proxmox::DiskHelper.disk?('scsi0')
    end

    it 'virtio12 returns true' do
      assert Fog::Proxmox::DiskHelper.disk?('virtio12')
    end

    it 'sata2 returns true' do
      assert Fog::Proxmox::DiskHelper.disk?('sata2')
    end

    it 'ide0 returns true' do
      assert Fog::Proxmox::DiskHelper.disk?('ide0')
    end

    it 'dsfdsfdsfds returns false' do
      assert !Fog::Proxmox::DiskHelper.disk?('dsfdsfdsfds')
    end
  end

  describe '#server_disk?' do
    it 'ide0 returns true' do
      assert Fog::Proxmox::DiskHelper.server_disk?('ide0')
    end

    it 'scsi1 returns true' do
      assert Fog::Proxmox::DiskHelper.server_disk?('scsi1')
    end

    it 'virtio returns false' do
      assert !Fog::Proxmox::DiskHelper.server_disk?('virtio')
    end
  end

  describe '#container_disk?' do
    it 'rootfs returns true' do
      assert Fog::Proxmox::DiskHelper.container_disk?('rootfs')
    end

    it 'mp0 returns true' do
      assert Fog::Proxmox::DiskHelper.container_disk?('mp0')
    end

    it 'mp returns false' do
      assert !Fog::Proxmox::DiskHelper.container_disk?('mp')
    end
  end

  describe '#cdrom?' do
    it 'local:iso/alpine-virt-3.7.0-x86_64.iso,media=cdrom returns true' do
      assert Fog::Proxmox::DiskHelper.cdrom?('local:iso/alpine-virt-3.7.0-x86_64.iso,media=cdrom')
    end

    it 'local:iso/alpine-virt-3.7.0-x86_64.iso returns false' do
      assert !Fog::Proxmox::DiskHelper.cdrom?('local:iso/alpine-virt-3.7.0-x86_64.iso')
    end
  end

  describe '#to_bytes' do
    it '1Gb returns 1 073 741 824' do
      assert_equal Fog::Proxmox::DiskHelper.to_bytes('1Gb'), 1_073_741_824
    end
  end

  describe '#to_human_bytes' do
    it '1 073 741 824 returns 1Gb' do
      assert_equal '1Gb', Fog::Proxmox::DiskHelper.to_human_bytes(1_073_741_824)
    end
  end

  describe '#to_int_gb' do
    it '8589934592 returns 8' do
      size = Fog::Proxmox::DiskHelper.to_int_gb(8_589_934_592)
      assert_equal(8, size)
    end

    it '2 returns 0' do
      size = Fog::Proxmox::DiskHelper.to_int_gb(2)
      assert_equal(0, size)
    end
  end

  describe '#template?' do
    it 'local:100/base-100-disk-0.qcow2 returns true' do
      assert Fog::Proxmox::DiskHelper.template?(template[:virtio0])
    end

    it 'local:108/vm-108-disk-1.qcow2 returns false' do
      assert !Fog::Proxmox::DiskHelper.template?(virtio[:virtio1])
    end
  end

  describe '#cloud_init?' do
    it 'local-lvm:vm-100-cloudinit,media=cdrom returns true' do
      assert Fog::Proxmox::DiskHelper.cloud_init?(cloudinit[:ide0])
    end

    it 'local:108/vm-108-disk-1.qcow2 returns false' do
      assert !Fog::Proxmox::DiskHelper.cloud_init?(virtio[:virtio1])
    end
  end

  describe '#of_type?' do
    it 'qemu and rootfs returns false' do
      refute Fog::Proxmox::DiskHelper.of_type?(rootfs, 'qemu')
    end

    it 'qemu and scsi0 returns true' do
      assert Fog::Proxmox::DiskHelper.of_type?(scsi0, 'qemu')
    end

    it 'lxc and rootfs returns true' do
      assert Fog::Proxmox::DiskHelper.of_type?(rootfs, 'lxc')
    end

    it 'qemu and scsi0 returns false' do
      refute Fog::Proxmox::DiskHelper.of_type?(scsi0, 'lxc')
    end
  end
end
