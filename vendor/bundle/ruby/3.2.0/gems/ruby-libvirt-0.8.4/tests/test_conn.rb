#!/usr/bin/ruby

# Test the conn methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("connect")

conn = Libvirt::open(URI)

cleanup_test_domain(conn)
cleanup_test_network(conn)

# test setup
if !test_default_uri?
  begin
    `rm -f /etc/sysconfig/network-scripts/ifcfg-rb-libvirt-test`
    `brctl delbr rb-libvirt-test >& /dev/null`
  rescue
  end
  `qemu-img create -f qcow2 #{$GUEST_DISK} 5G`
  `rm -rf #{$POOL_PATH}; mkdir #{$POOL_PATH} ; echo $?`
end

cpu_xml = <<EOF
<cpu>
  <arch>x86_64</arch>
  <model>athlon</model>
</cpu>
EOF

# TESTGROUP: conn.close
conn2 = Libvirt::open(URI)
expect_too_many_args(conn2, "close", 1)
expect_success(conn2, "no args", "close")

# TESTGROUP: conn.closed?
conn2 = Libvirt::open(URI)

expect_too_many_args(conn2, "closed?", 1)
expect_success(conn2, "no args", "closed?") {|x| x == false }
conn2.close
expect_success(conn2, "no args", "closed?") {|x| x == true }

# TESTGROUP: conn.type
expect_too_many_args(conn, "type", 1)

if test_default_uri?
  expect_success(conn, "no args", "type") {|x| x == "TEST"}
else
  expect_success(conn, "no args", "type") {|x| x == "QEMU"}
end

# TESTGROUP: conn.version
expect_too_many_args(conn, "version", 1)

expect_success(conn, "no args", "version")

# TESTGROUP: conn.libversion
expect_too_many_args(conn, "libversion", 1)

expect_success(conn, "no args", "libversion")

# TESTGROUP: conn.hostname
expect_too_many_args(conn, "hostname", 1)

expect_success(conn, "no args", "hostname")

# TESTGROUP: conn.uri
expect_too_many_args(conn, "uri", 1)

expect_success(conn, "no args", "uri") {|x| x == URI }

# TESTGROUP: conn.max_vcpus
expect_too_many_args(conn, "max_vcpus", 'kvm', 1)

if !test_default_uri?
  expect_fail(conn, Libvirt::RetrieveError, "invalid arg", "max_vcpus", "foo")
end

expect_success(conn, "no args", "max_vcpus")
expect_success(conn, "nil arg", "max_vcpus")
expect_success(conn, "kvm arg", "max_vcpus")
expect_success(conn, "qemu arg", "max_vcpus")

# TESTGROUP: conn.node_get_info
expect_too_many_args(conn, "node_get_info", 1)

expect_success(conn, "no args", "node_get_info")

# TESTGROUP: conn.node_free_memory
expect_too_many_args(conn, "node_free_memory", 1)

expect_success(conn, "no args", "node_free_memory")

# TESTGROUP: conn.node_cells_free_memory
expect_too_many_args(conn, "node_cells_free_memory", 1, 2, 3)
expect_invalid_arg_type(conn, "node_cells_free_memory", 'start')
expect_invalid_arg_type(conn, "node_cells_free_memory", 0, 'end')

expect_success(conn, "no args", "node_cells_free_memory")
expect_success(conn, "start cell", "node_cells_free_memory", 0)
expect_success(conn, "start cell and max cells", "node_cells_free_memory", 0, 1)

# TESTGROUP: conn.node_get_security_model
expect_too_many_args(conn, "node_get_security_model", 1)
expect_success(conn, "no args", "node_get_security_model")

# TESTGROUP: conn.encrypted?
expect_too_many_args(conn, "encrypted?", 1)
expect_success(conn, "no args", "encrypted?")

# TESTGROUP: conn.secure?
expect_too_many_args(conn, "secure?", 1)
expect_success(conn, "no args", "secure?") {|x| x == true}

# TESTGROUP: conn.capabilities
expect_too_many_args(conn, "capabilities", 1)
expect_success(conn, "no args", "capabilities")

# TESTGROUP: conn.compare_cpu
if !test_default_uri?
  expect_too_many_args(conn, "compare_cpu", 1, 2, 3)
  expect_too_few_args(conn, "compare_cpu")
  expect_invalid_arg_type(conn, "compare_cpu", 1)
  expect_invalid_arg_type(conn, "compare_cpu", "hello", 'bar')
  expect_fail(conn, Libvirt::RetrieveError, "invalid XML", "compare_cpu", "hello")
  expect_success(conn, "CPU XML", "compare_cpu", cpu_xml)
end

