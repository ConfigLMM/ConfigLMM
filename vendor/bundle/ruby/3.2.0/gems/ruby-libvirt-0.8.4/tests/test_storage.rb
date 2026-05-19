#!/usr/bin/ruby

# Test the storage methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("storage_pool")

conn = Libvirt::open(URI)

begin
  oldpool = conn.lookup_storage_pool_by_name("rb-libvirt-test")
  oldpool.destroy
  oldpool.undefine
rescue
  # in case we didn't find it, don't do anything
end

# test setup
if !test_default_uri?
  `rm -rf #{$POOL_PATH}; mkdir -p #{$POOL_PATH} ; echo $?`
end

new_storage_vol_xml = <<EOF
<volume>
  <name>test.img</name>
  <allocation>0</allocation>
  <capacity unit="G">1</capacity>
  <target>
    <path>/tmp/rb-libvirt-test/test.img</path>
  </target>
</volume>
EOF

new_storage_vol_xml_2 = <<EOF
<volume>
  <name>test2.img</name>
  <allocation>0</allocation>
  <capacity unit="G">5</capacity>
  <target>
    <path>/tmp/rb-libvirt-test/test2.img</path>
  </target>
</volume>
EOF

# TESTGROUP: vol.pool
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newvol, "pool", 1)

expect_success(newvol, "no args", "pool")

newvol.delete

newpool.destroy

# TESTGROUP: pool.build
newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "build", 1, 2)
expect_invalid_arg_type(newpool, "build", 'foo')

expect_success(newpool, "no args", "build")

newpool.undefine

# TESTGROUP: pool.undefine
newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "undefine", 1)

expect_success(newpool, "no args", "undefine")

# TESTGROUP: pool.create
newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "create", 1, 2)
expect_invalid_arg_type(newpool, "create", 'foo')

expect_success(newpool, "no args", "create")

newpool.destroy
newpool.undefine

# TESTGROUP: pool.destroy
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "destroy", 1)

expect_success(newpool, "no args", "destroy")

# TESTGROUP: pool.delete
newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "delete", 1, 2)
expect_invalid_arg_type(newpool, "delete", 'foo')

expect_success(newpool, "no args", "delete")

if !test_default_uri?
  `mkdir -p /tmp/rb-libvirt-test`
end

newpool.undefine

if !test_default_uri?
  `mkdir -p #{$POOL_PATH}`
end

# TESTGROUP: pool.refresh
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "refresh", 1, 2)
expect_invalid_arg_type(newpool, "refresh", 'foo')

expect_success(newpool, "no args", "refresh")

newpool.destroy

# TESTGROUP: pool.name
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "name", 1)

expect_success(newpool, "no args", "name") {|x| x == "rb-libvirt-test"}

newpool.destroy

# TESTGROUP: pool.uuid
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "uuid", 1)

expect_success(newpool, "no args", "uuid") {|x| x == $POOL_UUID}

newpool.destroy

# TESTGROUP: pool.info
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "info", 1)

expect_success(newpool, "no args", "info")

newpool.destroy

# TESTGROUP: pool.xml_desc
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "xml_desc", 1, 2)
expect_invalid_arg_type(newpool, "xml_desc", "foo")

expect_success(newpool, "no args", "xml_desc")

newpool.destroy

# TESTGROUP: pool.autostart?
newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "autostart?", 1)

expect_success(newpool, "no args", "autostart?") {|x| x == false}

newpool.autostart = true

expect_success(newpool, "no args", "autostart?") {|x| x == true}

newpool.undefine

# TESTGROUP: pool.autostart=
newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "autostart=", 1, 2)
expect_invalid_arg_type(newpool, "autostart=", 'foo')
expect_invalid_arg_type(newpool, "autostart=", nil)
expect_invalid_arg_type(newpool, "autostart=", 1234)

expect_success(newpool, "no args", "autostart=", true)
if not newpool.autostart?
  puts_fail "storage_pool.autostart= did not set autostart to true"
else
  puts_ok "storage_pool.autostart= set autostart to true"
end

