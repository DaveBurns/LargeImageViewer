Large Image Viewer
==================
#Overview and Motivation
LargeImageViewer (LIV from now on) is a set of tools that let you publish very large images to the web and view them at full resolution, i.e. 1:1 pixel depth.
The original inspiration for this project was the Zoomify add-on that is packaged with Adobe Photoshop. It takes an image, generates the tiles for it, and then packages those tiles with a Flash component used by a web browser to zoom and pan around the image.

I like that feature but it has some problems:
- It uses Flash but that doesn't work on most mobile devices and I also want a more universal, secure, JavaScript-based approach.
- It is available in Adobe Photoshop but not Lightroom which is my primary photography editor.
- It is not easy to embed the output flexibly into a web page with other output and control size and placement.
- The user interface in the browser is simple but is unique and non-standard.

I solved this problem by writing a jQuery library that takes tiles and displays them using Google Maps.

- It uses JavaScript and the UI is mobile-friendly.
- As Google updates its Maps API, LIV gets updates for almost no effort.
- It is easy to embed one or more LIVs on a single web page and control their size dynamically.
- The user interface is familiar to the most users. (Most people know how to use Google Maps.)

The LIV project has three high-level components:
1. The jQuery library used for viewing 
1. A plugin for Adobe Lightroom that will generate tiles for an image using ImageMagick, then generate a simple HTML page that includes the LIV jQuery library and points it to the generated tiles. Currently you must upload that output yourself to a web site.
1. A plugin for WordPress that offers a shortcode for embedding the LIV viewer within a page. You must generate the tiles yourself and upload them to your web site.

#Project status
I think things are pretty solid but without input from other users, I would consider this beta software.

There is no single, packaged download with all components packaged together.
This may happen in the future. For now, you may need to build ImageMagick yourself if you don't already have it.
You can download the binaries for Windows here: https://www.imagemagick.org/script/download.php#windows.
For macOS, you can build them using the instructions in OXVImageMagickBuildNotes.txt in the Lightroom plugin directory of this project.

#Dependencies
- The viewer requires Google Maps
- The viewer requires jQuery
- You must have a way to generate tiles. It doesn't have to be ImageMagick but that is the current assumption.

#Generating Image Tiles
As you can see, a requirement before viewing an image is to generate tiles for each of the "zoom levels".
The Lightroom plugin automatically generates the tiles by running ImageMagick for you.
If you want to use the jQuery viewer without using Lightroom, you must invoke ImageMagick yourself.

You need to run it once for each zoom level, telling ImageMagick to resize the image before tiling it.
Here is an example command-line to guide you (this assumes ImageMagick 7.x):
```commandline
magick convert <myLargeImage.tiff> \
-unsharp 0.5x0.5+2+0.01 \       # optional: add unsharp masking
-bordercolor white -border 1 \  # optional: add border
-background black \             # optional: add background color to tiles that are on image edges.
-extent 5632x3840 \             # you must specify the output size of the image. This will change for every zoom level. 
-gravity northwest \            # start tiling from the upper left corner.
-crop 256x256 \                 # you must specify a tile size of 256x256. The LIV jQuery viewer assumes this.
-quality 60 \                   # The JPEG quality of the tiles. Change as needed.
-set filename:tile "%[fx:page.x/256]_%[fx:page.y/256]" \  # Calc a piece of the output tiles' file names
"<myOutputDir>/tile_<zoomLevel>_%[filename:tile].jpg"     # Set zoomLevel to the current zoom level, i.e. 0 for image fits in one tile, 1 for double that, 2 for double that, and so on until image is at original size.
```

## How to use the LIV jQuery plugin
Put these script includes at the top of your HTML:
### Basic Usage:
Here is the simplest HTML use case:
```html
<script type="text/javascript" src="https://maps.google.com/maps/api/js?v=3&key=<YOUR_KEY_HERE>"></script>
<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/3.1.1/jquery.min.js"></script>
<script type="text/javascript" src="jquery.largeimageviewer.min.js"></script>
<!-- -->
<div id="largeImage" style="height: 300px;"></div>
```

You attach LargeImageViewer to that div with some required parameters like so:
```javascript
$( document ).ready( function() {
    $( '#largeImage' ).largeImageViewer( {
        image_width: 5000,
        image_height: 5000,
        tile_path: 'tiles',
    });
});
```

### Full Set of Parameters
The LIV viewer library has some options you can specify to customize the viewer's behavior:

| Name | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| image_width | integer | <none> | Required. The pixel width of the original, full image |
| image_height | integer | <none> | Required. The pixel height of the original, full image |
| tile_path | string | <none> | Required. The path to the tile JPEGs, relative to the HTML page. |
| initial_x | integer/string | 'center' | The initial panning position in the X direction, ranging from -50 to 50. Or the magic string 'center' is equivalent to 0. |
| initial_y | integer/string | 'center' | The initial panning position in the Y direction, ranging from -50 to 50. Or the magic string 'center' is equivalent to 0. |
| initial_zoom | integer/string | 'fit' | Which zoom level to use for initial display. Or the magic string 'fit' to calc a best fit for the output \<div> |
| background_color | string | '#000' | The background color for the div when there is no tile to display. Passed directly to Google Maps mapOptions. |
| title_top | string | <none> | A title to overlay at the top of the image. |
| title_bottom | string | <none> | A title to overlay at the bottom of the image. |
| copyright_text | string | <none> | A small message to overlay at the bottom right of the image. |
| copyright_url | string | <none> | A URL for copyright info. Using this turns 'copyright_text' into a link. |
| fullscreen_control | Boolean | <none> | Whether or not to force the Full Screen Control on or off. If unspecified, defaults to GMaps behavior which is to show it depending on platform and screen size. |
| no_css | Boolean | false | LIV attaches CSS classes "liv_caption" to title_top and title_bottom and "liv_copyright" to copyright_text. If this is set to false, LIV inserts default styles for those classes into your HTML. If true, these classes are left for you to define. |
| debug | Boolean | false | If true, LIV outputs debig information to the browser's JavaScript console. |

####For example:

```javascript
$( document ).ready( function() {
    $( '#largeImage' ).largeImageViewer( {
        image_width: 2219,
        image_height: 3327,
        tile_path: 'tiles',
        initial_x: 'center',
        initial_y: 'center',
        initial_zoom: 'fit',
        background_color: 'black',
        titleBottom: "My image's title",
        copyright_text: "Copyright 2017 by John Smith",
        copyright_url: "http://www.example.com/copyright.html",
        fullscreen_control: true,
    });
});
```

##Adobe Lightroom plugin
TO DO.

##WordPress plugin
The plugin creates a new shortcode that you can embed in your content.
The shortcode creates a \<div> element at the point of use in your content.
This div has a CSS class named "liv_container" that you can use to style all LIVs on a single page.
The first LIV div created has an HTML id of "liv_0", the next "liv_1", and so on. You can use these to set CSS styles for individual LIVs.

All parameters to the shortcode match the names of paremeters to the jQuery library.
There is an additional parameter named 'height' which you can use to set the pixel height of the div that is inserted.
If you don't set it, the height defaults to 300px.
 
Here is an example:
```
[liv height='600' title_top='My Panorama Title' tile_path='/my_tiles' image_width='7788' image_height='2805']
```

TO DO: how to configure the WordPress plugin's defaults in WP Admin such as the Google Maps API key.
