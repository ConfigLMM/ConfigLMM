#!/usr/bin/ruby

# Test the stream methods the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("stream")

conn = Libvirt::open(URI)

# TESTGROUP: stream.send
st = conn.stream

expect_too_many_args(st, "send", 1, 2)
expect_too_few_args(st, "send")
expect_invalid_arg_type(st, "send", 1)
expect_invalid_arg_type(st, "send", nil)
expect_invalid_arg_type(st, "send", [])
expect_invalid_arg_type(st, "send", {})

# FIXME: we need to setup a proper stream for this to work
#expect_success(st, "buffer arg", "send", buffer)

st.free

# TESTGROUP: stream.recv
st = conn.stream

expect_too_many_args(st, "recv", 1, 2)
expect_too_few_args(st, "recv")
expect_invalid_arg_type(st, "recv", nil)
expect_invalid_arg_type(st, "recv", 'foo')
expect_invalid_arg_type(st, "recv", [])
expect_invalid_arg_type(st, "recv", {})

# FIXME: we need to setup a proper stream for this to work
#expect_success(st, "bytes arg", "recv", 12)

st.free

# TESTGROUP: stream.sendall
st = conn.stream

# equivalent to expect_too_many_args
begin
  st.sendall(1, 2) {|x,y| x = y}
rescue NoMethodError
  puts_skipped "#{$test_object}.sendall does not exist"
rescue ArgumentError => e
  puts_ok "#{$test_object}.sendall too many args threw #{ArgumentError.to_s}"
rescue => e
  puts_fail "#{$test_object}.sendall too many args expected to throw #{ArgumentError.to_s}, but instead threw #{e.class.to_s}: #{e.to_s}"
else
  puts_fail "#{$test_object}.sendall too many args expected to throw #{ArgumentError.to_s}, but threw nothing"
end

expect_fail(st, RuntimeError, "no block given", "sendall")

# FIXME: we need to setup a proper stream for this to work
#st.sendall {|opaque,nbytes| return opaque}

st.free

# TESTGROUP: stream.recvall
st = conn.stream

# equivalent to expect_too_many_args
begin
  st.recvall(1, 2) {|x,y| x = y}
rescue NoMethodError
  puts_skipped "#{$test_object}.recvall does not exist"
rescue ArgumentError => e
  puts_ok "#{$test_object}.recvall too many args threw #{ArgumentError.to_s}"
rescue => e
  puts_fail "#{$test_object}.recvall too many args expected to throw #{ArgumentError.to_s}, but instead threw #{e.class.to_s}: #{e.to_s}"
else
  puts_fail "#{$test_object}.recvall too many args expected to throw #{ArgumentError.to_s}, but threw nothing"
end

expect_fail(st, RuntimeError, "no block given", "recvall")

# FIXME: we need to setup a proper stream for this to work
#st.recvall {|data,opaque| return opaque}

st.free

# TESTGROUP: stream.event_add_callback
st_event_callback_proc = lambda {|stream,events,opaque|
}

st = conn.stream

expect_too_many_args(st, "event_add_callback", 1, 2, 3, 4)
expect_too_few_args(st, "event_add_callback")
expect_too_few_args(st, "event_add_callback", 1)
expect_invalid_arg_type(st, "event_add_callback", nil, st_event_callback_proc)
expect_invalid_arg_type(st, "event_add_callback", 'foo', st_event_callback_proc)
expect_invalid_arg_type(st, "event_add_callback", [], st_event_callback_proc)
expect_invalid_arg_type(st, "event_add_callback", {}, st_event_callback_proc)
expect_invalid_arg_type(st, "event_add_callback", 1, nil)
expect_invalid_arg_type(st, "event_add_callback", 1, 'foo')
expect_invalid_arg_type(st, "event_add_callback", 1, 1)
expect_invalid_arg_type(st, "event_add_callback", 1, [])
expect_invalid_arg_type(st, "event_add_callback", 1, {})

# FIXME: I get "this function is not support by the connection driver"
#expect_success(st, "events and callback arg", "event_add_callback", Libvirt::Stream::EVENT_READABLE, st_event_callback_proc)
#st.event_remove_callback

st.free

# TESTGROUP: stream.event_update_callback
st = conn.stream

expect_too_many_args(st, "event_update_callback", 1, 2)
expect_too_few_args(st, "event_update_callback")
expect_invalid_arg_type(st, "event_update_callback", nil)
expect_invalid_arg_type(st, "event_update_callback", 'foo')
expect_invalid_arg_type(st, "event_update_callback", [])
expect_invalid_arg_type(st, "event_update_callback", {})

# FIXME: we would need to get st.event_add_callback working to get this working
#expect_success(st, "events arg", "event_update_callback", Libvirt::Stream::EVENT_WRITABLE)

st.free

# TESTGROUP: stream.remove_callback
st = conn.stream

expect_too_many_args(st, "event_remove_callback", 1)

# FIXME: we would need to get st.event_add_callback working to get this working
#expect_success(st, "no arg", "event_remove_callback")

st.free

# TESTGROUP: stream.finish
st = conn.stream

expect_too_many_args(st, "finish", 1)

# FIXME: I get "this function is not support by the connection driver"
#expect_success(st, "no arg", "finish")

st.free

# TESTGROUP: stream.abort
st = conn.stream

expect_too_many_args(st, "abort", 1)

# FIXME: I get "this function is not support by the connection driver"
#expect_success(st, "no arg", "abort")

st.free

# TESTGROUP: stream.abort
st = conn.stream

expect_too_many_args(st, "free", 1)

expect_success(st, "no arg", "free")

# END TESTS

conn.close

finish_tests
