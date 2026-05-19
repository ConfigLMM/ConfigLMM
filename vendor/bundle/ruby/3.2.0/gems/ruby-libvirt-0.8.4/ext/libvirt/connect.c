/*
 * connect.c: virConnect methods
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
#include <libvirt/libvirt-qemu.h>
#include <libvirt/virterror.h>
#include "extconf.h"
#include "common.h"
#include "domain.h"
#include "network.h"
#include "interface.h"
#include "nodedevice.h"
#include "nwfilter.h"
#include "secret.h"
#include "stream.h"

/*
 * Generate a call to a virConnectNumOf... function. C is the Ruby VALUE
 * holding the connection and OBJS is a token indicating what objects to
 * get the number of, e.g. 'Domains'
 */
#define gen_conn_num_of(c, objs)                                        \
    do {                                                                \
        int r;                                                          \
        r = virConnectNumOf##objs(ruby_libvirt_connect_get(c));         \
        ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virConnectNumOf" # objs, ruby_libvirt_connect_get(c)); \
        return INT2NUM(r);                                              \
    } while(0)

/*
 * Generate a call to a virConnectList... function. C is the Ruby VALUE
 * holding the connection and OBJS is a token indicating what objects to
 * get the number of, e.g. 'Domains' The list function must return an array
 * of strings, which is returned as a Ruby array
 */
#define gen_conn_list_names(c, objs)                                    \
    do {                                                                \
        int r, num;                                                     \
        char **names;                                                   \
        num = virConnectNumOf##objs(ruby_libvirt_connect_get(c));       \
        ruby_libvirt_raise_error_if(num < 0, e_RetrieveError, "virConnectNumOf" # objs, ruby_libvirt_connect_get(c)); \
        if (num == 0) {                                                 \
            /* if num is 0, don't call virConnectList* function */      \
            return rb_ary_new2(num);                                    \
        }                                                               \
        names = alloca(sizeof(char *) * num);                           \
        r = virConnectList##objs(ruby_libvirt_connect_get(c), names, num); \
        ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virConnectList" # objs, ruby_libvirt_connect_get(c)); \
        return ruby_libvirt_generate_list(r, names);                    \
    } while(0)

static VALUE c_connect;
VALUE c_node_security_model;
static VALUE c_node_info;

static void connect_close(void *c)
{
    int r;

    if (!c) {
        return;
    }
    r = virConnectClose((virConnectPtr) c);
    ruby_libvirt_raise_error_if(r < 0, rb_eSystemCallError, "virConnectClose",
                                c);
}

VALUE ruby_libvirt_connect_new(virConnectPtr c)
{
    return Data_Wrap_Struct(c_connect, NULL, connect_close, c);
}

VALUE ruby_libvirt_conn_attr(VALUE c)
{
    if (rb_obj_is_instance_of(c, c_connect) != Qtrue) {
        c = rb_iv_get(c, "@connection");
    }
    if (rb_obj_is_instance_of(c, c_connect) != Qtrue) {
        rb_raise(rb_eArgError, "Expected Connection object");
    }
    return c;
}

virConnectPtr ruby_libvirt_connect_get(VALUE c)
{
    c = ruby_libvirt_conn_attr(c);
    ruby_libvirt_get_struct(Connect, c);
}

/*
 * call-seq:
 *   conn.close -> nil
 *
 * Call virConnectClose[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectClose]
 * to close the connection.
 */
static VALUE libvirt_connect_close(VALUE c)
{
    virConnectPtr conn;

    Data_Get_Struct(c, virConnect, conn);
    if (conn) {
        connect_close(conn);
        DATA_PTR(c) = NULL;
    }
    return Qnil;
}

/*
 * call-seq:
 *   conn.closed? -> [True|False]
 *
 * Return +true+ if the connection is closed, +false+ if it is open.
 */
static VALUE libvirt_connect_closed_p(VALUE c)
{
    virConnectPtr conn;

    Data_Get_Struct(c, virConnect, conn);
    return (conn == NULL) ? Qtrue : Qfalse;
}

/*
 * call-seq:
 *   conn.type -> String
 *
 * Call virConnectGetType[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetType]
 * to retrieve the type of hypervisor for this connection.
 */
static VALUE libvirt_connect_type(VALUE c)
{
    ruby_libvirt_generate_call_string(virConnectGetType,
                                      ruby_libvirt_connect_get(c), 0,
                                      ruby_libvirt_connect_get(c));
}

/*
 * call-seq:
 *   conn.version -> Fixnum
 *
 * Call virConnectGetVersion[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetVersion]
 * to retrieve the version of the hypervisor for this connection.
 */
static VALUE libvirt_connect_version(VALUE c)
{
    int r;
    unsigned long v;

    r = virConnectGetVersion(ruby_libvirt_connect_get(c), &v);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virConnectGetVersion",
                                ruby_libvirt_connect_get(c));

    return ULONG2NUM(v);
}

/*
 * call-seq:
 *   conn.libversion -> Fixnum
 *
 * Call virConnectGetLibVersion[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetLibVersion]
 * to retrieve the version of the libvirt library for this connection.
 */
static VALUE libvirt_connect_libversion(VALUE c)
{
    int r;
    unsigned long v;

    r = virConnectGetLibVersion(ruby_libvirt_connect_get(c), &v);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virConnectGetLibVersion",
                                ruby_libvirt_connect_get(c));

    return ULONG2NUM(v);
}

/*
 * call-seq:
 *   conn.hostname -> String
 *
 * Call virConnectGetHostname[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetHostname]
 * to retrieve the hostname of the hypervisor for this connection.
 */
static VALUE libvirt_connect_hostname(VALUE c)
{
    ruby_libvirt_generate_call_string(virConnectGetHostname,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c));
}

/*
 * call-seq:
 *   conn.uri -> String
 *
 * Call virConnectGetURI[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetURI]
 * to retrieve the canonical URI for this connection.
 */
static VALUE libvirt_connect_uri(VALUE c)
{
    ruby_libvirt_generate_call_string(virConnectGetURI,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c));
}

/*
 * call-seq:
 *   conn.max_vcpus(type=nil) -> Fixnum
 *
 * Call virConnectGetMaxVcpus[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetMaxVcpus]
 * to retrieve the maximum number of virtual cpus supported by the hypervisor
 * for this connection.
 */
static VALUE libvirt_connect_max_vcpus(int argc, VALUE *argv, VALUE c)
{
    VALUE type;

    rb_scan_args(argc, argv, "01", &type);

    ruby_libvirt_generate_call_int(virConnectGetMaxVcpus,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_get_cstring_or_null(type));
}

/*
 * call-seq:
 *   conn.node_info -> Libvirt::Connect::Nodeinfo
 *
 * Call virNodeGetInfo[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetInfo]
 * to retrieve information about the node for this connection.
 */
static VALUE libvirt_connect_node_info(VALUE c)
{
    int r;
    virNodeInfo nodeinfo;
    VALUE result;

    r = virNodeGetInfo(ruby_libvirt_connect_get(c), &nodeinfo);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virNodeGetInfo",
                                ruby_libvirt_connect_get(c));

    result = rb_class_new_instance(0, NULL, c_node_info);
    rb_iv_set(result, "@model", rb_str_new2(nodeinfo.model));
    rb_iv_set(result, "@memory", ULONG2NUM(nodeinfo.memory));
    rb_iv_set(result, "@cpus", UINT2NUM(nodeinfo.cpus));
    rb_iv_set(result, "@mhz", UINT2NUM(nodeinfo.mhz));
    rb_iv_set(result, "@nodes", UINT2NUM(nodeinfo.nodes));
    rb_iv_set(result, "@sockets", UINT2NUM(nodeinfo.sockets));
    rb_iv_set(result, "@cores", UINT2NUM(nodeinfo.cores));
    rb_iv_set(result, "@threads", UINT2NUM(nodeinfo.threads));

    return result;
}

/*
 * call-seq:
 *   conn.node_free_memory -> Fixnum
 *
 * Call virNodeGetFreeMemory[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetFreeMemory]
 * to retrieve the amount of free memory available on the host for this
 * connection.
 */
static VALUE libvirt_connect_node_free_memory(VALUE c)
{
    unsigned long long freemem;

    freemem = virNodeGetFreeMemory(ruby_libvirt_connect_get(c));

    ruby_libvirt_raise_error_if(freemem == 0, e_RetrieveError,
                                "virNodeGetFreeMemory",
                                ruby_libvirt_connect_get(c));

    return ULL2NUM(freemem);
}

/*
 * call-seq:
 *   conn.node_cells_free_memory(startCell=0, maxCells=#nodeCells) -> list
 *
 * Call virNodeGetCellsFreeMemory[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetCellsFreeMemory]
 * to retrieve the amount of free memory in each NUMA cell on the host for
 * this connection.
 */
static VALUE libvirt_connect_node_cells_free_memory(int argc, VALUE *argv,
                                                    VALUE c)
{
    int i, r;
    VALUE cells, start, max;
    unsigned long long *freeMems;
    virNodeInfo nodeinfo;
    unsigned int startCell, maxCells;

    rb_scan_args(argc, argv, "02", &start, &max);

    if (NIL_P(start)) {
        startCell = 0;
    }
    else {
        startCell = NUM2UINT(start);
    }

    if (NIL_P(max)) {
        r = virNodeGetInfo(ruby_libvirt_connect_get(c), &nodeinfo);
        ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virNodeGetInfo",
                                    ruby_libvirt_connect_get(c));
        maxCells = nodeinfo.nodes;
    }
    else {
        maxCells = NUM2UINT(max);
    }

    freeMems = alloca(sizeof(unsigned long long) * maxCells);

    r = virNodeGetCellsFreeMemory(ruby_libvirt_connect_get(c), freeMems,
                                  startCell, maxCells);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virNodeGetCellsFreeMemory",
                                ruby_libvirt_connect_get(c));

    cells = rb_ary_new2(r);
    for (i = 0; i < r; i++) {
        rb_ary_store(cells, i, ULL2NUM(freeMems[i]));
    }

    return cells;
}

/*
 * call-seq:
 *   conn.node_security_model -> Libvirt::Connect::NodeSecurityModel
 *
 * Call virNodeGetSecurityModel[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetSecurityModel]
 * to retrieve the security model in use on the host for this connection.
 */
static VALUE libvirt_connect_node_security_model(VALUE c)
{
    virSecurityModel secmodel;
    int r;
    VALUE result;

    r = virNodeGetSecurityModel(ruby_libvirt_connect_get(c), &secmodel);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virNodeGetSecurityModel",
                                ruby_libvirt_connect_get(c));

    result = rb_class_new_instance(0, NULL, c_node_security_model);
    rb_iv_set(result, "@model", rb_str_new2(secmodel.model));
    rb_iv_set(result, "@doi", rb_str_new2(secmodel.doi));

    return result;
}

/*
 * call-seq:
 *   conn.encrypted? -> [True|False]
 *
 * Call virConnectIsEncrypted[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectIsEncrypted]
 * to determine if the connection is encrypted.
 */
static VALUE libvirt_connect_encrypted_p(VALUE c)
{
    ruby_libvirt_generate_call_truefalse(virConnectIsEncrypted,
                                         ruby_libvirt_connect_get(c),
                                         ruby_libvirt_connect_get(c));
}

/*
 * call-seq:
 *   conn.secure? -> [True|False]
 *
 * Call virConnectIsSecure[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectIsSecure]
 * to determine if the connection is secure.
 */
static VALUE libvirt_connect_secure_p(VALUE c)
{
    ruby_libvirt_generate_call_truefalse(virConnectIsSecure,
                                         ruby_libvirt_connect_get(c),
                                         ruby_libvirt_connect_get(c));
}

/*
 * call-seq:
 *   conn.capabilities -> String
 *
 * Call virConnectGetCapabilities[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetCapabilities]
 * to retrieve the capabilities XML for this connection.
 */
static VALUE libvirt_connect_capabilities(VALUE c)
{
    ruby_libvirt_generate_call_string(virConnectGetCapabilities,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c));
}

/*
 * call-seq:
 *   conn.compare_cpu(xml, flags=0) -> compareflag
 *
 * Call virConnectCompareCPU[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectCompareCPU]
 * to compare the host CPU with the XML contained in xml.  Returns one of
 * Libvirt::CPU_COMPARE_ERROR, Libvirt::CPU_COMPARE_INCOMPATIBLE,
 * Libvirt::CPU_COMPARE_IDENTICAL, or Libvirt::CPU_COMPARE_SUPERSET.
 */
static VALUE libvirt_connect_compare_cpu(int argc, VALUE *argv, VALUE c)
{
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    ruby_libvirt_generate_call_int(virConnectCompareCPU,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   StringValueCStr(xml),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.baseline_cpu([xml, xml2, ...], flags=0) -> XML
 *
 * Call virConnectBaselineCPU[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectBaselineCPU]
 * to compare the most feature-rich CPU which is compatible with all
 * given host CPUs.
 */
static VALUE libvirt_connect_baseline_cpu(int argc, VALUE *argv, VALUE c)
{
    VALUE xmlcpus, flags, retval, entry;
    char *r;
    unsigned int ncpus;
    const char **xmllist;
    int exception = 0;
    unsigned int i;

    rb_scan_args(argc, argv, "11", &xmlcpus, &flags);

    Check_Type(xmlcpus, T_ARRAY);

    if (RARRAY_LEN(xmlcpus) < 1) {
        rb_raise(rb_eArgError,
                 "wrong number of cpu arguments (%ld for 1 or more)",
                 RARRAY_LEN(xmlcpus));
    }

    ncpus = RARRAY_LEN(xmlcpus);
    xmllist = alloca(sizeof(const char *) * ncpus);

    for (i = 0; i < ncpus; i++) {
        entry = rb_ary_entry(xmlcpus, i);
        xmllist[i] = StringValueCStr(entry);
    }

    r = virConnectBaselineCPU(ruby_libvirt_connect_get(c), xmllist, ncpus,
                              ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r == NULL, e_RetrieveError,
                                "virConnectBaselineCPU",
                                ruby_libvirt_connect_get(c));

    retval = rb_protect(ruby_libvirt_str_new2_wrap, (VALUE)&r, &exception);
    free(r);
    if (exception) {
        rb_jump_tag(exception);
    }

    return retval;
}

static int domain_event_lifecycle_callback(virConnectPtr conn,
                                           virDomainPtr dom, int event,
                                           int detail, void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, newc;

    Check_Type(passthrough, T_ARRAY);

    if (RARRAY_LEN(passthrough) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);

    newc = ruby_libvirt_connect_new(conn);
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 5, newc,
                   ruby_libvirt_domain_new(dom, newc), INT2NUM(event),
                   INT2NUM(detail), cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 5, newc,
                   ruby_libvirt_domain_new(dom, newc), INT2NUM(event),
                   INT2NUM(detail), cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong domain event lifecycle callback (expected Symbol or Proc)");
    }

    return 0;
}

static int domain_event_reboot_callback(virConnectPtr conn, virDomainPtr dom,
                                        void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, newc;

    Check_Type(passthrough, T_ARRAY);

    if (RARRAY_LEN(passthrough) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);

    newc = ruby_libvirt_connect_new(conn);
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 3, newc,
                   ruby_libvirt_domain_new(dom, newc), cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 3, newc,
                   ruby_libvirt_domain_new(dom, newc), cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong domain event reboot callback (expected Symbol or Proc)");
    }

    return 0;
}

