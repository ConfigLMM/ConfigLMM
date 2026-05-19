/*
 * libvirt.c: Ruby bindings for libvirt
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
 *
 * Author: David Lutterkort <dlutter@redhat.com>
 */

#include <ruby.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>
#include <libvirt/libvirt-lxc.h>
#include "extconf.h"
#include "common.h"
#include "storage.h"
#include "connect.h"
#include "network.h"
#include "nodedevice.h"
#include "secret.h"
#include "nwfilter.h"
#include "interface.h"
#include "domain.h"
#include "stream.h"

#if !LIBVIR_CHECK_VERSION(2, 0, 0)
# error "Libvirt >= 2.0.0 is required for the ruby binding"
#endif

static VALUE c_libvirt_version;

VALUE m_libvirt;

/* define additional errors here */
static VALUE e_ConnectionError;         /* ConnectionError - error during connection establishment */
VALUE e_DefinitionError;
VALUE e_RetrieveError;
VALUE e_Error;
VALUE e_NoSupportError;

/* custom error function to suppress libvirt printing to stderr */
static void rubyLibvirtErrorFunc(void *RUBY_LIBVIRT_UNUSED(userdata),
                                 virErrorPtr RUBY_LIBVIRT_UNUSED(err))
{
}

/*
 * call-seq:
 *   Libvirt::version(type=nil) -> [ libvirt_version, type_version ]
 *
 * Call virGetVersion[https://libvirt.org/html/libvirt-libvirt-host.html#virGetVersion]
 * to get the version of libvirt and of the hypervisor TYPE.
 */
static VALUE libvirt_version(int argc, VALUE *argv,
                             VALUE RUBY_LIBVIRT_UNUSED(m))
{
    unsigned long libVer, typeVer;
    VALUE type, result, rargv[2];
    int r;

    rb_scan_args(argc, argv, "01", &type);

    r = virGetVersion(&libVer, ruby_libvirt_get_cstring_or_null(type),
                      &typeVer);
    ruby_libvirt_raise_error_if(r < 0, rb_eArgError, "virGetVersion", NULL);

    result = rb_ary_new2(2);
    rargv[0] = rb_str_new2("libvirt");
    rargv[1] = ULONG2NUM(libVer);
    rb_ary_store(result, 0, rb_class_new_instance(2, rargv, c_libvirt_version));
    rargv[0] = type;
    rargv[1] = ULONG2NUM(typeVer);
    rb_ary_store(result, 1, rb_class_new_instance(2, rargv, c_libvirt_version));
    return result;
}

/*
 * call-seq:
 *   Libvirt::open(uri=nil) -> Libvirt::Connect
 *
 * Call virConnectOpen[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectOpen]
 * to open a connection to a URL.
 */
static VALUE libvirt_open(int argc, VALUE *argv, VALUE RUBY_LIBVIRT_UNUSED(m))
{
    VALUE uri;
    virConnectPtr conn;

    rb_scan_args(argc, argv, "01", &uri);

    conn = virConnectOpen(ruby_libvirt_get_cstring_or_null(uri));
    ruby_libvirt_raise_error_if(conn == NULL, e_ConnectionError,
                                "virConnectOpen", NULL);

    return ruby_libvirt_connect_new(conn);
}

/*
 * call-seq:
 *   Libvirt::open_read_only(uri=nil) -> Libvirt::Connect
 *
 * Call virConnectOpenReadOnly[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectOpenReadOnly]
 * to open a read-only connection to a URL.
 */
static VALUE libvirt_open_read_only(int argc, VALUE *argv,
                                    VALUE RUBY_LIBVIRT_UNUSED(m))
{
    VALUE uri;
    virConnectPtr conn;

    rb_scan_args(argc, argv, "01", &uri);

    conn = virConnectOpenReadOnly(ruby_libvirt_get_cstring_or_null(uri));

    ruby_libvirt_raise_error_if(conn == NULL, e_ConnectionError,
                                "virConnectOpenReadOnly", NULL);

    return ruby_libvirt_connect_new(conn);
}

static int libvirt_auth_callback_wrapper(virConnectCredentialPtr cred,
                                         unsigned int ncred, void *cbdata)
{
    VALUE userdata, newcred, result;
    unsigned int i;

    userdata = (VALUE)cbdata;

    if (!rb_block_given_p()) {
        rb_raise(rb_eRuntimeError, "No block given, this should never happen!\n");
    }

    for (i = 0; i < ncred; i++) {
        newcred = rb_hash_new();

        rb_hash_aset(newcred, rb_str_new2("type"), INT2NUM(cred[i].type));
        rb_hash_aset(newcred, rb_str_new2("prompt"),
                     rb_str_new2(cred[i].prompt));
        if (cred[i].challenge) {
            rb_hash_aset(newcred, rb_str_new2("challenge"),
                         rb_str_new2(cred[i].challenge));
        }
        else {
            rb_hash_aset(newcred, rb_str_new2("challenge"), Qnil);
        }
        if (cred[i].defresult) {
            rb_hash_aset(newcred, rb_str_new2("defresult"),
                         rb_str_new2(cred[i].defresult));
        }
        else {
            rb_hash_aset(newcred, rb_str_new2("defresult"), Qnil);
        }
        rb_hash_aset(newcred, rb_str_new2("result"), Qnil);
        rb_hash_aset(newcred, rb_str_new2("userdata"), userdata);

        result = rb_yield(newcred);
        if (NIL_P(result)) {
            cred[i].result = NULL;
            cred[i].resultlen = 0;
        }
        else {
            cred[i].result = strdup(StringValueCStr(result));
            cred[i].resultlen = strlen(cred[i].result);
        }
    }

    return 0;
}

