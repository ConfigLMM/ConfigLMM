#ifndef STREAM_H
#define STREAM_H

void ruby_libvirt_stream_init(void);

VALUE ruby_libvirt_stream_new(virStreamPtr s, VALUE conn);
virStreamPtr ruby_libvirt_stream_get(VALUE s);

#endif
