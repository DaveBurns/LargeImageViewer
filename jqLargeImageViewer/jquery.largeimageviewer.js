// Large Image Viewer
//
// jQuery plugin
//
// Copyright 2013 David F. Burns


(function( $ ) {

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
                logId: '[element with no id]',
                showPanControl: false,
                imageWidth: 0,
                imageHeight: 0,
                imageTileSize: 256,
                initialX: 'center',
                initialY: 'center',
                initialZoom: 'fit',
                tileURLFunc: imageMagickGetTileURL,
                zoomSize: 'large',
                backgroundColor: '#000',
                tilePath: 'tiles',
                showFullScreenControl: false,
                titleTop: {},
                titleBottom: {},
                copyright: {}
            };


            // TODO: is there a better pattern for getting this removed from minimized builds?
            // TRY: http://stackoverflow.com/questions/2934509/exclude-debug-javascript-code-during-minification/
            function LIVLogger( item ) {
                if ( ! options.debug ) return;
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


            // -------------- Define LIVFullScreenControl -------------------

            // Constructor
            function LIVFullScreenControl( map, mapDivContainer ) {
                this.controlText = null;
                this.controlUI = null;
                this.domContainer = mapDivContainer;

                // we need to know our initial full-screen state. To do that, compare the size of the viewport
                // and the size of the div that contains the map.
                this.isFullScreen = ( ( $( window ).innerWidth() === this.domContainer.width )
                    &&
                    ( $( window ).innerHeight() === this.domContainer.height ) );
                log( 'initial full screen state: ' + this.isFullScreen );

                function createFullScreenControlText() {
                    var t = document.createElement( 'div' );
                    t.style.fontSize = '10px';
                    t.style.fontFamily = 'Arial,sans-serif';
                    t.style.color = '#000';
                    t.style.padding = '4px';

                    return t;
                }

                function createFullScreenControlUI() {
                    var u = document.createElement( 'div' );
                    u.style.backgroundColor = '#fff';
                    u.style.borderStyle = 'solid';
                    u.style.borderWidth = '1px';
                    u.style.borderColor = '#000';
                    u.style.cursor = 'pointer';
                    u.style.textAlign = 'center';
                    u.title = 'Toggle the full screen mode';
                    u.style.margin = '10px 5px 5px 5px';

                    return u;
                }

                this.controlText = createFullScreenControlText();
                this.setText( this.isFullScreen );
                this.controlUI = createFullScreenControlUI();
                this.controlUI.appendChild( this.controlText );

                var controlDiv = document.createElement( 'div' );
                controlDiv.appendChild( this.controlUI );
                controlDiv.index = 1; // used for ordering with other controls in same position
                map.controls[ google.maps.ControlPosition.TOP_RIGHT ].push( controlDiv );

                // Setup the click event listener to toggle the full screen
                // Need to use a closure so that the click handler has access to this full screen control object
                (
                    function( fscontrol ) {
                        google.maps.event.addDomListener( fscontrol.controlUI, 'click', function() { fscontrol.toggle(); } );
                    }
                    )( this );
            }


            LIVFullScreenControl.prototype.setText = function( isFullScreen ) {
                this.controlText.innerHTML = isFullScreen ? 'Exit Full Screen' : 'Full Screen';
            };


            LIVFullScreenControl.prototype.enterFullScreen = function() {
                this.isFullScreen = true;
                $( this.domContainer ).addClass( 'LIVFullScreen' );
                google.maps.event.trigger( map, 'resize' );
                this.setText( this.isFullScreen );
            };


            LIVFullScreenControl.prototype.exitFullScreen = function() {
                this.isFullScreen = false;
                $( this.domContainer ).removeClass( 'LIVFullScreen' );
                google.maps.event.trigger( map, 'resize' );
                this.setText( this.isFullScreen );
            };


            LIVFullScreenControl.prototype.fullScreen = function( show ) {
                // if no args, act as a getter and return the current state
                if( !arguments.length ) {
                    return this.isFullScreen;
                }

                // Add/remove control per "show" boolean
                show ? this.enterFullScreen() : this.exitFullScreen();
                return this;
            };


            LIVFullScreenControl.prototype.toggle = function() {
                this.fullScreen( !this.fullScreen() );
            };

            // --------------------------------------------------------------


            // If the map position is out of range, move it back
            function constrainBounds() {
//    			log("-----------constrainBounds()");

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
//				    log('image width smaller than viewport');
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
//				    log('image height smaller than viewport');
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
//			    log('Bounds are: ' + map.getBounds().toString());
                constrainBounds();
            }


            function onCenterChanged() {
//			    log('onCenterChanged: ' + map.getCenter().toString());
                constrainBounds();
            }


            /*
             // Resize the height of the div containing the map.
             function onResize() {
             log('LIV onResize');
             if ( map ) {
             log( 'firing map resize' );
             google.maps.event.trigger( map, 'resize' );
             constrainBounds();
             }
             }
             */

            // calcImageExtents takes the original image size and derives the image size at each zoom
            // level. The smallest zoom (level 0) is where the entire image fits into one tile. This stores
            // that information along with some precalculated info about each zoom level for use later.
            function calcImageExtents( origWidth, origHeight, tileSize ) {
                var nextWidth = parseInt( origWidth, 10 ); // must do this conversion or else the while loop below does lexical instead
                var nextHeight = parseInt( origHeight, 10 );  // of numerical comparisons which leads to hard to debug behavior.
                var divisor = 1;
                var sizeArray = [];

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
//        			log( 'fitting zoom: maxHeight: ' + maxHeight + ' maxWidth: ' + maxWidth );

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
                var initialX = optionsX || 'center';
                if ( initialX === 'center' ) {
                    initialX = 0;
                }
                var initialY = optionsY || 'center';
                if ( initialY === 'center' ) {
                    initialY = 0;
                }

                return new google.maps.LatLng( initialY, initialX );
            }


            // creates the tile URL if tiles were created using ImageMagick. Function signature is per Google spec. Don't add/change params.
            function imageMagickGetTileURL( tileCoord, zoomLevel ) {
                if (tileCoord.x < 0 || tileCoord.x >= imageExtents[zoomLevel].widthInTiles) {
                    return null;
                }
                if (tileCoord.y < 0 || tileCoord.y >= imageExtents[zoomLevel].heightInTiles) {
                    return null;
                }

                var url = options.tilePath + '/tile_' + zoomLevel + '_' + tileCoord.x + '_' + tileCoord.y + '.jpg';
//			log("asked for " + tileCoord.x + "," + tileCoord.y + " zoom=" + zoomLevel + ". returned: " + url);
                return url;
            }


            function addTextControl( map, position, textOptions ) {
                var myText = "";
                var cssClass = "LIVCaption";

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
                    var control =  document.createElement( 'div' );
                    control.innerHTML = '<span class="' + cssClass + '">' + myText + '</span>';
                    map.controls[ position ].push( control );
                }
            }


            function addCopyrightMessage( map, copyright ) {
                if ( typeof copyright.text === 'undefined' ) {
                    return;
                }

                var html = '<a style="color: #aaa;"';

                var copyrightDiv = document.createElement( 'div' );
                if ( typeof copyright.URL !== 'undefined' ) {
                    html += ' target="_blank" href="' + copyright.URL + '"';
                }
                html += '>' + copyright.text + '</a>';

                copyrightDiv.style.fontSize = '11px';
                copyrightDiv.style.fontFamily = 'Arial, sans-serif';
                copyrightDiv.style.margin = '0 2px 4px 0';
                copyrightDiv.style.whiteSpace = 'nowrap';
                copyrightDiv.innerHTML = html;

                map.controls[ google.maps.ControlPosition.BOTTOM_RIGHT ].push( copyrightDiv );
            }


            //
            // BEGIN PUBLIC API FUNCTIONS
            //

            this.getMap = function() {
                return map;
            };

            //
            // END PUBLIC API FUNCTIONS
            //


            // attach and config LIV to DOM object here
            function init( elementToAttachTo, options ) {
                var i;

                // set the log id. Do this so that the DOM id is not required.
                if ( typeof elementToAttachTo.id === 'string' ) {
                    options.logId = elementToAttachTo.id;
                }

                // set up a local logger instance. just prefixes log message with element id to make it easier to distinguish
                // messages when more than one element in a page has a LIV object attached.
                log = function( item ) { if ( typeof( item ) === 'string' ) { LIVLogger( options.logId + ': ' + item ); } else { LIVLogger( options.logId + ': OBJECT'); LIVLogger( item ); } };
                log( 'Attaching Large Image Viewer. Options:' );
                log( options );

                imageExtents = calcImageExtents( options.imageWidth, options.imageHeight, options.imageTileSize );
                log( imageExtents );

                var initialZoom = calcInitialZoom( elementToAttachTo, options.initialZoom, imageExtents );
                log( 'initialZoom: ' + initialZoom );

                var initialCenter = calcInitialCenter( options.initialX, options.initialY );
                log( 'initialCenter: ' + initialCenter );

                var imageMapTypeOptions =	{
                    getTileUrl: options.tileURLFunc,
                    isPng: false,
                    minZoom: 0, // always want this to be zero
                    maxZoom: ( imageExtents.length - 1 ),
                    opacity: 1.0,
                    tileSize: new google.maps.Size( options.imageTileSize, options.imageTileSize )
                };

                var customMapType = new google.maps.ImageMapType( imageMapTypeOptions );
                customMapType.projection = new LIVProjection( imageExtents[0].widthInPixels, imageExtents[0].heightInPixels );

                var zoomSize;
                switch ( options.zoomSize ) {
                    case 'large':
                        zoomSize = google.maps.ZoomControlStyle.LARGE;
                        break;
                    case 'small':
                        zoomSize = google.maps.ZoomControlStyle.SMALL;
                        break;
                    default:
                        zoomSize = google.maps.ZoomControlStyle.DEFAULT;
                }

                var LIV_MAPTYPE_ID = 'LIV';
                var mapOptions =	{
                    zoom: initialZoom,
                    center: initialCenter,
                    mapTypeId: LIV_MAPTYPE_ID,

                    panControl: options.showPanControl,
                    zoomControl: true,
                    zoomControlOptions: {
                        style: zoomSize
                    },
                    streetViewControl: false,
                    mapTypeControl: false,
                    scaleControl: false,

                    backgroundColor: options.backgroundColor
                    //backgroundColor: '#AAA', // use this for debugging tiling by making it different from tile background color
                };

                // Now create the custom map. Would normally be G_NORMAL_MAP,G_SATELLITE_MAP,G_HYBRID_MAP
                map = new google.maps.Map( elementToAttachTo, mapOptions );
                if ( !map ) { throw 'Google Maps creation failed.'; }
                map.mapTypes.set( LIV_MAPTYPE_ID, customMapType );

                // add strings and other controls
                addTextControl( map, google.maps.ControlPosition.TOP_CENTER,    options.titleTop );
                addTextControl( map, google.maps.ControlPosition.BOTTOM_CENTER, options.titleBottom );
                addCopyrightMessage( map, options.copyright );

                if ( options.showFullScreenControl ) {
                    this.fullScreenControl = new LIVFullScreenControl( map, elementToAttachTo );
                    log( this.fullScreenControl );
                }

//			google.maps.event.addListener( map, 'click', onClick );
                google.maps.event.addListener( map, 'bounds_changed', onBoundsChanged );
                google.maps.event.addListener( map, 'center_changed', onCenterChanged );
                //			google.maps.event.addListener(map, "zoom_changed", onZoomChanged);
                //			google.maps.event.addListener(map, "idle", onIdle);

//                onResize();
            }


            options = $.extend( defaults, options );  // merge specified options onto defaults
            return this.each( function() {
                init( this, options );
            });
        }
    });
})( jQuery );



