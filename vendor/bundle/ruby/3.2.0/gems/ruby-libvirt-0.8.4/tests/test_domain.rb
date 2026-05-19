#!/usr/bin/ruby

# Test the domain methods the bindings support.  Note that this tester requires
# the qemu driver to be enabled and available for use.

# Note that the order of the TESTGROUPs below match the order that the
# functions are defined in the ext/libvirt/domain.c file

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("domain")

conn = Libvirt::open(URI)

cleanup_test_domain(conn)

# setup for later tests
if !test_default_uri?
  `qemu-img create -f qcow2 #{$GUEST_DISK} 5G`
  `qemu-img create -f raw #{$GUEST_RAW_DISK} 5G`
end


new_hostdev_xml = <<EOF
<hostdev mode='subsystem' type='pci' managed='yes'>
  <source>
    <address bus='0x45' slot='0x55' function='0x33'/>
  </source>
</hostdev>
EOF

# start tests

# TESTGROUP: dom.migrate_max_speed
if !test_default_uri?
  newdom = conn.create_domain_xml($new_dom_xml)
  test_sleep 1

  expect_too_many_args(newdom, "migrate_max_speed", 1, 2)
  expect_invalid_arg_type(newdom, "migrate_max_speed", 'foo')
  expect_invalid_arg_type(newdom, "migrate_max_speed", [])
  expect_invalid_arg_type(newdom, "migrate_max_speed", {})

  expect_success(newdom, "no args", "migrate_max_speed")

  newdom.destroy
end

# TESTGROUP: dom.reset
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "reset", 1, 2)
expect_invalid_arg_type(newdom, "reset", 'foo')
expect_invalid_arg_type(newdom, "reset", [])
expect_invalid_arg_type(newdom, "reset", {})

expect_success(newdom, "no args", "reset")

newdom.destroy

# TESTGROUP: dom.hostname
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "hostname", 1, 2)
expect_invalid_arg_type(newdom, "hostname", 'foo')
expect_invalid_arg_type(newdom, "hostname", [])
expect_invalid_arg_type(newdom, "hostname", {})

# FIXME: spits an error "this function is not supported by the connection driver"
#expect_success(newdom, "no args", "hostname")

newdom.destroy

# TESTGROUP: dom.metadata
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "metadata", 1, 2, 3, 4)
expect_too_few_args(newdom, "metadata")
expect_invalid_arg_type(newdom, "metadata", 'foo')
expect_invalid_arg_type(newdom, "metadata", nil)
expect_invalid_arg_type(newdom, "metadata", [])
expect_invalid_arg_type(newdom, "metadata", {})
expect_invalid_arg_type(newdom, "metadata", 1, 1)
expect_invalid_arg_type(newdom, "metadata", 1, 'foo', 'bar')

expect_success(newdom, "no args", "metadata", Libvirt::Domain::METADATA_DESCRIPTION) {|x| x == "Ruby Libvirt Tester"}

newdom.destroy

# TESTGROUP: dom.metadata=
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "metadata=", 1, 2, 3, 4, 5, 6)
expect_too_few_args(newdom, "metadata=")
expect_too_few_args(newdom, "metadata=", [1])
expect_invalid_arg_type(newdom, "metadata=", 1)
expect_invalid_arg_type(newdom, "metadata=", 'foo')
expect_invalid_arg_type(newdom, "metadata=", nil)
expect_invalid_arg_type(newdom, "metadata=", {})
expect_invalid_arg_type(newdom, "metadata=", ['foo', nil])
expect_invalid_arg_type(newdom, "metadata=", [nil, nil])
expect_invalid_arg_type(newdom, "metadata=", [[], nil])
expect_invalid_arg_type(newdom, "metadata=", [{}, nil])
expect_invalid_arg_type(newdom, "metadata=", [1, 1])
expect_invalid_arg_type(newdom, "metadata=", [1, []])
expect_invalid_arg_type(newdom, "metadata=", [1, {}])

expect_success(newdom, "no args", "metadata=", [Libvirt::Domain::METADATA_DESCRIPTION, 'foo'])
expect_success(newdom, "no args", "metadata=", [Libvirt::Domain::METADATA_DESCRIPTION, 'foo', nil, nil, 0])

expect_success(newdom, "no args", "metadata", Libvirt::Domain::METADATA_DESCRIPTION) {|x| x == "foo"}

newdom.destroy

# TESTGROUP: dom.updated?
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "updated?", 1)

expect_success(newdom, "no args", "updated?")

newdom.destroy

# TESTGROUP: dom.inject_nmi
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "inject_nmi", 1, 2)
expect_invalid_arg_type(newdom, "inject_nmi", 'foo')

expect_success(newdom, "no args", "inject_nmi")

newdom.destroy

# TESTGROUP: dom.control_info
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "control_info", 1, 2)
expect_invalid_arg_type(newdom, "control_info", 'foo')

expect_success(newdom, "no args", "control_info")

newdom.destroy

# TESTGROUP: dom.send_key
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "send_key", 1, 2, 3, 4)
expect_too_few_args(newdom, "send_key")
expect_too_few_args(newdom, "send_key", 1)
expect_too_few_args(newdom, "send_key", 1, 2)
expect_invalid_arg_type(newdom, "send_key", nil, 0, [])
expect_invalid_arg_type(newdom, "send_key", nil, 0, [1])
expect_invalid_arg_type(newdom, "send_key", 'foo', 0, [])
expect_invalid_arg_type(newdom, "send_key", 0, nil, [])
expect_invalid_arg_type(newdom, "send_key", 0, 'foo', [])
expect_invalid_arg_type(newdom, "send_key", 0, 1, nil)
expect_invalid_arg_type(newdom, "send_key", 0, 1, 'foo')
expect_invalid_arg_type(newdom, "send_key", 0, 1, 2)
expect_invalid_arg_type(newdom, "send_key", nil, 0, [nil])
expect_invalid_arg_type(newdom, "send_key", nil, 0, ['foo'])

