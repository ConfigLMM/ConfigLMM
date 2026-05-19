module Fog
  module Libvirt
    class Compute
      module Shared
        def update_display(options = { })
          raise ArgumentError, "uuid is a required parameter" unless options.key? :uuid

          domain = client.lookup_domain_by_uuid(options[:uuid])

          display          = { }
          display[:type]   = options[:type] || 'vnc'
          display[:port]   = (options[:port] || -1).to_s
          display[:listen] = options[:listen].to_s   if options[:listen]
          display[:passwd] = options[:password].to_s if options[:password]
          display[:autoport] = 'yes' if display[:port] == '-1'
          new_keymap       = options[:keymap] || xml_elements(domain.xml_desc, "graphics", "keymap")[0]
          display[:keymap] = new_keymap unless new_keymap.nil?

          builder = Nokogiri::XML::Builder.new { graphics_ (display) }
          xml     = Nokogiri::XML(builder.to_xml).root.to_s

          domain.update_device(xml, 0)
          # if we got no exceptions, then we're good'
          true
        end
      end

      class Real
        include Shared
      end

      class Mock
        include Shared
      end
    end
  end
end