# TESTGROUP: conn.baseline_cpu
expect_too_many_args(conn, "baseline_cpu", 1, 2, 3)
expect_too_few_args(conn, "baseline_cpu")
expect_invalid_arg_type(conn, "baseline_cpu", 1)
expect_invalid_arg_type(conn, "baseline_cpu", [cpu_xml], "foo")
expect_fail(conn, ArgumentError, "empty array", "baseline_cpu", [])
expect_success(conn, "CPU XML", "baseline_cpu", [cpu_xml])

# TESTGROUP: conn.domain_event_register_any
dom_event_callback_proc = lambda {|connect, dom, event, detail, opaque|
}

# def dom_event_callback_symbol(conn, dom, event, detail, opaque)
# end

expect_too_many_args(conn, "domain_event_register_any", 1, 2, 3, 4, 5)
expect_too_few_args(conn, "domain_event_register_any")
expect_too_few_args(conn, "domain_event_register_any", 1)
expect_invalid_arg_type(conn, "domain_event_register_any", "hello", 1)
expect_invalid_arg_type(conn, "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, 1)
expect_invalid_arg_type(conn, "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc, 1)
expect_fail(conn, ArgumentError, "invalid event ID", "domain_event_register_any", 456789, dom_event_callback_proc)

# callbackID = expect_success(conn, "eventID and proc", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc)
# conn.domain_event_deregister_any(callbackID)

# callbackID = expect_success(conn, "eventID and symbol", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, :dom_event_callback_symbol)
# conn.domain_event_deregister_any(callbackID)

# callbackID = expect_success(conn, "eventID, proc, nil domain", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc, nil)
# conn.domain_event_deregister_any(callbackID)

# callbackID = expect_success(conn, "eventID, proc, nil domain, opaque", "domain_event_register_any", Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc, nil, "opaque user data")
# conn.domain_event_deregister_any(callbackID)

# # TESTGROUP: conn.domain_event_deregister_any
# dom_event_callback_proc = lambda {|conn, dom, event, detail, opaque|
# }

# callbackID = conn.domain_event_register_any(Libvirt::Connect::DOMAIN_EVENT_ID_LIFECYCLE, dom_event_callback_proc)

expect_too_many_args(conn, "domain_event_deregister_any", 1, 2)
expect_too_few_args(conn, "domain_event_deregister_any")
expect_invalid_arg_type(conn, "domain_event_deregister_any", "hello")

# expect_success(conn, "callbackID", "domain_event_deregister_any", callbackID)

# TESTGROUP: conn.domain_event_register
# dom_event_callback_proc = lambda {|conn, dom, event, detail, opaque|
# }

# def dom_event_callback_symbol(conn, dom, event, detail, opaque)
# end

expect_too_many_args(conn, "domain_event_register", 1, 2, 3)
expect_too_few_args(conn, "domain_event_register")
expect_invalid_arg_type(conn, "domain_event_register", "hello")

# expect_success(conn, "proc", "domain_event_register", dom_event_callback_proc)
# conn.domain_event_deregister

# expect_success(conn, "symbol", "domain_event_register", :dom_event_callback_symbol)
# conn.domain_event_deregister

# expect_success(conn, "proc and opaque", "domain_event_register", dom_event_callback_proc, "opaque user data")
# conn.domain_event_deregister

# # TESTGROUP: conn.domain_event_deregister
# dom_event_callback_proc = lambda {|conn, dom, event, detail, opaque|
# }

# conn.domain_event_register(dom_event_callback_proc)

expect_too_many_args(conn, "domain_event_deregister", 1)
# expect_success(conn, "no args", "domain_event_deregister")

# TESTGROUP: conn.num_of_domains
expect_too_many_args(conn, "num_of_domains", 1)
expect_success(conn, "no args", "num_of_domains")

# TESTGROUP: conn.list_domains
expect_too_many_args(conn, "list_domains", 1)
expect_success(conn, "no args", "list_domains")

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_success(conn, "no args", "list_domains")

newdom.destroy

# TESTGROUP: conn.num_of_defined_domains
expect_too_many_args(conn, "num_of_defined_domains", 1)
expect_success(conn, "no args", "num_of_defined_domains")

# TESTGROUP: conn.list_defined_domains
expect_too_many_args(conn, "list_defined_domains", 1)
expect_success(conn, "no args", "list_defined_domains")

# TESTGROUP: conn.create_domain_linux
expect_too_many_args(conn, "create_domain_linux", $new_dom_xml, 0, 1)
expect_too_few_args(conn, "create_domain_linux")
expect_invalid_arg_type(conn, "create_domain_linux", nil)
expect_invalid_arg_type(conn, "create_domain_linux", 1)
expect_invalid_arg_type(conn, "create_domain_linux", $new_dom_xml, "foo")
expect_fail(conn, Libvirt::Error, "invalid xml", "create_domain_linux", "hello")
newdom = expect_success(conn, "domain xml", "create_domain_linux", $new_dom_xml) {|x| x.class == Libvirt::Domain}
test_sleep 1

expect_fail(conn, Libvirt::Error, "already existing domain", "create_domain_linux", $new_dom_xml)

newdom.destroy

# TESTGROUP: conn.create_domain_xml
expect_too_many_args(conn, "create_domain_xml", $new_dom_xml, 0, 1)
expect_too_few_args(conn, "create_domain_xml")
expect_invalid_arg_type(conn, "create_domain_xml", nil)
expect_invalid_arg_type(conn, "create_domain_xml", 1)
expect_invalid_arg_type(conn, "create_domain_xml", $new_dom_xml, "foo")
expect_fail(conn, Libvirt::Error, "invalid xml", "create_domain_xml", "hello")
newdom = expect_success(conn, "domain xml", "create_domain_xml", $new_dom_xml) {|x| x.class == Libvirt::Domain}
test_sleep 1

expect_fail(conn, Libvirt::Error, "already existing domain", "create_domain_xml", $new_dom_xml)

newdom.destroy

# TESTGROUP: conn.lookup_domain_by_name
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(conn, "lookup_domain_by_name", 1, 2)
expect_too_few_args(conn, "lookup_domain_by_name")
expect_invalid_arg_type(conn, "lookup_domain_by_name", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent name arg", "lookup_domain_by_name", "foobarbazsucker")

expect_success(conn, "name arg for running domain", "lookup_domain_by_name", "rb-libvirt-test") {|x| x.name == "rb-libvirt-test"}
newdom.destroy

newdom = conn.define_domain_xml($new_dom_xml)
expect_success(conn, "name arg for defined domain", "lookup_domain_by_name", "rb-libvirt-test") {|x| x.name == "rb-libvirt-test"}
newdom.undefine

# TESTGROUP: conn.lookup_domain_by_id
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(conn, "lookup_domain_by_id", 1, 2)
expect_too_few_args(conn, "lookup_domain_by_id")
expect_invalid_arg_type(conn, "lookup_domain_by_id", "foo")
expect_fail(conn, Libvirt::Error, "with negative value", "lookup_domain_by_id", -1)

expect_success(conn, "id arg for running domain", "lookup_domain_by_id", newdom.id)
newdom.destroy

# TESTGROUP: conn.lookup_domain_by_uuid
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(conn, "lookup_domain_by_uuid", 1, 2)
expect_too_few_args(conn, "lookup_domain_by_uuid")
expect_invalid_arg_type(conn, "lookup_domain_by_uuid", 1)
expect_fail(conn, Libvirt::RetrieveError, "invalid UUID", "lookup_domain_by_uuid", "abcd")

expect_success(conn, "UUID arg for running domain", "lookup_domain_by_uuid", newdom.uuid) {|x| x.uuid == $GUEST_UUID}
newdom.destroy

newdom = conn.define_domain_xml($new_dom_xml)
expect_success(conn, "UUID arg for defined domain", "lookup_domain_by_uuid", newdom.uuid) {|x| x.uuid == $GUEST_UUID}
newdom.undefine

# TESTGROUP: conn.define_domain_xml
expect_too_many_args(conn, "define_domain_xml", 1, 2, 3)
expect_too_few_args(conn, "define_domain_xml")
expect_invalid_arg_type(conn, "define_domain_xml", 1)
expect_invalid_arg_type(conn, "define_domain_xml", nil)
expect_fail(conn, Libvirt::DefinitionError, "invalid XML", "define_domain_xml", "hello")

newdom = expect_success(conn, "domain xml arg", "define_domain_xml", $new_dom_xml)
newdom.undefine

# TESTGROUP: conn.num_of_interfaces
expect_too_many_args(conn, "num_of_interfaces", 1)
expect_success(conn, "no args", "num_of_interfaces")

# TESTGROUP: conn.list_interfaces
expect_too_many_args(conn, "list_interfaces", 1)
expect_success(conn, "no args", "list_interfaces")

# TESTGROUP: conn.num_of_defined_interfaces
expect_too_many_args(conn, "num_of_defined_interfaces", 1)
expect_success(conn, "no args", "num_of_defined_interfaces")

# TESTGROUP: conn.list_defined_interfaces
expect_too_many_args(conn, "list_defined_interfaces", 1)
expect_success(conn, "no args", "list_defined_interfaces")

# TESTGROUP: conn.lookup_interface_by_name
newiface = conn.define_interface_xml($new_interface_xml)

expect_too_many_args(conn, "lookup_interface_by_name", 1, 2)
expect_too_few_args(conn, "lookup_interface_by_name")
expect_invalid_arg_type(conn, "lookup_interface_by_name", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent name arg", "lookup_interface_by_name", "foobarbazsucker")

expect_success(conn, "name arg", "lookup_interface_by_name", "rb-libvirt-test")

expect_success(conn, "name arg", "lookup_interface_by_name", "rb-libvirt-test")

newiface.undefine

# TESTGROUP: conn.lookup_interface_by_mac
newiface = conn.define_interface_xml($new_interface_xml)

expect_too_many_args(conn, "lookup_interface_by_mac", 1, 2)
expect_too_few_args(conn, "lookup_interface_by_mac")
expect_invalid_arg_type(conn, "lookup_interface_by_mac", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent mac arg", "lookup_interface_by_mac", "foobarbazsucker")

# FIXME: we can't look up an interface by MAC address on an inactive interface,
# but we also can't start up the interface without a /etc/sysconfig file.
#expect_success(conn, "mac arg", "lookup_interface_by_mac", $NEW_INTERFACE_MAC) {|x| x.mac == $NEW_INTERFACE_MAC}

newiface.undefine

# TESTGROUP: conn.define_interface_xml
expect_too_many_args(conn, "define_interface_xml", 1, 2, 3)
expect_too_few_args(conn, "define_interface_xml")
expect_invalid_arg_type(conn, "define_interface_xml", 1)
expect_invalid_arg_type(conn, "define_interface_xml", nil)
expect_invalid_arg_type(conn, "define_interface_xml", "hello", 'foo')
expect_fail(conn, Libvirt::DefinitionError, "invalid XML", "define_interface_xml", "hello")

expect_success(conn, "interface XML", "define_interface_xml", $new_interface_xml)
newiface.undefine

# TESTGROUP: conn.num_of_networks
expect_too_many_args(conn, "num_of_networks", 1)
expect_success(conn, "no args", "num_of_networks")

# TESTGROUP: conn.list_networks
expect_too_many_args(conn, "list_networks", 1)
expect_success(conn, "no args", "list_networks")

# TESTGROUP: conn.num_of_defined_networks
expect_too_many_args(conn, "num_of_defined_networks", 1)
expect_success(conn, "no args", "num_of_defined_networks")

# TESTGROUP: conn.list_defined_networks
expect_too_many_args(conn, "list_defined_networks", 1)
expect_success(conn, "no args", "list_defined_networks")

# TESTGROUP: conn.lookup_network_by_name
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(conn, "lookup_network_by_name", 1, 2)
expect_too_few_args(conn, "lookup_network_by_name")
expect_invalid_arg_type(conn, "lookup_network_by_name", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent name arg", "lookup_network_by_name", "foobarbazsucker")

expect_success(conn, "name arg", "lookup_network_by_name", "rb-libvirt-test")
newnet.destroy

newnet = conn.define_network_xml($new_net_xml)
expect_success(conn, "name arg", "lookup_network_by_name", "rb-libvirt-test")
newnet.undefine

# TESTGROUP: conn.lookup_network_by_uuid
newnet = conn.create_network_xml($new_net_xml)

expect_too_many_args(conn, "lookup_network_by_uuid", 1, 2)
expect_too_few_args(conn, "lookup_network_by_uuid")
expect_invalid_arg_type(conn, "lookup_network_by_uuid", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent uuid arg", "lookup_network_by_uuid", "foobarbazsucker")

expect_success(conn, "uuid arg", "lookup_network_by_uuid", $NETWORK_UUID)
newnet.destroy

newnet = conn.define_network_xml($new_net_xml)
expect_success(conn, "uuid arg", "lookup_network_by_uuid", $NETWORK_UUID)
newnet.undefine

# TESTGROUP: conn.create_network_xml
expect_too_many_args(conn, "create_network_xml", $new_net_xml, 0)
expect_too_few_args(conn, "create_network_xml")
expect_invalid_arg_type(conn, "create_network_xml", nil)
expect_invalid_arg_type(conn, "create_network_xml", 1)
expect_fail(conn, Libvirt::Error, "invalid xml", "create_network_xml", "hello")

newnet = expect_success(conn, "network XML", "create_network_xml", $new_net_xml)

expect_fail(conn, Libvirt::Error, "already existing network", "create_network_xml", $new_net_xml)

newnet.destroy

# TESTGROUP: conn.define_network_xml
expect_too_many_args(conn, "define_network_xml", 1, 2)
expect_too_few_args(conn, "define_network_xml")
expect_invalid_arg_type(conn, "define_network_xml", 1)
expect_invalid_arg_type(conn, "define_network_xml", nil)
expect_fail(conn, Libvirt::DefinitionError, "invalid XML", "define_network_xml", "hello")

newnet = expect_success(conn, "network XML", "define_network_xml", $new_net_xml)
newnet.undefine

# TESTGROUP: conn.num_of_nodedevices
expect_too_many_args(conn, "num_of_nodedevices", 1, 2, 3)
expect_invalid_arg_type(conn, "num_of_nodedevices", 1)
expect_invalid_arg_type(conn, "num_of_nodedevices", 'foo', 'bar')
expect_success(conn, "no args", "num_of_nodedevices")

# TESTGROUP: conn.list_nodedevices
expect_too_many_args(conn, "list_nodedevices", 1, 2, 3)
expect_invalid_arg_type(conn, "list_nodedevices", 1)
expect_invalid_arg_type(conn, "list_nodedevices", 'foo', 'bar')
expect_success(conn, "no args", "list_nodedevices")

# TESTGROUP: conn.lookup_nodedevice_by_name
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(conn, "lookup_nodedevice_by_name", 1, 2)
expect_too_few_args(conn, "lookup_nodedevice_by_name")
expect_invalid_arg_type(conn, "lookup_nodedevice_by_name", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent name arg", "lookup_nodedevice_by_name", "foobarbazsucker")

expect_success(conn, "name arg", "lookup_nodedevice_by_name", testnode.name)

# TESTGROUP: conn.create_nodedevice_xml
expect_too_many_args(conn, "create_nodedevice_xml", 1, 2, 3)
expect_too_few_args(conn, "create_nodedevice_xml")
expect_invalid_arg_type(conn, "create_nodedevice_xml", 1)
expect_invalid_arg_type(conn, "create_nodedevice_xml", "foo", 'bar')
expect_fail(conn, Libvirt::Error, "invalid XML", "create_nodedevice_xml", "hello")

#expect_success(conn, "nodedevice XML", "create_nodedevice_xml", "<nodedevice/>")

# TESTGROUP: conn.num_of_nwfilters
if !test_default_uri?
  expect_too_many_args(conn, "num_of_nwfilters", 1)
  expect_success(conn, "no args", "num_of_nwfilters")
end

# TESTGROUP: conn.list_nwfilters
if !test_default_uri?
  expect_too_many_args(conn, "list_nwfilters", 1)
  expect_success(conn, "no args", "list_nwfilters")
end

# TESTGROUP: conn.lookup_nwfilter_by_name
if !test_default_uri?
  newnw = conn.define_nwfilter_xml($new_nwfilter_xml)

  expect_too_many_args(conn, "lookup_nwfilter_by_name", 1, 2)
  expect_too_few_args(conn, "lookup_nwfilter_by_name")
  expect_invalid_arg_type(conn, "lookup_nwfilter_by_name", 1)

  expect_success(conn, "name arg", "lookup_nwfilter_by_name", "rb-libvirt-test")

  newnw.undefine
end

# TESTGROUP: conn.lookup_nwfilter_by_uuid
if !test_default_uri?
  newnw = conn.define_nwfilter_xml($new_nwfilter_xml)

  expect_too_many_args(conn, "lookup_nwfilter_by_uuid", 1, 2)
  expect_too_few_args(conn, "lookup_nwfilter_by_uuid")
  expect_invalid_arg_type(conn, "lookup_nwfilter_by_uuid", 1)

  expect_success(conn, "uuid arg", "lookup_nwfilter_by_uuid", $NWFILTER_UUID) {|x| x.uuid == $NWFILTER_UUID}

  newnw.undefine
end

# TESTGROUP: conn.define_nwfilter_xml
if !test_default_uri?
  expect_too_many_args(conn, "define_nwfilter_xml", 1, 2)
  expect_too_few_args(conn, "define_nwfilter_xml")
  expect_invalid_arg_type(conn, "define_nwfilter_xml", 1)
  expect_invalid_arg_type(conn, "define_nwfilter_xml", nil)
  expect_fail(conn, Libvirt::DefinitionError, "invalid XML", "define_nwfilter_xml", "hello")

  newnw = expect_success(conn, "nwfilter XML", "define_nwfilter_xml", $new_nwfilter_xml)

  newnw.undefine
end

# TESTGROUP: conn.num_of_secrets
if !test_default_uri?
  expect_too_many_args(conn, "num_of_secrets", 1)
  expect_success(conn, "no args", "num_of_secrets")
end

# TESTGROUP: conn.list_secrets
if !test_default_uri?
  expect_too_many_args(conn, "list_secrets", 1)
  expect_success(conn, "no args", "list_secrets")
end

# TESTGROUP: conn.lookup_secret_by_uuid
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(conn, "lookup_secret_by_uuid", 1, 2)
  expect_too_few_args(conn, "lookup_secret_by_uuid")
  expect_invalid_arg_type(conn, "lookup_secret_by_uuid", 1)

  expect_success(conn, "uuid arg", "lookup_secret_by_uuid", $SECRET_UUID) {|x| x.uuid == $SECRET_UUID}

  newsecret.undefine
end

# TESTGROUP: conn.lookup_secret_by_usage
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(conn, "lookup_secret_by_usage", 1, 2, 3)
  expect_too_few_args(conn, "lookup_secret_by_usage")
  expect_invalid_arg_type(conn, "lookup_secret_by_usage", 'foo', 1)
  expect_invalid_arg_type(conn, "lookup_secret_by_usage", 1, 2)
  expect_fail(conn, Libvirt::RetrieveError, "invalid secret", "lookup_secret_by_usage", Libvirt::Secret::USAGE_TYPE_VOLUME, "foo")

  expect_success(conn, "usage type and key", "lookup_secret_by_usage", Libvirt::Secret::USAGE_TYPE_VOLUME, "/var/lib/libvirt/images/mail.img")

  newsecret.undefine
end

# TESTGROUP: conn.define_secret_xml
if !test_default_uri?
  expect_too_many_args(conn, "define_secret_xml", 1, 2, 3)
  expect_too_few_args(conn, "define_secret_xml")
  expect_invalid_arg_type(conn, "define_secret_xml", 1)
  expect_invalid_arg_type(conn, "define_secret_xml", nil)
  expect_invalid_arg_type(conn, "define_secret_xml", "hello", 'foo')
  expect_fail(conn, Libvirt::DefinitionError, "invalid XML", "define_secret_xml", "hello")

  expect_success(conn, "secret XML", "define_secret_xml", $new_secret_xml)

  newsecret.undefine
end

# TESTGROUP: conn.list_storage_pools
expect_too_many_args(conn, "list_storage_pools", 1)
expect_success(conn, "no args", "list_storage_pools")

# TESTGROUP: conn.num_of_storage_pools
expect_too_many_args(conn, "num_of_storage_pools", 1)
expect_success(conn, "no args", "num_of_storage_pools")

# TESTGROUP: conn.list_defined_storage_pools
expect_too_many_args(conn, "list_defined_storage_pools", 1)
expect_success(conn, "no args", "list_defined_storage_pools")

# TESTGROUP: conn.num_of_defined_storage_pools
expect_too_many_args(conn, "num_of_defined_storage_pools", 1)
expect_success(conn, "no args", "num_of_defined_storage_pools")

# TESTGROUP: conn.lookup_storage_pool_by_name
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(conn, "lookup_storage_pool_by_name", 1, 2)
expect_too_few_args(conn, "lookup_storage_pool_by_name")
expect_invalid_arg_type(conn, "lookup_storage_pool_by_name", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent name arg", "lookup_storage_pool_by_name", "foobarbazsucker")

expect_success(conn, "name arg", "lookup_storage_pool_by_name", "rb-libvirt-test")

newpool.destroy

newpool = conn.define_storage_pool_xml($new_storage_pool_xml)
expect_success(conn, "name arg", "lookup_storage_pool_by_name", "rb-libvirt-test")
newpool.undefine

# TESTGROUP: conn.lookup_storage_pool_by_uuid
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(conn, "lookup_storage_pool_by_uuid", 1, 2)
expect_too_few_args(conn, "lookup_storage_pool_by_uuid")
expect_invalid_arg_type(conn, "lookup_storage_pool_by_uuid", 1)
expect_fail(conn, Libvirt::RetrieveError, "non-existent uuid arg", "lookup_storage_pool_by_uuid", "foobarbazsucker")

expect_success(conn, "uuid arg", "lookup_storage_pool_by_uuid", $POOL_UUID)

newpool.destroy

newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_success(conn, "uuid arg", "lookup_storage_pool_by_uuid", $POOL_UUID)

newpool.undefine

# TESTGROUP: conn.create_storage_pool_xml
expect_too_many_args(conn, "create_storage_pool_xml", $new_storage_pool_xml, 0, 1)
expect_too_few_args(conn, "create_storage_pool_xml")
expect_invalid_arg_type(conn, "create_storage_pool_xml", nil)
expect_invalid_arg_type(conn, "create_storage_pool_xml", 1)
expect_invalid_arg_type(conn, "create_storage_pool_xml", $new_storage_pool_xml, "foo")
expect_fail(conn, Libvirt::Error, "invalid xml", "create_storage_pool_xml", "hello")

expect_success(conn, "storage pool XML", "create_storage_pool_xml", $new_storage_pool_xml)

expect_fail(conn, Libvirt::Error, "already existing domain", "create_storage_pool_xml", $new_storage_pool_xml)

newpool.destroy

# TESTGROUP: conn.define_storage_pool_xml
expect_too_many_args(conn, "define_storage_pool_xml", $new_storage_pool_xml, 0, 1)
expect_too_few_args(conn, "define_storage_pool_xml")
expect_invalid_arg_type(conn, "define_storage_pool_xml", nil)
expect_invalid_arg_type(conn, "define_storage_pool_xml", 1)
expect_invalid_arg_type(conn, "define_storage_pool_xml", $new_storage_pool_xml, "foo")
expect_fail(conn, Libvirt::Error, "invalid xml", "define_storage_pool_xml", "hello")

expect_success(conn, "storage pool XML", "define_storage_pool_xml", $new_storage_pool_xml)

newpool.undefine

# TESTGROUP: conn.discover_storage_pool_sources
expect_too_many_args(conn, "discover_storage_pool_sources", 1, 2, 3, 4)
expect_too_few_args(conn, "discover_storage_pool_sources")
expect_invalid_arg_type(conn, "discover_storage_pool_sources", 1)
expect_invalid_arg_type(conn, "discover_storage_pool_sources", "foo", 1)
expect_invalid_arg_type(conn, "discover_storage_pool_sources", "foo", "bar", "baz")

expect_fail(conn, Libvirt::Error, "invalid pool type", "discover_storage_pool_sources", "foo")

expect_success(conn, "pool type", "discover_storage_pool_sources", "logical")

# TESTGROUP: conn.sys_info
expect_too_many_args(conn, "sys_info", 1, 2)
expect_invalid_arg_type(conn, "sys_info", "foo")

expect_success(conn, "system info", "sys_info")

# TESTGROUP: conn.interface_change_begin
expect_too_many_args(conn, "interface_change_begin", 1, 2)
expect_invalid_arg_type(conn, "interface_change_begin", 'hello')

expect_success(conn, "interface change begin", "interface_change_begin")

conn.interface_change_rollback

# TESTGROUP: conn.interface_change_commit
expect_too_many_args(conn, "interface_change_commit", 1, 2)
expect_invalid_arg_type(conn, "interface_change_commit", 'foo')

# FIXME: libvirt throws an error on commit with no changes.  What changes can
# we do here?
#expect_success(conn, "interface change commit", "interface_change_commit")

# TESTGROUP: conn.interface_change_rollback
conn.interface_change_begin

expect_too_many_args(conn, "interface_change_rollback", 1, 2)
expect_invalid_arg_type(conn, "interface_change_rollback", 'foo')

expect_success(conn, "interface change rollback", "interface_change_rollback")

# TESTGROUP: conn.node_cpu_stats
expect_too_many_args(conn, "node_cpu_stats", 1, 2, 3)
expect_invalid_arg_type(conn, "node_cpu_stats", 'foo')
expect_invalid_arg_type(conn, "node_cpu_stats", 1, 'bar')

expect_success(conn, "node cpu stats", "node_cpu_stats")

# TESTGROUP: conn.node_memory_stats
if !test_default_uri?
  expect_too_many_args(conn, "node_memory_stats", 1, 2, 3)
  expect_invalid_arg_type(conn, "node_memory_stats", 'foo')
  expect_invalid_arg_type(conn, "node_memory_stats", 1, 'bar')

  expect_success(conn, "node memory status", "node_memory_stats")
end

# TESTGROUP: conn.save_image_xml_desc
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  newdom.create
  test_sleep 1
  newdom.save($GUEST_SAVE)

  expect_too_many_args(conn, "save_image_xml_desc", 1, 2, 3)
  expect_too_few_args(conn, "save_image_xml_desc")
  expect_invalid_arg_type(conn, "save_image_xml_desc", nil)
  expect_invalid_arg_type(conn, "save_image_xml_desc", 1)
  expect_invalid_arg_type(conn, "save_image_xml_desc", 'foo', 'bar')

  expect_success(conn, "save image path", "save_image_xml_desc", $GUEST_SAVE)
  `rm -f #{$GUEST_SAVE}`
end

# TESTGROUP: conn.define_save_image_xml
expect_too_many_args(conn, "define_save_image_xml", 1, 2, 3, 4)
expect_too_few_args(conn, "define_save_image_xml")
expect_too_few_args(conn, "define_save_image_xml", 'foo')
expect_invalid_arg_type(conn, "define_save_image_xml", nil, 'foo')
expect_invalid_arg_type(conn, "define_save_image_xml", 1, 'foo')
expect_invalid_arg_type(conn, "define_save_image_xml", 'foo', nil)
expect_invalid_arg_type(conn, "define_save_image_xml", 'foo', 1)
expect_invalid_arg_type(conn, "define_save_image_xml", 'foo', 'bar', 'baz')

# TESTGROUP: conn.alive?
expect_too_many_args(conn, "alive?", 1)

expect_success(conn, "alive connection", "alive?") {|x| x == true}

# TESTGROUP: conn.list_all_nwfilters
if !test_default_uri?
  expect_too_many_args(conn, "list_all_nwfilters", 1, 2)
  expect_invalid_arg_type(conn, "list_all_nwfilters", "foo")

  expect_success(conn, "no args", "list_all_nwfilters")
end

# TESTGROUP: conn.list_all_storage_pools
expect_too_many_args(conn, "list_all_storage_pools", 1, 2)
expect_invalid_arg_type(conn, "list_all_storage_pools", "foo")

expect_success(conn, "no args", "list_all_storage_pools")

# TESTGROUP: conn.list_all_nodedevices
expect_too_many_args(conn, "list_all_nodedevices", 1, 2)
expect_invalid_arg_type(conn, "list_all_nodedevices", "foo")

expect_success(conn, "no args", "list_all_nodedevices")

# TESTGROUP: conn.list_all_secrets
if !test_default_uri?
  expect_too_many_args(conn, "list_all_secrets", 1, 2)
  expect_invalid_arg_type(conn, "list_all_secrets", "foo")

  expect_success(conn, "no args", "list_all_secrets")
end

# TESTGROUP: conn.list_all_interfaces
expect_too_many_args(conn, "list_all_interfaces", 1, 2)
expect_invalid_arg_type(conn, "list_all_interfaces", "foo")

expect_success(conn, "no args", "list_all_interfaces")

# TESTGROUP: conn.list_all_networks
expect_too_many_args(conn, "list_all_networks", 1, 2)
expect_invalid_arg_type(conn, "list_all_networks", "foo")

expect_success(conn, "no args", "list_all_networks")

# TESTGROUP: conn.list_all_domains
expect_too_many_args(conn, "list_all_domains", 1, 2)
expect_invalid_arg_type(conn, "list_all_domains", "foo")

expect_success(conn, "no args", "list_all_domains")

# TESTGROUP: conn.set_keepalive
expect_too_many_args(conn, "set_keepalive", 1, 2, 3, 4)
expect_too_few_args(conn, "set_keepalive")
expect_too_few_args(conn, "set_keepalive", 1)
expect_invalid_arg_type(conn, "set_keepalive", 'foo', 0)
expect_invalid_arg_type(conn, "set_keepalive", 0, 'foo')

# FIXME: somehow we need an event loop implementation for this to work
#expect_success(conn, "interval and count", "set_keepalive", 1, 10)

# TESTGROUP: conn.node_suspend_for_duration
expect_too_many_args(conn, "node_suspend_for_duration", 1, 2, 3, 4)
expect_too_few_args(conn, "node_suspend_for_duration")
expect_too_few_args(conn, "node_suspend_for_duration", 1)
expect_invalid_arg_type(conn, "node_suspend_for_duration", 'foo', 1)
expect_invalid_arg_type(conn, "node_suspend_for_duration", 1, 'foo')
expect_invalid_arg_type(conn, "node_suspend_for_duration", 1, 2, 'foo')

# TESTGROUP: conn.node_memory_parameters
if !test_default_uri?
  expect_too_many_args(conn, "node_memory_parameters", 1, 2)
  expect_invalid_arg_type(conn, "node_memory_parameters", 'foo')

  expect_success(conn, "no args", "node_memory_parameters")
end

# TESTGROUP: conn.node_memory_paramters=
expect_too_many_args(conn, "node_memory_parameters=", 1, 2)
expect_invalid_arg_type(conn, "node_memory_parameters=", nil)
expect_invalid_arg_type(conn, "node_memory_parameters=", ['foo', 0])
expect_invalid_arg_type(conn, "node_memory_parameters=", [{}, 'foo'])

# TESTGROUP: conn.keepalive=
expect_too_many_args(conn, "keepalive=", 1, 2)
expect_too_few_args(conn, "keepalive=", [])
expect_too_few_args(conn, "keepalive=", [1])
expect_invalid_arg_type(conn, "keepalive=", 1)
expect_invalid_arg_type(conn, "keepalive=", ['foo', 1])
expect_invalid_arg_type(conn, "keepalive=", [1, 'foo'])

# FIXME: somehow we need an event loop implementation for this to work
#expect_success(conn, "interval and count", "keepalive=", 1, 10)

# END TESTS

conn.close

finish_tests