expect_success(newpool, "no args", "autostart=", false)
if newpool.autostart?
  puts_fail "storage_pool.autostart= did not set autostart to false"
else
  puts_ok "storage_pool.autostart= set autostart to false"
end

newpool.undefine

# TESTGROUP: pool.num_of_volumes
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "num_of_volumes", 1)

expect_success(newpool, "no args", "num_of_volumes") {|x| x == 0}

newpool.destroy

# TESTGROUP: pool.list_volumes
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "list_volumes", 1)

expect_success(newpool, "no args", "list_volumes")
newvol = newpool.create_volume_xml(new_storage_vol_xml)
expect_success(newpool, "no args", "list_volumes")

newvol.delete
newpool.destroy

# TESTGROUP: pool.free
newpool = conn.define_storage_pool_xml($new_storage_pool_xml)
newpool.undefine
expect_too_many_args(newpool, "free", 1)

expect_success(newpool, "no args", "free")

# TESTGROUP: pool.lookup_volume_by_name
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newpool, "lookup_volume_by_name", 1, 2)
expect_too_few_args(newpool, "lookup_volume_by_name")
expect_invalid_arg_type(newpool, "lookup_volume_by_name", 1);
expect_invalid_arg_type(newpool, "lookup_volume_by_name", nil);
expect_fail(newpool, Libvirt::RetrieveError, "non-existent name arg", "lookup_volume_by_name", "foobarbazsucker")

expect_success(newpool, "name arg", "lookup_volume_by_name", "test.img")

newvol.delete
newpool.destroy

# TESTGROUP: pool.lookup_volume_by_key
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newpool, "lookup_volume_by_key", 1, 2)
expect_too_few_args(newpool, "lookup_volume_by_key")
expect_invalid_arg_type(newpool, "lookup_volume_by_key", 1);
expect_invalid_arg_type(newpool, "lookup_volume_by_key", nil);
expect_fail(newpool, Libvirt::RetrieveError, "non-existent key arg", "lookup_volume_by_key", "foobarbazsucker")

expect_success(newpool, "name arg", "lookup_volume_by_key", newvol.key)

newvol.delete
newpool.destroy

# TESTGROUP: pool.lookup_volume_by_path
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newpool, "lookup_volume_by_path", 1, 2)
expect_too_few_args(newpool, "lookup_volume_by_path")
expect_invalid_arg_type(newpool, "lookup_volume_by_path", 1);
expect_invalid_arg_type(newpool, "lookup_volume_by_path", nil);
expect_fail(newpool, Libvirt::RetrieveError, "non-existent path arg", "lookup_volume_by_path", "foobarbazsucker")

expect_success(newpool, "name arg", "lookup_volume_by_path", newvol.path)

newvol.delete
newpool.destroy

# TESTGROUP: pool.create_volume_xml
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "create_volume_xml", new_storage_vol_xml, 0, 1)
expect_too_few_args(newpool, "create_volume_xml")
expect_invalid_arg_type(newpool, "create_volume_xml", nil)
expect_invalid_arg_type(newpool, "create_volume_xml", 1)
expect_invalid_arg_type(newpool, "create_volume_xml", new_storage_vol_xml, "foo")
expect_fail(newpool, Libvirt::Error, "invalid xml", "create_volume_xml", "hello")

expect_success(newpool, "storage volume XML", "create_volume_xml", new_storage_vol_xml)

expect_fail(newpool, Libvirt::Error, "already existing domain", "create_volume_xml", new_storage_vol_xml)

newvol.delete
newpool.destroy

# TESTGROUP: pool.create_volume_xml_from
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newpool, "create_volume_xml_from", new_storage_vol_xml_2, 0, 1, 2)
expect_too_few_args(newpool, "create_volume_xml_from")
expect_invalid_arg_type(newpool, "create_volume_xml_from", 1, 2)
expect_invalid_arg_type(newpool, "create_volume_xml_from", "foo", 2)
expect_invalid_arg_type(newpool, "create_volume_xml_from", "foo", newvol, "bar")
expect_fail(newpool, Libvirt::Error, "invalid xml", "create_volume_xml_from", "hello", newvol)

