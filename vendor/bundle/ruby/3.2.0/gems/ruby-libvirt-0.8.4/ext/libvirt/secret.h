#ifndef SECRET_H
#define SECRET_H

void ruby_libvirt_secret_init(void);

VALUE ruby_libvirt_secret_new(virSecretPtr s, VALUE conn);

#endif
