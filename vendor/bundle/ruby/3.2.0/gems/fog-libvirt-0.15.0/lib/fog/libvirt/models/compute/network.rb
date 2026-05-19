require 'fog/core/model'
require 'fog/libvirt/models/compute/util/util'

module Fog
  module Libvirt
    class Compute
      class Network < Fog::Model
        include Fog::Libvirt::Util

        identity :uuid
        attribute :name
        attribute :bridge_name
        attribute :xml

        def initialize(attributes = {})
          super
        end

        def dhcp_leases(mac, flags = 0)
          service.dhcp_leases(uuid, mac, flags)
        end

        def save
          raise Fog::Errors::Error.new('Creating a new network is not yet implemented. Contributions welcome!')
        end

        def shutdown
          service.destroy_network(uuid)
        end

        def to_xml
          builder = Nokogiri::XML::Builder.new do |xml|
            xml.network do
              xml.name(name)
              xml.bridge(:name => bridge_name, :stp => 'on', :delay => '0')
            end
          end

          builder.to_xml
        end
      end
    end
  end
end