/*
 * call-seq:
 *   Libvirt::open_auth(uri=nil, credlist=nil, userdata=nil, flags=0) {|...| authentication block} -> Libvirt::Connect
 *
 * Call virConnectOpenAuth[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectOpenAuth]
 * to open a connection to a libvirt URI, with a possible authentication block.
 * If an authentication block is desired, then credlist should be an array that
 * specifies which credentials the authentication block is willing to support;
 * the full list is available at https://libvirt.org/html/libvirt-libvirt.html#virConnectCredentialType.
 * If userdata is not nil and an authentication block is given, userdata will
 * be passed unaltered into the authentication block.  The flags parameter
 * controls how to open connection.  The only options currently available for
 * flags are 0 for a read/write connection and Libvirt::CONNECT_RO for a
 * read-only connection.
 *
 * If the credlist is not empty, and an authentication block is given, the
 * authentication block will be called once for each credential necessary
 * to complete the authentication.  The authentication block will be passed a
 * single parameter, which is a hash of values containing information necessary
 * to complete authentication.  This hash contains 5 elements:
 *
 * type - the type of credential to be examined
 *
 * prompt - a suggested prompt to show to the user
 *
 * challenge - any additional challenge information
 *
 * defresult - a default result to use if credentials could not be obtained
 *
 * userdata - the userdata passed into open_auth initially
 *
 * The authentication block should return the result of collecting the
 * information; these results will then be sent to libvirt for authentication.
 */
static VALUE libvirt_open_auth(int argc, VALUE *argv,
                               VALUE RUBY_LIBVIRT_UNUSED(m))
{
    virConnectAuthPtr auth;
    VALUE uri, credlist, userdata, flags, tmp;
    virConnectPtr conn;
    unsigned int i;

    rb_scan_args(argc, argv, "04", &uri, &credlist, &userdata, &flags);

    if (rb_block_given_p()) {
        auth = alloca(sizeof(virConnectAuth));

        if (TYPE(credlist) == T_NIL) {
            auth->ncredtype = 0;
        }
        else if (TYPE(credlist) == T_ARRAY) {
            auth->ncredtype = RARRAY_LEN(credlist);
        }
        else {
            rb_raise(rb_eTypeError,
                     "wrong argument type (expected Array or nil)");
        }
        auth->credtype = NULL;
        if (auth->ncredtype > 0) {
            auth->credtype = alloca(sizeof(int) * auth->ncredtype);

            for (i = 0; i < auth->ncredtype; i++) {
                tmp = rb_ary_entry(credlist, i);
                auth->credtype[i] = NUM2INT(tmp);
            }
        }

        auth->cb = libvirt_auth_callback_wrapper;
        auth->cbdata = (void *)userdata;
    }
    else {
        auth = virConnectAuthPtrDefault;
    }

    conn = virConnectOpenAuth(ruby_libvirt_get_cstring_or_null(uri), auth,
                              ruby_libvirt_value_to_uint(flags));

    ruby_libvirt_raise_error_if(conn == NULL, e_ConnectionError,
                                "virConnectOpenAuth", NULL);

    return ruby_libvirt_connect_new(conn);
}

static VALUE add_handle, update_handle, remove_handle;
static VALUE add_timeout, update_timeout, remove_timeout;

/*
 * call-seq:
 *   Libvirt::event_invoke_handle_callback(handle, fd, events, opaque) -> Qnil
 *
 * Unlike most of the other functions in the ruby-libvirt bindings, this one
 * does not directly correspond to a libvirt API function.  Instead, this
 * module method (and event_invoke_timeout_callback) are meant to be called
 * when there is an event of interest to libvirt on one of the file descriptors
 * that libvirt uses.  The application is notified of the file descriptors
 * that libvirt uses via the callbacks from Libvirt::event_register_impl.  When
 * there is an event of interest, the application must call
 * event_invoke_timeout_callback to ensure proper operation.
 *
 * Libvirt::event_invoke_handle_callback takes 4 arguments:
 *
 * handle - an application specific handle ID.  This can be any integer, but must be unique from all other libvirt handles in the application.
 *
 * fd - the file descriptor of interest.  This was given to the application as a callback to add_handle of Libvirt::event_register_impl
 *
 * events - the events that have occured on the fd.  Note that the events are libvirt specific, and are some combination of Libvirt::EVENT_HANDLE_READABLE, Libvirt::EVENT_HANDLE_WRITABLE, Libvirt::EVENT_HANDLE_ERROR, Libvirt::EVENT_HANDLE_HANGUP.  To notify libvirt of more than one event at a time, these values should be logically OR'ed together.
 *
 * opaque - the opaque data passed from libvirt during the Libvirt::event_register_impl add_handle callback.  To ensure proper operation this data must be passed through to event_invoke_handle_callback without modification.
 */
static VALUE libvirt_event_invoke_handle_callback(VALUE RUBY_LIBVIRT_UNUSED(m),
                                                  VALUE handle, VALUE fd,
                                                  VALUE events, VALUE opaque)
{
    virEventHandleCallback cb;
    void *op;
    VALUE libvirt_cb, libvirt_opaque;

    Check_Type(opaque, T_HASH);

    libvirt_cb = rb_hash_aref(opaque, rb_str_new2("libvirt_cb"));

    /* This is equivalent to Data_Get_Struct; I reproduce it here because
     * I don't want the additional type-cast that Data_Get_Struct does
     */
    Check_Type(libvirt_cb, T_DATA);
    cb = DATA_PTR(libvirt_cb);

    if (cb) {
        libvirt_opaque = rb_hash_aref(opaque, rb_str_new2("opaque"));
        Data_Get_Struct(libvirt_opaque, void *, op);
        cb(NUM2INT(handle), NUM2INT(fd), NUM2INT(events), op);
    }

    return Qnil;
}

