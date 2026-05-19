Shindo.tests('Fog::Compute[:libvirt] | network model', ['libvirt']) do

  networks = Fog::Compute[:libvirt].networks
  network = networks.first

  tests('The network model should') do
    tests('have the action') do
      test('reload') { network.respond_to? 'reload' }
      test('dhcp_leases') { network.respond_to? 'dhcp_leases' }
    end
    tests('have a dhcp_leases action that') do
      test('returns an array') { network.dhcp_leases('aa:bb:cc:dd:ee:ff', 0).kind_of? Array }
    end
    tests('have attributes') do
      model_attribute_hash = network.attributes
      attributes = [ :name, :uuid, :bridge_name]
      tests("The network model should respond to") do
        attributes.each do |attribute|
          test("#{attribute}") { network.respond_to? attribute }
        end
      end
      tests("The attributes hash should have key") do
        attributes.each do |attribute|
          test("#{attribute}") { model_attribute_hash.key? attribute }
        end
      end
    end
    test('be a kind of Fog::Libvirt::Compute::Network') { network.kind_of? Fog::Libvirt::Compute::Network }
  end

  tests("to_xml") do
    test("default") do
      expected = <<~NETWORK
        <?xml version="1.0"?>
        <network>
          <name>default</name>
          <bridge name="virbr0" stp="on" delay="0"/>
        </network>
      NETWORK
      network.to_xml == expected
    end
  end
end
