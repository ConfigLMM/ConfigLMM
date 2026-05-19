/*
 * common.c: Common utilities for the ruby libvirt bindings
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

#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include <stdio.h>
#include <ruby.h>
#include <ruby/encoding.h>
#include <ruby/st.h>
#include <libvirt/libvirt.h>
#include <libvirt/virterror.h>
#include "common.h"
#include "connect.h"

struct rb_exc_new2_arg {
    VALUE error;
    char *msg;
};

static VALUE ruby_libvirt_exc_new2_wrap(VALUE arg)
{
    struct rb_exc_new2_arg *e = (struct rb_exc_new2_arg *)arg;
    VALUE ruby_msg = ruby_libvirt_str_new2_wrap((VALUE)&e->msg);

    return rb_exc_new3(e->error, ruby_msg);
}

VALUE ruby_libvirt_ary_new2_wrap(VALUE arg)
{
    return rb_ary_new2(*((int *)arg));
}

VALUE ruby_libvirt_ary_push_wrap(VALUE arg)
{
    struct ruby_libvirt_ary_push_arg *e = (struct ruby_libvirt_ary_push_arg *)arg;

    return rb_ary_push(e->arr, e->value);
}

VALUE ruby_libvirt_ary_store_wrap(VALUE arg)
{
    struct ruby_libvirt_ary_store_arg *e = (struct ruby_libvirt_ary_store_arg *)arg;

    rb_ary_store(e->arr, e->index, e->elem);

    return Qnil;
}

VALUE ruby_libvirt_str_new2_wrap(VALUE arg)
{
    char **str = (char **)arg;
    VALUE ruby_msg = rb_str_new2(*str);
    int enc = rb_enc_find_index("UTF-8");

    rb_enc_associate_index(ruby_msg, enc);
    return ruby_msg;
}

VALUE ruby_libvirt_str_new_wrap(VALUE arg)
{
    struct ruby_libvirt_str_new_arg *e = (struct ruby_libvirt_str_new_arg *)arg;

    return rb_str_new(e->val, e->size);
}

VALUE ruby_libvirt_hash_aset_wrap(VALUE arg)
{
    struct ruby_libvirt_hash_aset_arg *e = (struct ruby_libvirt_hash_aset_arg *)arg;

    return rb_hash_aset(e->hash, rb_str_new2(e->name), e->val);
}

VALUE ruby_libvirt_str_new2_and_ary_store_wrap(VALUE arg)
{
    struct ruby_libvirt_str_new2_and_ary_store_arg *e = (struct ruby_libvirt_str_new2_and_ary_store_arg *)arg;

    rb_ary_store(e->arr, e->index, rb_str_new2(e->value));

    return Qnil;
}

void ruby_libvirt_raise_error_if(const int condition, VALUE error,
                                 const char *method, virConnectPtr conn)
{
    VALUE ruby_errinfo;
    virErrorPtr err;
    char *msg;
    int rc;
    struct rb_exc_new2_arg arg;
    int exception = 0;

    if (!condition) {
        return;
    }

    if (conn == NULL) {
        err = virGetLastError();
    }
    else {
        err = virConnGetLastError(conn);
    }

    if (err != NULL && err->message != NULL) {
        rc = asprintf(&msg, "Call to %s failed: %s", method, err->message);
    }
    else {
        rc = asprintf(&msg, "Call to %s failed", method);
    }

    if (rc < 0) {
        /* there's not a whole lot we can do here; try to raise an
         * out-of-memory message */
        rb_memerror();
    }

    arg.error = error;
    arg.msg = msg;
    ruby_errinfo = rb_protect(ruby_libvirt_exc_new2_wrap, (VALUE)&arg,
                              &exception);
    free(msg);
    if (exception) {
        rb_jump_tag(exception);
    }

    rb_iv_set(ruby_errinfo, "@libvirt_function_name", rb_str_new2(method));

    if (err != NULL) {
        rb_iv_set(ruby_errinfo, "@libvirt_code", INT2NUM(err->code));
        rb_iv_set(ruby_errinfo, "@libvirt_component", INT2NUM(err->domain));
        rb_iv_set(ruby_errinfo, "@libvirt_level", INT2NUM(err->level));
        if (err->message != NULL) {
            rb_iv_set(ruby_errinfo, "@libvirt_message",
                      ruby_libvirt_str_new2_wrap((VALUE)&err->message));
        }
    }

    rb_exc_raise(ruby_errinfo);
};

