#!/usr/bin/ruby

# Test the secret methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("secret")

conn = Libvirt::open(URI)

# TESTGROUP: secret.uuid
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(newsecret, "uuid", 1)

  expect_success(newsecret, "no args", "uuid") {|x| x == $SECRET_UUID}

  newsecret.undefine
end

# TESTGROUP: secret.usagetype
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(newsecret, "usagetype", 1)

  expect_success(newsecret, "no args", "usagetype") {|x| x == Libvirt::Secret::USAGE_TYPE_VOLUME}

  newsecret.undefine
end

# TESTGROUP: secret.usageid
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(newsecret, "usageid", 1)

  expect_success(newsecret, "no args", "usageid")

  newsecret.undefine
end

# TESTGROUP: secret.xml_desc
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(newsecret, "xml_desc", 1, 2)
  expect_invalid_arg_type(newsecret, "xml_desc", "foo")

  expect_success(newsecret, "no args", "xml_desc")

  newsecret.undefine
end

# TESTGROUP: secret.set_value
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(newsecret, "set_value", 1, 2, 3)
  expect_too_few_args(newsecret, "set_value")
  expect_invalid_arg_type(newsecret, "set_value", 1)
  expect_invalid_arg_type(newsecret, "set_value", "foo", "bar")

  expect_success(newsecret, "value arg", "set_value", "foo")

  newsecret.undefine
end

# TESTGROUP: secret.value=
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(newsecret, "value=", 1, 2)
  expect_too_few_args(newsecret, "value=")
  expect_invalid_arg_type(newsecret, "value=", {})
  expect_invalid_arg_type(newsecret, "value=", nil)
  expect_invalid_arg_type(newsecret, "value=", 1)
  expect_invalid_arg_type(newsecret, "value=", [1, 1])
  expect_invalid_arg_type(newsecret, "value=", [nil, 1])
  expect_invalid_arg_type(newsecret, "value=", [[], 1])
  expect_invalid_arg_type(newsecret, "value=", [{}, 1])
  expect_invalid_arg_type(newsecret, "value=", ['foo', nil])
  expect_invalid_arg_type(newsecret, "value=", ['foo', 'foo'])
  expect_invalid_arg_type(newsecret, "value=", ['foo', []])
  expect_invalid_arg_type(newsecret, "value=", ['foo', {}])

  expect_success(newsecret, "value arg", "value=", "foo")

  newsecret.undefine
end

# TESTGROUP: secret.get_value
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)
  newsecret.set_value("foo")

  expect_too_many_args(newsecret, "get_value", 1, 2)
  expect_invalid_arg_type(newsecret, "get_value", 'foo')

  expect_success(newsecret, "no args", "get_value") {|x| x == 'foo'}

  newsecret.undefine
end

# TESTGROUP: secret.undefine
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)

  expect_too_many_args(newsecret, "undefine", 1)

  expect_success(newsecret, "no args", "undefine")
end

# TESTGROUP: secret.free
if !test_default_uri?
  newsecret = conn.define_secret_xml($new_secret_xml)
  newsecret.undefine

  expect_too_many_args(newsecret, "free", 1)

  expect_success(newsecret, "no args", "free")
end

# END TESTS

conn.close

finish_tests
