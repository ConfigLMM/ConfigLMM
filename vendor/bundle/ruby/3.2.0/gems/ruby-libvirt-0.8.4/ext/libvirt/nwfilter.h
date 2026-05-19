#ifndef NWFILTER_H
#define NWFILTER_H

void ruby_libvirt_nwfilter_init(void);

VALUE ruby_libvirt_nwfilter_new(virNWFilterPtr n, VALUE conn);

#endif
