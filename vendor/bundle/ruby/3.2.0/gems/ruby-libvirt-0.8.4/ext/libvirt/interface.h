#ifndef INTERFACE_H
#define INTERFACE_H

void ruby_libvirt_interface_init(void);

VALUE ruby_libvirt_interface_new(virInterfacePtr i, VALUE conn);

#endif
