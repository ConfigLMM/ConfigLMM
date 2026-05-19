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

require 'fog/proxmox/compute/models/disk'

module Fog
  module Proxmox
    class Compute
      # class Disks Collection of disk
      class Disks < Fog::Collection
        model Fog::Proxmox::Compute::Disk

        def all
          self
        end

        def get(id)
          all.find { |disk| disk.identity == id }
        end

        def next_device(controller)
          Fog::Proxmox::ControllerHelper.last_index(controller, self) + 1
        end

        def cdrom
          find(&:cdrom?)
        end

        def rootfs
          find(&:rootfs?)
        end

        def cloudinit
          find(&:cloud_init?)
        end
      end
    end
  end
end
