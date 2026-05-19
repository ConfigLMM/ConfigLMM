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

require 'fog/proxmox/attributes'
require 'fog/proxmox/helpers/nic_helper'
require 'fog/proxmox/helpers/controller_helper'

module Fog
  module Proxmox
    class Compute
      # ServerConfig model: https://pve.proxmox.com/pve-docs/api-viewer/index.html#/nodes/{node}/{qemu|lxc}/{vmid}/config
      # memory, balloon, shares and swap are in Mb
      class ServerConfig < Fog::Model
        identity  :vmid
        attribute :description
        attribute :ostype
        attribute :smbios1
        attribute :bios
        attribute :numa
        attribute :kvm
        attribute :vcpus
        attribute :cores
        attribute :bootdisk
        attribute :onboot
        attribute :boot
        attribute :agent
        attribute :scsihw
        attribute :sockets
        attribute :memory
        attribute :shares
        attribute :balloon
        attribute :name
        attribute :cpu
        attribute :cpulimit
        attribute :cpuunits
        attribute :keyboard
        attribute :vga
        attribute :storage
        attribute :template
        attribute :arch
        attribute :swap
        attribute :hostname
        attribute :nameserver
        attribute :searchdomain
        attribute :password
        attribute :startup
        attribute :console
        attribute :cmode
        attribute :tty
        attribute :force
        attribute :lock
        attribute :pool
        attribute :bwlimit
        attribute :unprivileged
        attribute :interfaces
        attribute :disks
        attribute :ciuser
        attribute :cipassword
        attribute :cicustom
        attribute :citype
        attribute :ipconfigs
        attribute :sshkeys
        attribute :searchdomain
        attribute :nameserver

        def initialize(new_attributes = {})
          prepare_service_value(new_attributes)
          Fog::Proxmox::Attributes.set_attr_and_sym('vmid', attributes, new_attributes)
          requires :vmid
          initialize_interfaces(new_attributes)
          initialize_disks(new_attributes)
          super(new_attributes)
        end

        def mac_addresses
          Fog::Proxmox::NicHelper.to_mac_adresses_array(interfaces)
        end

        def type_console
          console = 'vnc' if %w[std cirrus vmware].include?(vga)
          console = 'spice' if %w[qxl qxl2 qxl3 qxl4].include?(vga)
          console = 'term' if %w[serial0 serial1 serial2 serial3].include?(vga)
          console
        end

        def flatten
          flat_hash = attributes.reject { |attribute| %i[node_id type vmid disks interfaces].include? attribute }
          flat_hash.merge(interfaces_flatten)
          flat_hash.merge(disks_flatten)
          flat_hash
        end

        private

        def interfaces_flatten
          flat_hash = {}
          interfaces.each { |interface| flat_hash.merge(interface.flatten) }
          flat_hash
        end

        def disks_flatten
          flat_hash = {}
          disks.each { |disk| flat_hash.merge(disk.flatten) }
          flat_hash
        end

        def initialize_interfaces(new_attributes)
          nets = Fog::Proxmox::NicHelper.collect_nics(new_attributes)
          attributes[:interfaces] = Fog::Proxmox::Compute::Interfaces.new
          nets.each do |key, value|
            nic_hash = {
              id: key.to_s,
              model: Fog::Proxmox::NicHelper.extract_nic_id(value),
              macaddr: Fog::Proxmox::NicHelper.extract_mac_address(value)
            }
            names = Fog::Proxmox::Compute::Interface.attributes.reject do |attribute|
              %i[id macaddr model].include? attribute
            end
            names.each { |name| nic_hash.store(name.to_sym, Fog::Proxmox::ControllerHelper.extract(name, value)) }
            attributes[:interfaces] << Fog::Proxmox::Compute::Interface.new(nic_hash)
          end
        end

        def initialize_disks(new_attributes)
          controllers = Fog::Proxmox::ControllerHelper.collect_controllers(new_attributes)
          attributes[:disks] = Fog::Proxmox::Compute::Disks.new
          controllers.each do |key, value|
            storage, volid, size = Fog::Proxmox::DiskHelper.extract_storage_volid_size(value)
            disk_hash = {
              id: key.to_s,
              size: size,
              volid: volid,
              storage: storage
            }
            names = Fog::Proxmox::Compute::Disk.attributes.reject do |attribute|
              %i[id size storage volid].include? attribute
            end
            names.each { |name| disk_hash.store(name.to_sym, Fog::Proxmox::ControllerHelper.extract(name, value)) }
            attributes[:disks] << Fog::Proxmox::Compute::Disk.new(disk_hash)
          end
        end
      end
    end
  end
end
