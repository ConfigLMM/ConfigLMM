#!/usr/bin/ruby

# Test the nwfilter methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("nwfilter")

conn = Libvirt::open(URI)

# TESTGROUP: nwfilter.undefine
if !test_default_uri?
  newnw = conn.define_nwfilter_xml($new_nwfilter_xml)

  expect_too_many_args(newnw, "undefine", 1)

  expect_success(newnw, "no args", "undefine")
end

# TESTGROUP: nwfilter.name
if !test_default_uri?
  newnw = conn.define_nwfilter_xml($new_nwfilter_xml)

  expect_too_many_args(newnw, "name", 1)

  expect_success(newnw, "no args", "name") {|x| x == "rb-libvirt-test"}

  newnw.undefine
end

# TESTGROUP: nwfilter.uuid
if !test_default_uri?
  newnw = conn.define_nwfilter_xml($new_nwfilter_xml)

  expect_too_many_args(newnw, "uuid", 1)

  expect_success(newnw, "no args", "uuid") {|x| x == $NWFILTER_UUID}

  newnw.undefine
end

# TESTGROUP: nwfilter.xml_desc
if !test_default_uri?
  newnw = conn.define_nwfilter_xml($new_nwfilter_xml)

  expect_too_many_args(newnw, "xml_desc", 1, 2)
  expect_invalid_arg_type(newnw, "xml_desc", "foo")

  expect_success(newnw, "no args", "xml_desc")

  newnw.undefine
end

# TESTGROUP: nwfilter.free
if !test_default_uri?
  newnw = conn.define_nwfilter_xml($new_nwfilter_xml)
  newnw.undefine
  expect_too_many_args(newnw, "free", 1)

  expect_success(newnw, "no args", "free")
end

# END TESTS

conn.close

finish_tests