char *ruby_libvirt_get_cstring_or_null(VALUE arg)
{
    if (TYPE(arg) == T_NIL) {
        return NULL;
    }
    else if (TYPE(arg) == T_STRING) {
        return StringValueCStr(arg);
    }
    else {
        rb_raise(rb_eTypeError, "wrong argument type (expected String or nil)");
    }

    return NULL;
}

VALUE ruby_libvirt_new_class(VALUE klass, void *ptr, VALUE conn,
                             RUBY_DATA_FUNC free_func)
{
    VALUE result;
    result = Data_Wrap_Struct(klass, NULL, free_func, ptr);
    rb_iv_set(result, "@connection", conn);
    return result;
}

int ruby_libvirt_is_symbol_or_proc(VALUE handle)
{
    return ((strcmp(rb_obj_classname(handle), "Symbol") == 0) ||
            (strcmp(rb_obj_classname(handle), "Proc") == 0));
}

/* this is an odd function, because it has massive side-effects.
 * The intended usage of this function is after a list has been collected
 * from a libvirt list function, and now we want to make an array out of it.
 * However, it is possible that the act of creating an array causes an
 * exception, which would lead to a memory leak of the values we got from
 * libvirt.  Therefore, this function not only wraps all of the relevant
 * calls with rb_protect, it also frees every individual entry in list after
 * it is done with it.  Freeing list itself is left to the callers.
 */
VALUE ruby_libvirt_generate_list(int num, char **list)
{
    VALUE result;
    int exception = 0;
    int i, j;
    struct ruby_libvirt_str_new2_and_ary_store_arg arg;

    i = 0;

    result = rb_protect(ruby_libvirt_ary_new2_wrap, (VALUE)&num, &exception);
    if (exception) {
        goto exception;
    }
    for (i = 0; i < num; i++) {
        arg.arr = result;
        arg.index = i;
        arg.value = list[i];
        rb_protect(ruby_libvirt_str_new2_and_ary_store_wrap, (VALUE)&arg,
                   &exception);
        if (exception) {
            goto exception;
        }

        xfree(list[i]);
    }

    return result;

exception:
    for (j = i; j < num; j++) {
        xfree(list[j]);
    }
    rb_jump_tag(exception);

    /* not needed, but here to shut the compiler up */
    return Qnil;
}

void ruby_libvirt_typed_params_to_hash(void *voidparams, int i, VALUE hash)
{
    virTypedParameterPtr params = (virTypedParameterPtr)voidparams;
    VALUE val;

    switch (params[i].type) {
    case VIR_TYPED_PARAM_INT:
        val = INT2NUM(params[i].value.i);
        break;
    case VIR_TYPED_PARAM_UINT:
        val = UINT2NUM(params[i].value.ui);
        break;
    case VIR_TYPED_PARAM_LLONG:
        val = LL2NUM(params[i].value.l);
        break;
    case VIR_TYPED_PARAM_ULLONG:
        val = ULL2NUM(params[i].value.ul);
        break;
    case VIR_TYPED_PARAM_DOUBLE:
        val = rb_float_new(params[i].value.d);
        break;
    case VIR_TYPED_PARAM_BOOLEAN:
        val = (params[i].value.b == 0) ? Qfalse : Qtrue;
        break;
    case VIR_TYPED_PARAM_STRING:
        val = rb_str_new2(params[i].value.s);
        break;
    default:
        rb_raise(rb_eArgError, "Invalid parameter type");
    }

    rb_hash_aset(hash, rb_str_new2(params[i].field), val);
}

