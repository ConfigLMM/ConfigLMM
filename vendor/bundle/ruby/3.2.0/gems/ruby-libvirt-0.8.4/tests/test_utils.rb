$FAIL = 0
$SUCCESS = 0
$SKIPPED = 0

DEFAULT_URI = "test:///default"
URI = ENV['RUBY_LIBVIRT_TEST_URI'] || DEFAULT_URI

$GUEST_BASE = '/var/lib/libvirt/images/rb-libvirt-test'
$GUEST_DISK = $GUEST_BASE + '.qcow2'
$GUEST_SAVE = $GUEST_BASE + '.save'
$GUEST_UUID = "93a5c045-6457-2c09-e56f-927cdf34e17a"
$GUEST_RAW_DISK = $GUEST_BASE + '.raw'

# XML data for later tests
$new_dom_xml = <<EOF
<domain type='kvm'>
  <description>Ruby Libvirt Tester</description>
  <name>rb-libvirt-test</name>
  <uuid>#{$GUEST_UUID}</uuid>
  <memory>1048576</memory>
  <currentMemory>1048576</currentMemory>
  <vcpu>2</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <pae/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <devices>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='#{$GUEST_DISK}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='bridge'>
      <mac address='52:54:00:60:3c:95'/>
      <source bridge='virbr0'/>
      <model type='virtio'/>
      <target dev='rl556'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target port='0'/>
    </console>
    <input type='mouse' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' keymap='en-us'/>
    <video>
      <model type='cirrus' vram='9216' heads='1'/>
    </video>
  </devices>
</domain>
EOF

$NEW_INTERFACE_MAC = 'aa:bb:cc:dd:ee:ff'
$new_interface_xml = <<EOF
<interface type="ethernet" name="rb-libvirt-test">
  <start mode="onboot"/>
  <mac address="#{$NEW_INTERFACE_MAC}"/>
  <protocol family='ipv4'>
    <dhcp peerdns='yes'/>
  </protocol>
</interface>
EOF

$NETWORK_UUID = "04068860-d9a2-47c5-bc9d-9e047ae901da"
$new_net_xml = <<EOF
<network>
  <name>rb-libvirt-test</name>
  <uuid>#{$NETWORK_UUID}</uuid>
  <forward mode='nat'/>
  <bridge name='rubybr0' stp='on' delay='0' />
  <ip address='192.168.134.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.134.2' end='192.168.134.254' />
    </dhcp>
  </ip>
</network>
EOF

$new_network_dhcp_ip = <<EOF
<host mac='00:11:22:33:44:55' ip='192.168.134.5'/>
EOF

$NWFILTER_UUID = "bd339530-134c-6d07-441a-17fb90dad807"
$new_nwfilter_xml = <<EOF
<filter name='rb-libvirt-test' chain='ipv4'>
  <uuid>#{$NWFILTER_UUID}</uuid>
  <rule action='accept' direction='out' priority='100'>
    <ip srcipaddr='0.0.0.0' dstipaddr='255.255.255.255' protocol='tcp' srcportstart='63000' dstportstart='62000'/>
  </rule>
  <rule action='accept' direction='in' priority='100'>
    <ip protocol='tcp' srcportstart='63000' dstportstart='62000'/>
  </rule>
</filter>
EOF

$SECRET_UUID = "bd339530-134c-6d07-4410-17fb90dad805"
$new_secret_xml = <<EOF
<secret ephemeral='no' private='no'>
  <description>test secret</description>
  <uuid>#{$SECRET_UUID}</uuid>
  <usage type='volume'>
    <volume>/var/lib/libvirt/images/mail.img</volume>
  </usage>
</secret>
EOF

$POOL_UUID = "33a5c045-645a-2c00-e56b-927cdf34e17a"
$POOL_PATH = "/var/lib/libvirt/images/rb-libvirt-test"
$new_storage_pool_xml = <<EOF
<pool type="dir">
  <name>rb-libvirt-test</name>
  <uuid>#{$POOL_UUID}</uuid>
  <target>
    <path>#{$POOL_PATH}</path>
  </target>
</pool>
EOF

$test_object = "unknown"

def set_test_object(obj)
  $test_object = obj
end

def test_default_uri?()
  return URI == DEFAULT_URI
end

