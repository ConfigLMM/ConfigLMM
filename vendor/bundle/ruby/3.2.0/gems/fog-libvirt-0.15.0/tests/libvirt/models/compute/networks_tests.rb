Shindo.tests('Fog::Compute[:libvirt] | networks collection', ['libvirt']) do

  networks = Fog::Compute[:libvirt].networks

  tests('The networks collection') do
    test('should be a kind of Fog::Libvirt::Compute::Networks') { networks.kind_of? Fog::Libvirt::Compute::Networks }
    tests('should be able to reload itself').succeeds { networks.reload }
    tests('should be able to get a model') do
      tests('by instance id').succeeds { networks.get networks.first.uuid }
    end
  end

end
