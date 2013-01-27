// Large Image Viewer
// Copyright 2013 David F. Burns
// TODO: Put license notices here from any open source things this is derived from

if (typeof (LIVFactory) === 'undefined') {

LIVdebug = false;

// LIVFactory: a singleton factory for LargeImageViewer's based on the
// JavaScript module pattern: http://yuiblog.com/blog/2007/06/12/module-pattern/
LIVFactory = (function () {

	// Utility functions:

	function LIVlog(item) {
		if ( ! LIVdebug ) return;
		if (window.console) {
			if (typeof(item) === 'object') {
				if (window.console.dir) {
					console.dir(item);
				}
			}
			else {
				console.log(item);
			}
		}
	}

	function getElementAttributes( element ) {
		var attributes = element.attributes;
		var numAttributes = attributes.length;
		var kvpairs = {};

		for (var i = 0; i < numAttributes; i++) {
			kvpairs[attributes.item(i).nodeName] = attributes.item(i).nodeValue;
		}

		return kvpairs;
	}

	function attachEventListener( element, eventName, funcName ) {
		if (element.addEventListener) {
			element.addEventListener(eventName, funcName, false);
		} else if (element.attachEvent) {
			element.attachEvent('on' + eventName, funcName);
		}
	}

	function getElementsByClass( searchClass, node, tag ) {
        var classElements = [];
        if ( typeof( node ) === 'undefined' || node === null ) {
			node = document;
		}
        if ( typeof( tag ) === 'undefined' || tag === null ) {
			tag = '*';
		}
        var els = node.getElementsByTagName( tag );
        var elsLen = els.length;
        var pattern = new RegExp( '(^|\\s)' + searchClass + '(\\s|$)' );
        for (var i = 0, j = 0; i < elsLen; i++) {
			if ( pattern.test( els[i].className ) ) {
				classElements[j] = els[i];
				j++;
			}
        }
        return classElements;
	}
	
	function getElementClasses( element ) {
//		log( element );
//		log( 'getElementClasses: ' + element.className );
		return element.className.split( /\s+/ );
	}
	
	function doesElementHaveClass( element, className ) {
//		log( 'doesElementHaveClass: ' + className );
		var classNames = getElementClasses( element );
//		log( classNames );
		for ( var i = 0; i < classNames.length; i++ ) {
			if ( classNames[ i ] === className ) {
				return true;
			}
		}
		return false;
	}

	
	// calcImageExtents takes the original image size and derives the image size at each zoom
	// level. The smallest zoom (level 0) is where the entire image fits into one tile. This stores
	// that information along with some precalculated info about each zoom level for use later.
	function calcImageExtents(origWidth, origHeight, tileSize) {
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


	function getElementPixelSizes( element ) {
		var elHeight = "innerHeight" in element 
					   ? element.innerHeight
					   : element.offsetHeight;
		var elWidth = "innerWidth" in element 
					   ? element.innerWidth
					   : element.offsetWidth;
		return { height: elHeight, width: elWidth };
	}
	
	function calcInitialZoom( el, configZoom, extents ) {
		var zoom = configZoom;

		if ( zoom === 'fit' ) {
			var maxSize = getElementPixelSizes( el );
//			LIVlog( 'fitting zoom: maxHeight: ' + maxSize.height + ' maxWidth: ' + maxSize.width );
			
			for ( zoom = extents.length - 1; zoom; zoom-- ) {
				if ( ( extents[ zoom ].widthInPixels < maxSize.width )
					 &&
					 ( extents[ zoom ].heightInPixels < maxSize.height ) ) {
					break;
				}
			}
		}
		
		return zoom;
	}

	function calcInitialCenter( configX, configY ) {
		var initialX = configX || 'center';
		if ( initialX === 'center' ) {
			initialX = 0;
		}
		var initialY = configY || 'center';
		if ( initialY === 'center' ) {
			initialY = 0;
		}
		
		return new google.maps.LatLng( initialY, initialX );
	}

	
    // -------------- Define LargeImageProjection -------------------
    // The gist of this new Projection type is that the extent is the size of the
    // image in pixels at that zoom level. The midpoint of the image has coord (0,0).
    // The lower left has coord (-50, -50) and the upper right has coord (50, 50).

    // Constructor
    function LargeImageProjection(worldWidth, worldHeight) {
		this.worldWidth = worldWidth;
		this.worldHeight = worldHeight;
//		log( this );
	}

    // Override base google.maps.Projection functions
    LargeImageProjection.prototype.fromPointToLatLng = function( point, nowrap ) {
		var lng = (point.x / this.worldWidth) * 100 - 50;
		var lat = -(point.y / this.worldHeight) * 100 + 50;
		return new google.maps.LatLng(lat, lng, nowrap);
    };

    LargeImageProjection.prototype.fromLatLngToPoint = function( latlng ) {
		var x = this.worldWidth * ((latlng.lng() + 50) / 100);
		var y = -this.worldHeight * ((latlng.lat() - 50) / 100);
		return new google.maps.Point(x, y);
    };
    // --------------------------------------------------------------

    // Define the LargeImageViewer

	function LargeImageViewer() {
		// using 'var' creates private variables
		var map = null;
		var config = {};
		var imageExtents = null;
		var element = null;
		var log = null;
		
		// using 'this' creates public variables 
		this.attachTo = attachTo;
		this.onResize = onResize;


		// creates the tile URL if tiles were created using ImageMagick
		function imageMagickGetTileURL( tileCoord, zoomLevel ) {
			if (tileCoord.x < 0 || tileCoord.x >= imageExtents[zoomLevel].widthInTiles) {
				return null;
			}
			if (tileCoord.y < 0 || tileCoord.y >= imageExtents[zoomLevel].heightInTiles) {
				return null;
			}

			var url = config.tilesrc + '/tile_' + zoomLevel + '_' + tileCoord.x + '_' + tileCoord.y + '.jpg';
//			log("asked for " + tileCoord.x + "," + tileCoord.y + " zoom=" + zoomLevel + ". returned: " + url);
			return url;
		}


		// If the map position is out of range, move it back
		function constrainBounds() {
//			log("-----------constrainBounds()");

			var C = map.getCenter();
			var lng = C.lng(); //if (isNaN(lng)) { log("lng trouble here"); };
			var lat = C.lat(); //if (isNaN(lat)) { log("lat trouble here"); };
			var B = map.getBounds(); // get the bounds of the viewport in coordinates
			var sw = B.getSouthWest();
			var ne = B.getNorthEast();
			var span = B.toSpan();
	
//			log( 'span.lng: ' + span.lng() + ' span.lat: ' + span.lat() )
//			log( 'Bounds: ' + B.toString() );

			// Figure out if the image is outside of the artificial boundaries
			// created by our custom projection object.
			var new_lat = lat;
			var new_lng = lng;

			if ( 100 < span.lng() ) {
//				log('image width smaller than viewport');
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
//				log('image height smaller than viewport');
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
				map.setCenter(new google.maps.LatLng(new_lat, new_lng));
			}
		}

		
		function onBoundsChanged() {
	//			log('onBoundsChanged: '  + map.getCenter().toString());
	//			log("onBoundsChanged: zoom level now: " + map.getZoom());
//			log('Bounds are: ' + map.getBounds().toString());
			constrainBounds();
		}


		function onCenterChanged() {
//			log('onCenterChanged: ' + map.getCenter().toString());
			constrainBounds();
		}

		
		// Resize the height of the div containing the map.
		function onResize() {
			log('LIV onResize');
			if (map) {
				log('firing map resize');
				google.maps.event.trigger(map, 'resize');
				constrainBounds();
			}
		}


		function attachTo( elementToAttachTo ) {
			var i;
			
			element = elementToAttachTo;
			config = getElementAttributes( element );

			// check config contents and set defaults
			
			// set the log id. Do this so that the DOM id is not required.
			config.logid = '[element with no id]';
			if ( typeof( config.id ) === 'string' ) {
				config.logid = config.id;
			}
			
			if ( ( typeof( config.showpancontrol ) === 'undefined' ) ||
				 ( config.showpancontrol === 'false' ) ) {
				config.showpancontrol = false;
			}
			else {
				config.showpancontrol = true;
			}

			// set up a local logger instance. just prefixes log message with element id to make it easier to distinguish
			// messages when more than one element in a page has a LIV object attached.
			log = function(item) { if (typeof(item) === 'string') { LIVlog(config.logid + ': ' + item); } else { LIVlog(item); } };
			log( 'attaching Large Image Viewer' );
			log( config );

			imageExtents = calcImageExtents( config.imgwidth, config.imgheight, config.imgtilesize );
			log( imageExtents );

			var initialZoom = calcInitialZoom( element, config.initialzoom, imageExtents );
			log( 'initialZoom: ' + initialZoom );

			var initialCenter = calcInitialCenter( config.initialx, config.initialy );
			log( 'initialCenter: ' + initialCenter );
			
			// get child elements that are divs and save them so they can be added to the map as controls later.
			// we must do this before the map is created because Google Maps wipes out all elements within the map div.
			var controlDivs = element.getElementsByTagName( 'div' );
			var controlDivsBottomCenter = [];
			var controlDivsTopCenter = [];
			for ( i = 0; i < controlDivs.length; i++ ) {
				if ( doesElementHaveClass( controlDivs[ i ], 'livTextBottomCenter' ) ) {
					controlDivsBottomCenter.push( controlDivs[ i ] );
				}
				if ( doesElementHaveClass( controlDivs[ i ], 'livTextTopCenter' ) ) {
					controlDivsTopCenter.push( controlDivs[ i ] );
				}
			}
			
			var imageMapTypeOptions =	{
											getTileUrl: imageMagickGetTileURL,
											isPng: false,
											minZoom: 0, // always want this to be zero
											maxZoom: ( imageExtents.length - 1 ),
											opacity: 1.0,
											tileSize: new google.maps.Size( config.imgtilesize, config.imgtilesize )
										};

			var customMap = new google.maps.ImageMapType( imageMapTypeOptions );
			customMap.projection = new LargeImageProjection( imageExtents[0].widthInPixels, imageExtents[0].heightInPixels );

			var zoomSize = google.maps.ZoomControlStyle.DEFAULT;
			if (config.zoomsize === 'large') {
				zoomSize = google.maps.ZoomControlStyle.LARGE;
			}
			else if (config.zoomsize === 'small') {
				zoomSize = google.maps.ZoomControlStyle.SMALL;
			}
			
			var LIV_MAPTYPE_ID = 'LIV';
			var mapOptions =	{
									zoom: initialZoom,
									center: initialCenter,
									mapTypeId: LIV_MAPTYPE_ID,

									panControl: config.showpancontrol,
									zoomControl: true,
									zoomControlOptions: {
										style: zoomSize
									},
									streetViewControl: false,
									mapTypeControl: false,
									scaleControl: false,

									backgroundColor: config.backgroundcolor
						//				backgroundColor: '#AAA', // use this for debugging tiling by making it different from tile background color
								};

			// Now create the custom map. Would normally be G_NORMAL_MAP,G_SATELLITE_MAP,G_HYBRID_MAP
			map = new google.maps.Map( element, mapOptions );
			if ( !map ) { alert( 'map is null' ); }  // TODO: remove this and add an exception handler instead 
			map.mapTypes.set( LIV_MAPTYPE_ID, customMap );

			// add the saved control divs to the map
			for ( i = 0; i < controlDivsBottomCenter.length; i++ ) {
				map.controls[ google.maps.ControlPosition.BOTTOM_CENTER ].push( controlDivsBottomCenter[ i ] );
			}
			for ( i = 0; i < controlDivsTopCenter.length; i++ ) {
				map.controls[ google.maps.ControlPosition.TOP_CENTER ].push( controlDivsTopCenter[ i ] );
			}

//			google.maps.event.addListener( map, 'click', onClick );
			google.maps.event.addListener( map, 'bounds_changed', onBoundsChanged );
			google.maps.event.addListener( map, 'center_changed', onCenterChanged );
	//			google.maps.event.addListener(map, "zoom_changed", onZoomChanged);
	//			google.maps.event.addListener(map, "idle", onIdle);

			attachEventListener( element, 'resize', onResize );
		}
	}

	function init() {
		var elementArray = getElementsByClass( 'liv' );
		var i;
//		LIVlog( elementArray );

		for ( i = 0; i < elementArray.length; i++ ) {
			var liv = new LargeImageViewer();
			liv.attachTo( elementArray[ i ] );
		}
	}

	return {
		init: init,
		attachEventListener: attachEventListener
	};
	
}());

}

LIVFactory.attachEventListener( window, 'load', LIVFactory.init );



		// creates the tile URL if tiles were created using Photoshop's Zoomify export
		// function zoomifyGetTileURL(tileCoord, zoomLevel) {
			// if ((tileCoord.x > imageExtents[zoomLevel].widthInTiles - 1) || (tileCoord.y > imageExtents[zoomLevel].heightInTiles - 1)) {
			// //        log(imageExtents[zoomLevel].widthInTiles + " " + imageExtents[zoomLevel].heightInTiles);
			// //        log("asked for " + tileCoord.x + "," + tileCoord.y + " zoom=" + zoomLevel + ". returned: img/_MG_8882-93-Panorama_img/transparent.png");
			// return "./transparent.png";
			// }
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

	// function getWindowHeight() {
		// if (window.self && self.innerHeight) {
			// return self.innerHeight;
		// }
		// if (document.documentElement && document.documentElement.clientHeight) {
			// return document.documentElement.clientHeight;
		// }
		// return 0;
	// }

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
