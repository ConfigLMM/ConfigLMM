#ifndef CONNECT_H
#define CONNECT_H

void ruby_libvirt_connect_init(void);

VALUE ruby_libvirt_connect_new(virConnectPtr p);
virConnectPtr ruby_libvirt_connect_get(VALUE s);
VALUE ruby_libvirt_conn_attr(VALUE s);

extern VALUE c_node_security_model;

#endif