# FIXME: this fails for reasons that are unclear to me
#expect_success(newdom, "codeset, holdtime, keycodes args", "send_key", 0, 1, [])

newdom.destroy

# TESTGROUP: dom.migrate
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

dconn = Libvirt::open(URI)

expect_too_many_args(newdom, "migrate", 1, 2, 3, 4, 5, 6)
expect_too_few_args(newdom, "migrate")
expect_fail(newdom, ArgumentError, "invalid connection object", "migrate", "foo")
expect_invalid_arg_type(newdom, "migrate", dconn, 'foo')
expect_invalid_arg_type(newdom, "migrate", dconn, 0, 1)
expect_invalid_arg_type(newdom, "migrate", dconn, 0, 'foo', 1)
expect_invalid_arg_type(newdom, "migrate", dconn, 0, 'foo', 'bar', 'baz')

# FIXME: how can we make this work?
#expect_success(newdom, "conn arg", "migrate", dconn)

dconn.close

newdom.destroy

# TESTGROUP: dom.migrate_to_uri
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "migrate_to_uri", 1, 2, 3, 4, 5)
expect_too_few_args(newdom, "migrate_to_uri")
expect_invalid_arg_type(newdom, "migrate_to_uri", 1)
expect_invalid_arg_type(newdom, "migrate_to_uri", URI, 'foo')
expect_invalid_arg_type(newdom, "migrate_to_uri", URI, 0, 1)
expect_invalid_arg_type(newdom, "migrate_to_uri", URI, 0, 'foo', 'bar')

#expect_success(newdom, "URI arg", "migrate_to_uri", "qemu://remote/system")

dconn.close

newdom.destroy

# TESTGROUP: dom.migrate_set_max_downtime
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "migrate_set_max_downtime", 1, 2, 3)
expect_too_few_args(newdom, "migrate_set_max_downtime")
expect_invalid_arg_type(newdom, "migrate_set_max_downtime", 'foo')
expect_invalid_arg_type(newdom, "migrate_set_max_downtime", 10, 'foo')
expect_fail(newdom, Libvirt::Error, "on off domain", "migrate_set_max_downtime", 10)

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1
#expect_fail(newdom, Libvirt::Error, "while no migration in progress", "migrate_set_max_downtime", 10)

#newdom.migrate_to_uri("qemu://remote/system")
#expect_success(newdom, "10 second downtime", "migrate_set_max_downtime", 10)

newdom.destroy

# TESTGROUP: dom.migrate2
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

dconn = Libvirt::open(URI)

expect_too_many_args(newdom, "migrate2", 1, 2, 3, 4, 5, 6, 7)
expect_too_few_args(newdom, "migrate2")
expect_fail(newdom, ArgumentError, "invalid connection object", "migrate2", "foo")
expect_invalid_arg_type(newdom, "migrate2", dconn, 0)

# FIXME: how can we make this work?
#expect_success(newdom, "conn arg", "migrate2", dconn)

dconn.close

newdom.destroy

# TESTGROUP: dom.migrate_to_uri2
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "migrate_to_uri2", 1, 2, 3, 4, 5, 6, 7)
expect_invalid_arg_type(newdom, "migrate_to_uri2", 1)
expect_invalid_arg_type(newdom, "migrate_to_uri2", URI, 1)
expect_invalid_arg_type(newdom, "migrate_to_uri2", URI, 'foo', 1)
expect_invalid_arg_type(newdom, "migrate_to_uri2", URI, 'foo', 'bar', 'baz')
expect_invalid_arg_type(newdom, "migrate_to_uri2", URI, 'foo', 'bar', 0, 1)
expect_invalid_arg_type(newdom, "migrate_to_uri2", URI, 'foo', 'bar', 0, 'foo', 'baz')

#expect_success(newdom, "URI arg", "migrate_to_uri2", "qemu://remote/system")

dconn.close

newdom.destroy

# TESTGROUP: dom.migrate_set_max_speed
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "migrate_set_max_speed", 1, 2, 3)
expect_too_few_args(newdom, "migrate_set_max_speed")
expect_invalid_arg_type(newdom, "migrate_set_max_speed", 'foo')
expect_invalid_arg_type(newdom, "migrate_set_max_speed", 5, 'foo')

#expect_success(newdom, "Bandwidth arg", "migrate_set_max_speed", 5)

newdom.destroy

# TESTGROUP: dom.shutdown
if !test_default_uri?
  newdom = conn.create_domain_xml($new_dom_xml)
  test_sleep 1

  expect_too_many_args(newdom, "shutdown", 1, 2)
  expect_success(newdom, "no args", "shutdown")
  sleep 1
  newdom.destroy
end

# TESTGROUP: dom.reboot
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1
expect_too_many_args(newdom, "reboot", 1, 2)
expect_invalid_arg_type(newdom, "reboot", "hello")

expect_success(newdom, "no args", "reboot")
test_sleep 1

expect_success(newdom, "flags arg", "reboot", 0)
test_sleep 1

newdom.destroy

# TESTGROUP: dom.destroy
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "destroy", 1, 2)
expect_success(newdom, "no args", "destroy")

# TESTGROUP: dom.suspend
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "suspend", 1)
expect_success(newdom, "no args", "suspend")
newdom.destroy

# TESTGROUP: dom.resume
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_fail(newdom, Libvirt::Error, "already running", "resume")

newdom.suspend
expect_too_many_args(newdom, "resume", 1)
expect_success(newdom, "no args suspended domain", "resume")
newdom.destroy

