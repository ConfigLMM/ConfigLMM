#!/usr/bin/ruby

# Test the open calls that the bindings support

$: << File.dirname(__FILE__)

require 'libvirt'
require 'test_utils.rb'

set_test_object("Libvirt")

def expect_connect_error(func, args)
  expect_fail(Libvirt, Libvirt::ConnectionError, "invalid driver", func, *args)
end

# TESTGROUP: Libvirt::version
expect_too_many_args(Libvirt, "version", "test", 1)
expect_invalid_arg_type(Libvirt, "version", 1)
expect_success(Libvirt, "no args", "version") {|x| x.class == Array and x.length == 2}
expect_success(Libvirt, "nil arg", "version", nil) {|x| x.class == Array and x.length == 2}
expect_success(Libvirt, "Test arg", "version", "Test") {|x| x.class == Array and x.length == 2}

# TESTGROUP: Libvirt::open
if !test_default_uri?
  expect_too_many_args(Libvirt, "open", URI, 1)
  expect_connect_error("open", "foo:///system")
  conn = expect_success(Libvirt, "no args", "open") {|x| x.class == Libvirt::Connect }
  conn.close
  conn = expect_success(Libvirt, URI, "open", URI) {|x| x.class == Libvirt::Connect }
  conn.close
  conn = expect_success(Libvirt, "nil arg", "open", nil) {|x| x.class == Libvirt::Connect }
  conn.close
end

# TESTGROUP: Libvirt::open_read_only
if !test_default_uri?
  expect_too_many_args(Libvirt, "open_read_only", URI, 1)
  expect_connect_error("open_read_only", "foo:///system")
  conn = expect_success(Libvirt, "no args", "open_read_only") {|x| x.class == Libvirt::Connect }
  conn.close
  conn = expect_success(Libvirt, URI, "open_read_only", URI) {|x| x.class == Libvirt::Connect }
  conn.close
  conn = expect_success(Libvirt, "nil arg", "open_read_only", nil) {|x| x.class == Libvirt::Connect }
  conn.close
end

