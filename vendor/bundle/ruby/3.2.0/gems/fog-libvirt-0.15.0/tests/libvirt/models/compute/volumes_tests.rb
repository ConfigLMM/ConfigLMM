Shindo.tests('Fog::Compute[:libvirt] | volumes collection', ['libvirt']) do

  volumes = Fog::Compute[:libvirt].volumes

  volumes.create(:name => 'test')

  tests('The volumes collection') do
    test('should not be empty') { not volumes.empty? }
    test('should be a kind of Fog::Libvirt::Compute::Volumes') { volumes.kind_of? Fog::Libvirt::Compute::Volumes }
    tests('should be able to reload itself').succeeds { volumes.reload }
    tests('should be able to get a model') do
      tests('by instance uuid').succeeds { volumes.get volumes.first.id }
    end
    test('filtered should be empty') { volumes.all(:name => "does-not-exist").empty? }
  end

end