# TESTGROUP: dom.save
if !test_default_uri?
  newdom = conn.create_domain_xml($new_dom_xml)
  test_sleep 1

  expect_too_many_args(newdom, "save", 1, 2, 3, 4)
  expect_too_few_args(newdom, "save")
  expect_invalid_arg_type(newdom, "save", 1)
  expect_invalid_arg_type(newdom, "save", nil)
  expect_fail(newdom, Libvirt::Error, "non-existent path", "save", "/this/path/does/not/exist")

  expect_success(newdom, "path arg", "save", $GUEST_SAVE)

  `rm -f #{$GUEST_SAVE}`
end

# TESTGROUP: dom.managed_save
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  newdom.create
  test_sleep 1

  expect_too_many_args(newdom, "managed_save", 1, 2)
  expect_invalid_arg_type(newdom, "managed_save", "hello")
  expect_success(newdom, "no args", "managed_save")
  newdom.undefine(Libvirt::Domain::UNDEFINE_MANAGED_SAVE)
end

# TESTGROUP: dom.has_managed_save?
newdom = conn.define_domain_xml($new_dom_xml)
newdom.create
test_sleep 1

expect_too_many_args(newdom, "has_managed_save?", 1, 2)
expect_invalid_arg_type(newdom, "has_managed_save?", "hello")

if newdom.has_managed_save?
  puts_fail "domain.has_managed_save? reports true on a new domain"
else
  puts_ok "domain.has_managed_save? not true on new domain"
end

newdom.managed_save

if not newdom.has_managed_save?
  puts_fail "domain.has_managed_save? reports false after a managed save"
else
  puts_ok "domain.has_managed_save? reports true after a managed save"
end

newdom.undefine(Libvirt::Domain::UNDEFINE_MANAGED_SAVE)

# TESTGROUP: dom.managed_save_remove
newdom = conn.define_domain_xml($new_dom_xml)
newdom.create
test_sleep 1
newdom.managed_save

expect_too_many_args(newdom, "managed_save_remove", 1, 2)
expect_invalid_arg_type(newdom, "managed_save_remove", "hello")

if not newdom.has_managed_save?
  puts_fail "prior to domain.managed_save_remove, no managed save file"
end
expect_success(newdom, "no args", "managed_save_remove")
if newdom.has_managed_save?
  puts_fail "after domain.managed_save_remove, managed save file still exists"
else
  puts_ok "after domain.managed_save_remove, managed save file no longer exists"
end

newdom.undefine

# TESTGROUP: dom.core_dump
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  newdom.create
  test_sleep 1

  expect_too_many_args(newdom, "core_dump", 1, 2, 3)
  expect_too_few_args(newdom, "core_dump")
  expect_invalid_arg_type(newdom, "core_dump", 1, 2)
  expect_invalid_arg_type(newdom, "core_dump", "/path", "foo")
  expect_fail(newdom, Libvirt::Error, "invalid path", "core_dump", "/this/path/does/not/exist")

  expect_success(newdom, "live with path arg", "core_dump", "/var/lib/libvirt/images/ruby-libvirt-test.core")

  `rm -f /var/lib/libvirt/images/ruby-libvirt-test.core`

  expect_success(newdom, "crash with path arg", "core_dump", "/var/lib/libvirt/images/ruby-libvirt-test.core", Libvirt::Domain::DUMP_CRASH)

  expect_fail(newdom, Libvirt::Error, "of shut-off domain", "core_dump", "/var/lib/libvirt/images/ruby-libvirt-test.core", Libvirt::Domain::DUMP_CRASH)

  `rm -f /var/lib/libvirt/images/ruby-libvirt-test.core`

  newdom.undefine
end

# TESTGROUP: Libvirt::Domain::restore
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  newdom.create
  test_sleep 1
  newdom.save($GUEST_SAVE)

  expect_too_many_args(Libvirt::Domain, "restore", 1, 2, 3)
  expect_too_few_args(Libvirt::Domain, "restore")
  expect_invalid_arg_type(Libvirt::Domain, "restore", 1, 2)
  expect_invalid_arg_type(Libvirt::Domain, "restore", conn, 2)
  expect_fail(Libvirt::Domain, Libvirt::Error, "invalid path", "restore", conn, "/this/path/does/not/exist")
  `touch /tmp/foo`
  expect_fail(Libvirt::Domain, Libvirt::Error, "invalid save file", "restore", conn, "/tmp/foo")
  `rm -f /tmp/foo`

  expect_success(Libvirt::Domain, "2 args", "restore", conn, $GUEST_SAVE)

  `rm -f #{$GUEST_SAVE}`

  newdom.destroy
  newdom.undefine
end

# TESTGROUP: dom.info
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "info", 1)

expect_success(newdom, "no args", "info") {|x| x.state == Libvirt::Domain::RUNNING and x.max_mem == 1048576 and x.memory == 1048576 and x.nr_virt_cpu == 2}

newdom.destroy

# TESTGROUP: dom.security_label
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "security_label", 1)

expect_success(newdom, "no args", "security_label")

newdom.destroy

# TESTGROUP: dom.block_stats
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "block_stats", 1, 2)
expect_too_few_args(newdom, "block_stats")
expect_invalid_arg_type(newdom, "block_stats", 1)
expect_fail(newdom, Libvirt::RetrieveError, "invalid path", "block_stats", "foo")

expect_success(newdom, "block device arg", "block_stats", "vda")

newdom.destroy

# TESTGROUP: dom.memory_stats
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "memory_stats", 1, 2)
expect_invalid_arg_type(newdom, "memory_stats", "foo")

expect_success(newdom, "no args", "memory_stats")

newdom.destroy

