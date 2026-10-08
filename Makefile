obj-m += acer-wmi.o

# Version affichée par « modinfo acer_wmi » (fichier VERSION)
ACER_PH315_VERSION := $(shell cat $(src)/VERSION 2>/dev/null || echo dev)
ccflags-y += -DACER_PH315_VERSION='"$(ACER_PH315_VERSION)"'

KDIR ?= /lib/modules/$(shell uname -r)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