/*
 * call-seq:
 *   Libvirt::event_invoke_timeout_callback(timer, opaque) -> Qnil
 *
 * Unlike most of the other functions in the ruby-libvirt bindings, this one
 * does not directly correspond to a libvirt API function.  Instead, this
 * module method (and event_invoke_handle_callback) are meant to be called
 * when there is a timeout of interest to libvirt.  The application is
 * notified of the timers that libvirt uses via the callbacks from
 * Libvirt::event_register_impl.  When a timeout expires, the application must
 * call event_invoke_timeout_callback to ensure proper operation.
 *
 * Libvirt::event_invoke_timeout_callback takes 2 arguments:
 *
 * handle - an application specific timer ID.  This can be any integer, but must be unique from all other libvirt timers in the application.
 *
 * opaque - the opaque data passed from libvirt during the Libvirt::event_register_impl add_handle callback.  To ensure proper operation this data must be passed through to event_invoke_handle_callback without modification.
 */
static VALUE libvirt_event_invoke_timeout_callback(VALUE RUBY_LIBVIRT_UNUSED(m),
                                                   VALUE timer, VALUE opaque)
{
    virEventTimeoutCallback cb;
    void *op;
    VALUE libvirt_cb, libvirt_opaque;

    Check_Type(opaque, T_HASH);

    libvirt_cb = rb_hash_aref(opaque, rb_str_new2("libvirt_cb"));

    /* This is equivalent to Data_Get_Struct; I reproduce it here because
     * I don't want the additional type-cast that Data_Get_Struct does
     */
    Check_Type(libvirt_cb, T_DATA);
    cb = DATA_PTR(libvirt_cb);

    if (cb) {
        libvirt_opaque = rb_hash_aref(opaque, rb_str_new2("opaque"));
        Data_Get_Struct(libvirt_opaque, void *, op);
        cb(NUM2INT(timer), op);
    }

    return Qnil;
}

static int internal_add_handle_func(int fd, int events,
                                    virEventHandleCallback cb, void *opaque,
                                    virFreeCallback ff)
{
    VALUE rubyargs, res;

    rubyargs = rb_hash_new();
    rb_hash_aset(rubyargs, rb_str_new2("libvirt_cb"),
                 Data_Wrap_Struct(rb_class_of(add_handle), NULL, NULL, cb));
    rb_hash_aset(rubyargs, rb_str_new2("opaque"),
                 Data_Wrap_Struct(rb_class_of(add_handle), NULL, NULL, opaque));
    rb_hash_aset(rubyargs, rb_str_new2("free_func"),
                 Data_Wrap_Struct(rb_class_of(add_handle), NULL, NULL, ff));

    /* call out to the ruby object */
    if (strcmp(rb_obj_classname(add_handle), "Symbol") == 0) {
        res = rb_funcall(rb_class_of(add_handle), rb_to_id(add_handle), 3,
                         INT2NUM(fd), INT2NUM(events), rubyargs);
    }
    else if (strcmp(rb_obj_classname(add_handle), "Proc") == 0) {
        res = rb_funcall(add_handle, rb_intern("call"), 3, INT2NUM(fd),
                         INT2NUM(events), rubyargs);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong add handle callback argument type (expected Symbol or Proc)");
    }

    if (TYPE(res) != T_FIXNUM) {
        rb_raise(rb_eTypeError,
                 "expected integer return from add_handle callback");
    }

    return NUM2INT(res);
}

static void internal_update_handle_func(int watch, int event)
{
    /* call out to the ruby object */
    if (strcmp(rb_obj_classname(update_handle), "Symbol") == 0) {
        rb_funcall(rb_class_of(update_handle), rb_to_id(update_handle), 2,
                   INT2NUM(watch), INT2NUM(event));
    }
    else if (strcmp(rb_obj_classname(update_handle), "Proc") == 0) {
        rb_funcall(update_handle, rb_intern("call"), 2, INT2NUM(watch),
                   INT2NUM(event));
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong update handle callback argument type (expected Symbol or Proc)");
    }
}

static int internal_remove_handle_func(int watch)
{
    VALUE res, libvirt_opaque, ff;
    virFreeCallback ff_cb;
    void *op;

    /* call out to the ruby object */
    if (strcmp(rb_obj_classname(remove_handle), "Symbol") == 0) {
        res = rb_funcall(rb_class_of(remove_handle), rb_to_id(remove_handle),
                         1, INT2NUM(watch));
    }
    else if (strcmp(rb_obj_classname(remove_handle), "Proc") == 0) {
        res = rb_funcall(remove_handle, rb_intern("call"), 1, INT2NUM(watch));
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong remove handle callback argument type (expected Symbol or Proc)");
    }

    if (TYPE(res) != T_HASH) {
        rb_raise(rb_eTypeError,
                 "expected opaque hash returned from remove_handle callback");
    }

    ff = rb_hash_aref(res, rb_str_new2("free_func"));
    if (!NIL_P(ff)) {
        /* This is equivalent to Data_Get_Struct; I reproduce it here because
         * I don't want the additional type-cast that Data_Get_Struct does
         */
        Check_Type(ff, T_DATA);
        ff_cb = DATA_PTR(ff);
        if (ff_cb) {
            libvirt_opaque = rb_hash_aref(res, rb_str_new2("opaque"));
            Data_Get_Struct(libvirt_opaque, void *, op);

            (*ff_cb)(op);
        }
    }

    return 0;
}