newvol2 = expect_success(newpool, "storage volume XML", "create_volume_xml_from", new_storage_vol_xml_2, newvol)

expect_fail(newpool, Libvirt::Error, "already existing domain", "create_volume_xml_from", new_storage_vol_xml_2, newvol)

newvol2.delete
newvol.delete
newpool.destroy

# TESTGROUP: pool.active?
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)

expect_too_many_args(newpool, "active?", 1)

expect_success(newpool, "no args", "active?") {|x| x == true}

newpool.destroy

newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_success(newpool, "no args", "active?") {|x| x == false}

newpool.create

expect_success(newpool, "no args", "active?") {|x| x == true}

newpool.destroy
newpool.undefine

# TESTGROUP: pool.persistent?
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
test_sleep 1

expect_too_many_args(newpool, "persistent?", 1)

expect_success(newpool, "no args", "persistent?") {|x| x == false}

newpool.destroy

newpool = conn.define_storage_pool_xml($new_storage_pool_xml)

expect_success(newpool, "no args", "persistent?") {|x| x == true}

newpool.undefine

# TESTGROUP:
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
test_sleep 1

expect_too_many_args(newpool, "list_all_volumes", 1, 2)
expect_invalid_arg_type(newpool, "list_all_volumes", 'foo')
expect_invalid_arg_type(newpool, "list_all_volumes", [])
expect_invalid_arg_type(newpool, "list_all_volumes", {})

expect_success(newpool, "no args", "list_all_volumes")

newpool.destroy

set_test_object("storage_volume")

# TESTGROUP: vol.name
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newvol, "name", 1)

expect_success(newvol, "no args", "name")

newvol.delete
newpool.destroy

# TESTGROUP: vol.key
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newvol, "key", 1)

expect_success(newvol, "no args", "key")

newvol.delete
newpool.destroy

# TESTGROUP: vol.delete
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newvol, "delete", 1, 2)
expect_invalid_arg_type(newvol, "delete", 'foo')

expect_success(newvol, "no args", "delete")

newpool.destroy

# TESTGROUP: vol.wipe
if !test_default_uri?
  newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
  newvol = newpool.create_volume_xml(new_storage_vol_xml)

  expect_too_many_args(newvol, "wipe", 1, 2)
  expect_invalid_arg_type(newvol, "wipe", 'foo')

  expect_success(newvol, "no args", "wipe")

  newvol.delete
  newpool.destroy
end

# TESTGROUP: vol.info
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newvol, "info", 1)

expect_success(newvol, "no args", "info")

newvol.delete
newpool.destroy

# TESTGROUP: vol.xml_desc
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newvol, "xml_desc", 1, 2)
expect_invalid_arg_type(newvol, "xml_desc", "foo")

expect_success(newvol, "no args", "xml_desc")

newvol.delete
newpool.destroy

# TESTGROUP: vol.path
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)

expect_too_many_args(newvol, "path", 1)

expect_success(newvol, "no args", "path")

newvol.delete
newpool.destroy

# TESTGROUP: vol.free
newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
newvol = newpool.create_volume_xml(new_storage_vol_xml)
newvol.delete

expect_too_many_args(newvol, "free", 1)

expect_success(newvol, "no args", "free")

newpool.destroy