VALUE ruby_libvirt_get_parameters(VALUE d, unsigned int flags, void *opaque,
                                  unsigned int typesize,
                                  const char *(*nparams_cb)(VALUE d,
                                                            unsigned int flags,
                                                            void *opaque,
                                                            int *nparams),
                                  const char *(*get_cb)(VALUE d,
                                                        unsigned int flags,
                                                        void *voidparams,
                                                        int *nparams,
                                                        void *opaque),
                                  void (*hash_set)(void *voidparams, int i,
                                                   VALUE result))
{
    int nparams = 0;
    void *params;
    VALUE result;
    const char *errname;
    int i;

    errname = nparams_cb(d, flags, opaque, &nparams);
    ruby_libvirt_raise_error_if(errname != NULL, e_RetrieveError, errname,
                                ruby_libvirt_connect_get(d));

    result = rb_hash_new();

    if (nparams == 0) {
        return result;
    }

    params = alloca(typesize * nparams);

    errname = get_cb(d, flags, params, &nparams, opaque);
    ruby_libvirt_raise_error_if(errname != NULL, e_RetrieveError, errname,
                                ruby_libvirt_connect_get(d));

    for (i = 0; i < nparams; i++) {
        hash_set(params, i, result);
    }

    return result;
}

VALUE ruby_libvirt_get_typed_parameters(VALUE d, unsigned int flags,
                                        void *opaque,
                                        const char *(*nparams_cb)(VALUE d,
                                                                  unsigned int flags,
                                                                  void *opaque,
                                                                  int *nparams),
                                        const char *(*get_cb)(VALUE d,
                                                              unsigned int flags,
                                                              void *params,
                                                              int *nparams,
                                                              void *opaque))
{
    return ruby_libvirt_get_parameters(d, flags, opaque,
                                       sizeof(virTypedParameter), nparams_cb,
                                       get_cb,
                                       ruby_libvirt_typed_params_to_hash);
}

void ruby_libvirt_assign_hash_and_flags(VALUE in, VALUE *hash, VALUE *flags)
{
    if (TYPE(in) == T_HASH) {
        *hash = in;
        *flags = INT2NUM(0);
    }
    else if (TYPE(in) == T_ARRAY) {
        if (RARRAY_LEN(in) != 2) {
            rb_raise(rb_eArgError, "wrong number of arguments (%ld for 1 or 2)",
                     RARRAY_LEN(in));
        }
        *hash = rb_ary_entry(in, 0);
        *flags = rb_ary_entry(in, 1);
    }
    else {
        rb_raise(rb_eTypeError, "wrong argument type (expected Hash or Array)");
    }
}

int ruby_libvirt_typed_parameter_assign(VALUE key, VALUE val, VALUE in)
{
    struct ruby_libvirt_parameter_assign_args *args = (struct ruby_libvirt_parameter_assign_args *)in;
    char *keyname;
    unsigned int i;
    int found;

    keyname = StringValueCStr(key);

    found = 0;
    for (i = 0; i < args->num_allowed; i++) {
        if (strcmp(args->allowed[i].name, keyname) == 0) {
            args->params[args->i].type = args->allowed[i].type;
            switch (args->params[args->i].type) {
            case VIR_TYPED_PARAM_INT:
                args->params[i].value.i = NUM2INT(val);
                break;
            case VIR_TYPED_PARAM_UINT:
                args->params[i].value.ui = NUM2UINT(val);
                break;
            case VIR_TYPED_PARAM_LLONG:
                args->params[i].value.l = NUM2LL(val);
                break;
            case VIR_TYPED_PARAM_ULLONG:
                args->params[args->i].value.ul = NUM2ULL(val);
                break;
            case VIR_TYPED_PARAM_DOUBLE:
                args->params[i].value.d = NUM2DBL(val);
                break;
            case VIR_TYPED_PARAM_BOOLEAN:
                args->params[i].value.b = (val == Qtrue) ? 1 : 0;
                break;
            case VIR_TYPED_PARAM_STRING:
                args->params[args->i].value.s = StringValueCStr(val);
                break;
            default:
                rb_raise(rb_eArgError, "Invalid parameter type");
            }
            /* ensure that the field is NULL-terminated */
            args->params[args->i].field[VIR_TYPED_PARAM_FIELD_LENGTH - 1] = '\0';
            strncpy(args->params[args->i].field, keyname,
                    VIR_TYPED_PARAM_FIELD_LENGTH - 1);
            (args->i)++;
            found = 1;
            break;
        }
    }

    if (!found) {
        rb_raise(rb_eArgError, "Unknown key %s", keyname);
    }

    return ST_CONTINUE;
}

