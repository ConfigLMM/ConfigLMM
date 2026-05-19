/*
 * stream.c: virStream methods
 *
 * Copyright (C) 2007,2010 Red Hat Inc.
 * Copyright (C) 2013-2016 Chris Lalancette <clalancette@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
 */

#include <ruby.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>
#include "common.h"
#include "connect.h"
#include "extconf.h"

static VALUE c_stream;

static void stream_free(void *s)
{
    ruby_libvirt_free_struct(Stream, s);
}

virStreamPtr ruby_libvirt_stream_get(VALUE s)
{
    ruby_libvirt_get_struct(Stream, s);
}

VALUE ruby_libvirt_stream_new(virStreamPtr s, VALUE conn)
{
    return ruby_libvirt_new_class(c_stream, s, conn, stream_free);
}

/*
 * call-seq:
 *   stream.send(buffer) -> Fixnum
 *
 * Call virStreamSend[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamSend]
 * to send the data in buffer out to the stream.  The return value is the
 * number of bytes sent, which may be less than the size of the buffer.  If
 * an error occurred, -1 is returned.  If the transmit buffers are full and the
 * stream is marked non-blocking, returns -2.
 */
static VALUE libvirt_stream_send(VALUE s, VALUE buffer)
{
    int ret;

    StringValue(buffer);

    ret = virStreamSend(ruby_libvirt_stream_get(s), RSTRING_PTR(buffer),
                        RSTRING_LEN(buffer));
    ruby_libvirt_raise_error_if(ret == -1, e_RetrieveError, "virStreamSend",
                                ruby_libvirt_connect_get(s));

    return INT2NUM(ret);
}

/*
 * call-seq:
 *   stream.recv(bytes) -> [return_value, data]
 *
 * Call virStreamRecv[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamRecv]
 * to receive up to bytes amount of data from the stream.  The return is an
 * array with two elements; the return code from the virStreamRecv call and
 * the data (as a String) read from the stream.  If an error occurred, the
 * return_value is set to -1.  If there is no data pending and the stream is
 * marked as non-blocking, return_value is set to -2.
 */
static VALUE libvirt_stream_recv(VALUE s, VALUE bytes)
{
    char *data;
    int ret;
    VALUE result;

    data = alloca(sizeof(char) * NUM2INT(bytes));

    ret = virStreamRecv(ruby_libvirt_stream_get(s), data, NUM2INT(bytes));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError, "virStreamRecv",
                                ruby_libvirt_connect_get(s));

    result = rb_ary_new2(2);

    rb_ary_store(result, 0, INT2NUM(ret));
    rb_ary_store(result, 1, rb_str_new(data, ret));

    return result;
}

static int internal_sendall(virStreamPtr RUBY_LIBVIRT_UNUSED(st), char *data,
                            size_t nbytes, void *opaque)
{
    VALUE result, retcode, buffer;

    result = rb_yield_values(2, (VALUE)opaque, INT2NUM(nbytes));

    if (TYPE(result) != T_ARRAY) {
        rb_raise(rb_eTypeError, "wrong type (expected Array)");
    }

    if (RARRAY_LEN(result) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(result));
    }

    retcode = rb_ary_entry(result, 0);
    buffer = rb_ary_entry(result, 1);

    if (NUM2INT(retcode) < 0) {
        return NUM2INT(retcode);
    }

    StringValue(buffer);

    if (RSTRING_LEN(buffer) > (int)nbytes) {
        rb_raise(rb_eArgError, "asked for %zd bytes, block returned %ld",
                 nbytes, RSTRING_LEN(buffer));
    }

    memcpy(data, RSTRING_PTR(buffer), RSTRING_LEN(buffer));

    return RSTRING_LEN(buffer);
}

/*
 * call-seq:
 *   stream.sendall(opaque=nil){|opaque, nbytes| send block} -> nil
 *
 * Call virStreamSendAll[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamSendAll]
 * to send the entire data stream.  The send block is required and is executed
 * one or more times to send data.  Each invocation of the send block yields
 * the opaque data passed into the initial call and the number of bytes this
 * iteration is prepared to handle.  The send block should return an array of
 * 2 elements; the first element should be the return code from the block
 * (-1 for error, 0 otherwise), and the second element should be the data
 * that the block prepared to send.
 */