static int internal_add_timeout_func(int interval, virEventTimeoutCallback cb,
                                     void *opaque, virFreeCallback ff)
{
    VALUE rubyargs, res;

    rubyargs = rb_hash_new();

    rb_hash_aset(rubyargs, rb_str_new2("libvirt_cb"),
                 Data_Wrap_Struct(rb_class_of(add_timeout), NULL, NULL, cb));
    rb_hash_aset(rubyargs, rb_str_new2("opaque"),
                 Data_Wrap_Struct(rb_class_of(add_timeout), NULL, NULL,
                                  opaque));
    rb_hash_aset(rubyargs, rb_str_new2("free_func"),
                 Data_Wrap_Struct(rb_class_of(add_timeout), NULL, NULL, ff));

    /* call out to the ruby object */
    if (strcmp(rb_obj_classname(add_timeout), "Symbol") == 0) {
        res = rb_funcall(rb_class_of(add_timeout), rb_to_id(add_timeout), 2,
                         INT2NUM(interval), rubyargs);
    }
    else if (strcmp(rb_obj_classname(add_timeout), "Proc") == 0) {
        res = rb_funcall(add_timeout, rb_intern("call"), 2, INT2NUM(interval),
                         rubyargs);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong add timeout callback argument type (expected Symbol or Proc)");
    }

    if (TYPE(res) != T_FIXNUM) {
        rb_raise(rb_eTypeError,
                 "expected integer return from add_timeout callback");
    }

    return NUM2INT(res);
}

static void internal_update_timeout_func(int timer, int timeout)
{
    /* call out to the ruby object */
    if (strcmp(rb_obj_classname(update_timeout), "Symbol") == 0) {
        rb_funcall(rb_class_of(update_timeout), rb_to_id(update_timeout), 2,
                   INT2NUM(timer), INT2NUM(timeout));
    }
    else if (strcmp(rb_obj_classname(update_timeout), "Proc") == 0) {
        rb_funcall(update_timeout, rb_intern("call"), 2, INT2NUM(timer),
                   INT2NUM(timeout));
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong update timeout callback argument type (expected Symbol or Proc)");
    }
}

static int internal_remove_timeout_func(int timer)
{
    VALUE res, libvirt_opaque, ff;
    virFreeCallback ff_cb;
    void *op;

    /* call out to the ruby object */
    if (strcmp(rb_obj_classname(remove_timeout), "Symbol") == 0) {
        res = rb_funcall(rb_class_of(remove_timeout), rb_to_id(remove_timeout),
                         1, INT2NUM(timer));
    }
    else if (strcmp(rb_obj_classname(remove_timeout), "Proc") == 0) {
        res = rb_funcall(remove_timeout, rb_intern("call"), 1, INT2NUM(timer));
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong remove timeout callback argument type (expected Symbol or Proc)");
    }

    if (TYPE(res) != T_HASH) {
        rb_raise(rb_eTypeError,
                 "expected opaque hash returned from remove_timeout callback");
    }

    ff = rb_hash_aref(res, rb_str_new2("free_func"));
    if (!NIL_P(ff)) {
        /* This is equivalent to Data_Get_Struct; I reproduce it here because
         * I don't want the additional type-cast that Data_Get_Struct does
         */
        Check_Type(ff, T_DATA);
        ff_cb = DATA_PTR(ff);
        if (ff_cb) {
            libvirt_opaque = rb_hash_aref(res, rb_str_new2("opaque"));
            Data_Get_Struct(libvirt_opaque, void *, op);

            (*ff_cb)(op);
        }
    }

    return 0;
}

#define set_event_func_or_null(type)                \
    do {                                            \
        if (NIL_P(type)) {                          \
            type##_temp = NULL;                     \
        }                                           \
        else {                                      \
            type##_temp = internal_##type##_func;   \
        }                                           \
    } while(0)

static int is_symbol_proc_or_nil(VALUE handle)
{
    if (NIL_P(handle)) {
        return 1;
    }
    return ruby_libvirt_is_symbol_or_proc(handle);
}

/*
 * call-seq:
 *   Libvirt::event_register_impl(add_handle=nil, update_handle=nil, remove_handle=nil, add_timeout=nil, update_timeout=nil, remove_timeout=nil) -> Qnil
 *
 * Call virEventRegisterImpl[https://libvirt.org/html/libvirt-libvirt-event.html#virEventRegisterImpl]
 * to register callback handlers for handles and timeouts.  These handles and
 * timeouts are used as part of the libvirt infrastructure for generating
 * domain events.  Each callback must be a Symbol (that is the name of a
 * method to callback), a Proc, or nil (to disable the callback).  In the
 * end-user application program, these callbacks are typically used to track
 * the file descriptors or timers that libvirt is interested in (and is intended
 * to be integrated into the "main loop" of a UI program).  The individual
 * callbacks will be given a certain number of arguments, and must return
 * certain values.  Those arguments and return types are:
 *
 * add_handle(fd, events, opaque) => Fixnum
 *
 * update_handle(handleID, event) => nil
 *
 * remove_handle(handleID) => opaque data from add_handle
 *
 * add_timeout(interval, opaque) => Fixnum
 *
 * update_timeout(timerID, timeout) => nil
 *
 * remove_timeout(timerID) => opaque data from add_timeout
 *
 * Any arguments marked as "opaque" must be accepted from the library and saved
 * without modification.  The values passed to the callbacks are meant to be
 * passed to the event_invoke_handle_callback and event_invoke_timeout_callback
 * module methods; see the documentation for those methods for more details.
 */