# TESTGROUP: dom.blockinfo
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "blockinfo", 1, 2, 3)
expect_too_few_args(newdom, "blockinfo")
expect_invalid_arg_type(newdom, "blockinfo", 1)
expect_invalid_arg_type(newdom, "blockinfo", "foo", "bar")
expect_fail(newdom, Libvirt::RetrieveError, "invalid path", "blockinfo", "foo")

expect_success(newdom, "path arg", "blockinfo", $GUEST_DISK)

newdom.destroy

# TESTGROUP: dom.block_peek
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "block_peek", 1, 2, 3, 4, 5)
expect_too_few_args(newdom, "block_peek")
expect_too_few_args(newdom, "block_peek", 1)
expect_too_few_args(newdom, "block_peek", 1, 2)
expect_invalid_arg_type(newdom, "block_peek", 1, 2, 3)
expect_invalid_arg_type(newdom, "block_peek", "foo", "bar", 3)
expect_invalid_arg_type(newdom, "block_peek", "foo", 0, "bar")
expect_invalid_arg_type(newdom, "block_peek", "foo", 0, 512, "baz")
expect_fail(newdom, Libvirt::RetrieveError, "invalid path", "block_peek", "foo", 0, 512)

# blockpeek = newdom.block_peek($GUEST_RAW_DISK, 0, 512)

# # 0x51 0x46 0x49 0xfb are the first 4 bytes of a qcow2 image
# if blockpeek[0].unpack('C')[0] != 0x51 or blockpeek[1].unpack('C')[0] != 0x46 or
#   blockpeek[2].unpack('C')[0] != 0x49 or blockpeek[3].unpack('C')[0] != 0xfb
#   puts_fail "domain.block_peek read did not return valid data"
# else
#   puts_ok "domain.block_peek read valid data"
# end

newdom.destroy

# TESTGROUP: dom.memory_peek
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "memory_peek", 1, 2, 3, 4)
expect_too_few_args(newdom, "memory_peek")
expect_too_few_args(newdom, "memory_peek", 1)
expect_invalid_arg_type(newdom, "memory_peek", "foo", 2)
expect_invalid_arg_type(newdom, "memory_peek", 0, "bar")
expect_invalid_arg_type(newdom, "memory_peek", 0, 512, "baz")

expect_success(newdom, "offset and size args", "memory_peek", 0, 512)

newdom.destroy

# TESTGROUP: dom.get_vcpus
expect_too_many_args(newdom, "get_vcpus", 1)

newdom = conn.define_domain_xml($new_dom_xml)

expect_success(newdom, "get_vcpus on shutoff domain", "get_vcpus") {|x| x.length == 2}

newdom.create
test_sleep 1

expect_success(newdom, "no args", "get_vcpus") {|x| x.length == 2}

newdom.destroy
newdom.undefine

# TESTGROUP: dom.active?
expect_too_many_args(newdom, "active?", 1)

newdom = conn.define_domain_xml($new_dom_xml)

expect_success(newdom, "no args", "active?") {|x| x == false}

newdom.create
test_sleep 1

expect_success(newdom, "no args", "active?") {|x| x == true}

newdom.destroy
newdom.undefine

# TESTGROUP: dom.persistent?
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "persistent?", 1)

expect_success(newdom, "no args", "persistent?") {|x| x == false}

newdom.destroy

newdom = conn.define_domain_xml($new_dom_xml)

expect_success(newdom, "no args", "persistent?") {|x| x == true}

newdom.undefine

# TESTGROUP: dom.ifinfo
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "ifinfo", 1, 2)
expect_too_few_args(newdom, "ifinfo")
expect_invalid_arg_type(newdom, "ifinfo", 1)
expect_fail(newdom, Libvirt::RetrieveError, "invalid arg", "ifinfo", "foo")

expect_success(newdom, "interface arg", "ifinfo", "rl556")

newdom.destroy

# TESTGROUP: dom.name
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "name", 1)

expect_success(newdom, "no args", "name") {|x| x == "rb-libvirt-test"}
expect_success(newdom, "is UTF-8", "name") {|x| x.encoding.name == "UTF-8"}

newdom.destroy

# TESTGROUP: dom.id
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "id", 1)

expect_success(newdom, "no args", "id")

newdom.destroy

# TESTGROUP: dom.uuid
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "uuid", 1)

expect_success(newdom, "no args", "uuid") {|x| x == $GUEST_UUID}

newdom.destroy

# TESTGROUP: dom.os_type
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "os_type", 1)

if test_default_uri?
  expect_success(newdom, "no args", "os_type") {|x| x == "linux"}
else
  expect_success(newdom, "no args", "os_type") {|x| x == "hvm"}
end

newdom.destroy

# TESTGROUP: dom.max_memory
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "max_memory", 1)

expect_success(newdom, "no args", "max_memory") {|x| x == 1048576}

newdom.destroy

# TESTGROUP: dom.max_memory=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "max_memory=", 1, 2)
expect_too_few_args(newdom, "max_memory=")
expect_invalid_arg_type(newdom, "max_memory=", 'foo')

expect_success(newdom, "memory arg", "max_memory=", 200000)

newdom.undefine

# TESTGROUP: dom.memory=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "memory=", 1, 2)
expect_too_many_args(newdom, "memory=", [1, 2, 3])
expect_too_few_args(newdom, "memory=")
expect_too_few_args(newdom, "memory=", [])
expect_invalid_arg_type(newdom, "memory=", 'foo')
expect_fail(newdom, Libvirt::Error, "shutoff domain", "memory=", [2, Libvirt::Domain::AFFECT_LIVE])

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_success(newdom, "number arg", "memory=", 200000)

newdom.destroy

# TESTGROUP: dom.max_vcpus
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "max_vcpus", 1)