static VALUE libvirt_stream_sendall(int argc, VALUE *argv, VALUE s)
{
    VALUE opaque = RUBY_Qnil;
    int ret;

    if (!rb_block_given_p()) {
        rb_raise(rb_eRuntimeError, "A block must be provided");
    }

    rb_scan_args(argc, argv, "01", &opaque);

    ret = virStreamSendAll(ruby_libvirt_stream_get(s), internal_sendall,
                           (void *)opaque);
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError, "virStreamSendAll",
                                ruby_libvirt_connect_get(s));

    return Qnil;
}

static int internal_recvall(virStreamPtr RUBY_LIBVIRT_UNUSED(st),
                            const char *buf, size_t nbytes, void *opaque)
{
    VALUE result;

    result = rb_yield_values(2, rb_str_new(buf, nbytes), (VALUE)opaque);

    if (TYPE(result) != T_FIXNUM) {
        rb_raise(rb_eArgError, "wrong type (expected an integer)");
    }

    return NUM2INT(result);
}

/*
 * call-seq:
 *   stream.recvall(opaque){|data, opaque| receive block} -> nil
 *
 * Call virStreamRecvAll[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamRecvAll]
 * to receive the entire data stream.  The receive block is required and is
 * called one or more times to receive data.  Each invocation of the receive
 * block yields the data received and the opaque data passed into the initial
 * call.  The block should return -1 if an error occurred and 0 otherwise.
 */
static VALUE libvirt_stream_recvall(int argc, VALUE *argv, VALUE s)
{
    VALUE opaque = RUBY_Qnil;
    int ret;

    if (!rb_block_given_p()) {
        rb_raise(rb_eRuntimeError, "A block must be provided");
    }

    rb_scan_args(argc, argv, "01", &opaque);

    ret = virStreamRecvAll(ruby_libvirt_stream_get(s), internal_recvall,
                           (void *)opaque);
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError, "virStreamRecvAll",
                                ruby_libvirt_connect_get(s));

    return Qnil;
}

static void stream_event_callback(virStreamPtr st, int events, void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, news, s;

    if (TYPE(passthrough) != T_ARRAY) {
        rb_raise(rb_eTypeError,
                 "wrong domain event lifecycle callback argument type (expected Array)");
    }

    if (RARRAY_LEN(passthrough) != 3) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 3)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);
    s = rb_ary_entry(passthrough, 2);

    news = ruby_libvirt_stream_new(st, ruby_libvirt_conn_attr(s));
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 3, news, INT2NUM(events),
                   cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 3, news, INT2NUM(events), cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong stream event callback (expected Symbol or Proc)");
    }
}

/*
 * call-seq:
 *   stream.event_add_callback(events, callback, opaque=nil) -> nil
 *
 * Call virStreamEventAddCallback[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamEventAddCallback]
 * to register a callback to be notified when a stream becomes readable or
 * writeable.  The events parameter is an integer representing the events the
 * user is interested in; it should be one or more of EVENT_READABLE,
 * EVENT_WRITABLE, EVENT_ERROR, and EVENT_HANGUP, ORed together.  The callback
 * can either be a Symbol (that is the name of a method to callback) or a Proc.
 * The callback should accept 3 parameters: a pointer to the Stream object
 * itself, the integer that represents the events that actually occurred, and
 * an opaque pointer that was (optionally) passed into
 * stream.event_add_callback to begin with.
 */
static VALUE libvirt_stream_event_add_callback(int argc, VALUE *argv, VALUE s)
{
    VALUE events = RUBY_Qnil, callback = RUBY_Qnil, opaque = RUBY_Qnil, passthrough;
    int ret;

    rb_scan_args(argc, argv, "21", &events, &callback, &opaque);

    if (!ruby_libvirt_is_symbol_or_proc(callback)) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Symbol or Proc)");
    }

    passthrough = rb_ary_new2(3);
    rb_ary_store(passthrough, 0, callback);
    rb_ary_store(passthrough, 1, opaque);
    rb_ary_store(passthrough, 2, s);

    ret = virStreamEventAddCallback(ruby_libvirt_stream_get(s), NUM2INT(events),
                                    stream_event_callback, (void *)passthrough,
                                    NULL);
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virStreamEventAddCallback",
                                ruby_libvirt_connect_get(s));

    return Qnil;
}

