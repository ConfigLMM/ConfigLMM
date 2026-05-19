#!/usr/bin/env ruby
# dhcp_test.rb
# 4 de octubre de 2007
#

$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'

require 'net-dhcp'

class TestDhcp_test < Test::Unit::TestCase
#  def setup
#  end
#
#  def teardown
#  end

  def test_packing
    # assert_equal("foo", bar)

    # assert, assert_block, assert_equal, assert_in_delta, assert_instance_of,
    # assert_kind_of, assert_match, assert_nil, assert_no_match, assert_not_equal,
    # assert_not_nil, assert_not_same, assert_nothing_raised, assert_nothing_thrown,
    # assert_operator, assert_raise, assert_raises, assert_respond_to, assert_same,
    # assert_send, assert_throws

    d = DHCP::Discover.new
    expected = [
      d.op, d.htype, d.hlen, d.hops, 
      d.xid, 
      d.secs, d.flags, 
      d.ciaddr, 
      d.yiaddr, 
      d.siaddr, 
      d.giaddr,
      ]
    expected += d.chaddr
    expected += [0x00]*192
    expected << $DHCP_MAGIC
    
    payload = d.pack
    
    actual = payload.unpack('C4Nn2N4C16C192N')
    
    assert_equal expected, actual, 'pack does not work'
  end

  def test_size
    d = DHCP::Discover.new
    payload = d.pack
    assert_equal 300, payload.size, 'size of the payload does not match'
  end

  def test_eql?
    d1 = DHCP::Discover.new
    d2 = DHCP::Discover.new
    
    assert_not_equal d1, d2, '.eql? two messages with different xid field are considered equal'   
    assert_equal true, d1.options.eql?(d1.options), 'eql? is not working for comparing option arrays'
  end
  
  def test_from_udp_payload 
    d1 = DHCP::Discover.new
    d2 = DHCP::Message.from_udp_payload(d1.pack)
    
    assert d1.eql?(d2), 'udp data is not correctly parsed'
  end
  
end
