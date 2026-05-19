/*
 * secret.c: virSecret methods
 *
 * Copyright (C) 2010 Red Hat Inc.
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

static VALUE c_secret;

static void secret_free(void *s)
{
    ruby_libvirt_free_struct(Secret, s);
}

static virSecretPtr secret_get(VALUE s)
{
    ruby_libvirt_get_struct(Secret, s);
}

VALUE ruby_libvirt_secret_new(virSecretPtr s, VALUE conn)
{
    return ruby_libvirt_new_class(c_secret, s, conn, secret_free);
}

/*
 * call-seq:
 *   secret.uuid -> String
 *
 * Call virSecretGetUUIDString[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretGetUUIDString]
 * to retrieve the UUID for this secret.
 */
static VALUE libvirt_secret_uuid(VALUE s)
{
    ruby_libvirt_generate_uuid(virSecretGetUUIDString,
                               ruby_libvirt_connect_get(s), secret_get(s));
}

/*
 * call-seq:
 *   secret.usagetype -> Fixnum
 *
 * Call virSecretGetUsageType[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretGetUsageType]
 * to retrieve the usagetype for this secret.
 */
static VALUE libvirt_secret_usagetype(VALUE s)
{
    ruby_libvirt_generate_call_int(virSecretGetUsageType,
                                   ruby_libvirt_connect_get(s),
                                   secret_get(s));
}

/*
 * call-seq:
 *   secret.usageid -> String
 *
 * Call virSecretGetUsageID[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretGetUsageID]
 * to retrieve the usageid for this secret.
 */
static VALUE libvirt_secret_usageid(VALUE s)
{
    ruby_libvirt_generate_call_string(virSecretGetUsageID,
                                      ruby_libvirt_connect_get(s), 0,
                                      secret_get(s));
}

/*
 * call-seq:
 *   secret.xml_desc(flags=0) -> String
 *
 * Call virSecretGetXMLDesc[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretGetXMLDesc]
 * to retrieve the XML for this secret.
 */
