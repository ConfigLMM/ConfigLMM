Shindo.tests('Fog::Compute[:libvirt] | nic model', ['libvirt']) do

  server = Fog::Compute[:libvirt].servers.create(:name => Fog::Mock.random_letters(8))
  nic = server.nics.first

  tests('The nic model should') do
    tests('have the action') do
      test('reload') { nic.respond_to? 'reload' }
    end
    tests('have attributes') do
      model_attribute_hash = nic.attributes
      attributes = [ :mac,
        :model,
        :type,
        :network,
        :bridge]
      tests("The nic model should respond to") do
        attributes.each do |attribute|
          test("#{attribute}") { nic.respond_to? attribute }
        end
      end
      tests("The attributes hash should have key") do
        attributes.delete(:bridge)
        attributes.each do |attribute|
          test("#{attribute}") { model_attribute_hash.key? attribute }
        end
      end
    end
    test('be a kind of Fog::Libvirt::Compute::Nic') { nic.kind_of? Fog::Libvirt::Compute::Nic }
  end

end
