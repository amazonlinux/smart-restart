DEST_DIR?=/
PREFIX?=/usr/bin
HOOK_DIR=

MAJOR=0
MINOR=2

VERSION=v$(MAJOR).$(MINOR)

$(info Building version $(VERSION))

# As long as no-one convince us otherwise, we're assuming the system is using DNF as 
# it's default package manager.
HOOK_DIR=/etc/dnf/plugins/post-transaction-actions.d
HOOK_COMMAND=in

ifeq ($(pkg_manager),yum)
HOOK_DIR=/etc/yum/post-actions
HOOK_COMMAND=install
endif

CONF_DIR=/etc/smart-restart-conf.d

HOOK_ACTION=install.action
HOOK_ACTION_TEMPLATE=$(HOOK_ACTION).in
DENYLIST_CONF_FILE=default-denylist
MAN_FILE=smart-restart.man1
MAN_FILE_LOCATION=/usr/share/man/man1


.PHONY: all srpm install

# We're not yet building anything. 
all:
	$(error There is nothing to build here yet. Please use "make install" to install the config files)

srpm: sources

sources: 
	tar czf ./smart-restart-$(VERSION).tar.gz --transform 's,^,smart-restart-$(VERSION)/,' bin conf Makefile smart-restart.spec doc/smart-restart.man1

install: 
	$(info Dest: $(DEST_DIR))
	$(info Prefix: $(PREFIX))
	$(info Hook dir: $(HOOK_DIR))
	$(info PWD: $(shell pwd))

	mkdir -p $(DEST_DIR)$(CONF_DIR)
	mkdir -p $(DEST_DIR)$(PREFIX)
	mkdir -p $(DEST_DIR)$(HOOK_DIR)
	mkdir -p $(DEST_DIR)$(MAN_FILE_LOCATION)

	cp bin/*.sh $(DEST_DIR)$(PREFIX)
	cp conf/$(DENYLIST_CONF_FILE) $(DEST_DIR)$(CONF_DIR)
	cp doc/$(MAN_FILE) $(DEST_DIR)$(MAN_FILE_LOCATION)/$(MAN_FILE)

	sed -e "s%#COMMAND#%$(HOOK_COMMAND)%g" -e "s%#PREFIX#%$(PREFIX)%g" conf/$(HOOK_ACTION_TEMPLATE) > $(DEST_DIR)$(HOOK_DIR)/$(HOOK_ACTION)

test:
	$(MAKE) -C tests

