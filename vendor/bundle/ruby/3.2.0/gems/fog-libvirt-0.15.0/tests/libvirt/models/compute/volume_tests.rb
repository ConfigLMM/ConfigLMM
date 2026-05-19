Shindo.tests('Fog::Compute[:libvirt] | volume model', ['libvirt']) do

  volume = Fog::Compute[:libvirt].volumes.create(:name => 'fog_test')

  tests('The volume model should') do
    tests('have attributes') do
      model_attribute_hash = volume.attributes
      attributes = [ :id,
        :pool_name,
        :key,
        :name,
        :path,
        :capacity,
        :allocation,
        :format_type]
      tests("The volume model should respond to") do
        attributes.each do |attribute|
          test("#{attribute}") { volume.respond_to? attribute }
        end
      end
      tests("The attributes hash should have key") do
        attributes.each do |attribute|
          test("#{attribute}") { model_attribute_hash.key? attribute }
        end
      end
    end
    test('be a kind of Fog::Libvirt::Compute::Volume') { volume.kind_of? Fog::Libvirt::Compute::Volume }
  end

  tests('Cloning volumes should') do
    test('respond to clone_volume') { volume.respond_to? :clone_volume }
    new_vol = volume.clone_volume('new_vol')
    # We'd like to test that the :name attr has changed, but it seems that's
    # not possible, so we can at least check the new_vol xml exists properly
    test('succeed') { volume.xml == new_vol.xml }
  end

  test('to_xml') do
    test('default') do
      expected = <<~VOLUME
        <?xml version="1.0"?>
        <volume>
          <name>fog_test</name>
          <allocation unit="G">1</allocation>
          <capacity unit="G">10</capacity>
          <target>
            <format type="raw"/>
            <permissions>
              <mode>0744</mode>
              <label>virt_image_t</label>
            </permissions>
          </target>
        </volume>
      VOLUME
      volume.to_xml == expected
    end
  end
end
