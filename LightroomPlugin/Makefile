# Makefile for LrLargeImageViewer

#MAKEFLAGS += -s
MAKEFLAGS += --warn-undefined-variables

SHELL = /bin/bash
LUAC=/usr/local/bin/luac
ZIP=/usr/bin/zip

NAME          = LrLargeImageViewer
DEVDIR        = $(NAME).lrdevplugin
PLUGIN_NAME   = $(NAME).lrplugin
BUILDDIR      = build/$(PLUGIN_NAME)

# Locations and files
EXTERNAL_LIV_DIR = /Users/Dave/projects/LIV/jqLargeImageViewer
EXTERNAL_LIVJS_FILES = $(notdir $(wildcard $(EXTERNAL_LIV_DIR)/jquery.largeimageviewer*.js))
DEVDIR_LIVJS_FILES = $(addprefix $(DEVDIR)/, $(EXTERNAL_LIVJS_FILES))

LUA_FILES     = $(notdir $(wildcard $(DEVDIR)/*.lua))
LUAC_FILES    = $(addprefix $(BUILDDIR)/, $(LUA_FILES:=c))
NONLUA_FILES  = $(notdir $(filter-out %.lua, $(wildcard $(DEVDIR)/*)))
ifeq (,$(findstring jquery, $(NONLUA_FILES)))
NONLUA_FILES += $(notdir $(DEVDIR_LIVJS_FILES))
endif
TARGET_NONLUA_FILES = $(addprefix $(BUILDDIR)/, $(NONLUA_FILES))

VERSION       = $(shell cat $(DEVDIR)/Info.lua | grep VERSION | tr -d ' ' | cut -d "{" -f 2 | cut -d "}" -f 1)
MAJOR         = $(shell echo $(VERSION) | cut -d "," -f 1 | cut -d "=" -f 2)
MINOR         = $(shell echo $(VERSION) | cut -d "," -f 2 | cut -d "=" -f 2)
REVISION      = $(shell echo $(VERSION) | cut -d "," -f 3 | cut -d "=" -f 2)
BUILD         = $(shell echo $(VERSION) | cut -d "," -f 4 | cut -d "=" -f 2)

ZIPFILE = $(BUILDDIR)/$(NAME)-$(MAJOR).$(MINOR).$(REVISION).$(BUILD).zip

.PHONY: debug clean package updatelivjs

debug:
	@echo $(NONLUA_FILES) | tr ' ' '\n'

clean:
	-rm -rf $(BUILDDIR)/*
	-rm -f $(DEVDIR_LIVJS_FILES)

package: $(ZIPFILE)

updatelivjs: $(DEVDIR_LIVJS_FILES)

$(ZIPFILE): $(BUILDDIR) $(LUAC_FILES) $(TARGET_NONLUA_FILES)
	-rm -f $@
	cd build && $(ZIP) -r --quiet ../$@ $(PLUGIN_NAME)

$(BUILDDIR):
	-mkdir -p $(BUILDDIR)

$(BUILDDIR)/%.luac: $(DEVDIR)/%.lua
	$(LUAC) -o $@ $<


define COPY_FILE
$(3)/$(1) : $(2)/$(1)
	cp $$< $$@
endef

$(foreach filename, $(NONLUA_FILES), $(eval $(call COPY_FILE,$(filename),$(DEVDIR),$(BUILDDIR))))

$(foreach filename, $(EXTERNAL_LIVJS_FILES), $(eval $(call COPY_FILE,$(filename),$(EXTERNAL_LIV_DIR),$(DEVDIR))))