expect_success(newdom, "no args", "max_vcpus")

newdom.destroy

# TESTGROUP: dom.vcpus=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "vcpus=", 1, 2)
expect_too_many_args(newdom, "vcpus=", [0, 1, 2])
expect_too_few_args(newdom, "vcpus=")
expect_too_few_args(newdom, "vcpus=", [])
expect_invalid_arg_type(newdom, "vcpus=", 'foo')
expect_fail(newdom, Libvirt::Error, "shutoff domain", "vcpus=", [2, Libvirt::Domain::AFFECT_LIVE])

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_success(newdom, "number arg", "vcpus=", 2)

newdom.destroy

# TESTGROUP: dom.pin_vcpu
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "pin_vcpu", 1, 2, 3, 4)
expect_too_few_args(newdom, "pin_vcpu")
expect_invalid_arg_type(newdom, "pin_vcpu", 'foo', [0])
expect_invalid_arg_type(newdom, "pin_vcpu", 0, 1)

expect_success(newdom, "cpu args", "pin_vcpu", 0, [0])

newdom.destroy

# TESTGROUP: dom.xml_desc
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "xml_desc", 1, 2)
expect_invalid_arg_type(newdom, "xml_desc", "foo")

expect_success(newdom, "no args", "xml_desc")

newdom.destroy

# TESTGROUP: dom.undefine
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "undefine", 1, 2)

expect_success(newdom, "no args", "undefine")

# TESTGROUP: dom.create
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "create", 1, 2)
expect_invalid_arg_type(newdom, "create", "foo")

expect_success(newdom, "no args", "create")

expect_fail(newdom, Libvirt::Error, "on already running domain", "create")

newdom.destroy
newdom.undefine

# TESTGROUP: dom.autostart?
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "autostart?", 1)

expect_success(newdom, "no args", "autostart?") {|x| x == false}

newdom.autostart = true

expect_success(newdom, "no args", "autostart?") {|x| x == true}

newdom.undefine

# TESTGROUP: dom.autostart=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "autostart=", 1, 2)
expect_invalid_arg_type(newdom, "autostart=", 'foo')
expect_invalid_arg_type(newdom, "autostart=", nil)
expect_invalid_arg_type(newdom, "autostart=", 1234)

expect_success(newdom, "true arg", "autostart=", true)
if not newdom.autostart?
  puts_fail "domain.autostart= did not set autostart to true"
else
  puts_ok "domain.autostart= set autostart to true"
end

expect_success(newdom, "false arg", "autostart=", false)
if newdom.autostart?
  puts_fail "domain.autostart= did not set autostart to false"
else
  puts_ok "domain.autostart= set autostart to false"
end

newdom.undefine

# TESTGROUP: dom.attach_device
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "attach_device", 1, 2, 3)
expect_too_few_args(newdom, "attach_device")
expect_invalid_arg_type(newdom, "attach_device", 1)
expect_invalid_arg_type(newdom, "attach_device", 'foo', 'bar')
expect_fail(newdom, Libvirt::Error, "invalid XML", "attach_device", "hello")
expect_fail(newdom, Libvirt::Error, "shut off domain", "attach_device", new_hostdev_xml)

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

#expect_success(newdom, "hostdev XML", "attach_device", new_hostdev_xml)

newdom.destroy

# TESTGROUP: dom.detach_device
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "detach_device", 1, 2, 3)
expect_too_few_args(newdom, "detach_device")
expect_invalid_arg_type(newdom, "detach_device", 1)
expect_invalid_arg_type(newdom, "detach_device", 'foo', 'bar')
expect_fail(newdom, Libvirt::Error, "invalid XML", "detach_device", "hello")
expect_fail(newdom, Libvirt::Error, "shut off domain", "detach_device", new_hostdev_xml)

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

#expect_success(newdom, "hostdev XML", "detach_device", new_hostdev_xml)

newdom.destroy

# TESTGROUP: dom.update_device
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "update_device", 1, 2, 3)
expect_too_few_args(newdom, "update_device")
expect_invalid_arg_type(newdom, "update_device", 1)
expect_invalid_arg_type(newdom, "update_device", 'foo', 'bar')
expect_fail(newdom, Libvirt::Error, "invalid XML", "update_device", "hello")
expect_fail(newdom, Libvirt::Error, "shut off domain", "update_device", new_hostdev_xml)

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

#expect_success(newdom, "hostdev XML", "update_device", new_hostdev_xml)

newdom.destroy

# TESTGROUP: dom.free
newdom = conn.define_domain_xml($new_dom_xml)
newdom.undefine
expect_too_many_args(newdom, "free", 1)

expect_success(newdom, "free", "free")

# TESTGROUP: dom.snapshot_create_xml
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "snapshot_create_xml", 1, 2, 3)
expect_too_few_args(newdom, "snapshot_create_xml")
expect_invalid_arg_type(newdom, "snapshot_create_xml", 1)
expect_invalid_arg_type(newdom, "snapshot_create_xml", nil)
expect_invalid_arg_type(newdom, "snapshot_create_xml", 'foo', 'bar')

expect_success(newdom, "simple XML arg", "snapshot_create_xml", "<domainsnapshot/>")

snaps = newdom.num_of_snapshots
if snaps != 1
  puts_fail "domain.snapshot_create_xml after one snapshot has #{snaps} snapshots"
else
  puts_ok "domain.snapshot_create_xml after one snapshot has 1 snapshot"
end

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)

# TESTGROUP: dom.num_of_snapshots
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "num_of_snapshots", 1, 2)
expect_invalid_arg_type(newdom, "num_of_snapshots", 'foo')

expect_success(newdom, "no args", "num_of_snapshots") {|x| x == 0}

newdom.snapshot_create_xml("<domainsnapshot/>")

