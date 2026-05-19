Shindo.tests("Fog::Compute[:libvirt] | dhcp_leases request", 'libvirt') do

  compute = Fog::Compute[:libvirt]

  tests("DHCP leases response") do
    response = compute.dhcp_leases("fbd4ac68-cbea-4f95-86ed-22953fd92384", "99:88:77:66:55:44", 0)
    test("should be an array") { response.kind_of? Array }
    test("should have one element") { response.length == 1 }
    test("should have dict elements") { response[0].kind_of? Hash }
    ["ipaddr", "prefix", "expirytime", "type"].each {
      |k| test("should have dict elements with required key #{k}") { !response[0][k].nil? }
    }
  end

end
