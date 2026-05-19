#!/usr/bin/ruby

# Test the network methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("network")

conn = Libvirt::open(URI)

cleanup_test_network(conn)

# TESTGROUP: net.undefine
newnet = conn.define_network_xml($new_net_xml)

expect_too_many_args(newnet, "undefine", 1)

expect_success(newnet, "no args", "undefine")

# TESTGROUP: net.create
newnet = conn.define_network_xml($new_net_xml)

expect_too_many_args(newnet, "create", 1)

expect_success(newnet, "no args", "create")

expect_fail(newnet, Libvirt::Error, "on already running network", "create")

newnet.destroy
newnet.undefine

# TESTGROUP: net.update
newnet = conn.create_network_xml($new_net_xml)

expect_too_few_args(newnet, "update", 1)

command = Libvirt::Network::NETWORK_UPDATE_COMMAND_ADD_LAST
section = Libvirt::Network::NETWORK_SECTION_IP_DHCP_HOST
flags   = Libvirt::Network::NETWORK_UPDATE_AFFECT_CURRENT
expect_success(newnet, "dhcp ip", "update",
               command, section, -1, $new_network_dhcp_ip, flags)

newnet.destroy

# TESTGROUP: net.destroy
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(newnet, "destroy", 1)

expect_success(newnet, "no args", "destroy")

# TESTGROUP: net.name
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(newnet, "name", 1)

expect_success(newnet, "no args", "name") {|x| x == "rb-libvirt-test"}

newnet.destroy

# TESTGROUP: net.uuid
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(newnet, "uuid", 1)

expect_success(newnet, "no args", "uuid") {|x| x == $NETWORK_UUID}

newnet.destroy

# TESTGROUP: net.xml_desc
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(newnet, "xml_desc", 1, 2)
expect_invalid_arg_type(newnet, "xml_desc", "foo")

expect_success(newnet, "no args", "xml_desc")

newnet.destroy

# TESTGROUP: net.bridge_name
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(newnet, "bridge_name", 1)

expect_success(newnet, "no args", "bridge_name") {|x| x == "rubybr0"}

newnet.destroy

# TESTGROUP: net.autostart?
newnet = conn.define_network_xml($new_net_xml)

expect_too_many_args(newnet, "autostart?", 1)

expect_success(newnet, "no args", "autostart?") {|x| x == false}

newnet.autostart = true

expect_success(newnet, "no args", "autostart?") {|x| x == true}

newnet.undefine

# TESTGROUP: net.autostart=
newnet = conn.define_network_xml($new_net_xml)

expect_too_many_args(newnet, "autostart=", 1, 2)
expect_invalid_arg_type(newnet, "autostart=", 'foo')
expect_invalid_arg_type(newnet, "autostart=", nil)
expect_invalid_arg_type(newnet, "autostart=", 1234)

expect_success(newnet, "boolean arg", "autostart=", true)
if not newnet.autostart?
  puts_fail "network.autostart= did not set autostart to true"
else
  puts_ok "network.autostart= set autostart to true"
end

expect_success(newnet, "boolean arg", "autostart=", false)
if newnet.autostart?
  puts_fail "network.autostart= did not set autostart to false"
else
  puts_ok "network.autostart= set autostart to false"
end

newnet.undefine

# TESTGROUP: net.free
newnet = conn.define_network_xml($new_net_xml)
newnet.undefine
expect_too_many_args(newnet, "free", 1)

expect_success(newnet, "no args", "free")

# TESTGROUP: net.active?
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(newnet, "active?", 1)

expect_success(newnet, "no args", "active?") {|x| x == true}

newnet.destroy

newnet = conn.define_network_xml($new_net_xml)

expect_success(newnet, "no args", "active?") {|x| x == false}

newnet.create

expect_success(newnet, "no args", "active?") {|x| x == true}

newnet.destroy
newnet.undefine

# TESTGROUP: net.persistent?
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(newnet, "persistent?", 1)

expect_success(newnet, "no args", "persistent?") {|x| x == false}

newnet.destroy

newnet = conn.define_network_xml($new_net_xml)

expect_success(newnet, "no args", "persistent?") {|x| x == true}

newnet.undefine

# END TESTS

conn.close

finish_tests