static int domain_event_rtc_callback(virConnectPtr conn, virDomainPtr dom,
                                     long long utc_offset, void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, newc;

    Check_Type(passthrough, T_ARRAY);

    if (RARRAY_LEN(passthrough) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);

    newc = ruby_libvirt_connect_new(conn);
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 4, newc,
                   ruby_libvirt_domain_new(dom, newc), LL2NUM(utc_offset),
                   cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 4, newc,
                   ruby_libvirt_domain_new(dom, newc), LL2NUM(utc_offset),
                   cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong domain event rtc callback (expected Symbol or Proc)");
    }

    return 0;
}

static int domain_event_watchdog_callback(virConnectPtr conn, virDomainPtr dom,
                                          int action, void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, newc;

    Check_Type(passthrough, T_ARRAY);

    if (RARRAY_LEN(passthrough) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);

    newc = ruby_libvirt_connect_new(conn);
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 4, newc,
                   ruby_libvirt_domain_new(dom, newc), INT2NUM(action),
                   cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 4, newc,
                   ruby_libvirt_domain_new(dom, newc), INT2NUM(action),
                   cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong domain event watchdog callback (expected Symbol or Proc)");
    }

    return 0;
}

static int domain_event_io_error_callback(virConnectPtr conn, virDomainPtr dom,
                                          const char *src_path,
                                          const char *dev_alias,
                                          int action,
                                          void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, newc;

    Check_Type(passthrough, T_ARRAY);

    if (RARRAY_LEN(passthrough) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);

    newc = ruby_libvirt_connect_new(conn);
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 6, newc,
                   ruby_libvirt_domain_new(dom, newc), rb_str_new2(src_path),
                   rb_str_new2(dev_alias), INT2NUM(action), cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 6, newc,
                   ruby_libvirt_domain_new(dom, newc),
                   rb_str_new2(src_path), rb_str_new2(dev_alias),
                   INT2NUM(action), cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong domain event IO error callback (expected Symbol or Proc)");
    }

    return 0;
}

static int domain_event_io_error_reason_callback(virConnectPtr conn,
                                                 virDomainPtr dom,
                                                 const char *src_path,
                                                 const char *dev_alias,
                                                 int action,
                                                 const char *reason,
                                                 void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, newc;

    Check_Type(passthrough, T_ARRAY);

    if (RARRAY_LEN(passthrough) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);

    newc = ruby_libvirt_connect_new(conn);
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 7, newc,
                   ruby_libvirt_domain_new(dom, newc), rb_str_new2(src_path),
                   rb_str_new2(dev_alias), INT2NUM(action),
                   rb_str_new2(reason), cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 7, newc,
                   ruby_libvirt_domain_new(dom, newc),
                   rb_str_new2(src_path), rb_str_new2(dev_alias),
                   INT2NUM(action), rb_str_new2(reason), cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong domain event IO error reason callback (expected Symbol or Proc)");
    }

    return 0;
}

static int domain_event_graphics_callback(virConnectPtr conn, virDomainPtr dom,
                                          int phase,
                                          virDomainEventGraphicsAddressPtr local,
                                          virDomainEventGraphicsAddressPtr remote,
                                          const char *authScheme,
                                          virDomainEventGraphicsSubjectPtr subject,
                                          void *opaque)
{
    VALUE passthrough = (VALUE)opaque;
    VALUE cb, cb_opaque, newc, local_hash, remote_hash, subject_array, pair;
    int i;

    Check_Type(passthrough, T_ARRAY);

    if (RARRAY_LEN(passthrough) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(passthrough));
    }

    cb = rb_ary_entry(passthrough, 0);
    cb_opaque = rb_ary_entry(passthrough, 1);

    local_hash = rb_hash_new();
    rb_hash_aset(local_hash, rb_str_new2("family"), INT2NUM(local->family));
    rb_hash_aset(local_hash, rb_str_new2("node"), rb_str_new2(local->node));
    rb_hash_aset(local_hash, rb_str_new2("service"),
                 rb_str_new2(local->service));

    remote_hash = rb_hash_new();
    rb_hash_aset(remote_hash, rb_str_new2("family"), INT2NUM(remote->family));
    rb_hash_aset(remote_hash, rb_str_new2("node"), rb_str_new2(remote->node));
    rb_hash_aset(remote_hash, rb_str_new2("service"),
                 rb_str_new2(remote->service));

    subject_array = rb_ary_new();
    for (i = 0; i < subject->nidentity; i++) {
        pair = rb_ary_new();
        rb_ary_store(pair, 0, rb_str_new2(subject->identities[i].type));
        rb_ary_store(pair, 1, rb_str_new2(subject->identities[i].name));

        rb_ary_store(subject_array, i, pair);
    }

    newc = ruby_libvirt_connect_new(conn);
    if (strcmp(rb_obj_classname(cb), "Symbol") == 0) {
        rb_funcall(rb_class_of(cb), rb_to_id(cb), 8, newc,
                   ruby_libvirt_domain_new(dom, newc), INT2NUM(phase),
                   local_hash, remote_hash, rb_str_new2(authScheme),
                   subject_array, cb_opaque);
    }
    else if (strcmp(rb_obj_classname(cb), "Proc") == 0) {
        rb_funcall(cb, rb_intern("call"), 8, newc,
                   ruby_libvirt_domain_new(dom, newc), INT2NUM(phase),
                   local_hash, remote_hash, rb_str_new2(authScheme),
                   subject_array, cb_opaque);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong domain event graphics callback (expected Symbol or Proc)");
    }

    return 0;
}

/*
 * call-seq:
 *   conn.domain_event_register_any(eventID, callback, dom=nil, opaque=nil) -> Fixnum
 *
 * Call virConnectDomainEventRegisterAny[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectDomainEventRegisterAny]
 * to register callback for eventID with libvirt.  The eventID must be one of
 * the Libvirt::Connect::DOMAIN_EVENT_ID_* constants.  The callback can either
 * be a Symbol (that is the name of a method to callback) or a Proc.  Note that
 * the callback must accept different numbers of arguments depending on the
 * eventID passed in.  The arguments are as follows:
 *
 * - DOMAIN_EVENT_ID_LIFECYCLE: Libvirt::Connect, Libvirt::Domain, event, detail, opaque
 * - DOMAIN_EVENT_ID_REBOOT: Libvirt::Connect, Libvirt::Domain, opaque
 * - DOMAIN_EVENT_ID_RTC_CHANGE: Libvirt::Connect, Libvirt::Domain, utc_offset, opaque
 * - DOMAIN_EVENT_ID_WATCHDOG: Libvirt::Connect, Libvirt::Domain, action, opaque
 * - DOMAIN_EVENT_ID_IO_ERROR: Libvirt::Connect, Libvirt::Domain, src_path, dev_alias, action, opaque
 * - DOMAIN_EVENT_ID_IO_ERROR_REASON: Libvirt::Connect, Libvirt::Domain, src_path, dev_alias, action, reason, opaque
 * - DOMAIN_EVENT_ID_GRAPHICS: Libvirt::Connect, Libvirt::Domain, phase, local, remote, auth_scheme, subject, opaque

 * If dom is a valid Libvirt::Domain object, then only events from that
 * domain will be seen.  The opaque parameter can be any valid ruby type, and
 * will be passed into callback as "opaque".  This method returns a
 * libvirt-specific handle, which must be used by the application to
 * deregister the callback later (see domain_event_deregister_any).
 */
static VALUE libvirt_connect_domain_event_register_any(int argc, VALUE *argv,
                                                       VALUE c)
{
    VALUE eventID, cb, dom, opaque, passthrough;
    virDomainPtr domain;
    virConnectDomainEventGenericCallback internalcb = NULL;

    rb_scan_args(argc, argv, "22", &eventID, &cb, &dom, &opaque);

    if (!ruby_libvirt_is_symbol_or_proc(cb)) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Symbol or Proc)");
    }

    if (NIL_P(dom)) {
        domain = NULL;
    }
    else {
        domain = ruby_libvirt_domain_get(dom);
    }

    switch(NUM2INT(eventID)) {
    case VIR_DOMAIN_EVENT_ID_LIFECYCLE:
        internalcb = VIR_DOMAIN_EVENT_CALLBACK(domain_event_lifecycle_callback);
        break;
    case VIR_DOMAIN_EVENT_ID_REBOOT:
        internalcb = VIR_DOMAIN_EVENT_CALLBACK(domain_event_reboot_callback);
        break;
    case VIR_DOMAIN_EVENT_ID_RTC_CHANGE:
        internalcb = VIR_DOMAIN_EVENT_CALLBACK(domain_event_rtc_callback);
        break;
    case VIR_DOMAIN_EVENT_ID_WATCHDOG:
        internalcb = VIR_DOMAIN_EVENT_CALLBACK(domain_event_watchdog_callback);
        break;
    case VIR_DOMAIN_EVENT_ID_IO_ERROR:
        internalcb = VIR_DOMAIN_EVENT_CALLBACK(domain_event_io_error_callback);
        break;
    case VIR_DOMAIN_EVENT_ID_IO_ERROR_REASON:
        internalcb = VIR_DOMAIN_EVENT_CALLBACK(domain_event_io_error_reason_callback);
        break;
    case VIR_DOMAIN_EVENT_ID_GRAPHICS:
        internalcb = VIR_DOMAIN_EVENT_CALLBACK(domain_event_graphics_callback);
        break;
    default:
        rb_raise(rb_eArgError, "invalid eventID argument %d",
                 NUM2INT(eventID));
        break;
    }

    passthrough = rb_ary_new();
    rb_ary_store(passthrough, 0, cb);
    rb_ary_store(passthrough, 1, opaque);

    ruby_libvirt_generate_call_int(virConnectDomainEventRegisterAny,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c), domain,
                                   NUM2INT(eventID), internalcb,
                                   (void *)passthrough, NULL);
}

/*
 * call-seq:
 *   conn.domain_event_deregister_any(callbackID) -> nil
 *
 * Call virConnectDomainEventDeregisterAny[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectDomainEventDeregisterAny]
 * to deregister a callback from libvirt.  The callbackID must be a
 * libvirt-specific handle returned by domain_event_register_any.
 */
static VALUE libvirt_connect_domain_event_deregister_any(VALUE c,
                                                         VALUE callbackID)
{
    ruby_libvirt_generate_call_nil(virConnectDomainEventDeregisterAny,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   NUM2INT(callbackID));
}

/*
 * this is a bit of silliness.  Because libvirt internals track the address
 * of the function pointer, trying to use domain_event_lifecycle_callback
 * for both register and register_any would mean that we could only register
 * one or the other for lifecycle callbacks.  Instead we do a simple wrapper
 * so that the addresses are different
 */
static int domain_event_callback(virConnectPtr conn,
                                 virDomainPtr dom, int event,
                                 int detail, void *opaque)
{
    return domain_event_lifecycle_callback(conn, dom, event, detail, opaque);
}
/*
 * call-seq:
 *   conn.domain_event_register(callback, opaque=nil) -> nil
 *
 * Call virConnectDomainEventRegister[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectDomainEventRegister]
 * to register callback for domain lifecycle events with libvirt.  The
 * callback can either be a Symbol (that is the name of a method to callback)
 * or a Proc.  The callback must accept 5 parameters: Libvirt::Connect,
 * Libvirt::Domain, event, detail, opaque.  The opaque parameter to
 * domain_event_register can be any valid ruby type, and will be passed into
 * callback as "opaque".  This method is deprecated in favor of
 * domain_event_register_any.
 */
static VALUE libvirt_connect_domain_event_register(int argc, VALUE *argv,
                                                   VALUE c)
{
    VALUE cb, opaque, passthrough;

    rb_scan_args(argc, argv, "11", &cb, &opaque);

    if (!ruby_libvirt_is_symbol_or_proc(cb)) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Symbol or Proc)");
    }

    passthrough = rb_ary_new();
    rb_ary_store(passthrough, 0, cb);
    rb_ary_store(passthrough, 1, opaque);

    ruby_libvirt_generate_call_nil(virConnectDomainEventRegister,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   domain_event_callback, (void *)passthrough,
                                   NULL);
}

/*
 * call-seq:
 *   conn.domain_event_deregister(callback) -> nil
 *
 * Call virConnectDomainEventDeregister[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectDomainEventDeregister]
 * to deregister the event callback from libvirt.  This method is deprecated
 * in favor of domain_event_deregister_any (though they cannot be mixed; if
 * the callback was registered with domain_event_register, it must be
 * deregistered with domain_event_deregister).
 */
static VALUE libvirt_connect_domain_event_deregister(VALUE c)
{
    ruby_libvirt_generate_call_nil(virConnectDomainEventDeregister,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   domain_event_callback);
}

/*
 * call-seq:
 *   conn.num_of_domains -> Fixnum
 *
 * Call virConnectNumOfDomains[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectNumOfDomains]
 * to retrieve the number of active domains on this connection.
 */
static VALUE libvirt_connect_num_of_domains(VALUE c)
{
    gen_conn_num_of(c, Domains);
}

/*
 * call-seq:
 *   conn.list_domains -> list
 *
 * Call virConnectListDomains[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectListDomains]
 * to retrieve a list of active domain IDs on this connection.
 */