# TESTGROUP: vol.download
if !test_default_uri?
  newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
  newvol = newpool.create_volume_xml(new_storage_vol_xml)
  stream = conn.stream

  expect_too_many_args(newvol, "download", 1, 2, 3, 4, 5)
  expect_too_few_args(newvol, "download")
  expect_too_few_args(newvol, "download", 1)
  expect_too_few_args(newvol, "download", 1, 2)
  expect_invalid_arg_type(newvol, "download", nil, 1, 1)
  expect_invalid_arg_type(newvol, "download", 'foo', 1, 1)
  expect_invalid_arg_type(newvol, "download", 1, 1, 1)
  expect_invalid_arg_type(newvol, "download", [], 1, 1)
  expect_invalid_arg_type(newvol, "download", {}, 1, 1)
  expect_invalid_arg_type(newvol, "download", stream, nil, 1)
  expect_invalid_arg_type(newvol, "download", stream, 'foo', 1)
  expect_invalid_arg_type(newvol, "download", stream, [], 1)
  expect_invalid_arg_type(newvol, "download", stream, {}, 1)
  expect_invalid_arg_type(newvol, "download", stream, 1, nil)
  expect_invalid_arg_type(newvol, "download", stream, 1, 'foo')
  expect_invalid_arg_type(newvol, "download", stream, 1, [])
  expect_invalid_arg_type(newvol, "download", stream, 1, {})
  expect_invalid_arg_type(newvol, "download", stream, 1, 1, 'foo')
  expect_invalid_arg_type(newvol, "download", stream, 1, 1, [])
  expect_invalid_arg_type(newvol, "download", stream, 1, 1, {})

  expect_success(newvol, "stream, offset, and length args", "download", stream, 0, 10)

  newvol.delete
  newpool.destroy
end

# TESTGROUP: vol.upload
if !test_default_uri?
  newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
  newvol = newpool.create_volume_xml(new_storage_vol_xml)
  stream = conn.stream

  expect_too_many_args(newvol, "upload", 1, 2, 3, 4, 5)
  expect_too_few_args(newvol, "upload")
  expect_too_few_args(newvol, "upload", 1)
  expect_too_few_args(newvol, "upload", 1, 2)
  expect_invalid_arg_type(newvol, "upload", nil, 1, 1)
  expect_invalid_arg_type(newvol, "upload", 'foo', 1, 1)
  expect_invalid_arg_type(newvol, "upload", 1, 1, 1)
  expect_invalid_arg_type(newvol, "upload", [], 1, 1)
  expect_invalid_arg_type(newvol, "upload", {}, 1, 1)
  expect_invalid_arg_type(newvol, "upload", stream, nil, 1)
  expect_invalid_arg_type(newvol, "upload", stream, 'foo', 1)
  expect_invalid_arg_type(newvol, "upload", stream, [], 1)
  expect_invalid_arg_type(newvol, "upload", stream, {}, 1)
  expect_invalid_arg_type(newvol, "upload", stream, 1, nil)
  expect_invalid_arg_type(newvol, "upload", stream, 1, 'foo')
  expect_invalid_arg_type(newvol, "upload", stream, 1, [])
  expect_invalid_arg_type(newvol, "upload", stream, 1, {})
  expect_invalid_arg_type(newvol, "upload", stream, 1, 1, 'foo')
  expect_invalid_arg_type(newvol, "upload", stream, 1, 1, [])
  expect_invalid_arg_type(newvol, "upload", stream, 1, 1, {})

  expect_success(newvol, "stream, offset, and length args", "upload", stream, 0, 10)

  newvol.delete
  newpool.destroy
end

# TESTGROUP: vol.upload
if !test_default_uri?
  newpool = conn.create_storage_pool_xml($new_storage_pool_xml)
  newvol = newpool.create_volume_xml(new_storage_vol_xml)

  expect_too_many_args(newvol, "wipe_pattern", 1, 2, 3)
  expect_too_few_args(newvol, "wipe_pattern")
  expect_invalid_arg_type(newvol, "wipe_pattern", nil)
  expect_invalid_arg_type(newvol, "wipe_pattern", 'foo')
  expect_invalid_arg_type(newvol, "wipe_pattern", [])
  expect_invalid_arg_type(newvol, "wipe_pattern", {})
  expect_invalid_arg_type(newvol, "wipe_pattern", 0, 'foo')
  expect_invalid_arg_type(newvol, "wipe_pattern", 0, [])
  expect_invalid_arg_type(newvol, "wipe_pattern", 0, {})

  expect_success(newvol, "alg arg", "wipe_pattern", Libvirt::StorageVol::WIPE_ALG_ZERO)

  newvol.delete
  newpool.destroy
end

# END TESTS

conn.close

finish_tests