expect_success(newdom, "no args", "num_of_snapshots") {|x| x == 1}

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)

# TESTGROUP: dom.list_snapshots
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "list_snapshots", 1, 2)
expect_invalid_arg_type(newdom, "list_snapshots", 'foo')

expect_success(newdom, "no args", "list_snapshots") {|x| x.length == 0}

newdom.snapshot_create_xml("<domainsnapshot/>")

expect_success(newdom, "no args", "list_snapshots") {|x| x.length == 1}

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)

# TESTGROUP: dom.lookup_snapshot_by_name
newdom = conn.define_domain_xml($new_dom_xml)
newdom.snapshot_create_xml("<domainsnapshot><name>foo</name></domainsnapshot>")

expect_too_many_args(newdom, "lookup_snapshot_by_name", 1, 2, 3)
expect_too_few_args(newdom, "lookup_snapshot_by_name")
expect_invalid_arg_type(newdom, "lookup_snapshot_by_name", 1)
expect_invalid_arg_type(newdom, "lookup_snapshot_by_name", 'foo', 'bar')
expect_utf8_exception_msg(newdom, Libvirt::RetrieveError, "lookup_snapshot_by_name", "__non_existing_snapshot")

expect_success(newdom, "name arg", "lookup_snapshot_by_name", "foo")

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)

# TESTGROUP: dom.has_current_snapshot?
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "has_current_snapshot?", 1, 2)
expect_invalid_arg_type(newdom, "has_current_snapshot?", 'foo')

expect_success(newdom, "no args", "has_current_snapshot?") {|x| x == false}

newdom.snapshot_create_xml("<domainsnapshot><name>foo</name></domainsnapshot>")

expect_success(newdom, "no args", "has_current_snapshot?") {|x| x == true}

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)

# TESTGROUP: dom.revert_to_snapshot
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "revert_to_snapshot", 1, 2, 3)
expect_too_few_args(newdom, "revert_to_snapshot")
expect_invalid_arg_type(newdom, "revert_to_snapshot", 1)
expect_invalid_arg_type(newdom, "revert_to_snapshot", nil)
expect_invalid_arg_type(newdom, "revert_to_snapshot", 'foo')

snap = newdom.snapshot_create_xml("<domainsnapshot><name>foo</name></domainsnapshot>")
test_sleep 1

expect_invalid_arg_type(newdom, "revert_to_snapshot", snap, 'foo')

expect_success(newdom, "snapshot arg", "revert_to_snapshot", snap)

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)

# TESTGROUP: dom.current_snapshot
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "current_snapshot", 1, 2)
expect_invalid_arg_type(newdom, "current_snapshot", 'foo')
expect_fail(newdom, Libvirt::RetrieveError, "with no snapshots", "current_snapshot")

newdom.snapshot_create_xml("<domainsnapshot><name>foo</name></domainsnapshot>")

expect_success(newdom, "no args", "current_snapshot")

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)

# TESTGROUP: dom.job_info
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)

  expect_too_many_args(newdom, "job_info", 1)

  expect_fail(newdom, Libvirt::RetrieveError, "shutoff domain", "job_info")

  newdom.undefine

  newdom = conn.create_domain_xml($new_dom_xml)
  test_sleep 1

  expect_success(newdom, "no args", "job_info")

  newdom.destroy
end

# TESTGROUP: dom.abort_job
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "abort_job", 1)

expect_fail(newdom, Libvirt::Error, "not running domain", "abort_job")

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_fail(newdom, Libvirt::Error, "no active job", "abort_job")

# FIXME: need to start long running job here
#expect_success(newdom, "no args", "abort_job")

newdom.destroy

# TESTGROUP: dom.scheduler_type
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "scheduler_type", 1)

expect_success(newdom, "no args", "scheduler_type")

newdom.undefine

# TESTGROUP: dom.scheduler_parameters
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "scheduler_parameters", 1, 1)

expect_success(newdom, "no args", "scheduler_parameters")

newdom.undefine

# TESTGROUP: dom.scheduler_parameters=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "scheduler_parameters=", 1, 2)
expect_too_few_args(newdom, "scheduler_parameters=")
expect_invalid_arg_type(newdom, "scheduler_parameters=", 0)

if !test_default_uri?
  expect_success(newdom, "cpu shares arg", "scheduler_parameters=", {"cpu_shares" => 512})
end

newdom.undefine

# TESTGROUP: dom.qemu_monitor_command
if !test_default_uri?
  newdom = conn.create_domain_xml($new_dom_xml)

  expect_too_many_args(newdom, "qemu_monitor_command", 1, 2, 3)
  expect_too_few_args(newdom, "qemu_monitor_command")
  expect_invalid_arg_type(newdom, "qemu_monitor_command", 1)
  expect_invalid_arg_type(newdom, "qemu_monitor_command", "foo", "bar")
  expect_fail(newdom, Libvirt::RetrieveError, "invalid command", "qemu_monitor_command", "foo")

  expect_success(newdom, "monitor command", "qemu_monitor_command", '{"execute":"query-cpus"}')

  newdom.destroy
end

# TESTGROUP: dom.num_vcpus
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "num_vcpus", 1, 2)
expect_too_few_args(newdom, "num_vcpus")
expect_invalid_arg_type(newdom, "num_vcpus", 'foo')
expect_fail(newdom, Libvirt::Error, "active flag on shutoff domain", "num_vcpus", Libvirt::Domain::VCPU_LIVE)
expect_fail(newdom, Libvirt::Error, "live and config flags", "num_vcpus", Libvirt::Domain::VCPU_LIVE | Libvirt::Domain::VCPU_CONFIG)
expect_success(newdom, "config flag", "num_vcpus", Libvirt::Domain::VCPU_CONFIG) {|x| x == 2}

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_fail(newdom, Libvirt::RetrieveError, "config flag on transient domain", "num_vcpus", Libvirt::Domain::VCPU_CONFIG)
expect_success(newdom, "live flag on transient domain", "num_vcpus", Libvirt::Domain::VCPU_LIVE)