static VALUE libvirt_connect_list_domains(VALUE c)
{
    int i, r, num, *ids;
    VALUE result;

    num = virConnectNumOfDomains(ruby_libvirt_connect_get(c));
    ruby_libvirt_raise_error_if(num < 0, e_RetrieveError,
                                "virConnectNumOfDomains",
                                ruby_libvirt_connect_get(c));

    result = rb_ary_new2(num);

    if (num == 0) {
        return result;
    }

    ids = alloca(sizeof(int) * num);
    r = virConnectListDomains(ruby_libvirt_connect_get(c), ids, num);
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError,
                                "virConnectListDomains",
                                ruby_libvirt_connect_get(c));

    for (i = 0; i < num; i++) {
        rb_ary_store(result, i, INT2NUM(ids[i]));
    }

    return result;
}

/*
 * call-seq:
 *   conn.num_of_defined_domains -> Fixnum
 *
 * Call virConnectNumOfDefinedDomains[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectNumOfDefinedDomains]
 * to retrieve the number of inactive domains on this connection.
 */
static VALUE libvirt_connect_num_of_defined_domains(VALUE c)
{
    gen_conn_num_of(c, DefinedDomains);
}

/*
 * call-seq:
 *   conn.list_defined_domains -> list
 *
 * Call virConnectListDefinedDomains[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectListDefinedDomains]
 * to retrieve a list of inactive domain names on this connection.
 */
static VALUE libvirt_connect_list_defined_domains(VALUE c)
{
    gen_conn_list_names(c, DefinedDomains);
}

/*
 * call-seq:
 *   conn.create_domain_linux(xml, flags=0) -> Libvirt::Domain
 *
 * Call virDomainCreateLinux[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCreateLinux]
 * to start a transient domain from the given XML.  Deprecated; use
 * conn.create_domain_xml instead.
 */
