require 'nokogiri'
require 'securerandom'

module Fog
  module Libvirt
    module Util
      def xml_element(xml, path, attribute=nil)
        xml = Nokogiri::XML(xml)
        attribute.nil? ? (xml/path).first.text : (xml/path).first[attribute.to_sym]
      end

      def xml_elements(xml, path, attribute=nil)
        xml = Nokogiri::XML(xml)
        attribute.nil? ? (xml/path).map : (xml/path).map{|element| element[attribute.to_sym]}
      end

      def randomized_name
        "fog-#{(SecureRandom.random_number*10E14).to_i.round}"
      end
    end
  end
end