# TESTGROUP: Libvirt::open_auth
if !test_default_uri?
  expect_too_many_args(Libvirt, "open_auth", URI, [], "hello there", 1, 2)
  expect_connect_error("open_auth", "foo:///system")
  expect_invalid_arg_type(Libvirt, "open_auth", 1)
  expect_invalid_arg_type(Libvirt, "open_auth", URI, [], "hello", "foo")

  conn = expect_success(Libvirt, "no args", "open_auth")  {|x| x.class == Libvirt::Connect }
  conn.close

  conn = expect_success(Libvirt, "uri arg", "open_auth", URI) {|x| x.class == Libvirt::Connect }
  conn.close

  conn = expect_success(Libvirt, "uri and empty cred args", "open_auth", URI, []) {|x| x.class == Libvirt::Connect }
  conn.close

  conn = expect_success(Libvirt, "uri and full cred args", "open_auth", URI, [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE]) {|x| x.class == Libvirt::Connect }
  conn.close

  conn = expect_success(Libvirt, "uri, full cred, and user args", "open_auth", URI, [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE], "hello") {|x| x.class == Libvirt::Connect }
  conn.close

  # equivalent to expect_invalid_arg_type
  begin
    conn = Libvirt::open_auth(URI, {}) do |cred|
    end
  rescue TypeError => e
    puts_ok "#{$test_object}.open_auth invalid arg type threw #{TypeError.to_s}"
  else
    puts_fail "#{$test_object}.open_auth invalid arg type expected to throw #{TypeError.to_s}, but threw nothing"
  end

  # equivalent to expect_invalid_arg_type
  begin
    conn = Libvirt::open_auth(URI, 1) do |cred|
    end
  rescue TypeError => e
    puts_ok "#{$test_object}.open_auth invalid arg type threw #{TypeError.to_s}"
  else
    puts_fail "#{$test_object}.open_auth invalid arg type expected to throw #{TypeError.to_s}, but threw nothing"
  end

  # equivalent to expect_invalid_arg_type
  begin
    conn = Libvirt::open_auth(URI, 'foo') do |cred|
    end
  rescue TypeError => e
    puts_ok "#{$test_object}.open_auth invalid arg type threw #{TypeError.to_s}"
  else
    puts_fail "#{$test_object}.open_auth invalid arg type expected to throw #{TypeError.to_s}, but threw nothing"
  end

  # equivalent to "expect_success"
  begin
    conn = Libvirt::open_auth(URI, [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE], "hello") do |cred|
      if not cred["userdata"].nil?
        puts "userdata is #{cred["userdata"]}"
      end
      if cred["type"] == Libvirt::CRED_AUTHNAME
        print "#{cred['prompt']}: "
        res = gets
        # strip off the \n
        res = res[0..-2]
      elsif cred["type"] == Libvirt::CRED_PASSPHRASE
        print "#{cred['prompt']}: "
        res = gets
        res = res[0..-2]
      else
        raise "Unsupported credential #{cred['type']}"
      end
      res
    end

    puts_ok "Libvirt.open_auth uri, creds, userdata, auth block succeeded"
    conn.close
  rescue NoMethodError
    puts_skipped "Libvirt.open_auth does not exist"
  rescue => e
    puts_fail "Libvirt.open_auth uri, creds, userdata, auth block expected to succeed, threw #{e.class.to_s}: #{e.to_s}"
  end

  # equivalent to "expect_success"
  begin
    conn = Libvirt::open_auth(URI) do |cred|
    end

    puts_ok "Libvirt.open_auth uri, succeeded"
    conn.close
  rescue NoMethodError
    puts_skipped "Libvirt.open_auth does not exist"
  rescue => e
    puts_fail "Libvirt.open_auth uri expected to succeed, threw #{e.class.to_s}: #{e.to_s}"
  end

  # equivalent to "expect_success"
  begin
    conn = Libvirt::open_auth(URI, [Libvirt::CRED_AUTHNAME, Libvirt::CRED_PASSPHRASE], "hello", Libvirt::CONNECT_RO) do |cred|
      if not cred["userdata"].nil?
        puts "userdata is #{cred["userdata"]}"
      end
      if cred["type"] == Libvirt::CRED_AUTHNAME
        print "#{cred['prompt']}: "
        res = gets
        # strip off the \n
        res = res[0..-2]
      elsif cred["type"] == Libvirt::CRED_PASSPHRASE
        print "#{cred['prompt']}: "
        res = gets
        res = res[0..-2]
      else
        raise "Unsupported credential #{cred['type']}"
      end
      res
    end

    puts_ok "Libvirt.open_auth uri, creds, userdata, R/O flag, auth block succeeded"
    conn.close
  rescue NoMethodError
    puts_skipped "Libvirt.open_auth does not exist"
  rescue => e
    puts_fail "Libvirt.open_auth uri, creds, userdata, R/O flag, auth block expected to succeed, threw #{e.class.to_s}: #{e.to_s}"
  end
end

# TESTGROUP: Libvirt::event_invoke_handle_callback
if !test_default_uri?
  conn = Libvirt::open(URI)

  expect_too_many_args(Libvirt, "event_invoke_handle_callback", 1, 2, 3, 4, 5)
  expect_too_few_args(Libvirt, "event_invoke_handle_callback")
  expect_too_few_args(Libvirt, "event_invoke_handle_callback", 1)
  expect_too_few_args(Libvirt, "event_invoke_handle_callback", 1, 2)
  expect_too_few_args(Libvirt, "event_invoke_handle_callback", 1, 2, 3)
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", "hello", 1, 1, 1)
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", "hello", 1, 1, [])
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", "hello", 1, 1, nil)
  # this is a bit bizarre; I am constructing a bogus hash to pass as the 4th
  # parameter to event_invoke_handle_callback.  In a real situation, I would
  # have been given this hash from libvirt earlier, and just pass it on.  I
  # don't want all of that complexity here, though, so I create the bogus hash.
  # One caveat; the data inside the hash *must* be of type T_DATA, so I pass in
  # a fake conn object just to appease the type checker (so I can test out the
  # other arguments properly)
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", "hello", 1, 1, { "libvirt_cb" => conn, "opaque" => conn })
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", 1, "hello", 1, { "libvirt_cb" => conn, "opaque" => conn })
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", 1, 1, "hello", { "libvirt_cb" => conn, "opaque" => conn })
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", 1, 1, 1, { "libvirt_cb" => "hello", "opaque" => conn })
  expect_invalid_arg_type(Libvirt, "event_invoke_handle_callback", 1, 1, 1, { "libvirt_cb" => conn, "opaque" => "hello" })
  conn.close
