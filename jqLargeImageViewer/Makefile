# Makefile for jqLargeImageViewer

MAKEFLAGS += --warn-undefined-variables

UGLIFYJS=uglifyjs

# full docs for options located here: https://github.com/mishoo/UglifyJS2
UGLIFYJS_OPTIONS=-m

CURRENTDEVDIR=/Users/Dave/projects/daveburnsphoto.com/panoramas/africa/TarangireRiverOverlook/
WPPLUGINDIR=/Users/Dave/projects/LIV/WordPressPlugin

JS=jquery.largeimageviewer.js
MINJS=$(JS:.js=.min.js)

.PHONY: clean install

install: $(MINJS)
	cp $(JS) $(MINJS) $(WPPLUGINDIR)/js
	cp $(JS) $(MINJS) $(CURRENTDEVDIR)

$(MINJS): $(JS)
	$(UGLIFYJS) $< -o $@ $(UGLIFYJS_OPTIONS)

clean:
	rm -f $(MINJS)


#            <!--or WHITESPACE_ONLY or ADVANCED_OPTIMIZATIONS-->
#            <!--<arg line="- -compilation_level SIMPLE_OPTIMIZATIONS" />-->
#            <arg line="--externs externs/google_maps_api_v3_11.js" />