newdom.destroy

# TESTGROUP: dom.vcpus_flags=
# dom.vcpus_flags= is deprecated in favor of dom.vcpus=, so we don't do any
# tests here for it

# TESTGROUP: dom.memory_parameters=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "memory_parameters=", 1, 2, 3)
expect_too_many_args(newdom, "memory_parameters=", [1, 2, 3])
expect_too_few_args(newdom, "memory_parameters=")
expect_too_few_args(newdom, "memory_parameters=", [])
expect_invalid_arg_type(newdom, "memory_parameters=", 0)
expect_invalid_arg_type(newdom, "memory_parameters=", [1, 0])
expect_invalid_arg_type(newdom, "memory_parameters=", [{}, "foo"])

expect_success(newdom, "soft and hard limit", "memory_parameters=", {"soft_limit" => 9007199254740999, "swap_hard_limit" => 9007199254740999})

newdom.undefine

# TESTGROUP: dom.memory_parameters
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "memory_parameters", 1, 2)

expect_success(newdom, "no args", "memory_parameters")

newdom.undefine

# TESTGROUP: dom.blkio_parameters=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "blkio_parameters=", 1, 2, 3)
expect_too_many_args(newdom, "blkio_parameters=", [1, 2, 3])
expect_too_few_args(newdom, "blkio_parameters=")
expect_too_few_args(newdom, "blkio_parameters=", [])
expect_invalid_arg_type(newdom, "blkio_parameters=", 0)
expect_invalid_arg_type(newdom, "blkio_parameters=", [1, 0])
expect_invalid_arg_type(newdom, "blkio_parameters=", [{}, "foo"])

expect_success(newdom, "hash", "blkio_parameters=", {"weight" => 100})

newdom.undefine

# TESTGROUP: dom.blkio_parameters
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "blkio_parameters", 1, 2)

expect_success(newdom, "no args", "blkio_parameters")

newdom.undefine

# TESTGROUP: dom.open_console
newdom = conn.create_domain_xml($new_dom_xml)
stream = conn.stream

expect_too_many_args(newdom, "open_console", 1, 2, 3, 4)
expect_too_few_args(newdom, "open_console")
expect_too_few_args(newdom, "open_console", 1)
expect_invalid_arg_type(newdom, "open_console", 1, stream)
expect_invalid_arg_type(newdom, "open_console", "pty", 1)
expect_invalid_arg_type(newdom, "open_console", "pty", stream, "wow")

#expect_success(newdom, "device and stream args", "open_console", "pty", stream)

newdom.destroy

# TESTGROUP: dom.block_rebase
newdom = conn.create_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "block_rebase", 1, 2, 3, 4, 5)
expect_too_few_args(newdom, "block_rebase")
expect_invalid_arg_type(newdom, "block_rebase", 1)
expect_invalid_arg_type(newdom, "block_rebase", "foo", 1)
expect_invalid_arg_type(newdom, "block_rebase", "foo", "bar", "baz")
expect_invalid_arg_type(newdom, "block_rebase", "foo", "bar", 1, "boom")

# FIXME: I don't know how to make block_rebase work
#expect_success(newdom, "disk", "block_rebase", diskname)

newdom.destroy

# TESTGROUP: dom.migrate_max_downtime=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "migrate_max_downtime=", 1, 2)
expect_too_many_args(newdom, "migrate_max_downtime=", [1, 2, 3])
expect_too_few_args(newdom, "migrate_max_downtime=")
expect_too_few_args(newdom, "migrate_max_downtime=", [])
expect_invalid_arg_type(newdom, "migrate_max_downtime=", 'foo')
expect_invalid_arg_type(newdom, "migrate_max_downtime=", nil)
expect_fail(newdom, Libvirt::Error, "on off domain", "migrate_max_downtime=", 10)
expect_fail(newdom, Libvirt::Error, "on off domain, two args", "migrate_max_downtime=", [10, 10])

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1
#expect_fail(newdom, Libvirt::Error, "while no migration in progress", "migrate_max_downtime=", 10)

# FIXME: get this working
#newdom.migrate_to_uri("qemu://remote/system")
#expect_success(newdom, "10 second downtime", "migrate_max_downtime=", 10)

newdom.destroy

# TESTGROUP: dom.migrate_max_speed=
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "migrate_max_speed=", 1, 2)
expect_too_many_args(newdom, "migrate_max_speed=", [1, 2, 3])
expect_too_few_args(newdom, "migrate_max_speed=")
expect_too_few_args(newdom, "migrate_max_speed=", [])
expect_invalid_arg_type(newdom, "migrate_max_speed=", 'foo')
expect_invalid_arg_type(newdom, "migrate_max_speed=", nil)
expect_invalid_arg_type(newdom, "migrate_max_speed=", ['foo', 1])
expect_invalid_arg_type(newdom, "migrate_max_speed=", [1, 'foo'])

#expect_success(newdom, "Bandwidth arg", "migrate_max_speed=", 5)

newdom.destroy

# TESTGROUP: dom.state
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "state", 1, 2)
expect_invalid_arg_type(newdom, "state", 'foo')

expect_success(newdom, "no arg", "state")

newdom.destroy

# TESTGROUP: dom.screenshot
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

stream = conn.stream