static VALUE libvirt_connect_create_linux(int argc, VALUE *argv, VALUE c)
{
    virDomainPtr dom;
    VALUE flags, xml;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    dom = virDomainCreateLinux(ruby_libvirt_connect_get(c),
                               StringValueCStr(xml),
                               ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(dom == NULL, e_Error, "virDomainCreateLinux",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.create_domain_xml(xml, flags=0) -> Libvirt::Domain
 *
 * Call virDomainCreateXML[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCreateXML]
 * to start a transient domain from the given XML.
 */
static VALUE libvirt_connect_create_domain_xml(int argc, VALUE *argv, VALUE c)
{
    virDomainPtr dom;
    VALUE flags, xml;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    dom = virDomainCreateXML(ruby_libvirt_connect_get(c), StringValueCStr(xml),
                             ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(dom == NULL, e_Error, "virDomainCreateXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.lookup_domain_by_name(name) -> Libvirt::Domain
 *
 * Call virDomainLookupByName[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainLookupByName]
 * to retrieve a domain object for name.
 */
static VALUE libvirt_connect_lookup_domain_by_name(VALUE c, VALUE name)
{
    virDomainPtr dom;

    dom = virDomainLookupByName(ruby_libvirt_connect_get(c),
                                StringValueCStr(name));
    ruby_libvirt_raise_error_if(dom == NULL, e_RetrieveError,
                                "virDomainLookupByName",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.lookup_domain_by_id(id) -> Libvirt::Domain
 *
 * Call virDomainLookupByID[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainLookupByID]
 * to retrieve a domain object for id.
 */
static VALUE libvirt_connect_lookup_domain_by_id(VALUE c, VALUE id)
{
    virDomainPtr dom;

    dom = virDomainLookupByID(ruby_libvirt_connect_get(c), NUM2INT(id));
    ruby_libvirt_raise_error_if(dom == NULL, e_RetrieveError,
                                "virDomainLookupByID",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.lookup_domain_by_uuid(uuid) -> Libvirt::Domain
 *
 * Call virDomainLookupByUUIDString[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainLookupByUUIDString]
 * to retrieve a domain object for uuid.
 */
static VALUE libvirt_connect_lookup_domain_by_uuid(VALUE c, VALUE uuid)
{
    virDomainPtr dom;

    dom = virDomainLookupByUUIDString(ruby_libvirt_connect_get(c),
                                      StringValueCStr(uuid));
    ruby_libvirt_raise_error_if(dom == NULL, e_RetrieveError,
                                "virDomainLookupByUUID",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.define_domain_xml(xml, flags=0) -> Libvirt::Domain
 *
 * Call virDomainDefineXML[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainDefineXML]
 * to define a permanent domain on this connection.
 */
static VALUE libvirt_connect_define_domain_xml(int argc, VALUE *argv, VALUE c)
{
    virDomainPtr dom;
    VALUE xml;
    VALUE flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    if (ruby_libvirt_value_to_uint(flags) != 0) {
        dom = virDomainDefineXMLFlags(ruby_libvirt_connect_get(c),
                                      StringValueCStr(xml),
                                      ruby_libvirt_value_to_uint(flags));
    } else {
        dom = virDomainDefineXML(ruby_libvirt_connect_get(c),
                                 StringValueCStr(xml));
    }

    ruby_libvirt_raise_error_if(dom == NULL, e_DefinitionError,
                                "virDomainDefineXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.domain_xml_from_native(nativeFormat, xml, flags=0) -> String
 *
 * Call virConnectDomainXMLFromNative[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectDomainXMLFromNative]
 * to convert a native hypervisor domain representation to libvirt XML.
 */
static VALUE libvirt_connect_domain_xml_from_native(int argc, VALUE *argv,
                                                    VALUE c)
{
    VALUE nativeFormat, xml, flags;

    rb_scan_args(argc, argv, "21", &nativeFormat, &xml, &flags);

    ruby_libvirt_generate_call_string(virConnectDomainXMLFromNative,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c),
                                      StringValueCStr(nativeFormat),
                                      StringValueCStr(xml),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.domain_xml_to_native(nativeFormat, xml, flags=0) -> String
 *
 * Call virConnectDomainXMLToNative[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectDomainXMLToNative]
 * to convert libvirt XML to a native domain hypervisor representation.
 */
static VALUE libvirt_connect_domain_xml_to_native(int argc, VALUE *argv,
                                                  VALUE c)
{
    VALUE nativeFormat, xml, flags;

    rb_scan_args(argc, argv, "21", &nativeFormat, &xml, &flags);

    ruby_libvirt_generate_call_string(virConnectDomainXMLToNative,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c),
                                      StringValueCStr(nativeFormat),
                                      StringValueCStr(xml),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.num_of_interfaces -> Fixnum
 *
 * Call virConnectNumOfInterfaces[https://libvirt.org/html/libvirt-libvirt-interface.html#virConnectNumOfInterfaces]
 * to retrieve the number of active interfaces on this connection.
 */
static VALUE libvirt_connect_num_of_interfaces(VALUE c)
{
    gen_conn_num_of(c, Interfaces);
}

/*
 * call-seq:
 *   conn.list_interfaces -> list
 *
 * Call virConnectListInterfaces[https://libvirt.org/html/libvirt-libvirt-interface.html#virConnectListInterfaces]
 * to retrieve a list of active interface names on this connection.
 */
static VALUE libvirt_connect_list_interfaces(VALUE c)
{
    gen_conn_list_names(c, Interfaces);
}

/*
 * call-seq:
 *   conn.num_of_defined_interfaces -> Fixnum
 *
 * Call virConnectNumOfDefinedInterfaces[https://libvirt.org/html/libvirt-libvirt-interface.html#virConnectNumOfDefinedInterfaces]
 * to retrieve the number of inactive interfaces on this connection.
 */
static VALUE libvirt_connect_num_of_defined_interfaces(VALUE c)
{
    gen_conn_num_of(c, DefinedInterfaces);
}

/*
 * call-seq:
 *   conn.list_defined_interfaces -> list
 *
 * Call virConnectListDefinedInterfaces[https://libvirt.org/html/libvirt-libvirt-interface.html#virConnectListDefinedInterfaces]
 * to retrieve a list of inactive interface names on this connection.
 */
static VALUE libvirt_connect_list_defined_interfaces(VALUE c)
{
    gen_conn_list_names(c, DefinedInterfaces);
}

/*
 * call-seq:
 *   conn.lookup_interface_by_name(name) -> Libvirt::Interface
 *
 * Call virInterfaceLookupByName[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceLookupByName]
 * to retrieve an interface object by name.
 */
static VALUE libvirt_connect_lookup_interface_by_name(VALUE c, VALUE name)
{
    virInterfacePtr iface;

    iface = virInterfaceLookupByName(ruby_libvirt_connect_get(c),
                                     StringValueCStr(name));
    ruby_libvirt_raise_error_if(iface == NULL, e_RetrieveError,
                                "virInterfaceLookupByName",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_interface_new(iface, c);
}

/*
 * call-seq:
 *   conn.lookup_interface_by_mac(mac) -> Libvirt::Interface
 *
 * Call virInterfaceLookupByMACString[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceLookupByMACString]
 * to retrieve an interface object by MAC address.
 */
static VALUE libvirt_connect_lookup_interface_by_mac(VALUE c, VALUE mac)
{
    virInterfacePtr iface;

    iface = virInterfaceLookupByMACString(ruby_libvirt_connect_get(c),
                                          StringValueCStr(mac));
    ruby_libvirt_raise_error_if(iface == NULL, e_RetrieveError,
                                "virInterfaceLookupByMACString",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_interface_new(iface, c);
}

/*
 * call-seq:
 *   conn.define_interface_xml(xml, flags=0) -> Libvirt::Interface
 *
 * Call virInterfaceDefineXML[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceDefineXML]
 * to define a new interface from xml.
 */
static VALUE libvirt_connect_define_interface_xml(int argc, VALUE *argv,
                                                  VALUE c)
{
    virInterfacePtr iface;
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    iface = virInterfaceDefineXML(ruby_libvirt_connect_get(c),
                                  StringValueCStr(xml),
                                  ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(iface == NULL, e_DefinitionError,
                                "virInterfaceDefineXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_interface_new(iface, c);
}

/*
 * call-seq:
 *   conn.num_of_networks -> Fixnum
 *
 * Call virConnectNumOfNetworks[https://libvirt.org/html/libvirt-libvirt-network.html#virConnectNumOfNetworks]
 * to retrieve the number of active networks on this connection.
 */
static VALUE libvirt_connect_num_of_networks(VALUE c)
{
    gen_conn_num_of(c, Networks);
}

/*
 * call-seq:
 *   conn.list_networks -> list
 *
 * Call virConnectListNetworks[https://libvirt.org/html/libvirt-libvirt-network.html#virConnectListNetworks]
 * to retrieve a list of active network names on this connection.
 */
static VALUE libvirt_connect_list_networks(VALUE c)
{
    gen_conn_list_names(c, Networks);
}

/*
 * call-seq:
 *   conn.num_of_defined_networks -> Fixnum
 *
 * Call virConnectNumOfDefinedNetworks[https://libvirt.org/html/libvirt-libvirt-network.html#virConnectNumOfDefinedNetworks]
 * to retrieve the number of inactive networks on this connection.
 */
static VALUE libvirt_connect_num_of_defined_networks(VALUE c)
{
    gen_conn_num_of(c, DefinedNetworks);
}

/*
 * call-seq:
 *   conn.list_of_defined_networks -> list
 *
 * Call virConnectListDefinedNetworks[https://libvirt.org/html/libvirt-libvirt-network.html#virConnectListDefinedNetworks]
 * to retrieve a list of inactive network names on this connection.
 */
static VALUE libvirt_connect_list_defined_networks(VALUE c)
{
    gen_conn_list_names(c, DefinedNetworks);
}

/*
 * call-seq:
 *   conn.lookup_network_by_name(name) -> Libvirt::Network
 *
 * Call virNetworkLookupByName[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkLookupByName]
 * to retrieve a network object by name.
 */
static VALUE libvirt_connect_lookup_network_by_name(VALUE c, VALUE name)
{
    virNetworkPtr netw;

    netw = virNetworkLookupByName(ruby_libvirt_connect_get(c),
                                  StringValueCStr(name));
    ruby_libvirt_raise_error_if(netw == NULL, e_RetrieveError,
                                "virNetworkLookupByName",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_network_new(netw, c);
}

/*
 * call-seq:
 *   conn.lookup_network_by_uuid(uuid) -> Libvirt::Network
 *
 * Call virNetworkLookupByUUIDString[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkLookupByUUIDString]
 * to retrieve a network object by UUID.
 */
static VALUE libvirt_connect_lookup_network_by_uuid(VALUE c, VALUE uuid)
{
    virNetworkPtr netw;

    netw = virNetworkLookupByUUIDString(ruby_libvirt_connect_get(c),
                                        StringValueCStr(uuid));
    ruby_libvirt_raise_error_if(netw == NULL, e_RetrieveError,
                                "virNetworkLookupByUUID",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_network_new(netw, c);
}

/*
 * call-seq:
 *   conn.create_network_xml(xml) -> Libvirt::Network
 *
 * Call virNetworkCreateXML[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkCreateXML]
 * to start a new transient network from xml.
 */
static VALUE libvirt_connect_create_network_xml(VALUE c, VALUE xml)
{
    virNetworkPtr netw;

    netw = virNetworkCreateXML(ruby_libvirt_connect_get(c),
                               StringValueCStr(xml));
    ruby_libvirt_raise_error_if(netw == NULL, e_Error, "virNetworkCreateXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_network_new(netw, c);
}

/*
 * call-seq:
 *   conn.define_network_xml(xml) -> Libvirt::Network
 *
 * Call virNetworkDefineXML[https://libvirt.org/html/libvirt-libvirt-network.html#virNetworkDefineXML]
 * to define a new permanent network from xml.
 */
static VALUE libvirt_connect_define_network_xml(VALUE c, VALUE xml)
{
    virNetworkPtr netw;

    netw = virNetworkDefineXML(ruby_libvirt_connect_get(c),
                               StringValueCStr(xml));
    ruby_libvirt_raise_error_if(netw == NULL, e_DefinitionError,
                                "virNetworkDefineXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_network_new(netw, c);
}


/*
 * call-seq:
 *   conn.num_of_nodedevices(cap=nil, flags=0) -> Fixnum
 *
 * Call virNodeNumOfDevices[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeNumOfDevices]
 * to retrieve the number of node devices on this connection.
 */
static VALUE libvirt_connect_num_of_nodedevices(int argc, VALUE *argv, VALUE c)
{
    int result;
    VALUE cap, flags;

    rb_scan_args(argc, argv, "02", &cap, &flags);

    result = virNodeNumOfDevices(ruby_libvirt_connect_get(c),
                                 ruby_libvirt_get_cstring_or_null(cap),
                                 ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(result < 0, e_RetrieveError,
                                "virNodeNumOfDevices",
                                ruby_libvirt_connect_get(c));

    return INT2NUM(result);
}

/*
 * call-seq:
 *   conn.list_nodedevices(cap=nil, flags=0) -> list
 *
 * Call virNodeListDevices[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeListDevices]
 * to retrieve a list of node device names on this connection.
 */
static VALUE libvirt_connect_list_nodedevices(int argc, VALUE *argv, VALUE c)
{
    int r, num;
    VALUE cap, flags;
    char *capstr;
    char **names;

    rb_scan_args(argc, argv, "02", &cap, &flags);

    if (TYPE(flags) != T_NIL && TYPE(flags) != T_FIXNUM) {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Number)");
    }

    capstr = ruby_libvirt_get_cstring_or_null(cap);

    num = virNodeNumOfDevices(ruby_libvirt_connect_get(c), capstr, 0);
    ruby_libvirt_raise_error_if(num < 0, e_RetrieveError,
                                "virNodeNumOfDevices",
                                ruby_libvirt_connect_get(c));
    if (num == 0) {
        /* if num is 0, don't call virNodeListDevices function */
        return rb_ary_new2(num);
    }

    names = alloca(sizeof(char *) * num);
    r = virNodeListDevices(ruby_libvirt_connect_get(c), capstr, names, num,
                           ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(r < 0, e_RetrieveError, "virNodeListDevices",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_generate_list(r, names);
}

/*
 * call-seq:
 *   conn.lookup_nodedevice_by_name(name) -> Libvirt::NodeDevice
 *
 * Call virNodeDeviceLookupByName[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceLookupByName]
 * to retrieve a nodedevice object by name.
 */
static VALUE libvirt_connect_lookup_nodedevice_by_name(VALUE c, VALUE name)
{
    virNodeDevicePtr nodedev;

    nodedev = virNodeDeviceLookupByName(ruby_libvirt_connect_get(c),
                                        StringValueCStr(name));
    ruby_libvirt_raise_error_if(nodedev == NULL, e_RetrieveError,
                                "virNodeDeviceLookupByName",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_nodedevice_new(nodedev, c);

}

/*
 * call-seq:
 *   conn.create_nodedevice_xml(xml, flags=0) -> Libvirt::NodeDevice
 *
 * Call virNodeDeviceCreateXML[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virNodeDeviceCreateXML]
 * to create a new node device from xml.
 */
static VALUE libvirt_connect_create_nodedevice_xml(int argc, VALUE *argv,
                                                   VALUE c)
{
    virNodeDevicePtr nodedev;
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    nodedev = virNodeDeviceCreateXML(ruby_libvirt_connect_get(c),
                                     StringValueCStr(xml),
                                     ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(nodedev == NULL, e_Error,
                                "virNodeDeviceCreateXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_nodedevice_new(nodedev, c);
}


/*
 * call-seq:
 *   conn.num_of_nwfilters -> Fixnum
 *
 * Call virConnectNumOfNWFilters[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virConnectNumOfNWFilters]
 * to retrieve the number of network filters on this connection.
 */
static VALUE libvirt_connect_num_of_nwfilters(VALUE c)
{
    gen_conn_num_of(c, NWFilters);
}

/*
 * call-seq:
 *   conn.list_nwfilters -> list
 *
 * Call virConnectListNWFilters[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virConnectListNWFilters]
 * to retrieve a list of network filter names on this connection.
 */
static VALUE libvirt_connect_list_nwfilters(VALUE c)
{
    gen_conn_list_names(c, NWFilters);
}

/*
 * call-seq:
 *   conn.lookup_nwfilter_by_name(name) -> Libvirt::NWFilter
 *
 * Call virNWFilterLookupByName[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterLookupByName]
 * to retrieve a network filter object by name.
 */
static VALUE libvirt_connect_lookup_nwfilter_by_name(VALUE c, VALUE name)
{
    virNWFilterPtr nwfilter;

    nwfilter = virNWFilterLookupByName(ruby_libvirt_connect_get(c),
                                       StringValueCStr(name));
    ruby_libvirt_raise_error_if(nwfilter == NULL, e_RetrieveError,
                                "virNWFilterLookupByName",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_nwfilter_new(nwfilter, c);
}

/*
 * call-seq:
 *   conn.lookup_nwfilter_by_uuid(uuid) -> Libvirt::NWFilter
 *
 * Call virNWFilterLookupByUUIDString[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterLookupByUUIDString]
 * to retrieve a network filter object by UUID.
 */
static VALUE libvirt_connect_lookup_nwfilter_by_uuid(VALUE c, VALUE uuid)
{
    virNWFilterPtr nwfilter;

    nwfilter = virNWFilterLookupByUUIDString(ruby_libvirt_connect_get(c),
                                             StringValueCStr(uuid));
    ruby_libvirt_raise_error_if(nwfilter == NULL, e_RetrieveError,
                                "virNWFilterLookupByUUIDString",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_nwfilter_new(nwfilter, c);
}

/*
 * call-seq:
 *   conn.define_nwfilter_xml(xml) -> Libvirt::NWFilter
 *
 * Call virNWFilterDefineXML[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virNWFilterDefineXML]
 * to define a new network filter from xml.
 */
static VALUE libvirt_connect_define_nwfilter_xml(VALUE c, VALUE xml)
{
    virNWFilterPtr nwfilter;

    nwfilter = virNWFilterDefineXML(ruby_libvirt_connect_get(c),
                                    StringValueCStr(xml));
    ruby_libvirt_raise_error_if(nwfilter == NULL, e_DefinitionError,
                                "virNWFilterDefineXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_nwfilter_new(nwfilter, c);
}


/*
 * call-seq:
 *   conn.num_of_secrets -> Fixnum
 *
 * Call virConnectNumOfSecrets[https://libvirt.org/html/libvirt-libvirt-secret.html#virConnectNumOfSecrets]
 * to retrieve the number of secrets on this connection.
 */
static VALUE libvirt_connect_num_of_secrets(VALUE c)
{
    gen_conn_num_of(c, Secrets);
}

/*
 * call-seq:
 *   conn.list_secrets -> list
 *
 * Call virConnectListSecrets[https://libvirt.org/html/libvirt-libvirt-secret.html#virConnectListSecrets]
 * to retrieve a list of secret UUIDs on this connection.
 */
static VALUE libvirt_connect_list_secrets(VALUE c)
{
    gen_conn_list_names(c, Secrets);
}

/*
 * call-seq:
 *   conn.lookup_secret_by_uuid(uuid) -> Libvirt::Secret
 *
 * Call virSecretLookupByUUID[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretLookupByUUID]
 * to retrieve a network object from uuid.
 */
static VALUE libvirt_connect_lookup_secret_by_uuid(VALUE c, VALUE uuid)
{
    virSecretPtr secret;

    secret = virSecretLookupByUUIDString(ruby_libvirt_connect_get(c),
                                         StringValueCStr(uuid));
    ruby_libvirt_raise_error_if(secret == NULL, e_RetrieveError,
                                "virSecretLookupByUUID",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_secret_new(secret, c);
}

/*
 * call-seq:
 *   conn.lookup_secret_by_usage(usagetype, usageID) -> Libvirt::Secret
 *
 * Call virSecretLookupByUsage[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretLookupByUsage]
 * to retrieve a secret by usagetype.
 */
static VALUE libvirt_connect_lookup_secret_by_usage(VALUE c, VALUE usagetype,
                                                    VALUE usageID)
{
    virSecretPtr secret;

    secret = virSecretLookupByUsage(ruby_libvirt_connect_get(c),
                                    NUM2UINT(usagetype),
                                    StringValueCStr(usageID));
    ruby_libvirt_raise_error_if(secret == NULL, e_RetrieveError,
                                "virSecretLookupByUsage",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_secret_new(secret, c);
}

/*
 * call-seq:
 *   conn.define_secret_xml(xml, flags=0) -> Libvirt::Secret
 *
 * Call virSecretDefineXML[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretDefineXML]
 * to define a new secret from xml.
 */
static VALUE libvirt_connect_define_secret_xml(int argc, VALUE *argv, VALUE c)
{
    virSecretPtr secret;
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    secret = virSecretDefineXML(ruby_libvirt_connect_get(c),
                                StringValueCStr(xml),
                                ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(secret == NULL, e_DefinitionError,
                                "virSecretDefineXML",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_secret_new(secret, c);
}


VALUE pool_new(virStoragePoolPtr n, VALUE conn);

/*
 * call-seq:
 *   conn.list_storage_pools -> list
 *
 * Call virConnectListStoragePools[https://libvirt.org/html/libvirt-libvirt-storage.html#virConnectListStoragePools]
 * to retrieve a list of active storage pool names on this connection.
 */
static VALUE libvirt_connect_list_storage_pools(VALUE c)
{
    gen_conn_list_names(c, StoragePools);
}

/*
 * call-seq:
 *   conn.num_of_storage_pools -> Fixnum
 *
 * Call virConnectNumOfStoragePools[https://libvirt.org/html/libvirt-libvirt-storage.html#virConnectNumOfStoragePools]
 * to retrieve the number of active storage pools on this connection.
 */
static VALUE libvirt_connect_num_of_storage_pools(VALUE c)
{
    gen_conn_num_of(c, StoragePools);
}

/*
 * call-seq:
 *   conn.list_defined_storage_pools -> list
 *
 * Call virConnectListDefinedStoragePools[https://libvirt.org/html/libvirt-libvirt-storage.html#virConnectListDefinedStoragePools]
 * to retrieve a list of inactive storage pool names on this connection.
 */
static VALUE libvirt_connect_list_defined_storage_pools(VALUE c)
{
    gen_conn_list_names(c, DefinedStoragePools);
}

/*
 * call-seq:
 *   conn.num_of_defined_storage_pools -> Fixnum
 *
 * Call virConnectNumOfDefinedStoragePools[https://libvirt.org/html/libvirt-libvirt-storage.html#virConnectNumOfDefinedStoragePools]
 * to retrieve the number of inactive storage pools on this connection.
 */
static VALUE libvirt_connect_num_of_defined_storage_pools(VALUE c)
{
    gen_conn_num_of(c, DefinedStoragePools);
}

/*
 * call-seq:
 *   conn.lookup_storage_pool_by_name(name) -> Libvirt::StoragePool
 *
 * Call virStoragePoolLookupByName[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolLookupByName]
 * to retrieve a storage pool object by name.
 */
static VALUE libvirt_connect_lookup_pool_by_name(VALUE c, VALUE name)
{
    virStoragePoolPtr pool;

    pool = virStoragePoolLookupByName(ruby_libvirt_connect_get(c),
                                      StringValueCStr(name));
    ruby_libvirt_raise_error_if(pool == NULL, e_RetrieveError,
                                "virStoragePoolLookupByName",
                                ruby_libvirt_connect_get(c));

    return pool_new(pool, c);
}

/*
 * call-seq:
 *   conn.lookup_storage_pool_by_uuid(uuid) -> Libvirt::StoragePool
 *
 * Call virStoragePoolLookupByUUIDString[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolLookupByUUIDString]
 * to retrieve a storage pool object by uuid.
 */
static VALUE libvirt_connect_lookup_pool_by_uuid(VALUE c, VALUE uuid)
{
    virStoragePoolPtr pool;

    pool = virStoragePoolLookupByUUIDString(ruby_libvirt_connect_get(c),
                                            StringValueCStr(uuid));
    ruby_libvirt_raise_error_if(pool == NULL, e_RetrieveError,
                                "virStoragePoolLookupByUUID",
                                ruby_libvirt_connect_get(c));

    return pool_new(pool, c);
}

/*
 * call-seq:
 *   conn.create_storage_pool_xml(xml, flags=0) -> Libvirt::StoragePool
 *
 * Call virStoragePoolCreateXML[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolCreateXML]
 * to start a new transient storage pool from xml.
 */
static VALUE libvirt_connect_create_pool_xml(int argc, VALUE *argv, VALUE c)
{
    virStoragePoolPtr pool;
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    pool = virStoragePoolCreateXML(ruby_libvirt_connect_get(c),
                                   StringValueCStr(xml),
                                   ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(pool == NULL, e_Error,
                                "virStoragePoolCreateXML",
                                ruby_libvirt_connect_get(c));

    return pool_new(pool, c);
}

/*
 * call-seq:
 *   conn.define_storage_pool_xml(xml, flags=0) -> Libvirt::StoragePool
 *
 * Call virStoragePoolDefineXML[https://libvirt.org/html/libvirt-libvirt-storage.html#virStoragePoolDefineXML]
 * to define a permanent storage pool from xml.
 */
static VALUE libvirt_connect_define_pool_xml(int argc, VALUE *argv, VALUE c)
{
    virStoragePoolPtr pool;
    VALUE xml, flags;

    rb_scan_args(argc, argv, "11", &xml, &flags);

    pool = virStoragePoolDefineXML(ruby_libvirt_connect_get(c),
                                   StringValueCStr(xml),
                                   ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(pool == NULL, e_DefinitionError,
                                "virStoragePoolDefineXML",
                                ruby_libvirt_connect_get(c));

    return pool_new(pool, c);
}

/*
 * call-seq:
 *   conn.discover_storage_pool_sources(type, srcSpec=nil, flags=0) -> String
 *
 * Call virConnectFindStoragePoolSources[https://libvirt.org/html/libvirt-libvirt-storage.html#virConnectFindStoragePoolSources]
 * to find the storage pool sources corresponding to type.
 */
static VALUE libvirt_connect_find_storage_pool_sources(int argc, VALUE *argv,
                                                       VALUE c)
{
    VALUE type, srcSpec, flags;

    rb_scan_args(argc, argv, "12", &type, &srcSpec, &flags);

    ruby_libvirt_generate_call_string(virConnectFindStoragePoolSources,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c),
                                      StringValueCStr(type),
                                      ruby_libvirt_get_cstring_or_null(srcSpec),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.sys_info(flags=0) -> String
 *
 * Call virConnectGetSysinfo[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetSysinfo]
 * to get machine-specific information about the hypervisor.  This may include
 * data such as the host UUID, the BIOS version, etc.
 */
static VALUE libvirt_connect_sys_info(int argc, VALUE *argv, VALUE c)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virConnectGetSysinfo,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.stream(flags=0) -> Libvirt::Stream
 *
 * Call virStreamNew[https://libvirt.org/html/libvirt-libvirt-stream.html#virStreamNew]
 * to create a new stream.
 */
static VALUE libvirt_connect_stream(int argc, VALUE *argv, VALUE c)
{
    VALUE flags;
    virStreamPtr stream;

    rb_scan_args(argc, argv, "01", &flags);

    stream = virStreamNew(ruby_libvirt_connect_get(c),
                          ruby_libvirt_value_to_uint(flags));

    ruby_libvirt_raise_error_if(stream == NULL, e_RetrieveError,
                                "virStreamNew", ruby_libvirt_connect_get(c));

    return ruby_libvirt_stream_new(stream, c);
}

/*
 * call-seq:
 *   conn.interface_change_begin(flags=0) -> nil
 *
 * Call virInterfaceChangeBegin[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceChangeBegin]
 * to create a restore point for interface changes.  Once changes have been
 * made, conn.interface_change_commit can be used to commit the result or
 * conn.interface_change_rollback can be used to rollback to this restore point.
 */
static VALUE libvirt_connect_interface_change_begin(int argc, VALUE *argv,
                                                    VALUE c)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virInterfaceChangeBegin,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.interface_change_commit(flags=0) -> nil
 *
 * Call virInterfaceChangeCommit[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceChangeCommit]
 * to commit the interface changes since the last conn.interface_change_begin.
 */
static VALUE libvirt_connect_interface_change_commit(int argc, VALUE *argv,
                                                     VALUE c)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virInterfaceChangeCommit,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.interface_change_rollback(flags=0) -> nil
 *
 * Call virInterfaceChangeRollback[https://libvirt.org/html/libvirt-libvirt-interface.html#virInterfaceChangeRollback]
 * to rollback to the restore point saved by conn.interface_change_begin.
 */
static VALUE libvirt_connect_interface_change_rollback(int argc, VALUE *argv,
                                                       VALUE c)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_nil(virInterfaceChangeRollback,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_value_to_uint(flags));
}

static void cpu_stats_set(void *voidparams, int i, VALUE result)
{
    virNodeCPUStatsPtr params = (virNodeCPUStatsPtr)voidparams;

    rb_hash_aset(result, rb_str_new2(params[i].field),
                 ULL2NUM(params[i].value));
}

static const char *cpu_stats_nparams(VALUE d, unsigned int flags, void *opaque,
                                     int *nparams)
{
    int intparam = *((int *)opaque);

    if (virNodeGetCPUStats(ruby_libvirt_connect_get(d), intparam, NULL,
                           nparams, flags) < 0) {
        return "virNodeGetCPUStats";
    }

    return NULL;
}

static const char *cpu_stats_get(VALUE d, unsigned int flags, void *voidparams,
                                 int *nparams, void *opaque)
{
    int intparam = *((int *)opaque);
    virNodeCPUStatsPtr params = (virNodeCPUStatsPtr)voidparams;

    if (virNodeGetCPUStats(ruby_libvirt_connect_get(d), intparam, params,
                           nparams, flags) < 0) {
        return "virNodeGetCPUStats";
    }

    return NULL;
}

/*
 * call-seq:
 *   conn.node_cpu_stats(cpuNum=-1, flags=0) -> Hash
 *
 * Call virNodeGetCPUStats[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetCPUStats]
 * to retrieve cpu statistics from the virtualization host.
 */
static VALUE libvirt_connect_node_cpu_stats(int argc, VALUE *argv, VALUE c)
{
    VALUE intparam, flags;
    int tmp;

    rb_scan_args(argc, argv, "02", &intparam, &flags);

    if (NIL_P(intparam)) {
        tmp = -1;
    }
    else {
        tmp = ruby_libvirt_value_to_int(intparam);
    }

    return ruby_libvirt_get_parameters(c, ruby_libvirt_value_to_uint(flags),
                                       (void *)&tmp, sizeof(virNodeCPUStats),
                                       cpu_stats_nparams, cpu_stats_get,
                                       cpu_stats_set);
}

static void memory_stats_set(void *voidparams, int i, VALUE result)
{
    virNodeMemoryStatsPtr params = (virNodeMemoryStatsPtr)voidparams;

    rb_hash_aset(result, rb_str_new2(params[i].field),
                 ULL2NUM(params[i].value));
}

static const char *memory_stats_nparams(VALUE d, unsigned int flags,
                                        void *opaque, int *nparams)
{
    int intparam = *((int *)opaque);

    if (virNodeGetMemoryStats(ruby_libvirt_connect_get(d), intparam, NULL,
                              nparams, flags) < 0) {
        return "virNodeGetMemoryStats";
    }

    return NULL;
}

static const char *memory_stats_get(VALUE d, unsigned int flags,
                                    void *voidparams, int *nparams,
                                    void *opaque)
{
    int intparam = *((int *)opaque);
    virNodeMemoryStatsPtr params = (virNodeMemoryStatsPtr)voidparams;

    if (virNodeGetMemoryStats(ruby_libvirt_connect_get(d), intparam, params,
                           nparams, flags) < 0) {
        return "virNodeGetMemoryStats";
    }

    return NULL;
}

/*
 * call-seq:
 *   conn.node_memory_stats(cellNum=-1, flags=0) -> Hash
 *
 * Call virNodeGetMemoryStats[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetMemoryStats]
 * to retrieve memory statistics from the virtualization host.
 */
static VALUE libvirt_connect_node_memory_stats(int argc, VALUE *argv, VALUE c)
{
    VALUE intparam, flags;
    int tmp;

    rb_scan_args(argc, argv, "02", &intparam, &flags);

    if (NIL_P(intparam)) {
        tmp = -1;
    }
    else {
        tmp = ruby_libvirt_value_to_int(intparam);
    }

    return ruby_libvirt_get_parameters(c, ruby_libvirt_value_to_uint(flags),
                                       (void *)&tmp, sizeof(virNodeMemoryStats),
                                       memory_stats_nparams, memory_stats_get,
                                       memory_stats_set);
}

/*
 * call-seq:
 *   conn.save_image_xml_desc(filename, flags=0) -> String
 *
 * Call virDomainSaveImageGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSaveImageGetXMLDesc]
 * to get the XML corresponding to a save file.
 */
static VALUE libvirt_connect_save_image_xml_desc(int argc, VALUE *argv, VALUE c)
{
    VALUE filename, flags;

    rb_scan_args(argc, argv, "11", &filename, &flags);

    ruby_libvirt_generate_call_string(virDomainSaveImageGetXMLDesc,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c),
                                      StringValueCStr(filename),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.define_save_image_xml(filename, newxml, flags=0) -> nil
 *
 * Call virDomainSaveImageDefineXML[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainSaveImageDefineXML]
 * to define new XML for a saved image.
 */
static VALUE libvirt_connect_define_save_image_xml(int argc, VALUE *argv,
                                                   VALUE c)
{
    VALUE filename, newxml, flags;

    rb_scan_args(argc, argv, "21", &filename, &newxml, &flags);

    ruby_libvirt_generate_call_nil(virDomainSaveImageDefineXML,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   StringValueCStr(filename),
                                   StringValueCStr(newxml),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   conn.node_suspend_for_duration(target, duration, flags=0) -> nil
 *
 * Call virNodeSuspendForDuration[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeSuspendForDuration]
 * to suspend the hypervisor for the specified duration.
 */
static VALUE libvirt_connect_node_suspend_for_duration(int argc, VALUE *argv,
                                                       VALUE c)
{
    VALUE target, duration, flags;

    rb_scan_args(argc, argv, "21", &target, &duration, &flags);

    ruby_libvirt_generate_call_nil(virNodeSuspendForDuration,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   NUM2UINT(target), NUM2ULL(duration),
                                   ruby_libvirt_value_to_uint(flags));
}

static const char *node_memory_nparams(VALUE d, unsigned int flags,
                                       void *RUBY_LIBVIRT_UNUSED(opaque),
                                       int *nparams)
{
    if (virNodeGetMemoryParameters(ruby_libvirt_connect_get(d), NULL, nparams,
                                   flags) < 0) {
        return "virNodeGetMemoryParameters";
    }

    return NULL;
}

static const char *node_memory_get(VALUE d, unsigned int flags,
                                   void *voidparams, int *nparams,
                                   void *RUBY_LIBVIRT_UNUSED(opaque))
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;

    if (virNodeGetMemoryParameters(ruby_libvirt_connect_get(d), params, nparams,
                                   flags) < 0) {
        return "virNodeGetMemoryParameters";
    }
    return NULL;
}

static const char *node_memory_set(VALUE d, unsigned int flags,
                                   virTypedParameterPtr params, int nparams,
                                   void *RUBY_LIBVIRT_UNUSED(opaque))
{
    if (virNodeSetMemoryParameters(ruby_libvirt_connect_get(d), params, nparams,
                                   flags) < 0) {
        return "virNodeSetMemoryParameters";
    }
    return NULL;
}

/*
 * call-seq:
 *   conn.node_memory_parameters(flags=0) -> Hash
 *
 * Call virNodeGetMemoryParameters[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetMemoryParameters]
 * to get information about memory on the host node.
 */
static VALUE libvirt_connect_node_memory_parameters(int argc, VALUE *argv,
                                                    VALUE c)
{
    VALUE flags;

    rb_scan_args(argc, argv, "01", &flags);

    return ruby_libvirt_get_typed_parameters(c,
                                             ruby_libvirt_value_to_uint(flags),
                                             NULL, node_memory_nparams,
                                             node_memory_get);
}

static struct ruby_libvirt_typed_param memory_allowed[] = {
    {VIR_NODE_MEMORY_SHARED_PAGES_TO_SCAN, VIR_TYPED_PARAM_UINT},
    {VIR_NODE_MEMORY_SHARED_SLEEP_MILLISECS, VIR_TYPED_PARAM_UINT},
    {VIR_NODE_MEMORY_SHARED_PAGES_SHARED, VIR_TYPED_PARAM_ULLONG},
    {VIR_NODE_MEMORY_SHARED_PAGES_SHARING, VIR_TYPED_PARAM_ULLONG},
    {VIR_NODE_MEMORY_SHARED_PAGES_UNSHARED, VIR_TYPED_PARAM_ULLONG},
    {VIR_NODE_MEMORY_SHARED_PAGES_VOLATILE, VIR_TYPED_PARAM_ULLONG},
    {VIR_NODE_MEMORY_SHARED_FULL_SCANS, VIR_TYPED_PARAM_ULLONG},
    {VIR_NODE_MEMORY_SHARED_MERGE_ACROSS_NODES, VIR_TYPED_PARAM_UINT},
};

/*
 * call-seq:
 *   conn.node_memory_parameters = Hash,flags=0
 *
 * Call virNodeSetMemoryParameters[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeSetMemoryParameters]
 * to set the memory parameters for this host node.
 */
static VALUE libvirt_connect_node_memory_parameters_equal(VALUE c, VALUE input)
{
    VALUE hash, flags;

    ruby_libvirt_assign_hash_and_flags(input, &hash, &flags);

    return ruby_libvirt_set_typed_parameters(c, hash, NUM2UINT(flags), NULL,
                                             memory_allowed,
                                             ARRAY_SIZE(memory_allowed),
                                             node_memory_set);
}

struct cpu_map_field_to_value {
    VALUE result;
    int cpu;
    int used;
};

static VALUE cpu_map_field_to_value(VALUE input)
{
    struct cpu_map_field_to_value *ftv = (struct cpu_map_field_to_value *)input;
    char cpuname[10];

    snprintf(cpuname, sizeof(cpuname), "%d", ftv->cpu);
    rb_hash_aset(ftv->result, rb_str_new2(cpuname), ftv->used ? Qtrue : Qfalse);

    return Qnil;
}

/*
 * call-seq:
 *   conn.node_cpu_map -> Hash
 *
 * Call virNodeGetCPUMap[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetCPUMap]
 * to get a map of online host CPUs.
 */
static VALUE libvirt_connect_node_cpu_map(int argc, VALUE *argv, VALUE c)
{
    VALUE flags, result;
    unsigned char *map;
    unsigned int online;
    int ret, i, exception = 0;
    struct cpu_map_field_to_value ftv;

    rb_scan_args(argc, argv, "01", &flags);

    ret = virNodeGetCPUMap(ruby_libvirt_connect_get(c), &map, &online,
                           ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_RetrieveError, "virNodeGetCPUMap",
                                ruby_libvirt_connect_get(c));

    result = rb_hash_new();

    for (i = 0; i < ret; i++) {
        ftv.result = result;
        ftv.cpu = i;
        ftv.used = VIR_CPU_USED(map, i);
        rb_protect(cpu_map_field_to_value, (VALUE)&ftv, &exception);
        if (exception) {
            free(map);
            rb_jump_tag(exception);
        }
    }

    free(map);

    return result;
}

/*
 * call-seq:
 *   conn.set_keepalive(interval, count) -> Fixnum
 *
 * Call virConnectSetKeepAlive[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectSetKeepAlive]
 * to start sending keepalive messages.  Deprecated; use conn.keepalive=
 * instead.
 */
static VALUE libvirt_connect_set_keepalive(VALUE c, VALUE interval, VALUE count)
{
    ruby_libvirt_generate_call_int(virConnectSetKeepAlive,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   NUM2INT(interval), NUM2UINT(count));
}

/*
 * call-seq:
 *   conn.keepalive = interval,count
 *
 * Call virConnectSetKeepAlive[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectSetKeepAlive]
 * to start sending keepalive messages.
 */
static VALUE libvirt_connect_keepalive_equal(VALUE c, VALUE in)
{
    VALUE interval, count;

    Check_Type(in, T_ARRAY);

    if (RARRAY_LEN(in) != 2) {
        rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                 RARRAY_LEN(in));
    }

    interval = rb_ary_entry(in, 0);
    count = rb_ary_entry(in, 1);

    ruby_libvirt_generate_call_int(virConnectSetKeepAlive,
                                   ruby_libvirt_connect_get(c),
                                   ruby_libvirt_connect_get(c),
                                   NUM2INT(interval), NUM2UINT(count));
}

/*
 * call-seq:
 *   conn.list_all_domains(flags=0) -> Array
 *
 * Call virConnectListAllDomains[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectListAllDomains]
 * to get an array of domain objects for all domains.
 */
static VALUE libvirt_connect_list_all_domains(int argc, VALUE *argv, VALUE c)
{
    ruby_libvirt_generate_call_list_all(virDomainPtr, argc, argv,
                                        virConnectListAllDomains,
                                        ruby_libvirt_connect_get(c), c,
                                        ruby_libvirt_domain_new, virDomainFree);
}

/*
 * call-seq:
 *   conn.list_all_networks(flags=0) -> Array
 *
 * Call virConnectListAllNetworks[https://libvirt.org/html/libvirt-libvirt-network.html#virConnectListAllNetworks]
 * to get an array of network objects for all networks.
 */
static VALUE libvirt_connect_list_all_networks(int argc, VALUE *argv, VALUE c)
{
    ruby_libvirt_generate_call_list_all(virNetworkPtr, argc, argv,
                                        virConnectListAllNetworks,
                                        ruby_libvirt_connect_get(c), c,
                                        ruby_libvirt_network_new,
                                        virNetworkFree);
}

/*
 * call-seq:
 *   conn.list_all_interfaces(flags=0) -> Array
 *
 * Call virConnectListAllInterfaces[https://libvirt.org/html/libvirt-libvirt-interface.html#virConnectListAllInterfaces]
 * to get an array of interface objects for all interfaces.
 */
static VALUE libvirt_connect_list_all_interfaces(int argc, VALUE *argv, VALUE c)
{
    ruby_libvirt_generate_call_list_all(virInterfacePtr, argc, argv,
                                        virConnectListAllInterfaces,
                                        ruby_libvirt_connect_get(c), c,
                                        ruby_libvirt_interface_new,
                                        virInterfaceFree);
}

/*
 * call-seq:
 *   conn.list_all_secrets(flags=0) -> Array
 *
 * Call virConnectListAllSecrets[https://libvirt.org/html/libvirt-libvirt-secret.html#virConnectListAllSecrets]
 * to get an array of secret objects for all secrets.
 */
static VALUE libvirt_connect_list_all_secrets(int argc, VALUE *argv, VALUE c)
{
    ruby_libvirt_generate_call_list_all(virSecretPtr, argc, argv,
                                        virConnectListAllSecrets,
                                        ruby_libvirt_connect_get(c), c,
                                        ruby_libvirt_secret_new, virSecretFree);
}

/*
 * call-seq:
 *   conn.list_all_nodedevices(flags=0) -> Array
 *
 * Call virConnectListAllNodeDevices[https://libvirt.org/html/libvirt-libvirt-nodedev.html#virConnectListAllNodeDevices]
 * to get an array of nodedevice objects for all nodedevices.
 */
static VALUE libvirt_connect_list_all_nodedevices(int argc, VALUE *argv,
                                                  VALUE c)
{
    ruby_libvirt_generate_call_list_all(virNodeDevicePtr, argc, argv,
                                        virConnectListAllNodeDevices,
                                        ruby_libvirt_connect_get(c), c,
                                        ruby_libvirt_nodedevice_new,
                                        virNodeDeviceFree);
}

/*
 * call-seq:
 *   conn.list_all_storage_pools(flags=0) -> Array
 *
 * Call virConnectListAllStoragePools[https://libvirt.org/html/libvirt-libvirt-storage.html#virConnectListAllStoragePools]
 * to get an array of storage pool objects for all storage pools.
 */
static VALUE libvirt_connect_list_all_storage_pools(int argc, VALUE *argv,
                                                    VALUE c)
{
    ruby_libvirt_generate_call_list_all(virStoragePoolPtr, argc, argv,
                                        virConnectListAllStoragePools,
                                        ruby_libvirt_connect_get(c), c,
                                        pool_new, virStoragePoolFree);
}

/*
 * call-seq:
 *   conn.list_all_nwfilters(flags=0) -> Array
 *
 * Call virConnectListAllNWFilters[https://libvirt.org/html/libvirt-libvirt-nwfilter.html#virConnectListAllNWFilters]
 * to get an array of nwfilters for all nwfilter objects.
 */
static VALUE libvirt_connect_list_all_nwfilters(int argc, VALUE *argv, VALUE c)
{
    ruby_libvirt_generate_call_list_all(virNWFilterPtr, argc, argv,
                                        virConnectListAllNWFilters,
                                        ruby_libvirt_connect_get(c), c,
                                        ruby_libvirt_nwfilter_new,
                                        virNWFilterFree);
}

/*
 * call-seq:
 *   conn.alive? -> [True|False]
 *
 * Call virConnectIsAlive[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectIsAlive]
 * to determine if the connection is alive.
 */
static VALUE libvirt_connect_alive_p(VALUE c)
{
    ruby_libvirt_generate_call_truefalse(virConnectIsAlive,
                                         ruby_libvirt_connect_get(c),
                                         ruby_libvirt_connect_get(c));
}

/*
 * call-seq:
 *   conn.create_domain_xml_with_files(xml, fds=nil, flags=0) -> Libvirt::Domain
 *
 * Call virDomainCreateXMLWithFiles[https://libvirt.org/html/libvirt-libvirt-domain.html#virDomainCreateXMLWithFiles]
 * to launch a new guest domain with a set of open file descriptors.
 */
static VALUE libvirt_connect_create_domain_xml_with_files(int argc, VALUE *argv,
                                                          VALUE c)
{
    VALUE xml, fds, flags;
    int *files;
    unsigned int numfiles, i;
    virDomainPtr dom;

    rb_scan_args(argc, argv, "12", &xml, &fds, &flags);

    Check_Type(xml, T_STRING);

    if (TYPE(fds) == T_NIL) {
        files = NULL;
        numfiles = 0;
    }
    else if (TYPE(fds) == T_ARRAY) {
        numfiles = RARRAY_LEN(fds);
        files = alloca(numfiles * sizeof(int));
        for (i = 0; i < numfiles; i++) {
            files[i] = NUM2INT(rb_ary_entry(fds, i));
        }
    }
    else {
        rb_raise(rb_eTypeError, "wrong argument type (expected Array)");
    }

    dom = virDomainCreateXMLWithFiles(ruby_libvirt_connect_get(c),
                                      ruby_libvirt_get_cstring_or_null(xml),
                                      numfiles, files,
                                      ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(dom == NULL, e_Error,
                                "virDomainCreateXMLWithFiles",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.qemu_attach(pid, flags=0) -> Libvirt::Domain
 *
 * Call virDomainQemuAttach
 * to attach to the Qemu process pid.
 */
static VALUE libvirt_connect_qemu_attach(int argc, VALUE *argv, VALUE c)
{
    VALUE pid, flags;
    virDomainPtr dom;

    rb_scan_args(argc, argv, "11", &pid, &flags);

    dom = virDomainQemuAttach(ruby_libvirt_connect_get(c), NUM2UINT(pid),
                              ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(dom == NULL, e_Error, "virDomainQemuAttach",
                                ruby_libvirt_connect_get(c));

    return ruby_libvirt_domain_new(dom, c);
}

/*
 * call-seq:
 *   conn.cpu_model_names(arch, flags=0) -> Array
 *
 * Call virConnectGetCPUModelNames[https://libvirt.org/html/libvirt-libvirt-host.html#virConnectGetCPUModelNames]
 * to get an array of CPU model names.
 */
static VALUE libvirt_connect_cpu_model_names(int argc, VALUE *argv, VALUE c)
{
    VALUE arch, flags, result;
    char **models;
    int i = 0, j, elems = 0;
    struct ruby_libvirt_str_new2_and_ary_store_arg args;
    int exception;

    rb_scan_args(argc, argv, "11", &arch, &flags);

    elems = virConnectGetCPUModelNames(ruby_libvirt_connect_get(c),
                                       StringValueCStr(arch), &models,
                                       ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(elems < 0, e_RetrieveError,
                                "virConnectGetCPUModelNames",
                                ruby_libvirt_connect_get(c));

    result = rb_protect(ruby_libvirt_ary_new2_wrap, (VALUE)&elems, &exception);
    if (exception) {
        goto error;
    }

    for (i = 0; i < elems; i++) {
        args.arr = result;
        args.index = i;
        args.value = models[i];

        rb_protect(ruby_libvirt_str_new2_and_ary_store_wrap, (VALUE)&args,
                   &exception);
        if (exception) {
            goto error;
        }
        free(models[i]);
    }
    free(models);

    return result;

error:
    for (j = i; j < elems; j++) {
        free(models[j]);
    }
    free(models);

    rb_jump_tag(exception);
    return Qnil;
}

/*
 * call-seq:
 *   conn.node_alloc_pages(page_arr, cells=nil, flags=0) -> Fixnum
 *
 * Call virNodeAllocPages[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeAllocPages]
 * to reserve huge pages in the system pool.
 */
static VALUE libvirt_connect_node_alloc_pages(int argc, VALUE *argv, VALUE c)
{
    VALUE page_arr, cells, flags, entry, size, count, tmp;
    int i, arraylen, start_cell, ret;
    unsigned int *page_sizes;
    unsigned long long *page_counts;
    unsigned int cell_count;

    rb_scan_args(argc, argv, "12", &page_arr, &cells, &flags);

    Check_Type(page_arr, T_ARRAY);

    arraylen = RARRAY_LEN(page_arr);

    page_sizes = alloca(arraylen * sizeof(unsigned int));
    page_counts = alloca(arraylen * sizeof(unsigned long long));

    for (i = 0; i < arraylen; i++) {
        entry = rb_ary_entry(page_arr, i);
        Check_Type(entry, T_HASH);

        size = rb_hash_aref(entry, rb_str_new2("size"));
        Check_Type(size, T_FIXNUM);

        count = rb_hash_aref(entry, rb_str_new2("count"));
        Check_Type(count, T_FIXNUM);

        page_sizes[i] = NUM2UINT(size);
        page_counts[i] = NUM2ULL(count);
    }

    if (NIL_P(cells)) {
        start_cell = -1;
        cell_count = 0;
    }
    else {
        Check_Type(cells, T_HASH);

        tmp = rb_hash_aref(cells, rb_str_new2("start"));
        Check_Type(tmp, T_FIXNUM);
        start_cell = NUM2INT(tmp);

        tmp = rb_hash_aref(cells, rb_str_new2("count"));
        Check_Type(tmp, T_FIXNUM);
        cell_count = NUM2UINT(tmp);
    }

    ret = virNodeAllocPages(ruby_libvirt_connect_get(c), arraylen, page_sizes,
                            page_counts, start_cell, cell_count,
                            ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_Error,
                                "virNodeAllocPages",
                                ruby_libvirt_connect_get(c));

    return INT2NUM(ret);
}

/*
 * call-seq:
 *   conn.domain_capabilities(emulatorbin, arch, machine, virttype, flags=0) -> String
 *
 * Call virConnectGetDomainCapabilities[https://libvirt.org/html/libvirt-libvirt-domain.html#virConnectGetDomainCapabilities]
 * to get the capabilities of the underlying emulator.
 */
static VALUE libvirt_connect_domain_capabilities(int argc, VALUE *argv, VALUE c)
{
    VALUE emulatorbin, arch, machine, virttype, flags;

    rb_scan_args(argc, argv, "41", &emulatorbin, &arch, &machine, &virttype,
                 &flags);

    ruby_libvirt_generate_call_string(virConnectGetDomainCapabilities,
                                      ruby_libvirt_connect_get(c), 1,
                                      ruby_libvirt_connect_get(c),
                                      ruby_libvirt_get_cstring_or_null(emulatorbin),
                                      ruby_libvirt_get_cstring_or_null(arch),
                                      ruby_libvirt_get_cstring_or_null(machine),
                                      ruby_libvirt_get_cstring_or_null(virttype),
                                      NUM2UINT(flags));
}

/*
 * call-seq:
 *   conn.node_free_pages(pages, cells, flags=0) -> Hash
 *
 * Call virNodeGetFreePages[https://libvirt.org/html/libvirt-libvirt-host.html#virNodeGetFreePages]
 * to query the host system on free pages of specified size.
 */
static VALUE libvirt_connect_node_free_pages(int argc, VALUE *argv, VALUE c)
{
    VALUE pageArr = RUBY_Qnil, cells = RUBY_Qnil, flags = RUBY_Qnil, result;
    unsigned int *pages;
    unsigned int npages, i, cellCount;
    int startCell, ret;
    unsigned long long *counts;

    rb_scan_args(argc, argv, "21", &pageArr, &cells, &flags);

    Check_Type(pageArr, T_ARRAY);
    Check_Type(cells, T_HASH);

    npages = RARRAY_LEN(pageArr);
    pages = alloca(npages);
    for (i = 0; i < npages; i++) {
        pages[i] = NUM2UINT(rb_ary_entry(pageArr, i));
    }

    startCell = NUM2INT(rb_hash_aref(cells, rb_str_new2("startCell")));
    cellCount = NUM2UINT(rb_hash_aref(cells, rb_str_new2("cellCount")));

    counts = alloca(npages * cellCount * sizeof(long long));

    ret = virNodeGetFreePages(ruby_libvirt_connect_get(c), npages, pages,
                              startCell, cellCount, counts,
                              ruby_libvirt_value_to_uint(flags));
    ruby_libvirt_raise_error_if(ret < 0, e_Error, "virNodeGetFreePages",
                                ruby_libvirt_connect_get(c));

    result = rb_hash_new();
    for (i = 0; i < npages; i++) {
        rb_hash_aset(result, UINT2NUM(pages[i]), ULL2NUM(counts[i]));
    }

    return result;
}

/*
 * Class Libvirt::Connect
 */
void ruby_libvirt_connect_init(void)
{
    c_connect = rb_define_class_under(m_libvirt, "Connect", rb_cObject);
    rb_undef_alloc_func(c_connect);
    rb_define_singleton_method(c_connect, "new",
                               ruby_libvirt_new_not_allowed, -1);

    /*
     * Class Libvirt::Connect::Nodeinfo
     */
    c_node_info = rb_define_class_under(c_connect, "Nodeinfo", rb_cObject);
    rb_define_attr(c_node_info, "model", 1, 0);
    rb_define_attr(c_node_info, "memory", 1, 0);
    rb_define_attr(c_node_info, "cpus", 1, 0);
    rb_define_attr(c_node_info, "mhz", 1, 0);
    rb_define_attr(c_node_info, "nodes", 1, 0);
    rb_define_attr(c_node_info, "sockets", 1, 0);
    rb_define_attr(c_node_info, "cores", 1, 0);
    rb_define_attr(c_node_info, "threads", 1, 0);

    /*
     * Class Libvirt::Connect::NodeSecurityModel
     */
    c_node_security_model = rb_define_class_under(c_connect,
                                                  "NodeSecurityModel",
                                                  rb_cObject);
    rb_define_attr(c_node_security_model, "model", 1, 0);
    rb_define_attr(c_node_security_model, "doi", 1, 0);

    rb_define_method(c_connect, "close", libvirt_connect_close, 0);
    rb_define_method(c_connect, "closed?", libvirt_connect_closed_p, 0);
    rb_define_method(c_connect, "type", libvirt_connect_type, 0);
    rb_define_method(c_connect, "version", libvirt_connect_version, 0);
    rb_define_method(c_connect, "libversion", libvirt_connect_libversion, 0);
    rb_define_method(c_connect, "hostname", libvirt_connect_hostname, 0);
    rb_define_method(c_connect, "uri", libvirt_connect_uri, 0);
    rb_define_method(c_connect, "max_vcpus", libvirt_connect_max_vcpus, -1);
    rb_define_method(c_connect, "node_info", libvirt_connect_node_info, 0);
    rb_define_alias(c_connect, "node_get_info", "node_info");
    rb_define_method(c_connect, "node_free_memory",
                     libvirt_connect_node_free_memory, 0);
    rb_define_method(c_connect, "node_cells_free_memory",
                     libvirt_connect_node_cells_free_memory, -1);
    rb_define_method(c_connect, "node_security_model",
                     libvirt_connect_node_security_model, 0);
    rb_define_alias(c_connect, "node_get_security_model",
                    "node_security_model");
    rb_define_method(c_connect, "encrypted?", libvirt_connect_encrypted_p, 0);
    rb_define_method(c_connect, "secure?", libvirt_connect_secure_p, 0);
    rb_define_method(c_connect, "capabilities", libvirt_connect_capabilities,
                     0);

    rb_define_const(c_connect, "CPU_COMPARE_ERROR",
                    INT2NUM(VIR_CPU_COMPARE_ERROR));
    rb_define_const(c_connect, "CPU_COMPARE_INCOMPATIBLE",
                    INT2NUM(VIR_CPU_COMPARE_INCOMPATIBLE));
    rb_define_const(c_connect, "CPU_COMPARE_IDENTICAL",
                    INT2NUM(VIR_CPU_COMPARE_IDENTICAL));
    rb_define_const(c_connect, "CPU_COMPARE_SUPERSET",
                    INT2NUM(VIR_CPU_COMPARE_SUPERSET));

    rb_define_method(c_connect, "compare_cpu", libvirt_connect_compare_cpu, -1);

    rb_define_const(c_connect, "COMPARE_CPU_FAIL_INCOMPATIBLE",
                    INT2NUM(VIR_CONNECT_COMPARE_CPU_FAIL_INCOMPATIBLE));

    rb_define_method(c_connect, "baseline_cpu", libvirt_connect_baseline_cpu,
                     -1);
    rb_define_const(c_connect, "BASELINE_CPU_EXPAND_FEATURES",
                    INT2NUM(VIR_CONNECT_BASELINE_CPU_EXPAND_FEATURES));

    rb_define_const(c_connect, "DOMAIN_EVENT_DEFINED",
                    INT2NUM(VIR_DOMAIN_EVENT_DEFINED));
    rb_define_const(c_connect, "DOMAIN_EVENT_DEFINED_ADDED",
                    INT2NUM(VIR_DOMAIN_EVENT_DEFINED_ADDED));
    rb_define_const(c_connect, "DOMAIN_EVENT_DEFINED_UPDATED",
                    INT2NUM(VIR_DOMAIN_EVENT_DEFINED_UPDATED));
    rb_define_const(c_connect, "DOMAIN_EVENT_UNDEFINED",
                    INT2NUM(VIR_DOMAIN_EVENT_UNDEFINED));
    rb_define_const(c_connect, "DOMAIN_EVENT_UNDEFINED_REMOVED",
                    INT2NUM(VIR_DOMAIN_EVENT_UNDEFINED_REMOVED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STARTED_BOOTED",
                    INT2NUM(VIR_DOMAIN_EVENT_STARTED_BOOTED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STARTED_MIGRATED",
                    INT2NUM(VIR_DOMAIN_EVENT_STARTED_MIGRATED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STARTED_RESTORED",
                    INT2NUM(VIR_DOMAIN_EVENT_STARTED_RESTORED));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED_PAUSED",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED_PAUSED));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED_MIGRATED",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED_MIGRATED));
    rb_define_const(c_connect, "DOMAIN_EVENT_RESUMED_UNPAUSED",
                    INT2NUM(VIR_DOMAIN_EVENT_RESUMED_UNPAUSED));
    rb_define_const(c_connect, "DOMAIN_EVENT_RESUMED_MIGRATED",
                    INT2NUM(VIR_DOMAIN_EVENT_RESUMED_MIGRATED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED_SHUTDOWN",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED_SHUTDOWN));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED_DESTROYED",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED_DESTROYED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED_CRASHED",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED_CRASHED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED_MIGRATED",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED_MIGRATED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED_SAVED",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED_SAVED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED_FAILED",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED_FAILED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STARTED",
                    INT2NUM(VIR_DOMAIN_EVENT_STARTED));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED));
    rb_define_const(c_connect, "DOMAIN_EVENT_RESUMED",
                    INT2NUM(VIR_DOMAIN_EVENT_RESUMED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STARTED_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_EVENT_STARTED_FROM_SNAPSHOT));
    rb_define_const(c_connect, "DOMAIN_EVENT_STOPPED_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_EVENT_STOPPED_FROM_SNAPSHOT));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED_IOERROR",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED_IOERROR));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED_WATCHDOG",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED_WATCHDOG));
    rb_define_const(c_connect, "DOMAIN_EVENT_ID_WATCHDOG",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_WATCHDOG));
    rb_define_const(c_connect, "DOMAIN_EVENT_WATCHDOG_NONE",
                    INT2NUM(VIR_DOMAIN_EVENT_WATCHDOG_NONE));
    rb_define_const(c_connect, "DOMAIN_EVENT_WATCHDOG_PAUSE",
                    INT2NUM(VIR_DOMAIN_EVENT_WATCHDOG_PAUSE));
    rb_define_const(c_connect, "DOMAIN_EVENT_WATCHDOG_RESET",
                    INT2NUM(VIR_DOMAIN_EVENT_WATCHDOG_RESET));
    rb_define_const(c_connect, "DOMAIN_EVENT_WATCHDOG_POWEROFF",
                    INT2NUM(VIR_DOMAIN_EVENT_WATCHDOG_POWEROFF));
    rb_define_const(c_connect, "DOMAIN_EVENT_WATCHDOG_SHUTDOWN",
                    INT2NUM(VIR_DOMAIN_EVENT_WATCHDOG_SHUTDOWN));
    rb_define_const(c_connect, "DOMAIN_EVENT_WATCHDOG_DEBUG",
                    INT2NUM(VIR_DOMAIN_EVENT_WATCHDOG_DEBUG));
    rb_define_const(c_connect, "DOMAIN_EVENT_ID_IO_ERROR",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_IO_ERROR));
    rb_define_const(c_connect, "DOMAIN_EVENT_IO_ERROR_NONE",
                    INT2NUM(VIR_DOMAIN_EVENT_IO_ERROR_NONE));
    rb_define_const(c_connect, "DOMAIN_EVENT_IO_ERROR_PAUSE",
                    INT2NUM(VIR_DOMAIN_EVENT_IO_ERROR_PAUSE));
    rb_define_const(c_connect, "DOMAIN_EVENT_IO_ERROR_REPORT",
                    INT2NUM(VIR_DOMAIN_EVENT_IO_ERROR_REPORT));
    rb_define_const(c_connect, "DOMAIN_EVENT_ID_GRAPHICS",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_GRAPHICS));
    rb_define_const(c_connect, "DOMAIN_EVENT_GRAPHICS_CONNECT",
                    INT2NUM(VIR_DOMAIN_EVENT_GRAPHICS_CONNECT));
    rb_define_const(c_connect, "DOMAIN_EVENT_GRAPHICS_INITIALIZE",
                    INT2NUM(VIR_DOMAIN_EVENT_GRAPHICS_INITIALIZE));
    rb_define_const(c_connect, "DOMAIN_EVENT_GRAPHICS_DISCONNECT",
                    INT2NUM(VIR_DOMAIN_EVENT_GRAPHICS_DISCONNECT));
    rb_define_const(c_connect, "DOMAIN_EVENT_GRAPHICS_ADDRESS_IPV4",
                    INT2NUM(VIR_DOMAIN_EVENT_GRAPHICS_ADDRESS_IPV4));
    rb_define_const(c_connect, "DOMAIN_EVENT_GRAPHICS_ADDRESS_IPV6",
                    INT2NUM(VIR_DOMAIN_EVENT_GRAPHICS_ADDRESS_IPV6));
    rb_define_const(c_connect, "DOMAIN_EVENT_ID_LIFECYCLE",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_LIFECYCLE));
    rb_define_const(c_connect, "DOMAIN_EVENT_ID_REBOOT",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_REBOOT));
    rb_define_const(c_connect, "DOMAIN_EVENT_ID_RTC_CHANGE",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_RTC_CHANGE));
    rb_define_const(c_connect, "DOMAIN_EVENT_ID_IO_ERROR_REASON",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_IO_ERROR_REASON));

    rb_define_const(c_connect, "DOMAIN_EVENT_ID_CONTROL_ERROR",
                    INT2NUM(VIR_DOMAIN_EVENT_ID_CONTROL_ERROR));
    rb_define_const(c_connect, "DOMAIN_EVENT_SHUTDOWN",
                    INT2NUM(VIR_DOMAIN_EVENT_SHUTDOWN));
    rb_define_const(c_connect, "DOMAIN_EVENT_PMSUSPENDED",
                    INT2NUM(VIR_DOMAIN_EVENT_PMSUSPENDED));
    rb_define_const(c_connect, "DOMAIN_EVENT_CRASHED",
                    INT2NUM(VIR_DOMAIN_EVENT_CRASHED));
    rb_define_const(c_connect, "DOMAIN_EVENT_STARTED_WAKEUP",
                    INT2NUM(VIR_DOMAIN_EVENT_STARTED_WAKEUP));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED_RESTORED",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED_RESTORED));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED_FROM_SNAPSHOT));
    rb_define_const(c_connect, "DOMAIN_EVENT_SUSPENDED_API_ERROR",
                    INT2NUM(VIR_DOMAIN_EVENT_SUSPENDED_API_ERROR));
    rb_define_const(c_connect, "DOMAIN_EVENT_RESUMED_FROM_SNAPSHOT",
                    INT2NUM(VIR_DOMAIN_EVENT_RESUMED_FROM_SNAPSHOT));
    rb_define_const(c_connect, "DOMAIN_EVENT_SHUTDOWN_FINISHED",
                    INT2NUM(VIR_DOMAIN_EVENT_SHUTDOWN_FINISHED));
    rb_define_const(c_connect, "DOMAIN_EVENT_PMSUSPENDED_MEMORY",
                    INT2NUM(VIR_DOMAIN_EVENT_PMSUSPENDED_MEMORY));
    rb_define_const(c_connect, "DOMAIN_EVENT_PMSUSPENDED_DISK",
                    INT2NUM(VIR_DOMAIN_EVENT_PMSUSPENDED_DISK));
    rb_define_const(c_connect, "DOMAIN_EVENT_CRASHED_PANICKED",
                    INT2NUM(VIR_DOMAIN_EVENT_CRASHED_PANICKED));
    rb_define_const(c_connect, "DOMAIN_EVENT_GRAPHICS_ADDRESS_UNIX",
                    INT2NUM(VIR_DOMAIN_EVENT_GRAPHICS_ADDRESS_UNIX));

    rb_define_method(c_connect, "domain_event_register",
                     libvirt_connect_domain_event_register, -1);
    rb_define_method(c_connect, "domain_event_deregister",
                     libvirt_connect_domain_event_deregister, 0);

    rb_define_method(c_connect, "domain_event_register_any",
                     libvirt_connect_domain_event_register_any, -1);
    rb_define_method(c_connect, "domain_event_deregister_any",
                     libvirt_connect_domain_event_deregister_any, 1);

    /* Domain creation/lookup */
    rb_define_method(c_connect, "num_of_domains",
                     libvirt_connect_num_of_domains, 0);
    rb_define_method(c_connect, "list_domains", libvirt_connect_list_domains,
                     0);
    rb_define_method(c_connect, "num_of_defined_domains",
                     libvirt_connect_num_of_defined_domains, 0);
    rb_define_method(c_connect, "list_defined_domains",
                     libvirt_connect_list_defined_domains, 0);
    rb_define_method(c_connect, "create_domain_linux",
                     libvirt_connect_create_linux, -1);
    rb_define_method(c_connect, "create_domain_xml",
                     libvirt_connect_create_domain_xml, -1);
    rb_define_method(c_connect, "lookup_domain_by_name",
                     libvirt_connect_lookup_domain_by_name, 1);
    rb_define_method(c_connect, "lookup_domain_by_id",
                     libvirt_connect_lookup_domain_by_id, 1);
    rb_define_method(c_connect, "lookup_domain_by_uuid",
                     libvirt_connect_lookup_domain_by_uuid, 1);
    rb_define_const(c_connect, "DOMAIN_DEFINE_VALIDATE",
                    INT2NUM(VIR_DOMAIN_DEFINE_VALIDATE));
    rb_define_method(c_connect, "define_domain_xml",
                     libvirt_connect_define_domain_xml, -1);

    rb_define_method(c_connect, "domain_xml_from_native",
                     libvirt_connect_domain_xml_from_native, -1);
    rb_define_method(c_connect, "domain_xml_to_native",
                     libvirt_connect_domain_xml_to_native, -1);

    /* Interface lookup/creation methods */
    rb_define_method(c_connect, "num_of_interfaces",
                     libvirt_connect_num_of_interfaces, 0);
    rb_define_method(c_connect, "list_interfaces",
                     libvirt_connect_list_interfaces, 0);
    rb_define_method(c_connect, "num_of_defined_interfaces",
                     libvirt_connect_num_of_defined_interfaces, 0);
    rb_define_method(c_connect, "list_defined_interfaces",
                     libvirt_connect_list_defined_interfaces, 0);
    rb_define_method(c_connect, "lookup_interface_by_name",
                     libvirt_connect_lookup_interface_by_name, 1);
    rb_define_method(c_connect, "lookup_interface_by_mac",
                     libvirt_connect_lookup_interface_by_mac, 1);
    rb_define_method(c_connect, "define_interface_xml",
                     libvirt_connect_define_interface_xml, -1);

    /* Network lookup/creation methods */
    rb_define_method(c_connect, "num_of_networks",
                     libvirt_connect_num_of_networks, 0);
    rb_define_method(c_connect, "list_networks", libvirt_connect_list_networks,
                     0);
    rb_define_method(c_connect, "num_of_defined_networks",
                     libvirt_connect_num_of_defined_networks, 0);
    rb_define_method(c_connect, "list_defined_networks",
                     libvirt_connect_list_defined_networks, 0);
    rb_define_method(c_connect, "lookup_network_by_name",
                     libvirt_connect_lookup_network_by_name, 1);
    rb_define_method(c_connect, "lookup_network_by_uuid",
                     libvirt_connect_lookup_network_by_uuid, 1);
    rb_define_method(c_connect, "create_network_xml",
                     libvirt_connect_create_network_xml, 1);
    rb_define_method(c_connect, "define_network_xml",
                     libvirt_connect_define_network_xml, 1);

    /* Node device lookup/creation methods */
    rb_define_method(c_connect, "num_of_nodedevices",
                     libvirt_connect_num_of_nodedevices, -1);
    rb_define_method(c_connect, "list_nodedevices",
                     libvirt_connect_list_nodedevices, -1);
    rb_define_method(c_connect, "lookup_nodedevice_by_name",
                     libvirt_connect_lookup_nodedevice_by_name, 1);
    rb_define_method(c_connect, "create_nodedevice_xml",
                     libvirt_connect_create_nodedevice_xml, -1);

    /* NWFilter lookup/creation methods */
    rb_define_method(c_connect, "num_of_nwfilters",
                     libvirt_connect_num_of_nwfilters, 0);
    rb_define_method(c_connect, "list_nwfilters",
                     libvirt_connect_list_nwfilters, 0);
    rb_define_method(c_connect, "lookup_nwfilter_by_name",
                     libvirt_connect_lookup_nwfilter_by_name, 1);
    rb_define_method(c_connect, "lookup_nwfilter_by_uuid",
                     libvirt_connect_lookup_nwfilter_by_uuid, 1);
    rb_define_method(c_connect, "define_nwfilter_xml",
                     libvirt_connect_define_nwfilter_xml, 1);

    /* Secret lookup/creation methods */
    rb_define_method(c_connect, "num_of_secrets",
                     libvirt_connect_num_of_secrets, 0);
    rb_define_method(c_connect, "list_secrets",
                     libvirt_connect_list_secrets, 0);
    rb_define_method(c_connect, "lookup_secret_by_uuid",
                     libvirt_connect_lookup_secret_by_uuid, 1);
    rb_define_method(c_connect, "lookup_secret_by_usage",
                     libvirt_connect_lookup_secret_by_usage, 2);
    rb_define_method(c_connect, "define_secret_xml",
                     libvirt_connect_define_secret_xml, -1);

    /* StoragePool lookup/creation methods */
    rb_define_method(c_connect, "num_of_storage_pools",
                     libvirt_connect_num_of_storage_pools, 0);
    rb_define_method(c_connect, "list_storage_pools",
                     libvirt_connect_list_storage_pools, 0);
    rb_define_method(c_connect, "num_of_defined_storage_pools",
                     libvirt_connect_num_of_defined_storage_pools, 0);
    rb_define_method(c_connect, "list_defined_storage_pools",
                     libvirt_connect_list_defined_storage_pools, 0);
    rb_define_method(c_connect, "lookup_storage_pool_by_name",
                     libvirt_connect_lookup_pool_by_name, 1);
    rb_define_method(c_connect, "lookup_storage_pool_by_uuid",
                     libvirt_connect_lookup_pool_by_uuid, 1);
    rb_define_method(c_connect, "create_storage_pool_xml",
                     libvirt_connect_create_pool_xml, -1);
    rb_define_method(c_connect, "define_storage_pool_xml",
                     libvirt_connect_define_pool_xml, -1);
    rb_define_method(c_connect, "discover_storage_pool_sources",
                     libvirt_connect_find_storage_pool_sources, -1);

    rb_define_method(c_connect, "sys_info", libvirt_connect_sys_info, -1);
    rb_define_method(c_connect, "stream", libvirt_connect_stream, -1);

    rb_define_method(c_connect, "interface_change_begin",
                     libvirt_connect_interface_change_begin, -1);
    rb_define_method(c_connect, "interface_change_commit",
                     libvirt_connect_interface_change_commit, -1);
    rb_define_method(c_connect, "interface_change_rollback",
                     libvirt_connect_interface_change_rollback, -1);

    rb_define_method(c_connect, "node_cpu_stats",
                     libvirt_connect_node_cpu_stats, -1);
    rb_define_const(c_connect, "NODE_CPU_STATS_ALL_CPUS",
                    INT2NUM(VIR_NODE_CPU_STATS_ALL_CPUS));
    rb_define_method(c_connect, "node_memory_stats",
                     libvirt_connect_node_memory_stats, -1);
    rb_define_const(c_connect, "NODE_MEMORY_STATS_ALL_CELLS",
                    INT2NUM(VIR_NODE_MEMORY_STATS_ALL_CELLS));

    rb_define_method(c_connect, "save_image_xml_desc",
                     libvirt_connect_save_image_xml_desc, -1);
    rb_define_method(c_connect, "define_save_image_xml",
                     libvirt_connect_define_save_image_xml, -1);

    rb_define_const(c_connect, "NODE_SUSPEND_TARGET_MEM",
                    INT2NUM(VIR_NODE_SUSPEND_TARGET_MEM));
    rb_define_const(c_connect, "NODE_SUSPEND_TARGET_DISK",
                    INT2NUM(VIR_NODE_SUSPEND_TARGET_DISK));
    rb_define_const(c_connect, "NODE_SUSPEND_TARGET_HYBRID",
                    INT2NUM(VIR_NODE_SUSPEND_TARGET_HYBRID));

    rb_define_method(c_connect, "node_suspend_for_duration",
                     libvirt_connect_node_suspend_for_duration, -1);

    rb_define_method(c_connect, "node_memory_parameters",
                     libvirt_connect_node_memory_parameters, -1);
    rb_define_method(c_connect, "node_memory_parameters=",
                     libvirt_connect_node_memory_parameters_equal, 1);

    rb_define_method(c_connect, "node_cpu_map",
                     libvirt_connect_node_cpu_map, -1);
    rb_define_alias(c_connect, "node_get_cpu_map", "node_cpu_map");

    rb_define_method(c_connect, "set_keepalive",
                     libvirt_connect_set_keepalive, 2);
    rb_define_method(c_connect, "keepalive=", libvirt_connect_keepalive_equal,
                     1);

    rb_define_const(c_connect, "LIST_DOMAINS_ACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_ACTIVE));
    rb_define_const(c_connect, "LIST_DOMAINS_INACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_INACTIVE));
    rb_define_const(c_connect, "LIST_DOMAINS_PERSISTENT",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_PERSISTENT));
    rb_define_const(c_connect, "LIST_DOMAINS_TRANSIENT",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_TRANSIENT));
    rb_define_const(c_connect, "LIST_DOMAINS_RUNNING",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_RUNNING));
    rb_define_const(c_connect, "LIST_DOMAINS_PAUSED",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_PAUSED));
    rb_define_const(c_connect, "LIST_DOMAINS_SHUTOFF",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_SHUTOFF));
    rb_define_const(c_connect, "LIST_DOMAINS_OTHER",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_OTHER));
    rb_define_const(c_connect, "LIST_DOMAINS_MANAGEDSAVE",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_MANAGEDSAVE));
    rb_define_const(c_connect, "LIST_DOMAINS_NO_MANAGEDSAVE",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_NO_MANAGEDSAVE));
    rb_define_const(c_connect, "LIST_DOMAINS_AUTOSTART",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_AUTOSTART));
    rb_define_const(c_connect, "LIST_DOMAINS_NO_AUTOSTART",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_NO_AUTOSTART));
    rb_define_const(c_connect, "LIST_DOMAINS_HAS_SNAPSHOT",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_HAS_SNAPSHOT));
    rb_define_const(c_connect, "LIST_DOMAINS_NO_SNAPSHOT",
                    INT2NUM(VIR_CONNECT_LIST_DOMAINS_NO_SNAPSHOT));
    rb_define_method(c_connect, "list_all_domains",
                     libvirt_connect_list_all_domains, -1);

    rb_define_const(c_connect, "LIST_NETWORKS_ACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_NETWORKS_ACTIVE));
    rb_define_const(c_connect, "LIST_NETWORKS_INACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_NETWORKS_INACTIVE));
    rb_define_const(c_connect, "LIST_NETWORKS_PERSISTENT",
                    INT2NUM(VIR_CONNECT_LIST_NETWORKS_PERSISTENT));
    rb_define_const(c_connect, "LIST_NETWORKS_TRANSIENT",
                    INT2NUM(VIR_CONNECT_LIST_NETWORKS_TRANSIENT));
    rb_define_const(c_connect, "LIST_NETWORKS_AUTOSTART",
                    INT2NUM(VIR_CONNECT_LIST_NETWORKS_AUTOSTART));
    rb_define_const(c_connect, "LIST_NETWORKS_NO_AUTOSTART",
                    INT2NUM(VIR_CONNECT_LIST_NETWORKS_NO_AUTOSTART));
    rb_define_method(c_connect, "list_all_networks",
                     libvirt_connect_list_all_networks, -1);

    rb_define_const(c_connect, "LIST_INTERFACES_INACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_INTERFACES_INACTIVE));
    rb_define_const(c_connect, "LIST_INTERFACES_ACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_INTERFACES_ACTIVE));
    rb_define_method(c_connect, "list_all_interfaces",
                     libvirt_connect_list_all_interfaces, -1);

    rb_define_const(c_connect, "LIST_SECRETS_EPHEMERAL",
                    INT2NUM(VIR_CONNECT_LIST_SECRETS_EPHEMERAL));
    rb_define_const(c_connect, "LIST_SECRETS_NO_EPHEMERAL",
                    INT2NUM(VIR_CONNECT_LIST_SECRETS_NO_EPHEMERAL));
    rb_define_const(c_connect, "LIST_SECRETS_PRIVATE",
                    INT2NUM(VIR_CONNECT_LIST_SECRETS_PRIVATE));
    rb_define_const(c_connect, "LIST_SECRETS_NO_PRIVATE",
                    INT2NUM(VIR_CONNECT_LIST_SECRETS_NO_PRIVATE));
    rb_define_method(c_connect, "list_all_secrets",
                     libvirt_connect_list_all_secrets, -1);

    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_SYSTEM",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_SYSTEM));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_PCI_DEV",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_PCI_DEV));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_USB_DEV",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_USB_DEV));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_USB_INTERFACE",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_USB_INTERFACE));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_NET",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_NET));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_SCSI_HOST",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_SCSI_HOST));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_SCSI_TARGET",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_SCSI_TARGET));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_SCSI",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_SCSI));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_STORAGE",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_STORAGE));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_FC_HOST",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_FC_HOST));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_VPORTS",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_VPORTS));
    rb_define_const(c_connect, "LIST_NODE_DEVICES_CAP_SCSI_GENERIC",
                    INT2NUM(VIR_CONNECT_LIST_NODE_DEVICES_CAP_SCSI_GENERIC));
    rb_define_method(c_connect, "list_all_nodedevices",
                     libvirt_connect_list_all_nodedevices, -1);

    rb_define_const(c_connect, "LIST_STORAGE_POOLS_INACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_INACTIVE));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_ACTIVE",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_ACTIVE));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_PERSISTENT",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_PERSISTENT));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_TRANSIENT",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_TRANSIENT));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_AUTOSTART",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_AUTOSTART));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_NO_AUTOSTART",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_NO_AUTOSTART));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_DIR",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_DIR));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_FS",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_FS));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_NETFS",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_NETFS));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_LOGICAL",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_LOGICAL));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_DISK",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_DISK));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_ISCSI",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_ISCSI));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_SCSI",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_SCSI));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_MPATH",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_MPATH));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_RBD",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_RBD));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_SHEEPDOG",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_SHEEPDOG));
    rb_define_method(c_connect, "list_all_storage_pools",
                     libvirt_connect_list_all_storage_pools, -1);
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_GLUSTER",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_GLUSTER));
    rb_define_const(c_connect, "LIST_STORAGE_POOLS_ZFS",
                    INT2NUM(VIR_CONNECT_LIST_STORAGE_POOLS_ZFS));
    rb_define_method(c_connect, "list_all_nwfilters",
                     libvirt_connect_list_all_nwfilters, -1);
    rb_define_method(c_connect, "alive?", libvirt_connect_alive_p, 0);
    rb_define_method(c_connect, "create_domain_xml_with_files",
                     libvirt_connect_create_domain_xml_with_files, -1);
    rb_define_method(c_connect, "qemu_attach", libvirt_connect_qemu_attach, -1);
    rb_define_method(c_connect, "cpu_model_names",
                     libvirt_connect_cpu_model_names, -1);
    rb_define_const(c_connect, "NODE_ALLOC_PAGES_ADD",
                    INT2NUM(VIR_NODE_ALLOC_PAGES_ADD));
    rb_define_const(c_connect, "NODE_ALLOC_PAGES_SET",
                    INT2NUM(VIR_NODE_ALLOC_PAGES_SET));
    rb_define_method(c_connect, "node_alloc_pages",
		     libvirt_connect_node_alloc_pages, -1);
    rb_define_method(c_connect, "domain_capabilities",
                     libvirt_connect_domain_capabilities, -1);
    rb_define_method(c_connect, "node_free_pages",
                     libvirt_connect_node_free_pages, -1);
}
