# Makefile for wpLargeImageViewer

MAKEFLAGS += --warn-undefined-variables

WP_INSTALL_DIR = /Users/Dave/projects/daveburnsphoto.com
WP_PLUGIN_DIR = $(WP_INSTALL_DIR)/wp-content/plugins

PLUGIN_SLUG = wp-largeimageviewer
PLUGIN_DIR = $(WP_PLUGIN_DIR)/$(PLUGIN_SLUG)
PLUGIN_JS_DIR = $(PLUGIN_DIR)/js

PLUGIN_SRC = $(PLUGIN_SLUG).php readme.txt
PLUGIN_JS_SRC = js/jquery.largeimageviewer.js js/jquery.largeimageviewer.min.js

.PHONY: install

install: $(PLUGIN_DIR)
	cp $(PLUGIN_SRC) $(PLUGIN_DIR)
	cp $(PLUGIN_JS_SRC) $(PLUGIN_JS_DIR)

$(PLUGIN_DIR):
	mkdir -p $(PLUGIN_DIR) $(PLUGIN_JS_DIR)
