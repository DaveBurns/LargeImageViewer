// Large Image Viewer
//
// jQuery plugin
//
// Copyright 2016 David F. Burns


(function( $ ) {
    "use strict";

    // prevent duplicate include of this file
    if ( typeof $.fn.largeImageViewer !== 'undefined' ) {
        return this;
    }

    if ( typeof google.maps === 'undefined' ) {
        window.console && window.console.log && console.log( 'LargeImageViewer: Not loading because Google Maps not detected.' );
        return this;
    }

    $.fn.extend( {
        largeImageViewer: function( options ) {
            // using 'var' creates private variables
            var map = null;
            var imageExtents = null;
            var log = null;
            var defaults = {
                debug: false,
                log_id: '[element with no id]',
                image_width: 0,
                image_height: 0,
                image_tile_size: 256,
                initial_x: 'center',
                initial_y: 'center',
                initial_zoom: 'fit',
                tile_url_func: imageMagickGetTileURL,
                background_color: '#000',
                tile_path: 'tiles',
                // fullscreen_control: false,  <-- do not specify a default because GMap's default is true or false depending on platform. But they don't offer "auto" :-(
                title_top: {},
                title_bottom: {},
                copyright_text: '',
                copyright_url: '',
                copyright_css: 'liv_copyright',
                no_css: false,
            };


            // TODO: is there a better pattern for getting this removed from minimized builds?
            // TRY: http://stackoverflow.com/questions/2934509/exclude-debug-javascript-code-during-minification/
            function LIVLogger( item ) {
                if ( ! options.debug ) { return; }
                if ( window.console ) {
                    if ( typeof item === 'object' ) {
                        if ( window.console.dir ) {
                            console.dir( item );
                        }
                    }
                    else {
                        console.log( item );
                    }
                }
            }


            // -------------- Define LargeImageProjection -------------------
            // The gist of this new Projection type is that the extent is the size of the
            // image in pixels at that zoom level. The midpoint of the image has coord (0,0).
            // The lower left has coord (-50, -50) and the upper right has coord (50, 50).

            // Constructor
            function LIVProjection(worldWidth, worldHeight) {
                this.worldWidth = worldWidth;
                this.worldHeight = worldHeight;
                //		log( this );
            }

            // Override base google.maps.Projection functions
            LIVProjection.prototype.fromPointToLatLng = function( point, nowrap ) {
                var lng = (point.x / this.worldWidth) * 100 - 50;
                var lat = -(point.y / this.worldHeight) * 100 + 50;
                return new google.maps.LatLng(lat, lng, nowrap);
            };

            LIVProjection.prototype.fromLatLngToPoint = function( latlng ) {
                var x = this.worldWidth * ((latlng.lng() + 50) / 100);
                var y = -this.worldHeight * ((latlng.lat() - 50) / 100);
                return new google.maps.Point( x, y );
            };
            // --------------------------------------------------------------


            // If the map position is out of range, move it back
            function constrainBounds() {
//              log("-----------constrainBounds()");

                var C = map.getCenter();
                var lng = C.lng(); //if (isNaN(lng)) { log("lng trouble here"); };
                var lat = C.lat(); //if (isNaN(lat)) { log("lat trouble here"); };
                var B = map.getBounds(); // get the bounds of the viewport in coordinates

                // if we're bootstrapping the map, B will not be defined yet
                if ( typeof B === 'undefined' ) {
                    return;
                }

                var sw = B.getSouthWest();
                var ne = B.getNorthEast();
                var span = B.toSpan();

//                log( 'span.lng: ' + span.lng() + ' span.lat: ' + span.lat() );
//                log( 'Bounds: ' + B.toString() );

                // Figure out if the image is outside of the artificial boundaries
                // created by our custom projection object.
                var new_lat = lat;
                var new_lng = lng;

                if ( 100 < span.lng() ) {
//                  log('image width smaller than viewport');
                    new_lng = 0;
                }
                else {
                    if (sw.lng() < -50) {
                        new_lng = -50 + ((ne.lng() - sw.lng()) / 2);
                    }
                    else if (ne.lng() > 50) {
                        new_lng = 50 - ((ne.lng() - sw.lng()) / 2);
                    }
                }

                if (100 < span.lat()) {
//                  log('image height smaller than viewport');
                    new_lat = 0;
                }
                else {
                    if (sw.lat() < -50) {
                        new_lat = -50 + ((ne.lat() - sw.lat()) / 2);
                    }
                    else if (ne.lat() > 50) {
                        new_lat = 50 - ((ne.lat() - sw.lat()) / 2);
                    }
                }

                // log("desired lat=" + lat + " lng=" + lng + "\tnew lat=" + new_lat + " lng = " + new_lng);

                // If necessary, move the map
                if ( (Math.abs(new_lat - lat) > 0.0001) || (Math.abs(new_lng - lng) > 0.0001) ) {
                    //				log("Desired lat=" + lat + " lng=" + lng + "\tconstrained lat=" + new_lat + " lng = " + new_lng);
                    //				log("Bounds: " + B.toString());
                    map.setCenter( new google.maps.LatLng(new_lat, new_lng) );
                }
            }


            function onBoundsChanged() {
                //			log('onBoundsChanged: '  + map.getCenter().toString());
                //			log("onBoundsChanged: zoom level now: " + map.getZoom());
//              log('Bounds are: ' + map.getBounds().toString());

                // This method of finding the map div is more technically correct but ...
                //var mapDiv = $( map.getDiv() ).children().eq( 0 );
                // ...this method is easier to read.
                var mapDiv = $( '.gm-style' );
                if ( mapDiv.height() == window.innerHeight &&
                     mapDiv.width()  == window.innerWidth ) {
                    log( 'FULL SCREEN' );
                }
                else {
                    log ('NOT FULL SCREEN');
                }
                constrainBounds();
            }


            function onCenterChanged() {
//              log('onCenterChanged: ' + map.getCenter().toString());
                constrainBounds();
            }


            // calcImageExtents takes the original image size and derives the image size at each zoom
            // level. The smallest zoom (level 0) is where the entire image fits into one tile. This stores
            // that information along with some precalculated info about each zoom level for use later.
            function calcImageExtents( origWidth, origHeight, tileSize ) {
                var nextWidth = parseInt( origWidth, 10 ); // must do this conversion or else the while loop below does lexical instead
                var nextHeight = parseInt( origHeight, 10 );  // of numerical comparisons which leads to hard to debug behavior.
                var divisor = 1;
                var sizeArray = [];

                //log( 'nextWidth: ' + nextWidth + ' nextHeight: ' + nextHeight );

                var span;

                tileSize = parseInt( tileSize, 10 );
                while ( (nextWidth > tileSize) || (nextHeight > tileSize) ) {
                    // Always base the calculation off the original dimensions.
                    // This prevents rounding errors from accumulating.
                    nextWidth = origWidth / divisor;
                    nextHeight = origHeight / divisor;

                    span = {};
                    span.widthInPixels = nextWidth;
                    span.heightInPixels = nextHeight;
                    span.widthInTiles = Math.ceil(span.widthInPixels / tileSize);
                    span.heightInTiles = Math.ceil(span.heightInPixels / tileSize);
                    sizeArray.push(span);

                    divisor *= 2;
                }

                sizeArray.reverse();
                return sizeArray;
            }


            function calcInitialZoom( el, optionsZoom, extents ) {
                var zoom = optionsZoom;

                if ( zoom === 'fit' ) {
                    var maxHeight = $(el).height();
                    var maxWidth = $(el).width();
                    //log( 'fitting zoom: maxHeight: ' + maxHeight + ' maxWidth: ' + maxWidth );

                    for ( zoom = extents.length - 1; zoom; zoom-- ) {
                        if ( ( extents[ zoom ].widthInPixels < maxWidth )
                            &&
                            ( extents[ zoom ].heightInPixels < maxHeight ) ) {
                            break;
                        }
                    }
                }

                return zoom;
            }


            function calcInitialCenter( optionsX, optionsY ) {
                var initial_x = optionsX || 'center';
                if ( initial_x === 'center' ) {
                    initial_x = 0;
                }
                var initial_y = optionsY || 'center';
                if ( initial_y === 'center' ) {
                    initial_y = 0;
                }

                return new google.maps.LatLng( initial_y, initial_x );
            }


            // creates the tile URL if tiles were created using ImageMagick. Function signature is per Google spec. Don't add/change params.
            function imageMagickGetTileURL( tileCoord, zoomLevel ) {
                if (tileCoord.x < 0 || tileCoord.x >= imageExtents[zoomLevel].widthInTiles) {
                    return null;
                }
                if (tileCoord.y < 0 || tileCoord.y >= imageExtents[zoomLevel].heightInTiles) {
                    return null;
                }

                //noinspection UnnecessaryLocalVariableJS
                var url = options.tile_path + '/tile_' + zoomLevel + '_' + tileCoord.x + '_' + tileCoord.y + '.jpg';
//                log("asked for " + tileCoord.x + "," + tileCoord.y + " zoom=" + zoomLevel + ". returned: " + url);
                return url;
            }


            function addHTMLControl( map, position, html ) {
                var control =  document.createElement( 'div' );
                control.innerHTML = html;
                map.controls[ position ].push( control );
            }

            function addCaption( map, position, textOptions ) {
                var myText = "";
                var cssClass = "liv_caption";

                if ( typeof textOptions === 'string' ) {
                    myText = textOptions;
                }
                else if ( typeof textOptions.text === 'string' ) {
                    myText = textOptions.text;
                    if (typeof textOptions.cssClass === 'string' ) {
                        cssClass = textOptions.cssClass;
                    }
                }
                else {
                    return;
                }

                if ( myText.length > 0 ) {
                    var html = '<span class="' + cssClass + '">' + myText + '</span>';
                    addHTMLControl( map, position, html );
                }
            }


            function addCopyrightMessage( map, position, text, url, cssClass ) {
                var html;
                if ( text.length > 0 ) {
                    if ( url.length > 0 ) {
                        html = '<a class="' + cssClass + '" target="_blank" href="' + url + '">' + text + '</a>';
                    }
                    else {
                        html = '<span class="' + cssClass + '">' + text + '</span>';
                    }

                    addHTMLControl( map, position, html );
                }
            }


            //
            // BEGIN PUBLIC API FUNCTIONS
            //

            //noinspection JSUnusedGlobalSymbols
            /**
             * @name getMap
             * @description For direct access to the map object. Caveat utilitor!
             * @returns GMap
             */
            this.getMap = function() {
                return map;
            };


            /**
             * @name resize
             * @description Call resize when the map's container div changes size without LIV knowing.
             * @returns void
             */
            this.resize = function() {
                google.maps.event.trigger( map, 'resize' );
            };

            //
            // END PUBLIC API FUNCTIONS
            //


            // attach and config LIV to DOM object here
            function init( elementToAttachTo, options ) {
                // set the log id. Do this so that the DOM id is not required.
                if ( typeof elementToAttachTo.id === 'string' ) {
                    options.log_id = elementToAttachTo.id;
                }

                // set up a local logger instance. just prefixes log message with element id to make it easier to distinguish
                // messages when more than one element in a page has a LIV object attached.
                log = function( item ) { if ( typeof( item ) === 'string' ) { LIVLogger( options.log_id + ': ' + item ); } else { LIVLogger( options.log_id + ': OBJECT'); LIVLogger( item ); } };
                log( 'Attaching Large Image Viewer. Options:' );
                log( options );

                imageExtents = calcImageExtents( options.image_width, options.image_height, options.image_tile_size );
                log( imageExtents );

                var initial_zoom = calcInitialZoom( elementToAttachTo, options.initial_zoom, imageExtents );
                log( 'initial_zoom: ' + initial_zoom );

                var initialCenter = calcInitialCenter( options.initial_x, options.initial_y );
                log( 'initialCenter: ' + initialCenter );

                var imageMapTypeOptions =	{
                    getTileUrl: options.tile_url_func,
                    isPng: false,
                    minZoom: 0, // always want this to be zero
                    maxZoom: ( imageExtents.length - 1 ),
                    opacity: 1.0,
                    tileSize: new google.maps.Size( options.image_tile_size, options.image_tile_size )
                };

                var customMapType = new google.maps.ImageMapType( imageMapTypeOptions );
                customMapType.projection = new LIVProjection( imageExtents[0].widthInPixels, imageExtents[0].heightInPixels );

                var LIV_MAPTYPE_ID = 'LIV';
                var mapOptions =	{
                    zoom: initial_zoom,
                    center: initialCenter,
                    mapTypeId: LIV_MAPTYPE_ID,

                    zoomControl: true,
                    streetViewControl: false,
                    mapTypeControl: false,
                    scaleControl: false,

                    backgroundColor: options.background_color
                    //backgroundColor: '#AAA', // use this for debugging tiling by making it different from tile background color
                };

                if ( options.fullscreen_control ) {
                    mapOptions.fullscreenControl = ( String( options.fullscreen_control ) === 'true' );
                }

                // Now create the custom map. Would normally be G_NORMAL_MAP,G_SATELLITE_MAP,G_HYBRID_MAP
                map = new google.maps.Map( elementToAttachTo, mapOptions );
                if ( !map ) { throw 'Google Maps creation failed.'; }
                map.mapTypes.set( LIV_MAPTYPE_ID, customMapType );

                // create default styles for map controls
                options.no_css = ( String( options.no_css ) === 'true' );
                if ( !options.no_css ) {
                    $( '<style type="text/css">' )
                        .text( '.liv_caption   { color: #fff; font-size: 20px; }' +
                               '.liv_copyright { color: #999; font-size: 10px; margin: 0 4px 0 0; white-space: nowrap; }' )
                        .appendTo( 'head' );
                }

                // add strings and other controls
                addCaption( map, google.maps.ControlPosition.TOP_CENTER,    options.title_top );
                addCaption( map, google.maps.ControlPosition.BOTTOM_CENTER, options.title_bottom );
                addCopyrightMessage( map, google.maps.ControlPosition.BOTTOM_RIGHT, options.copyright_text, options.copyright_url, 'liv_copyright' );

                google.maps.event.addListener( map, 'bounds_changed', onBoundsChanged );
                google.maps.event.addListener( map, 'center_changed', onCenterChanged );
            }

            options = $.extend( defaults, options );  // merge specified options onto defaults
            return this.each( function() {
                init( this, options );
            });
        }
    });
})( jQuery );
