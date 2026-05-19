require 'fog/core/model'
require 'fog/libvirt/models/compute/util/util'

module Fog
  module Libvirt
    class Compute
      class Volume < Fog::Model
        attr_reader :xml
        include Fog::Libvirt::Util

        identity :id, :aliases => 'key'

        attribute :pool_name
        attribute :key
        attribute :name
        attribute :path
        attribute :capacity
        attribute :allocation
        attribute :owner
        attribute :group
        attribute :format_type
        attribute :backing_volume

        # Can be created by passing in :xml => "<xml to create volume>"
        # A volume always belongs to a pool, :pool_name => "<name of pool>"
        #
        def initialize(attributes={ })
          @xml = attributes.delete(:xml)
          super(defaults.merge(attributes))

          # We need a connection to calculate the pool_name
          # This is why we do this after super
          self.pool_name ||= default_pool_name
        end

        # Takes a pool and either :xml or other settings
        def save
          requires :pool_name

          raise Fog::Errors::Error.new('Reserving an existing volume may create a duplicate') if key
          @xml ||= to_xml
          self.id = service.create_volume(pool_name, xml).key
          reload
        end

        # Destroy a volume
        def destroy
          service.volume_action key, :delete
        end

        # Wipes a volume , zeroes disk
        def wipe
          service.volume_action key, :wipe
        end

        # Clones this volume to the name provided
        def clone(name)
          new_volume      = self.dup
          new_volume.key  = nil
          new_volume.name = name
          new_volume.save

          new_volume.reload
        end

        def clone_volume(new_name)
          requires :pool_name

          new_volume      = self.dup
          new_volume.key  = nil
          new_volume.name = new_name

          new_volume.id = service.clone_volume(pool_name, new_volume.to_xml, self.name).key
          new_volume.reload
        end

        def upload_image(file_path)
          requires :pool_name
          service.upload_volume(pool_name, name, file_path)
        end

        def to_xml
          builder = Nokogiri::XML::Builder.new do |xml|
            xml.volume do
              xml.name(name)

              allocation_size, allocation_unit = split_size_unit(allocation)
              xml.allocation(allocation_size, :unit => allocation_unit)

              capacity_size, capacity_unit = split_size_unit(capacity)
              xml.capacity(capacity_size, :unit => capacity_unit)

              xml.target do
                xml.format(:type => format_type)
                xml_permissions(xml)
              end

              if backing_volume
                xml.backingStore do
                  xml.path(backing_volume.path)
                  xml.format(:type => backing_volume.format_type)
                  xml_permissions(xml)
                end
              end
            end
          end

          builder.to_xml
        end

        private

        def xml_permissions(xml)
          xml.permissions do
            xml.owner(owner) if owner
            xml.group(group) if group
            xml.mode('0744')
            xml.label('virt_image_t')
          end
        end

        def image_suffix
          return "img" if format_type == "raw"
          format_type
        end

        def randominzed_name
          "#{super}.#{image_suffix}"
        end

        # Try to guess the default/first pool of no pool_name was specified
        def default_pool_name
          name = "default"
          return name unless (service.pools.all(:name => name)).empty?

          # we default to the first pool we find.
          first_pool = service.pools.first

          raise Fog::Errors::Error.new('No storage pools are defined') unless first_pool
          first_pool.name
        end

        def defaults
          {
            :persistent  => true,
            :format_type => "raw",
            :name        => randomized_name,
            :capacity    => "10G",
            :allocation  => "1G",
            :owner       => nil,
            :group       => nil,
          }
        end

        def split_size_unit(text)
          if (text.kind_of? String) && (matcher = text.match(/(\d+)(.+)/))
            size    = matcher[1]
            unit    = matcher[2]
          else
            size    = text.to_i
            unit    = "G"
          end
          [size, unit]
        end
      end
    end
  end
end
