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
    # module ControllerHelper mixins
    module ControllerHelper
      CONTROLLERS = %w[ide sata scsi virtio mp rootfs].freeze
      def self.extract(name, controller_value)
        matches = controller_value.match(%r{,{0,1}#{name}={1}(?<name_value>[\w/.:]+)})
        matches ? matches[:name_value] : matches
      end

      def self.extract_index(name, key)
        matches = key.to_s.match(/#{name}(?<index>\d+)/)
        index = matches ? matches[:index] : matches
        index ? index.to_i : -1
      end

      def self.valid?(name, key)
        key.to_s.match(/^#{name}(\d*)$/)
      end

      def self.last_index(name, values)
        return -1 if values.empty?

        indexes = []
        values.each do |value|
          index = extract_index(name, value)
          indexes.push(index) if index
        end
        indexes.sort
        indexes.empty? ? -1 : indexes.last
      end

      def self.select(hash, name)
        hash.select { |key| valid?(name, key.to_s) }
      end

      def self.collect_controllers(attributes)
        controllers = {}
        CONTROLLERS.each { |controller| controllers.merge!(select(attributes, controller)) }
        controllers
      end
    end
  end
end