end

# TESTGROUP: Libvirt::event_invoke_timeout_callback
if !test_default_uri?
  conn = Libvirt::open(URI)

  expect_too_many_args(Libvirt, "event_invoke_timeout_callback", 1, 2, 3)
  expect_too_few_args(Libvirt, "event_invoke_timeout_callback")
  expect_too_few_args(Libvirt, "event_invoke_timeout_callback", 1)
  expect_invalid_arg_type(Libvirt, "event_invoke_timeout_callback", "hello", 1)
  expect_invalid_arg_type(Libvirt, "event_invoke_timeout_callback", "hello", [])
  expect_invalid_arg_type(Libvirt, "event_invoke_timeout_callback", "hello", nil)
  # this is a bit bizarre; I am constructing a bogus hash to pass as the 4th
  # parameter to event_invoke_handle_callback.  In a real situation, I would
  # have been given this hash from libvirt earlier, and just pass it on.  I
  # don't want all of that complexity here, though, so I create the bogus hash.
  # One caveat; the data inside the hash *must* be of type T_DATA, so I pass in
  # a fake conn object just to appease the type checker (so I can test out the
  # other arguments properly)
  expect_invalid_arg_type(Libvirt, "event_invoke_timeout_callback", "hello", { "libvirt_cb" => conn, "opaque" => conn })
  expect_invalid_arg_type(Libvirt, "event_invoke_timeout_callback", 1, { "libvirt_cb" => "hello", "opaque" => conn })
  expect_invalid_arg_type(Libvirt, "event_invoke_timeout_callback", 1, { "libvirt_cb" => conn, "opaque" => "hello" })
  conn.close
end

# TESTGROUP: Libvirt::event_register_impl
if !test_default_uri?
  expect_too_many_args(Libvirt, "event_register_impl", 1, 2, 3, 4, 5, 6, 7)
  expect_invalid_arg_type(Libvirt, "event_register_impl", 1)

  # symbol callbacks
  def virEventAddHandleImpl(fd, events, opaque)
  end
  def virEventUpdateHandleImpl(watch, event)
  end
  def virEventRemoveHandleImpl(handleID)
  end
  def virEventAddTimerImpl(interval, opaque)
  end
  def virEventUpdateTimerImpl(timer, timeout)
  end
  def virEventRemoveTimerImpl(timerID)
  end

  # proc callbacks
  virEventAddHandleProc = lambda {|fd, events, opaque|
  }
  virEventUpdateHandleProc = lambda {|watch, event|
  }
  virEventRemoveHandleProc = lambda {|handleID|
  }
  virEventAddTimerProc = lambda {|interval, opaque|
  }
  virEventUpdateTimerProc = lambda {|timer, timeout|
  }
  virEventRemoveTimerProc = lambda {|timerID|
  }

  expect_success(Libvirt, "all Symbol callbacks", "event_register_impl", :virEventAddHandleImpl, :virEventUpdateHandleImpl, :virEventRemoveHandleImpl, :virEventAddTimerImpl, :virEventUpdateTimerImpl, :virEventRemoveTimerImpl)
  expect_success(Libvirt, "unregister all callbacks", "event_register_impl", nil, nil, nil, nil, nil, nil)
  expect_success(Libvirt, "all Proc callbacks", "event_register_impl", virEventAddHandleProc, virEventUpdateHandleProc, virEventRemoveHandleProc, virEventAddTimerProc, virEventUpdateTimerProc, virEventRemoveTimerProc)
  expect_success(Libvirt, "unregister all callbacks", "event_register_impl")
end

# END TESTS

finish_tests
