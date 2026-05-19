Shindo.tests('Fog::Compute[:libvirt] | update_autostart request', ['libvirt']) do

  servers = Fog::Compute[:libvirt].servers

  tests('The response should') do
    test('should not be empty') { not servers.empty? }
    server = servers.first
    tests('should be false').succeeds { server.autostart == false }
    server.update_autostart(true)
  end

end