/*
 * call-seq:
 *   stream.event_update_callback(events) -> nil
 *
 * Call virStreamEventUpdateCallback[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamEventUpdateCallback]
 * to change the events that the event callback is looking for.  The events
 * parameter is an integer representing the events the user is interested in;
 * it should be one or more of EVENT_READABLE, EVENT_WRITABLE, EVENT_ERROR,
 * and EVENT_HANGUP, ORed together.
 */
static VALUE libvirt_stream_event_update_callback(VALUE s, VALUE events)
{
    ruby_libvirt_generate_call_nil(virStreamEventUpdateCallback,
                                   ruby_libvirt_connect_get(s),
                                   ruby_libvirt_stream_get(s), NUM2INT(events));
}

/*
 * call-seq:
 *   stream.event_remove_callback -> nil
 *
 * Call virStreamEventRemoveCallback[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamEventRemoveCallback]
 * to remove the event callback currently registered to this stream.
 */
static VALUE libvirt_stream_event_remove_callback(VALUE s)
{
    ruby_libvirt_generate_call_nil(virStreamEventRemoveCallback,
                                   ruby_libvirt_connect_get(s),
                                   ruby_libvirt_stream_get(s));
}

/*
 * call-seq:
 *   stream.finish -> nil
 *
 * Call virStreamFinish[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamFinish]
 * to finish this stream.  Finish is typically used when the stream is no
 * longer needed and needs to be cleaned up.
 */
static VALUE libvirt_stream_finish(VALUE s)
{
    ruby_libvirt_generate_call_nil(virStreamFinish, ruby_libvirt_connect_get(s),
                                   ruby_libvirt_stream_get(s));
}

/*
 * call-seq:
 *   stream.abort -> nil
 *
 * Call virStreamAbort[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamAbort]
 * to abort this stream.  Abort is typically used when something on the stream
 * has failed, and the stream needs to be cleaned up.
 */
static VALUE libvirt_stream_abort(VALUE s)
{
    ruby_libvirt_generate_call_nil(virStreamAbort, ruby_libvirt_connect_get(s),
                                   ruby_libvirt_stream_get(s));
}

/*
 * call-seq:
 *   stream.free -> nil
 *
 * Call virStreamFree[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamFree]
 * to free this stream.  The object will no longer be valid after this call.
 */
static VALUE libvirt_stream_free(VALUE s)
{
    ruby_libvirt_generate_call_free(Stream, s);
}

/*
 * Class Libvirt::Stream
 */
void ruby_libvirt_stream_init(void)
{
    c_stream = rb_define_class_under(m_libvirt, "Stream", rb_cObject);
    rb_undef_alloc_func(c_stream);
    rb_define_singleton_method(c_stream, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_attr(c_stream, "connection", 1, 0);

    rb_define_const(c_stream, "NONBLOCK", INT2NUM(VIR_STREAM_NONBLOCK));
    rb_define_const(c_stream, "EVENT_READABLE",
                    INT2NUM(VIR_STREAM_EVENT_READABLE));
    rb_define_const(c_stream, "EVENT_WRITABLE",
                    INT2NUM(VIR_STREAM_EVENT_WRITABLE));
    rb_define_const(c_stream, "EVENT_ERROR", INT2NUM(VIR_STREAM_EVENT_ERROR));
    rb_define_const(c_stream, "EVENT_HANGUP", INT2NUM(VIR_STREAM_EVENT_HANGUP));

    rb_define_method(c_stream, "send", libvirt_stream_send, 1);
    rb_define_method(c_stream, "recv", libvirt_stream_recv, 1);
    rb_define_method(c_stream, "sendall", libvirt_stream_sendall, -1);
    rb_define_method(c_stream, "recvall", libvirt_stream_recvall, -1);

    rb_define_method(c_stream, "event_add_callback",
                     libvirt_stream_event_add_callback, -1);
    rb_define_method(c_stream, "event_update_callback",
                     libvirt_stream_event_update_callback, 1);
    rb_define_method(c_stream, "event_remove_callback",
                     libvirt_stream_event_remove_callback, 0);
    rb_define_method(c_stream, "finish", libvirt_stream_finish, 0);
    rb_define_method(c_stream, "abort", libvirt_stream_abort, 0);
    rb_define_method(c_stream, "free", libvirt_stream_free, 0);
}