static VALUE libvirt_conn_event_register_impl(int argc, VALUE *argv,
                                              VALUE RUBY_LIBVIRT_UNUSED(c))
{
    virEventAddHandleFunc add_handle_temp;
    virEventUpdateHandleFunc update_handle_temp;
    virEventRemoveHandleFunc remove_handle_temp;
    virEventAddTimeoutFunc add_timeout_temp;
    virEventUpdateTimeoutFunc update_timeout_temp;
    virEventRemoveTimeoutFunc remove_timeout_temp;

    /*
     * subtle; we put the arguments (callbacks) directly into the global
     * add_handle, update_handle, etc. variables.  Then we register the
     * internal functions as the callbacks with virEventRegisterImpl
     */
    rb_scan_args(argc, argv, "06", &add_handle, &update_handle, &remove_handle,
                 &add_timeout, &update_timeout, &remove_timeout);

    if (!is_symbol_proc_or_nil(add_handle) ||
        !is_symbol_proc_or_nil(update_handle) ||
        !is_symbol_proc_or_nil(remove_handle) ||
        !is_symbol_proc_or_nil(add_timeout) ||
        !is_symbol_proc_or_nil(update_timeout) ||
        !is_symbol_proc_or_nil(remove_timeout)) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Symbol, Proc, or nil)");
    }

    set_event_func_or_null(add_handle);
    set_event_func_or_null(update_handle);
    set_event_func_or_null(remove_handle);
    set_event_func_or_null(add_timeout);
    set_event_func_or_null(update_timeout);
    set_event_func_or_null(remove_timeout);

    /* virEventRegisterImpl returns void, so no error checking here */
    virEventRegisterImpl(add_handle_temp, update_handle_temp,
                         remove_handle_temp, add_timeout_temp,
                         update_timeout_temp, remove_timeout_temp);

    return Qnil;
}

/*
 * call-seq:
 *   Libvirt::lxc_enter_security_label(model, label, flags=0) -> Libvirt::Domain::SecurityLabel
 *
 * Call virDomainLxcEnterSecurityLabel
 * to attach to the security label specified by label in the security model
 * specified by model.  The return object is a Libvirt::Domain::SecurityLabel
 * which may be able to be used to move back to the previous label.
 */
static VALUE libvirt_domain_lxc_enter_security_label(int argc, VALUE *argv,
                                                     VALUE RUBY_LIBVIRT_UNUSED(c))
{
    VALUE model = RUBY_Qnil, label = RUBY_Qnil, flags = RUBY_Qnil, result, modiv, doiiv, labiv;
    virSecurityModel mod;
    char *modstr, *doistr, *labstr;
    virSecurityLabel lab, oldlab;
    int ret;

    rb_scan_args(argc, argv, "21", &model, &label, &flags);

    if (rb_class_of(model) != c_node_security_model) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Libvirt::Connect::NodeSecurityModel)");
    }

    if (rb_class_of(label) != c_domain_security_label) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Libvirt::Domain::SecurityLabel)");
    }

    modiv = rb_iv_get(model, "@model");
    modstr = StringValueCStr(modiv);
    memcpy(mod.model, modstr, strlen(modstr));
    doiiv = rb_iv_get(model, "@doi");
    doistr = StringValueCStr(doiiv);
    memcpy(mod.doi, doistr, strlen(doistr));

    labiv = rb_iv_get(label, "@label");
    labstr = StringValueCStr(labiv);
    memcpy(lab.label, labstr, strlen(labstr));
    lab.enforcing = NUM2INT(rb_iv_get(label, "@enforcing"));

    ret = virDomainLxcEnterSecurityLabel(&mod, &lab, &oldlab,
                                         ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError,
                                "virDomainLxcEnterSecurityLabel", NULL);

    result = rb_class_new_instance(0, NULL, c_domain_security_label);
    rb_iv_set(result, "@label", rb_str_new2(oldlab.label));
    rb_iv_set(result, "@enforcing", INT2NUM(oldlab.enforcing));

    return result;
}

/*
 * Module Libvirt
 */
