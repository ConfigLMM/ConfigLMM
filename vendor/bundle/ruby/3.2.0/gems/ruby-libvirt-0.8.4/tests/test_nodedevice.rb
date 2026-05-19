#!/usr/bin/ruby

# Test the nodedevice methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("nodedevice")

conn = Libvirt::open(URI)

# TESTGROUP: nodedevice.name
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "name", 1)
expect_success(testnode, "no args", "name")

# TESTGROUP: nodedevice.parent
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "parent", 1)
expect_success(testnode, "no args", "parent")

# TESTGROUP: nodedevice.num_of_caps
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "num_of_caps", 1)
expect_success(testnode, "no args", "num_of_caps")

# TESTGROUP: nodedevice.list_caps
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "list_caps", 1)
expect_success(testnode, "no args", "list_caps")

# TESTGROUP: nodedevice.xml_desc
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "xml_desc", 1, 2)
expect_invalid_arg_type(testnode, "xml_desc", 'foo')
expect_success(testnode, "no args", "xml_desc")

# TESTGROUP: nodedevice.detach
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "detach", 1, 2, 3)
expect_invalid_arg_type(testnode, "detach", 1)
expect_invalid_arg_type(testnode, "detach", [])
expect_invalid_arg_type(testnode, "detach", {})
expect_invalid_arg_type(testnode, "detach", nil, 'foo')
expect_invalid_arg_type(testnode, "detach", nil, [])
expect_invalid_arg_type(testnode, "detach", nil, {})

#expect_success(testnode, "no args", "detach")

# TESTGROUP: nodedevice.reattach
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "reattach", 1)

#expect_success(testnode, "no args", "reattach")

# TESTGROUP: nodedevice.reset
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "reset", 1)

#expect_success(testnode, "no args", "reset")

# TESTGROUP: nodedevice.destroy
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "destroy", 1)

#expect_success(testnode, "no args", "destroy")

# TESTGROUP: nodedevice.free
testnode = conn.lookup_nodedevice_by_name(conn.list_nodedevices[0])

expect_too_many_args(testnode, "free", 1)

expect_success(testnode, "no args", "free")

# END TESTS

conn.close

finish_tests
