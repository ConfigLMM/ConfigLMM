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

require 'fog/proxmox/helpers/disk_helper'
require 'fog/proxmox/helpers/controller_helper'

module Fog
  module Proxmox
    class Compute
      # class Disk model: https://pve.proxmox.com/pve-docs/api-viewer/index.html#/nodes/{node}/{qemu|lxc}/{vmid}/config
      # size is in Gb
      class Disk < Fog::Model
        identity  :id
        attribute :volid
        attribute :size
        attribute :storage
        attribute :cache
        attribute :replicate
        attribute :media
        attribute :format
        attribute :model
        attribute :shared
        attribute :snapshot
        attribute :backup
        attribute :aio
        attribute :mp

        def controller
          Fog::Proxmox::DiskHelper.extract_controller(id)
        end

        def device
          Fog::Proxmox::DiskHelper.extract_device(id)
        end

        def cdrom?
          id == 'ide2' && media == 'cdrom'
        end

        def rootfs?
          id == 'rootfs'
        end

        def mount_point?
          Fog::Proxmox::DiskHelper.mount_point?(id)
        end

        def controller?
          Fog::Proxmox::DiskHelper.server_disk?(id)
        end

        def cloud_init?
          id != 'ide2' && media == 'cdrom'
        end

        def hard_disk?
          controller? && !cdrom? && !cloud_init?
        end

        def template?
          Fog::Proxmox::DiskHelper.template?(volid)
        end

        def flatten
          Fog::Proxmox::DiskHelper.flatten(attributes)
        end

        def to_s
          Fog::Proxmox::Hash.flatten(flatten)
        end

        def has_volume?
          !volid.empty?
        end
      end
    end
  end
end