// creates the tile URL if tiles were created using Photoshop's Zoomify export
// function zoomifyGetTileURL(tileCoord, zoomLevel) {
// var fileName = zoomLevel + "-" + tileCoord.x + "-" + tileCoord.y + ".jpg";
// var tileNumber = (tileCoord.y * imageExtents[zoomLevel].widthInTiles) + tileCoord.x;
// tileNumber += imageExtents[zoomLevel].firstTileOnDisk;
// var zoomifyGroupNumber = Math.floor(tileNumber / config.imgtilesize);
// var url = tileBasePath + zoomifyGroupNumber + "/" + fileName;
// //      log("asked for " + tileCoord.x + "," + tileCoord.y + " zoom=" + zoomLevel + ". returned: " + url);
// return url;
// }



//		function onIdle() {
//			log('onIdle');
//		}

//		function onZoomChanged() {
//			log('onZoomChanged');
//			constrainBounds();
//		}


// function showCoordsInfo(event) {
// //			if (overlay) {
// // ignore if we click on the info window
// //				return;
// //			}
// var currentProjection = map.getProjection();
// //	    if (!currentProjection) { alert("problem"); };
// var tilePoint = currentProjection.fromLatLngToPoint(event.latLng, false);
// // log("point = " + tilePoint.toString());
// // log("latlng = " + event.latLng.toString());

// var tileCoordinate = new google.maps.Point();
// var sizeOfTileInWorldDimensions = config.imgtilesize / Math.pow(2, map.getZoom());
// tileCoordinate.x = Math.floor( tilePoint.x / sizeOfTileInWorldDimensions );
// tileCoordinate.y = Math.floor( tilePoint.y / sizeOfTileInWorldDimensions );

// var myHtml =
// "Latitude: " + event.latLng.lat() +
// "<br/>Longitude: " + event.latLng.lng() +
// "<br/>The Tile Coordinate is:" +
// "<br/> x: " + tileCoordinate.x +
// "<br/> y: " + tileCoordinate.y +
// "<br/> at zoom level " + map.getZoom();

// var infowindow = new google.maps.InfoWindow({
// content: myHtml
// });

// var marker = new google.maps.Marker({
// position: event.latLng,
// map: map
// });

// infowindow.open(map, marker);
// }

// function onClick(event) {
// log( '--onClick' );
// log( event );
// //			showCoordsInfo(event);
// }