VALUE ruby_libvirt_set_typed_parameters(VALUE d, VALUE input,
                                        unsigned int flags, void *opaque,
                                        struct ruby_libvirt_typed_param *allowed,
                                        unsigned int num_allowed,
                                        const char *(*set_cb)(VALUE d,
                                                              unsigned int flags,
                                                              virTypedParameterPtr params,
                                                              int nparams,
                                                              void *opaque))
{
    const char *errname;
    struct ruby_libvirt_parameter_assign_args args;
    unsigned long hashsize;

    /* make sure input is a hash */
    Check_Type(input, T_HASH);

    hashsize = RHASH_SIZE(input);

    if (hashsize == 0) {
        return Qnil;
    }

    args.allowed = allowed;
    args.num_allowed = num_allowed;
    args.params = alloca(sizeof(virTypedParameter) * hashsize);
    args.i = 0;

    rb_hash_foreach(input, ruby_libvirt_typed_parameter_assign, (VALUE)&args);

    errname = set_cb(d, flags, args.params, args.i, opaque);
    ruby_libvirt_raise_error_if(errname != NULL, e_RetrieveError, errname,
                                ruby_libvirt_connect_get(d));

    return Qnil;
}

unsigned int ruby_libvirt_value_to_uint(VALUE in)
{
    if (NIL_P(in)) {
        return 0;
    }

    return NUM2UINT(in);
}

int ruby_libvirt_value_to_int(VALUE in)
{
    if (NIL_P(in)) {
        return 0;
    }

    return NUM2INT(in);
}

unsigned long ruby_libvirt_value_to_ulong(VALUE in)
{
    if (NIL_P(in)) {
        return 0;
    }

    return NUM2ULONG(in);
}

unsigned long long ruby_libvirt_value_to_ulonglong(VALUE in)
{
    if (NIL_P(in)) {
        return 0;
    }

    return NUM2ULL(in);
}

int ruby_libvirt_get_maxcpus(virConnectPtr conn)
{
    int maxcpu = -1;
    virNodeInfo nodeinfo;

    maxcpu = virNodeGetCPUMap(conn, NULL, NULL, 0);
    if (maxcpu < 0) {
        /* fall back to nodeinfo */
        ruby_libvirt_raise_error_if(virNodeGetInfo(conn, &nodeinfo) < 0,
                                    e_RetrieveError, "virNodeGetInfo", conn);

        maxcpu = VIR_NODEINFO_MAXCPUS(nodeinfo);
    }

    return maxcpu;
}

/* For classes where Ruby objects are just wrappers around C pointers,
 * the only acceptable way to create new instances is to use
 * Connect.create_domain_xml and similar. The use of Domain.new and
 * friends is explicitly disallowed by providing this functions as
 * implementation when defining the class
 */
VALUE ruby_libvirt_new_not_allowed(int argc, VALUE *argv, VALUE obj)
{
    rb_raise(rb_eTypeError, "Not allowed for this class");
}
