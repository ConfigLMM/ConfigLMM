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
    # module Variables mixins
    module Variables
      def self.to_variables(instance, hash, prefix)
        hash.select { |key| key.to_s.start_with? prefix }.each do |key, value|
          instance.instance_variable_set "@#{key}".to_sym, value
        end
      end

      def self.to_hash(instance, prefix)
        hash = {}
        instance.instance_variables.select { |variable| variable.to_s.start_with? '@' + prefix }.each do |param|
          name = param.to_s[1..-1]
          hash.store(name.to_sym, instance.instance_variable_get(param))
        end
        hash
      end
    end
  end
end
