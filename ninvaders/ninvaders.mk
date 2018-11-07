################################################################################
#
# nInvaders
#
################################################################################

NINVADERS_VERSION = 0.1.1
NINVADERS_SOURCE = ninvaders-$(NINVADERS_VERSION).tar.gz
NINVADERS_SITE = https://downloads.sourceforge.net/project/ninvaders/ninvaders/$(NINVADERS_VERSION)
NINVADERS_DEPENDENCIES = ncurses

define NINVADERS_BUILD_CMDS
    $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) all
endef

define NINVADERS_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/nInvaders $(TARGET_DIR)/usr/bin
endef

#Add user ninvaders
define NINVADERS_USERS
    ninvaders -1 ninvaders -1 !=ninvaders /home - -
endef

$(eval $(generic-package))