expect_too_many_args(newdom, "screenshot", 1, 2, 3, 4)
expect_too_few_args(newdom, "screenshot")
expect_too_few_args(newdom, "screenshot", stream)
expect_invalid_arg_type(newdom, "screenshot", 1, 0)
expect_invalid_arg_type(newdom, "screenshot", nil, 0)
expect_invalid_arg_type(newdom, "screenshot", stream, nil)
expect_invalid_arg_type(newdom, "screenshot", stream, 'foo')
expect_invalid_arg_type(newdom, "screenshot", stream, 0, 'foo')

expect_success(newdom, "stream and screen arg", "screenshot", stream, 0)

newdom.destroy

# TESTGROUP: dom.vcpus_flags=
newdom = conn.define_domain_xml($new_dom_xml)

expect_too_many_args(newdom, "vcpus_flags=", 1, 2)
expect_too_many_args(newdom, "vcpus_flags=", [0, 1, 2])
expect_too_few_args(newdom, "vcpus_flags=")
expect_too_few_args(newdom, "vcpus_flags=", [])
expect_invalid_arg_type(newdom, "vcpus_flags=", 'foo')
expect_fail(newdom, Libvirt::Error, "shutoff domain", "vcpus_flags=", [2, Libvirt::Domain::AFFECT_LIVE])

newdom.undefine

newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_success(newdom, "number arg", "vcpus_flags=", 2)

newdom.destroy

# TESTGROUP: domain.list_all_snapshots
newdom = conn.define_domain_xml($new_dom_xml)
snap = newdom.snapshot_create_xml("<domainsnapshot/>")

expect_too_many_args(newdom, "list_all_snapshots", 1, 2)
expect_invalid_arg_type(newdom, "list_all_snapshots", 'foo')

expect_success(newdom, "no args", "list_all_snapshots")

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
test_sleep 1

# TESTGROUP: domain.open_graphics
newdom = conn.create_domain_xml($new_dom_xml)
test_sleep 1

expect_too_many_args(newdom, "open_graphics", 1, 2, 3, 4)
expect_too_few_args(newdom, "open_graphics")
expect_invalid_arg_type(newdom, "open_graphics", nil)
expect_invalid_arg_type(newdom, "open_graphics", 'foo')
expect_invalid_arg_type(newdom, "open_graphics", [])
expect_invalid_arg_type(newdom, "open_graphics", {})
expect_invalid_arg_type(newdom, "open_graphics", 4, 'foo')
expect_invalid_arg_type(newdom, "open_graphics", 4, [])
expect_invalid_arg_type(newdom, "open_graphics", 4, {})
expect_invalid_arg_type(newdom, "open_graphics", 4, 0, 'foo')
expect_invalid_arg_type(newdom, "open_graphics", 4, 0, [])
expect_invalid_arg_type(newdom, "open_graphics", 4, 0, {})

#expect_success(newdom, "fd arg", "open_graphics", fd)

set_test_object("snapshot")

# TESTGROUP: snapshot.xml_desc
newdom = conn.define_domain_xml($new_dom_xml)
snap = newdom.snapshot_create_xml("<domainsnapshot/>")

expect_too_many_args(snap, "xml_desc", 1, 2)
expect_invalid_arg_type(snap, "xml_desc", 'foo')

expect_success(newdom, "no args", "xml_desc")

newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
test_sleep 1

# TESTGROUP: snapshot.delete
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "delete", 1, 2)
  expect_invalid_arg_type(snap, "delete", 'foo')

  expect_success(snap, "no args", "delete")

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.name
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "name", 1)

  expect_success(snap, "no args", "name")

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.num_children
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "num_children", 1, 2)

  expect_success(snap, "no args, no children", "num_children") {|x| x == 0}

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.list_children_names
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "list_children_names", 1, 2)

  expect_success(snap, "no args, no children", "num_children") {|x| x == 0}

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.free
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "free", 1)

  expect_success(snap, "no args", "free")

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.has_metadata?
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "has_metadata?", 1, 2)
  expect_invalid_arg_type(snap, "has_metadata?", "foo")

  expect_success(snap, "no args", "has_metadata?") {|x| x == true}

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.list_children_names
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot><name>snap</name></domainsnapshot>")
  snap2 = newdom.snapshot_create_xml("<domainsnapshot><name>snap2</name></domainsnapshot>")

  expect_too_many_args(snap, "list_children_names", 1, 2)
  expect_invalid_arg_type(snap, "list_children_names", "foo")
  expect_invalid_arg_type(snap, "list_children_names", [])
  expect_invalid_arg_type(snap, "list_children_names", {})

  expect_success(snap, "no args", "list_children_names")

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.list_all_children
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "list_all_children", 1, 2)
  expect_invalid_arg_type(snap, "list_all_children", "foo")
  expect_invalid_arg_type(snap, "list_all_children", [])
  expect_invalid_arg_type(snap, "list_all_children", {})

  expect_success(snap, "no args", "list_all_children")

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.parent
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")
  test_sleep 1
  snap2 = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap2, "parent", 1, 2)
  expect_invalid_arg_type(snap2, "parent", "foo")
  expect_invalid_arg_type(snap2, "parent", [])
  expect_invalid_arg_type(snap2, "parent", {})

  expect_success(snap2, "no args", "parent")
  expect_success(snap, "no args", "parent")

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# TESTGROUP: snapshot.current?
if !test_default_uri?
  newdom = conn.define_domain_xml($new_dom_xml)
  snap = newdom.snapshot_create_xml("<domainsnapshot/>")

  expect_too_many_args(snap, "current?", 1, 2)
  expect_invalid_arg_type(snap, "current?", "foo")
  expect_invalid_arg_type(snap, "current?", [])
  expect_invalid_arg_type(snap, "current?", {})

  expect_success(snap, "no args", "current?")

  newdom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  test_sleep 1
end

# END TESTS

conn.close

finish_tests
