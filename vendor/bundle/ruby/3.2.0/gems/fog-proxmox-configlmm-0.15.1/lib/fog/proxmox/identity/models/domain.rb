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
    class Identity
      # class Domain model authentication
      class Domain < Fog::Model
        identity :realm
        attribute :comment
        attribute :tfa
        attribute :type

        def initialize(new_attributes = {})
          initialize_type(new_attributes)
          super(new_attributes)
        end

        def save(new_attributes = {})
          service.create_domain(type.attributes.merge(new_attributes).merge(attributes.reject do |attribute|
                                                                              [:type].include? attribute
                                                                            end))
          reload
        end

        def destroy
          requires :realm
          service.delete_domain(realm)
          true
        end

        def update
          requires :realm
          service.update_domain(realm, type.attributes.merge(attributes).reject do |attribute|
                                         %i[type realm].include? attribute
                                       end)
          reload
        end

        private

        def initialize_type(new_attributes = {})
          if new_attributes.has_key? :realm
            realm = new_attributes.delete(:realm)
          elsif new_attributes.has_key? 'realm'
            realm = new_attributes.delete('realm')
          end
          attributes[:type] = Fog::Proxmox::Identity::DomainType.new(new_attributes)
          new_attributes.delete_if { |new_attribute| attributes[:type].attributes.has_key? new_attribute.to_sym }
          new_attributes.store(:realm, realm)
        end
      end
    end
  end
end