static VALUE libvirt_secret_xml_desc(int argc, VALUE *argv, VALUE s)
{
    VALUE flags = RUBY_Qnil;

    rb_scan_args(argc, argv, "01", &flags);

    ruby_libvirt_generate_call_string(virSecretGetXMLDesc,
                                      ruby_libvirt_connect_get(s), 1,
                                      secret_get(s),
                                      ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   secret.set_value(value, flags=0) -> nil
 *
 * Call virSecretSetValue[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretSetValue]
 * to set a new value in this secret.  Deprecated; use secret.value= instead.
 */
static VALUE libvirt_secret_set_value(int argc, VALUE *argv, VALUE s)
{
    VALUE flags = RUBY_Qnil, value;

    rb_scan_args(argc, argv, "11", &value, &flags);

    StringValue(value);

    ruby_libvirt_generate_call_nil(virSecretSetValue,
                                   ruby_libvirt_connect_get(s),
                                   secret_get(s),
                                   (unsigned char *)RSTRING_PTR(value),
                                   RSTRING_LEN(value),
                                   ruby_libvirt_value_to_uint(flags));
}

/*
 * call-seq:
 *   secret.value = value,flags=0
 *
 * Call virSecretSetValue[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretSetValue]
 * to set a new value in this secret.
 */
static VALUE libvirt_secret_value_equal(VALUE s, VALUE in)
{
    VALUE flags, value;

    if (TYPE(in) == T_STRING) {
        value = in;
        flags = INT2NUM(0);
    }
    else if (TYPE(in) == T_ARRAY) {
        if (RARRAY_LEN(in) != 2) {
            rb_raise(rb_eArgError, "wrong number of arguments (%ld for 2)",
                     RARRAY_LEN(in));
        }
        value = rb_ary_entry(in, 0);
        flags = rb_ary_entry(in, 1);
    }
    else {
        rb_raise(rb_eTypeError,
                 "wrong argument type (expected Number or Array)");
    }

    StringValue(value);

    ruby_libvirt_generate_call_nil(virSecretSetValue,
                                   ruby_libvirt_connect_get(s),
                                   secret_get(s),
                                   (unsigned char *)RSTRING_PTR(value),
                                   RSTRING_LEN(value), NUM2UINT(flags));
}

/*
 * call-seq:
 *   secret.value(flags=0) -> String
 *
 * Call virSecretGetValue[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretGetValue]
 * to retrieve the value from this secret.
 */
static VALUE libvirt_secret_value(int argc, VALUE *argv, VALUE s)
{
    VALUE flags = RUBY_Qnil, ret;
    unsigned char *val;
    size_t value_size;
    int exception = 0;
    struct ruby_libvirt_str_new_arg args;

    rb_scan_args(argc, argv, "01", &flags);

    val = virSecretGetValue(secret_get(s), &value_size,
                            ruby_libvirt_value_to_uint(flags));

    ruby_libvirt_raise_error_if(val == NULL, e_RetrieveError,
                                "virSecretGetValue",
                                ruby_libvirt_connect_get(s));

    args.val = (char *)val;
    args.size = value_size;
    ret = rb_protect(ruby_libvirt_str_new_wrap, (VALUE)&args, &exception);
    free(val);
    if (exception) {
        rb_jump_tag(exception);
    }

    return ret;
}

/*
 * call-seq:
 *   secret.undefine -> nil
 *
 * Call virSecretUndefine[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretUndefine]
 * to undefine this secret.
 */
static VALUE libvirt_secret_undefine(VALUE s)
{
    ruby_libvirt_generate_call_nil(virSecretUndefine,
                                   ruby_libvirt_connect_get(s),
                                   secret_get(s));
}

/*
 * call-seq:
 *   secret.free -> nil
 *
 * Call virSecretFree[https://libvirt.org/html/libvirt-libvirt-secret.html#virSecretFree]
 * to free this secret.  After this call the secret object is no longer valid.
 */
static VALUE libvirt_secret_free(VALUE s)
{
    ruby_libvirt_generate_call_free(Secret, s);
}

/*
 * Class Libvirt::Secret
 */
void ruby_libvirt_secret_init(void)
{
    c_secret = rb_define_class_under(m_libvirt, "Secret", rb_cObject);
    rb_undef_alloc_func(c_secret);
    rb_define_singleton_method(c_secret, "new",
                               ruby_libvirt_new_not_allowed, -1);

    rb_define_attr(c_secret, "connection", 1, 0);

    rb_define_const(c_secret, "USAGE_TYPE_VOLUME",
                    INT2NUM(VIR_SECRET_USAGE_TYPE_VOLUME));

    rb_define_const(c_secret, "USAGE_TYPE_CEPH",
                    INT2NUM(VIR_SECRET_USAGE_TYPE_CEPH));
    rb_define_const(c_secret, "USAGE_TYPE_ISCSI",
                    INT2NUM(VIR_SECRET_USAGE_TYPE_ISCSI));
    rb_define_const(c_secret, "USAGE_TYPE_NONE",
                    INT2NUM(VIR_SECRET_USAGE_TYPE_NONE));

    /* Secret object methods */
    rb_define_method(c_secret, "uuid", libvirt_secret_uuid, 0);
    rb_define_method(c_secret, "usagetype", libvirt_secret_usagetype, 0);
    rb_define_method(c_secret, "usageid", libvirt_secret_usageid, 0);
    rb_define_method(c_secret, "xml_desc", libvirt_secret_xml_desc, -1);
    rb_define_method(c_secret, "set_value", libvirt_secret_set_value, -1);
    rb_define_method(c_secret, "value=", libvirt_secret_value_equal, 1);
    rb_define_method(c_secret, "value", libvirt_secret_value, -1);
    rb_define_alias(c_secret, "get_value", "value");
    rb_define_method(c_secret, "undefine", libvirt_secret_undefine, 0);
    rb_define_method(c_secret, "free", libvirt_secret_free, 0);
}