void Init__libvirt(void)
{
    m_libvirt = rb_define_module("Libvirt");
    c_libvirt_version = rb_define_class_under(m_libvirt, "Version",
                                              rb_cObject);

    rb_define_const(m_libvirt, "CONNECT_RO", INT2NUM(VIR_CONNECT_RO));

    rb_define_const(m_libvirt, "CRED_USERNAME", INT2NUM(VIR_CRED_USERNAME));
    rb_define_const(m_libvirt, "CRED_AUTHNAME", INT2NUM(VIR_CRED_AUTHNAME));
    rb_define_const(m_libvirt, "CRED_LANGUAGE", INT2NUM(VIR_CRED_LANGUAGE));
    rb_define_const(m_libvirt, "CRED_CNONCE", INT2NUM(VIR_CRED_CNONCE));
    rb_define_const(m_libvirt, "CRED_PASSPHRASE", INT2NUM(VIR_CRED_PASSPHRASE));
    rb_define_const(m_libvirt, "CRED_ECHOPROMPT", INT2NUM(VIR_CRED_ECHOPROMPT));
    rb_define_const(m_libvirt, "CRED_NOECHOPROMPT",
                    INT2NUM(VIR_CRED_NOECHOPROMPT));
    rb_define_const(m_libvirt, "CRED_REALM", INT2NUM(VIR_CRED_REALM));
    rb_define_const(m_libvirt, "CRED_EXTERNAL", INT2NUM(VIR_CRED_EXTERNAL));

    rb_define_const(m_libvirt, "CONNECT_NO_ALIASES",
                    INT2NUM(VIR_CONNECT_NO_ALIASES));

    /*
     * Libvirt Errors
     */
    e_Error =           rb_define_class_under(m_libvirt, "Error",
                                              rb_eStandardError);
    e_ConnectionError = rb_define_class_under(m_libvirt, "ConnectionError",
                                              e_Error);
    e_DefinitionError = rb_define_class_under(m_libvirt, "DefinitionError",
                                              e_Error);
    e_RetrieveError =   rb_define_class_under(m_libvirt, "RetrieveError",
                                              e_Error);
    e_NoSupportError =  rb_define_class_under(m_libvirt, "NoSupportError",
                                              e_Error);

    rb_define_attr(e_Error, "libvirt_function_name", 1, 0);
    rb_define_attr(e_Error, "libvirt_message", 1, 0);
    rb_define_attr(e_Error, "libvirt_code", 1, 0);
    rb_define_attr(e_Error, "libvirt_component", 1, 0);
    rb_define_attr(e_Error, "libvirt_level", 1, 0);

    /* libvirt error components (domains) */
    rb_define_const(e_Error, "FROM_NONE", INT2NUM(VIR_FROM_NONE));
    rb_define_const(e_Error, "FROM_XEN", INT2NUM(VIR_FROM_XEN));
    rb_define_const(e_Error, "FROM_XEND", INT2NUM(VIR_FROM_XEND));
    rb_define_const(e_Error, "FROM_XENSTORE", INT2NUM(VIR_FROM_XENSTORE));
    rb_define_const(e_Error, "FROM_SEXPR", INT2NUM(VIR_FROM_SEXPR));
    rb_define_const(e_Error, "FROM_XML", INT2NUM(VIR_FROM_XML));
    rb_define_const(e_Error, "FROM_DOM", INT2NUM(VIR_FROM_DOM));
    rb_define_const(e_Error, "FROM_RPC", INT2NUM(VIR_FROM_RPC));
    rb_define_const(e_Error, "FROM_PROXY", INT2NUM(VIR_FROM_PROXY));
    rb_define_const(e_Error, "FROM_CONF", INT2NUM(VIR_FROM_CONF));
    rb_define_const(e_Error, "FROM_QEMU", INT2NUM(VIR_FROM_QEMU));
    rb_define_const(e_Error, "FROM_NET", INT2NUM(VIR_FROM_NET));
    rb_define_const(e_Error, "FROM_TEST", INT2NUM(VIR_FROM_TEST));
    rb_define_const(e_Error, "FROM_REMOTE", INT2NUM(VIR_FROM_REMOTE));
    rb_define_const(e_Error, "FROM_OPENVZ", INT2NUM(VIR_FROM_OPENVZ));
    rb_define_const(e_Error, "FROM_VMWARE", INT2NUM(VIR_FROM_VMWARE));
    rb_define_const(e_Error, "FROM_XENXM", INT2NUM(VIR_FROM_XENXM));
    rb_define_const(e_Error, "FROM_STATS_LINUX", INT2NUM(VIR_FROM_STATS_LINUX));
    rb_define_const(e_Error, "FROM_LXC", INT2NUM(VIR_FROM_LXC));
    rb_define_const(e_Error, "FROM_STORAGE", INT2NUM(VIR_FROM_STORAGE));
    rb_define_const(e_Error, "FROM_NETWORK", INT2NUM(VIR_FROM_NETWORK));
    rb_define_const(e_Error, "FROM_DOMAIN", INT2NUM(VIR_FROM_DOMAIN));
    rb_define_const(e_Error, "FROM_UML", INT2NUM(VIR_FROM_UML));
    rb_define_const(e_Error, "FROM_NODEDEV", INT2NUM(VIR_FROM_NODEDEV));
    rb_define_const(e_Error, "FROM_XEN_INOTIFY", INT2NUM(VIR_FROM_XEN_INOTIFY));
    rb_define_const(e_Error, "FROM_SECURITY", INT2NUM(VIR_FROM_SECURITY));
    rb_define_const(e_Error, "FROM_VBOX", INT2NUM(VIR_FROM_VBOX));
    rb_define_const(e_Error, "FROM_INTERFACE", INT2NUM(VIR_FROM_INTERFACE));
    rb_define_const(e_Error, "FROM_ONE", INT2NUM(VIR_FROM_ONE));
    rb_define_const(e_Error, "FROM_ESX", INT2NUM(VIR_FROM_ESX));
    rb_define_const(e_Error, "FROM_PHYP", INT2NUM(VIR_FROM_PHYP));
    rb_define_const(e_Error, "FROM_SECRET", INT2NUM(VIR_FROM_SECRET));
    rb_define_const(e_Error, "FROM_CPU", INT2NUM(VIR_FROM_CPU));
    rb_define_const(e_Error, "FROM_XENAPI", INT2NUM(VIR_FROM_XENAPI));
    rb_define_const(e_Error, "FROM_NWFILTER", INT2NUM(VIR_FROM_NWFILTER));
    rb_define_const(e_Error, "FROM_HOOK", INT2NUM(VIR_FROM_HOOK));
    rb_define_const(e_Error, "FROM_DOMAIN_SNAPSHOT",
                    INT2NUM(VIR_FROM_DOMAIN_SNAPSHOT));
    rb_define_const(e_Error, "FROM_AUDIT", INT2NUM(VIR_FROM_AUDIT));
    rb_define_const(e_Error, "FROM_SYSINFO", INT2NUM(VIR_FROM_SYSINFO));
    rb_define_const(e_Error, "FROM_STREAMS", INT2NUM(VIR_FROM_STREAMS));

    /* libvirt error codes */
    rb_define_const(e_Error, "ERR_OK", INT2NUM(VIR_ERR_OK));
    rb_define_const(e_Error, "ERR_INTERNAL_ERROR",
                    INT2NUM(VIR_ERR_INTERNAL_ERROR));
    rb_define_const(e_Error, "ERR_NO_MEMORY", INT2NUM(VIR_ERR_NO_MEMORY));
    rb_define_const(e_Error, "ERR_NO_SUPPORT", INT2NUM(VIR_ERR_NO_SUPPORT));
    rb_define_const(e_Error, "ERR_UNKNOWN_HOST", INT2NUM(VIR_ERR_UNKNOWN_HOST));
    rb_define_const(e_Error, "ERR_NO_CONNECT", INT2NUM(VIR_ERR_NO_CONNECT));
    rb_define_const(e_Error, "ERR_INVALID_CONN", INT2NUM(VIR_ERR_INVALID_CONN));
    rb_define_const(e_Error, "ERR_INVALID_DOMAIN",
                    INT2NUM(VIR_ERR_INVALID_DOMAIN));
    rb_define_const(e_Error, "ERR_INVALID_ARG", INT2NUM(VIR_ERR_INVALID_ARG));
    rb_define_const(e_Error, "ERR_OPERATION_FAILED",
                    INT2NUM(VIR_ERR_OPERATION_FAILED));
    rb_define_const(e_Error, "ERR_GET_FAILED", INT2NUM(VIR_ERR_GET_FAILED));
    rb_define_const(e_Error, "ERR_POST_FAILED", INT2NUM(VIR_ERR_POST_FAILED));
    rb_define_const(e_Error, "ERR_HTTP_ERROR", INT2NUM(VIR_ERR_HTTP_ERROR));
    rb_define_const(e_Error, "ERR_SEXPR_SERIAL", INT2NUM(VIR_ERR_SEXPR_SERIAL));
    rb_define_const(e_Error, "ERR_NO_XEN", INT2NUM(VIR_ERR_NO_XEN));
    rb_define_const(e_Error, "ERR_XEN_CALL", INT2NUM(VIR_ERR_XEN_CALL));
    rb_define_const(e_Error, "ERR_OS_TYPE", INT2NUM(VIR_ERR_OS_TYPE));
    rb_define_const(e_Error, "ERR_NO_KERNEL", INT2NUM(VIR_ERR_NO_KERNEL));
    rb_define_const(e_Error, "ERR_NO_ROOT", INT2NUM(VIR_ERR_NO_ROOT));
    rb_define_const(e_Error, "ERR_NO_SOURCE", INT2NUM(VIR_ERR_NO_SOURCE));
    rb_define_const(e_Error, "ERR_NO_TARGET", INT2NUM(VIR_ERR_NO_TARGET));
    rb_define_const(e_Error, "ERR_NO_NAME", INT2NUM(VIR_ERR_NO_NAME));
    rb_define_const(e_Error, "ERR_NO_OS", INT2NUM(VIR_ERR_NO_OS));
    rb_define_const(e_Error, "ERR_NO_DEVICE", INT2NUM(VIR_ERR_NO_DEVICE));
    rb_define_const(e_Error, "ERR_NO_XENSTORE", INT2NUM(VIR_ERR_NO_XENSTORE));
    rb_define_const(e_Error, "ERR_DRIVER_FULL", INT2NUM(VIR_ERR_DRIVER_FULL));
    rb_define_const(e_Error, "ERR_CALL_FAILED", INT2NUM(VIR_ERR_CALL_FAILED));
    rb_define_const(e_Error, "ERR_XML_ERROR", INT2NUM(VIR_ERR_XML_ERROR));
    rb_define_const(e_Error, "ERR_DOM_EXIST", INT2NUM(VIR_ERR_DOM_EXIST));
    rb_define_const(e_Error, "ERR_OPERATION_DENIED",
                    INT2NUM(VIR_ERR_OPERATION_DENIED));
    rb_define_const(e_Error, "ERR_OPEN_FAILED", INT2NUM(VIR_ERR_OPEN_FAILED));
    rb_define_const(e_Error, "ERR_READ_FAILED", INT2NUM(VIR_ERR_READ_FAILED));
    rb_define_const(e_Error, "ERR_PARSE_FAILED", INT2NUM(VIR_ERR_PARSE_FAILED));
    rb_define_const(e_Error, "ERR_CONF_SYNTAX", INT2NUM(VIR_ERR_CONF_SYNTAX));
    rb_define_const(e_Error, "ERR_WRITE_FAILED", INT2NUM(VIR_ERR_WRITE_FAILED));
    rb_define_const(e_Error, "ERR_XML_DETAIL", INT2NUM(VIR_ERR_XML_DETAIL));
    rb_define_const(e_Error, "ERR_INVALID_NETWORK",
                    INT2NUM(VIR_ERR_INVALID_NETWORK));
    rb_define_const(e_Error, "ERR_NETWORK_EXIST",
                    INT2NUM(VIR_ERR_NETWORK_EXIST));
    rb_define_const(e_Error, "ERR_SYSTEM_ERROR", INT2NUM(VIR_ERR_SYSTEM_ERROR));
    rb_define_const(e_Error, "ERR_RPC", INT2NUM(VIR_ERR_RPC));
    rb_define_const(e_Error, "ERR_GNUTLS_ERROR", INT2NUM(VIR_ERR_GNUTLS_ERROR));
    rb_define_const(e_Error, "WAR_NO_NETWORK", INT2NUM(VIR_WAR_NO_NETWORK));
    rb_define_const(e_Error, "ERR_NO_DOMAIN", INT2NUM(VIR_ERR_NO_DOMAIN));
    rb_define_const(e_Error, "ERR_NO_NETWORK", INT2NUM(VIR_ERR_NO_NETWORK));
    rb_define_const(e_Error, "ERR_INVALID_MAC", INT2NUM(VIR_ERR_INVALID_MAC));
    rb_define_const(e_Error, "ERR_AUTH_FAILED", INT2NUM(VIR_ERR_AUTH_FAILED));
    rb_define_const(e_Error, "ERR_INVALID_STORAGE_POOL",
                    INT2NUM(VIR_ERR_INVALID_STORAGE_POOL));
    rb_define_const(e_Error, "ERR_INVALID_STORAGE_VOL",
                    INT2NUM(VIR_ERR_INVALID_STORAGE_VOL));
    rb_define_const(e_Error, "WAR_NO_STORAGE", INT2NUM(VIR_WAR_NO_STORAGE));
    rb_define_const(e_Error, "ERR_NO_STORAGE_POOL",
                    INT2NUM(VIR_ERR_NO_STORAGE_POOL));
    rb_define_const(e_Error, "ERR_NO_STORAGE_VOL",
                    INT2NUM(VIR_ERR_NO_STORAGE_VOL));
    rb_define_const(e_Error, "WAR_NO_NODE", INT2NUM(VIR_WAR_NO_NODE));
    rb_define_const(e_Error, "ERR_INVALID_NODE_DEVICE",
                    INT2NUM(VIR_ERR_INVALID_NODE_DEVICE));
    rb_define_const(e_Error, "ERR_NO_NODE_DEVICE",
                    INT2NUM(VIR_ERR_NO_NODE_DEVICE));
    rb_define_const(e_Error, "ERR_NO_SECURITY_MODEL",
                    INT2NUM(VIR_ERR_NO_SECURITY_MODEL));
    rb_define_const(e_Error, "ERR_OPERATION_INVALID",
                    INT2NUM(VIR_ERR_OPERATION_INVALID));
    rb_define_const(e_Error, "WAR_NO_INTERFACE", INT2NUM(VIR_WAR_NO_INTERFACE));
    rb_define_const(e_Error, "ERR_NO_INTERFACE", INT2NUM(VIR_ERR_NO_INTERFACE));
    rb_define_const(e_Error, "ERR_INVALID_INTERFACE",
                    INT2NUM(VIR_ERR_INVALID_INTERFACE));
    rb_define_const(e_Error, "ERR_MULTIPLE_INTERFACES",
                    INT2NUM(VIR_ERR_MULTIPLE_INTERFACES));
    rb_define_const(e_Error, "WAR_NO_NWFILTER", INT2NUM(VIR_WAR_NO_NWFILTER));
    rb_define_const(e_Error, "ERR_INVALID_NWFILTER",
                    INT2NUM(VIR_ERR_INVALID_NWFILTER));
    rb_define_const(e_Error, "ERR_NO_NWFILTER", INT2NUM(VIR_ERR_NO_NWFILTER));
    rb_define_const(e_Error, "ERR_BUILD_FIREWALL",
                    INT2NUM(VIR_ERR_BUILD_FIREWALL));
    rb_define_const(e_Error, "WAR_NO_SECRET", INT2NUM(VIR_WAR_NO_SECRET));
    rb_define_const(e_Error, "ERR_INVALID_SECRET",
                    INT2NUM(VIR_ERR_INVALID_SECRET));
    rb_define_const(e_Error, "ERR_NO_SECRET", INT2NUM(VIR_ERR_NO_SECRET));
    rb_define_const(e_Error, "ERR_CONFIG_UNSUPPORTED",
                    INT2NUM(VIR_ERR_CONFIG_UNSUPPORTED));
    rb_define_const(e_Error, "ERR_OPERATION_TIMEOUT",
                    INT2NUM(VIR_ERR_OPERATION_TIMEOUT));
    rb_define_const(e_Error, "ERR_MIGRATE_PERSIST_FAILED",
                    INT2NUM(VIR_ERR_MIGRATE_PERSIST_FAILED));
    rb_define_const(e_Error, "ERR_HOOK_SCRIPT_FAILED",
                    INT2NUM(VIR_ERR_HOOK_SCRIPT_FAILED));
    rb_define_const(e_Error, "ERR_INVALID_DOMAIN_SNAPSHOT",
                    INT2NUM(VIR_ERR_INVALID_DOMAIN_SNAPSHOT));
    rb_define_const(e_Error, "ERR_NO_DOMAIN_SNAPSHOT",
                    INT2NUM(VIR_ERR_NO_DOMAIN_SNAPSHOT));

    /* libvirt levels */
    rb_define_const(e_Error, "LEVEL_NONE", INT2NUM(VIR_ERR_NONE));
    rb_define_const(e_Error, "LEVEL_WARNING", INT2NUM(VIR_ERR_WARNING));
    rb_define_const(e_Error, "LEVEL_ERROR", INT2NUM(VIR_ERR_ERROR));

    rb_define_module_function(m_libvirt, "version", libvirt_version, -1);
    rb_define_module_function(m_libvirt, "open", libvirt_open, -1);
    rb_define_module_function(m_libvirt, "open_read_only",
                              libvirt_open_read_only, -1);
    rb_define_module_function(m_libvirt, "open_auth", libvirt_open_auth, -1);

    rb_define_const(m_libvirt, "EVENT_HANDLE_READABLE",
                    INT2NUM(VIR_EVENT_HANDLE_READABLE));
    rb_define_const(m_libvirt, "EVENT_HANDLE_WRITABLE",
                    INT2NUM(VIR_EVENT_HANDLE_WRITABLE));
    rb_define_const(m_libvirt, "EVENT_HANDLE_ERROR",
                    INT2NUM(VIR_EVENT_HANDLE_ERROR));
    rb_define_const(m_libvirt, "EVENT_HANDLE_HANGUP",
                    INT2NUM(VIR_EVENT_HANDLE_HANGUP));

    /* since we are using globals, we have to register with the gc */
    rb_global_variable(&add_handle);
    rb_global_variable(&update_handle);
    rb_global_variable(&remove_handle);
    rb_global_variable(&add_timeout);
    rb_global_variable(&update_timeout);
    rb_global_variable(&remove_timeout);

    rb_define_module_function(m_libvirt, "event_register_impl",
                              libvirt_conn_event_register_impl, -1);
    rb_define_module_function(m_libvirt, "event_invoke_handle_callback",
                              libvirt_event_invoke_handle_callback, 4);
    rb_define_module_function(m_libvirt, "event_invoke_timeout_callback",
                              libvirt_event_invoke_timeout_callback, 2);

    rb_define_method(m_libvirt, "lxc_enter_security_label",
                     libvirt_domain_lxc_enter_security_label, -1);

    ruby_libvirt_connect_init();
    ruby_libvirt_storage_init();
    ruby_libvirt_network_init();
    ruby_libvirt_nodedevice_init();
    ruby_libvirt_secret_init();
    ruby_libvirt_nwfilter_init();
    ruby_libvirt_interface_init();
    ruby_libvirt_domain_init();
    ruby_libvirt_stream_init();

    virSetErrorFunc(NULL, rubyLibvirtErrorFunc);

    if (virInitialize() < 0) {
        rb_raise(rb_eSystemCallError, "virInitialize failed");
    }
}
