$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'minitest/autorun'
require 'tftp'

class Packet < Minitest::Test
  def test_parse_rrq
    assert_equal TFTP::Packet::RRQ.new('test.txt', :netascii),
                 TFTP::Packet.parse("\x00\x01test.txt\x00netascii\x00")
    assert_equal TFTP::Packet::RRQ.new('binary', :octet),
                 TFTP::Packet.parse("\x00\x01binary\x00octet\x00")
    assert_equal TFTP::Packet::RRQ.new('test.txt', :netascii),
                 TFTP::Packet.parse("\x00\x01test.txt\x00nEtasCIi\x00")
    assert_equal TFTP::Packet::RRQ.new('binary.exe', :octet),
                 TFTP::Packet.parse("\x00\x01binary.exe\x00OCTET\x00")


    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01\x00\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01\x00\x00\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01a\x00c\x00c\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x01foo\x00bar\x00") }
  end

  def test_encode_rrq
    assert_equal "\x00\x01test.txt\x00netascii\x00",
                 TFTP::Packet::RRQ.new('test.txt', :netascii).encode
    assert_equal "\x00\x01binary\x00octet\x00",
                 TFTP::Packet::RRQ.new('binary', :octet).encode
  end

  def test_parse_wrq
    assert_equal TFTP::Packet::WRQ.new('test.txt', :netascii),
                 TFTP::Packet.parse("\x00\x02test.txt\x00netascii\x00")
    assert_equal TFTP::Packet::WRQ.new('binary', :octet),
                 TFTP::Packet.parse("\x00\x02binary\x00octet\x00")
    assert_equal TFTP::Packet::WRQ.new('test.txt', :netascii),
                 TFTP::Packet.parse("\x00\x02test.txt\x00NetascIi\x00")
    assert_equal TFTP::Packet::WRQ.new('binary', :octet),
                 TFTP::Packet.parse("\x00\x02binary\x00OctEt\x00")


    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x02\x00\x00\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x02a\x00c\x00c\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x02foo\x00bar\x00") }
  end

  def test_encode_wrq
    assert_equal "\x00\x02test.txt\x00netascii\x00",
                 TFTP::Packet::WRQ.new('test.txt', :netascii).encode
    assert_equal "\x00\x02binary\x00octet\x00",
                 TFTP::Packet::WRQ.new('binary', :octet).encode
  end

  def test_parse_data
    assert_equal TFTP::Packet::DATA.new(0, "1234"),
                 TFTP::Packet.parse("\x00\x03\x00\x001234")
    assert_equal TFTP::Packet::DATA.new(16, ('a' * 512)),
                 TFTP::Packet.parse("\x00\x03\x00\x10" + ('a' * 512))
    assert       TFTP::Packet.parse("\x00\x03\x00\x001234").last?
    assert_equal TFTP::Packet::DATA.new(16, ''),
                 TFTP::Packet.parse("\x00\x03\x00\x10")
    assert       TFTP::Packet.parse("\x00\x03\x00\x10").last?

    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x03\x00\x00" + ('a' * 513)) }
  end

  def test_encode_data
    assert_equal "\x00\x03\x00\x001234",
                 TFTP::Packet::DATA.new(0, "1234").encode
    assert_equal "\x00\x03\x00\x10" + ('a' * 512),
                 TFTP::Packet::DATA.new(16, ('a' * 512)).encode
  end

  def test_parse_ack
    assert_equal TFTP::Packet::ACK.new(0),
                 TFTP::Packet.parse("\x00\x04\x00\x00")
    assert_equal TFTP::Packet::ACK.new(64434),
                 TFTP::Packet.parse("\x00\x04\xfb\xb2")


    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x04\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x04\x00" + ('A' * 8)) }
  end

  def test_encode_ack
    assert_equal "\x00\x04\x00\x00",
                  TFTP::Packet::ACK.new(0).encode
    assert_equal "\x00\x04\x00\x01",
                  TFTP::Packet::ACK.new(1).encode
  end

  def test_parse_error
    assert_equal TFTP::Packet::ERROR.new(0, 'Not defined, see error message (if any).'),
                 TFTP::Packet.parse("\x00\x05\x00\x00Not defined, see error message (if any).\x00")
    assert_equal TFTP::Packet::ERROR.new(7, 'No such user.'),
                 TFTP::Packet.parse("\x00\x05\x00\x07No such user.\x00")
    assert_equal TFTP::Packet::ERROR.new(3, ''),
                 TFTP::Packet.parse("\x00\x05\x00\x03\x00")

    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x05\x00\xff\x00") }
    assert_raises(TFTP::ParseError) { TFTP::Packet.parse("\x00\x05\x00\x03") }
  end

  def test_encode_error
    assert_equal "\x00\x05\x00\x07No such user.\x00",
                 TFTP::Packet::ERROR.new(7, 'No such user.').encode
    assert_equal "\x00\x05\x00\x03\x00",
                 TFTP::Packet::ERROR.new(3, '').encode
  end
end