def test_sleep(s)
  if !test_default_uri?
    sleep s
  end
end

def expect_success(object, msg, func, *args)
  begin
    x = object.__send__(func, *args)
    if block_given?
      res = yield x
      if not res
        raise "block failed"
      end
    end
    puts_ok "#{$test_object}.#{func} #{msg} succeeded"
    x
  rescue NoMethodError
    puts_skipped "#{$test_object}.#{func} does not exist"
  rescue => e
    puts_fail "#{$test_object}.#{func} #{msg} expected to succeed, threw #{e.class.to_s}: #{e.to_s}"
  end
end

def expect_fail(object, errtype, errmsg, func, *args)
  begin
    object.__send__(func, *args)
  rescue NoMethodError
    puts_skipped "#{$test_object}.#{func} does not exist"
  rescue errtype => e
    puts_ok "#{$test_object}.#{func} #{errmsg} threw #{errtype.to_s}"
  rescue => e
    puts_fail "#{$test_object}.#{func} #{errmsg} expected to throw #{errtype.to_s}, but instead threw #{e.class.to_s}: #{e.to_s}"
  else
    puts_fail "#{$test_object}.#{func} #{errmsg} expected to throw #{errtype.to_s}, but threw nothing"
  end
end

def expect_utf8_exception_msg(object, errtype, func, *args)
  begin
    object.__send__(func, *args)
  rescue NoMethodError
    puts_skipped "#{$test_object}.#{func} does not exist"
  rescue errtype => e
    if e.message.encoding.name == 'UTF-8'
      puts_ok "#{$test_object}.#{func} threw #{errtype.to_s} with UTF-8 encoding"
    else
      puts_fail "#{$test_object}.#{func} threw #{errtype.to_s} with #{e.message.encoding.name} encoding"
    end
  rescue => e
    puts_fail "#{$test_object}.#{func} expected to throw #{errtype.to_s}, but instead threw #{e.class.to_s}: #{e.to_s}"
  else
    puts_fail "#{$test_object}.#{func} expected to throw #{errtype.to_s}, but threw nothing"
  end
end

def expect_too_many_args(object, func, *args)
  expect_fail(object, ArgumentError, "too many args", func, *args)
end

def expect_too_few_args(object, func, *args)
  expect_fail(object, ArgumentError, "too few args", func, *args)
end

def expect_invalid_arg_type(object, func, *args)
  expect_fail(object, TypeError, "invalid arg type", func, *args)
end

def puts_ok(str)
  puts "OK: " + str
  $SUCCESS = $SUCCESS + 1
end

def puts_fail(str)
  puts "FAIL: " + str
  $FAIL = $FAIL + 1
end

def puts_skipped(str)
  puts "SKIPPED: " + str
  $SKIPPED = $SKIPPED + 1
end

def finish_tests
  puts "Successfully finished #{$SUCCESS} tests, failed #{$FAIL} tests, skipped #{$SKIPPED} tests"
end

def find_valid_iface(conn)
  conn.list_interfaces.each do |ifname|
    iface = conn.lookup_interface_by_name(ifname)
    if iface.mac == "00:00:00:00:00:00"
      next
    end
    return iface
  end
  return nil
end

def cleanup_test_domain(conn)
  # cleanup from previous runs
  begin
    olddom = conn.lookup_domain_by_name("rb-libvirt-test")
  rescue
    # in case we didn't find it, don't do anything
  end

  begin
    olddom.destroy
  rescue
    # in case we didn't destroy it, don't do anything
  end

  begin
    olddom.undefine(Libvirt::Domain::UNDEFINE_SNAPSHOTS_METADATA)
  rescue
    # in case we didn't undefine it, don't do anything
  end

  if URI != DEFAULT_URI
    `rm -f #{$GUEST_DISK}`
    `rm -f #{$GUEST_SAVE}`
  end
end

def cleanup_test_network(conn)
  # initial cleanup for previous run
  begin
    oldnet = conn.lookup_network_by_name("rb-libvirt-test")
  rescue
    # in case we didn't find it, don't do anything
  end

  begin
    oldnet.destroy
  rescue
    # in case we didn't find it, don't do anything
  end

  begin
    oldnet.undefine
  rescue
    # in case we didn't find it, don't do anything
  end
end
