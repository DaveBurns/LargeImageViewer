Large Image Viewer
==================
Here is a short description of what Large Image Viewer is all about. What it can do and what the three sections below are.

##jQuery plugin

###Basic Includes:
    <script type="text/javascript" src="http://maps.google.com/maps/api/js?v=3&key=<YOUR_KEY_HERE>"></script>
    <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.0/jquery.min.js"></script>
    <script type="text/javascript" src="jquery.largeimageviewer.min.js"></script>
### Basic usage:
Given a div with an arbitrary ID:
    
    <div id="largeImage"></div>

You attach LargeImageViewer to that div like so:

    $( document ).ready( function() {
        $( '#largeImage' ).largeImageViewer();
    });

### Advanced usage:
    $( document ).ready( function() {
        $( '#largeImage' ).largeImageViewer( {
            fullscreen_control: true,
            image_width: 2219,
            image_height: 3327,
            initial_x: 'center',
            initial_y: 'center',
            initial_zoom: 'fit',
            background_color: 'black',
            titleTop: {},
            titleBottom: "baboons and stuff",
            copyright: {}
        });
    });

##Adobe Lightroom plugin


##WordPress plugin
The plugin creates a new shortcode that you can embed in your content. Here is an example:
    
    [liv height='300' title_top='My Panorama Title' tile_path='/panoramas/my_pano/tiles' image_width='7788' image_height='2805']
