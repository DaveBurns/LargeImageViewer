--[[----------------------------------------------------------------------------

MIT License

Copyright (c) 2017 David F. Burns

This file is part of LrLargeImageViewer.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

------------------------------------------------------------------------------]]

require 'strict'
local Debug = require 'Debug'.init()

-- Lightroom API
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
--local LrErrors = import 'LrErrors'
local LrDialogs = import 'LrDialogs'
--local LrTasks = import 'LrTasks'
local LrProgressScope = import 'LrProgressScope'

--============================================================================--

local DFB = require 'DFB'

local LIVTask = {}


function LIVCheckFreeDiskSpace( path, extents )
	Debug.logn( "Checking free disk space" )

	local volumeAttributes = LrFileUtils.volumeAttributes( path )
	local volumeFreeSpace = volumeAttributes.fileSystemFreeSize
	Debug.logn("\tFree space: " .. volumeFreeSpace)

	local numTiles = calcNumTiles( extents )
	-- TODO: weak approximation. What if JPEG quality varies?
	local expectedTileFileSize = 60 * 1024;

	if ( volumeFreeSpace < ( numTiles * expectedTileFileSize ) ) then
		Debug.logn( "\tFail: need an estimated " .. ( numTiles * expectedTileFileSize ) )
		return "fail", "Not enough free space on disk"
	end

	Debug.logn( "\tsuccess" )
	return "success", nil
end


function LIVCreateOutputDirectories( basePath )
	Debug.logn( "Creating output directories" )

	local result, message

	result, message = DFB.createDirectory( basePath )
	if ( result == "fail" ) then
		return 'fail', 'Could not create directory: ' .. basePath
	end

    local tilePath = LrPathUtils.child( basePath, 'tiles' )
	result, message = DFB.createDirectory( tilePath )
	if ( result == 'fail' ) then
        return 'fail', 'Could not create directory: ' .. tilePath
	end

	Debug.logn( '\tsuccess' )
	return 'success', nil
end


function LIVCopyStaticFiles( outputDir )
	Debug.logn( 'Copying static files' )

	local result, message

    local src = _PLUGIN:resourceId( 'jquery.largeimageviewer.js' )
    local dest = LrPathUtils.child( outputDir, 'jquery.largeimageviewer.js' )
	result, message = DFB.copyFile( src, dest, true )
	if ( result == 'fail' ) then
        return 'fail', 'Could not copy from ' .. src .. ' to ' .. dest
	end
   
	Debug.logn( '\tsuccess' )
	return 'success', nil
end


function LIVGenerateHTMLFromTemplate( outputDir, tokenTable )
	Debug.logn( "Generating HTML from template" )

    local infile, outfile
    local err_msg, err_code

	infile, err_msg, err_code = io.open( _PLUGIN:resourceId( 'index.template.html' ), 'r' )
	if not infile then
		return 'fail', 'could not open input file. ' .. err_msg .. ' code: ' .. err_code
	end

	outfile, err_msg, err_code = io.open( LrPathUtils.child( outputDir, 'index.html' ), 'w' )
	if not outfile then
		return 'fail', 'could not open output file. ' .. err_msg .. ' code: ' .. err_code
	end

    local success
	for line in infile:lines() do
		line = DFB.replaceTokens( tokenTable, line )
		success, err_msg, err_code = outfile:write( line, '\n' )
        if not success then
            return 'fail', 'Could not write to HTML file: ' .. err_msg .. ' code: ' .. ( err_code and tostring( err_code ) or '<none>' )
        end
	end

	infile:close()
	outfile:close()

	Debug.logn( '\tsuccess' )
	return "success", nil
end


function LIVGenerateTiles( tilerProgressScope, extents, outputDir, exportParams, path, filename, width, height )
	Debug.logn( 'Generating ' .. #extents .. ' levels of tiles.' )

	Debug.logn( 'outputDir: ' .. outputDir )
	Debug.logn( 'path: ' .. path )
	Debug.logn( 'filename: ' .. filename )
	
	for i, _ in ipairs( extents ) do
		Debug.logn( '\tTiling zoom level: ' .. ( i - 1 ) )

		if ( tilerProgressScope:isCanceled() ) then
			Debug.logn( '\tTiler canceled' )
			break
		end
		
		local tile_dir = outputDir .. '/tiles'
      
		local IMConvertParams = {}
		local execOptions = {}

        if string.len( exportParams.liv_tiler_IMConvertPath ) > 0 then
            table.insert( IMConvertParams, exportParams.liv_tiler_IMConvertPath )
        else
            table.insert( IMConvertParams, _PLUGIN.path .. '/bin' .. ( WIN_ENV and '/magick.exe' or '/magick' ) )
        end

        table.insert( IMConvertParams, 'convert' )

        -- order of params is important here because it tells IM what order to perform the operations
      
		if ( Debug.enabled ) then
--			table.insert( IMConvertParams, "-monitor" )		-- enabling this slows IM down a LOT
		end
      
		table.insert( IMConvertParams, path )
      
		if ( ( extents[i].widthInPixels ~= width ) or ( extents[ i ].heightInPixels ~= height ) ) then
			table.insert( IMConvertParams, '-resize' )
			table.insert( IMConvertParams, extents[ i ].widthInPixels .. 'x' .. extents[i].heightInPixels )
		end
      
		table.insert( IMConvertParams, '-unsharp' )
		local sigma = exportParams.liv_tiler_SharpenRadius
		if ( sigma > 1 ) then
			sigma = math.sqrt( exportParams.liv_tiler_SharpenRadius )
		end
		table.insert( IMConvertParams, exportParams.liv_tiler_SharpenRadius .. 'x' .. sigma .. '+' ..
                                       exportParams.liv_tiler_SharpenAmount .. '+' .. exportParams.liv_tiler_SharpenThreshold )

		-- add border if asked for
		if ( exportParams.liv_tiler_BorderColor ~= 'none' ) then
			-- must set border color first since the border command executes immediately
			table.insert( IMConvertParams, '-bordercolor ' .. exportParams.liv_tiler_BorderColor )
			table.insert( IMConvertParams, '-border 1' )
		end

		table.insert( IMConvertParams, '-background ' .. exportParams.liv_viewer_BackgroundColor )
      
		table.insert( IMConvertParams, '-extent' )
		local w = extents[ i ].widthInTiles * 256
		local h = extents[ i ].heightInTiles * 256
		table.insert( IMConvertParams, w .. 'x' .. h)

		table.insert( IMConvertParams, '-gravity northwest' )

		table.insert( IMConvertParams, '-crop 256x256' )

		table.insert( IMConvertParams, '-quality ' .. exportParams.liv_tiler_TileJPEGQuality )

		table.insert( IMConvertParams, '-set filename:tile "%[fx:page.x/256]_%[fx:page.y/256]"' )

        local pathDelimiter
        if ( WIN_ENV == true ) then
            pathDelimiter = '\\'
        else
            pathDelimiter = '/'
        end

        table.insert( IMConvertParams, '"' .. tile_dir .. pathDelimiter .. 'tile_' .. ( i - 1 ) .. '_%[filename:tile].jpg"' )

--        Debug.logn( DFB.tableToString( IMConvertParams ) )

		execOptions.workingDir = LrPathUtils.parent( path )
		
		Debug.logn( '\t\tRunning tiler' )
		local execResult, stdoutTable, stderrTable = DFB.execAndCapture( exportParams.liv_tiler_IMConvertPath, IMConvertParams, execOptions )
      
		Debug.logn( '\t\t\tthe result is: ' .. execResult );
		if ( execResult ~= 0 ) then
			Debug.logn( 'ERROR. Aborting tiling process.' )
			break
		end
		if ( #stdoutTable > 0 ) then
			Debug.logn( 'STDOUT: ')
			Debug.logn( DFB.tableToString( stdoutTable ) )
		end
		if ( #stderrTable > 0 ) then
			Debug.logn( 'STDERR: ')
			Debug.logn( DFB.tableToString( stderrTable ) )
		end

		tilerProgressScope:setPortionComplete( i, #extents )
	end
	
	tilerProgressScope:done()
	
end



--------------------------------------------------------------------------------

function calcImageZoomExtents( origWidth, origHeight, tileSize )
	Debug.logn( 'Calculating zoom extents: ' .. origWidth .. ' x ' .. origHeight )
   
	local nextWidth = origWidth
	local nextHeight = origHeight
	local divisor = 1
	local extentList = {}

	local extent

	while ( ( nextWidth > tileSize ) or ( nextHeight > tileSize ) ) do
		nextWidth = math.ceil( origWidth / divisor )
		nextHeight = math.ceil( origHeight / divisor )

		extent = {}
		extent[ 'widthInPixels' ] = nextWidth
		extent[ 'heightInPixels' ] = nextHeight
		extent[ 'widthInTiles' ] = math.ceil( nextWidth / tileSize )
		extent[ 'heightInTiles' ] = math.ceil( nextHeight / tileSize )

		table.insert( extentList, 1, extent )

		divisor = divisor * 2
	end
   
	Debug.logn( DFB.tableToString( extentList, 'IMAGE EXTENT TABLE: extentList' ) )

	return extentList
end


function calcNumTiles( extents )
	Debug.logn( 'BEGIN calcNumTiles' )

	local total = 0

	for _, v in pairs( extents ) do
		total = total + v[ 'widthInTiles' ] * v[ 'heightInTiles' ]
	end

	Debug.logn( '\tNumber of tiles: ' .. total )

	return total
end


function generateGAScript( GAPropertyID )
    local script = [[
        <script type="text/javascript">
            var _gaq = _gaq || [];
            _gaq.push(['_setAccount', ']] .. GAPropertyID .. [[']);
            _gaq.push(['_trackPageview']);

            (function() {
                var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
                ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
                var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
            })();
        </script>
    ]]

    return script
end


LIVTask.processRenderedPhotos = function( functionContext, exportContext )

	Debug.logn( 'BEGIN processRenderedPhotos' )

	-- Make a local reference to the export parameters.

	local exportSession = exportContext.exportSession
	local exportParams = exportContext.propertyTable

	-- Set progress title.

	local nPhotos = exportSession:countRenditions()

	local progressScope = exportContext:configureProgress {
		title = nPhotos > 1
		and 'Creating LIV for ' .. nPhotos .. ' photos'
		or 'Creating LIV for one photo',
	}
   
	Debug.logn( DFB.tableToString (exportParams, 'EXPORT PARAMS: ') )

	-- Iterate through photo renditions.
   
	local failures = {}
   
	for i, rendition in exportContext:renditions{ stopIfCanceled = true } do
      
		-- Get next photo.
      
		local photo = rendition.photo
		local success, pathOrMessage = rendition:waitForRender()

		-- Check for cancellation again after photo has been rendered.

		if progressScope:isCanceled() then break end

        local rendition_errors = {}

        if success then

			-- get photo dim's and calc zoom extents
			local croppedDimensions
			photo.catalog:withReadAccessDo( function()
												croppedDimensions = photo:getRawMetadata( 'croppedDimensions' )
											end
											)

			-- check for border and if so, add 2 to width and height
			if ( exportParams.liv_tiler_BorderColor ~= 'none' ) then
				croppedDimensions.width = croppedDimensions.width + 2
				croppedDimensions.height = croppedDimensions.height + 2
			end
			
			-- calc the size of each zoom level
			local zoomExtents = calcImageZoomExtents( croppedDimensions.width, croppedDimensions.height, 256)

			Debug.logn( '----- METADATA' )
			local metadataTable = photo:getFormattedMetadata( nil )
			Debug.logn( DFB.tableToString ( metadataTable ) )
			Debug.logn( '----- METADATA' )

			metadataTable.PAGETITLE = exportParams.liv_page_PageTitle
			metadataTable.IMGWIDTH = croppedDimensions.width
			metadataTable.IMGHEIGHT = croppedDimensions.height
			metadataTable.IMGTILESIZE = 256
			metadataTable.BACKGROUNDCOLOR = exportParams.liv_viewer_BackgroundColor
			metadataTable.INITIALZOOM = exportParams.liv_viewer_InitialZoom
			metadataTable.INITIALX = exportParams.liv_viewer_InitialX
			metadataTable.INITIALY = exportParams.liv_viewer_InitialY
			if ( exportParams.liv_page_Size == 'fit' ) then
				metadataTable.DIVSIZE = 'height: 100%;'
			else
				metadataTable.DIVSIZE = 'height: ' .. exportParams.liv_page_SizeCustomHeight .. 'px; width: ' .. exportParams.liv_page_SizeCustomWidth .. 'px;'
			end
			metadataTable.GMAPSAPIKEY = exportParams.liv_page_GMapsApiKey
            metadataTable.TITLETOPTEXT = string.len( exportParams.liv_page_textOverlayTopText ) > 0 and exportParams.liv_page_textOverlayTopText or ''
            metadataTable.TITLEBOTTOMTEXT = string.len( exportParams.liv_page_textOverlayBottomText ) > 0 and exportParams.liv_page_textOverlayBottomText or ''

            if ( metadataTable.copyright ~= nil and string.len( DFB.trim( metadataTable.copyright ) ) > 0 ) then
                metadataTable.COPYRIGHTTEXT = DFB.encodeHTMLEntities( DFB.trim( metadataTable.copyright ) )
                if ( metadataTable.copyrightInfoUrl ~= nil and string.len( DFB.trim( metadataTable.copyrightInfoUrl ) ) > 0 ) then
                    metadataTable.COPYRIGHTURL = DFB.trim( metadataTable.copyrightInfoUrl )
                elseif ( metadataTable.creatorUrl ~= nil and string.len( DFB.trim( metadataTable.creatorUrl ) ) > 0 ) then
                    metadataTable.COPYRIGHTURL = DFB.trim( metadataTable.creatorUrl )
                else
                    metadataTable.COPYRIGHTURL = ''
                end
            end

            local addlHeadContents = ''
            if ( string.len( DFB.trim( exportParams.liv_page_GAPropertyID ) ) > 0 ) then
                addlHeadContents = addlHeadContents .. generateGAScript( DFB.trim( exportParams.liv_page_GAPropertyID ) )
            end
            metadataTable.ADDITIONALHTMLHEADCONTENTS = addlHeadContents


			local result, message
			local base_output_path = DFB.splitPath( pathOrMessage )
			--	 Debug.logn( to_string( base_output_path ) )
			local output_path = LrPathUtils.child( exportParams.liv_tiler_ExportPath, base_output_path.basename )

			-- check disk free space
			result, message = LIVCheckFreeDiskSpace( output_path, zoomExtents )
			if ( result == 'fail' ) then
                table.insert( rendition_errors, message )
			end

			-- create output directories: the base dir and tile subdirs
			result, message = LIVCreateOutputDirectories( output_path )
			if ( result == 'fail' ) then
                table.insert( rendition_errors, message )
			end

			-- copy files
			result, message = LIVCopyStaticFiles( output_path )
			if ( result == 'fail' ) then
                table.insert( rendition_errors, message )
			end

			-- generate web page via template
			result, message = LIVGenerateHTMLFromTemplate( output_path, metadataTable )
			if ( result == 'fail' ) then
                table.insert( rendition_errors, message )
			end

			-- convert rendered file to tiles
			local tilerProgressScope = LrProgressScope( { parent = progressScope,
														  functionContext = functionContext,
														  parentEndRange = (i / nPhotos)
														} )
			tilerProgressScope:setCancelable( true )

			result, message = LIVGenerateTiles( tilerProgressScope, zoomExtents, output_path, exportParams,
			                                    pathOrMessage, base_output_path.filename,
												croppedDimensions.width, croppedDimensions.height )
			if ( result == 'fail' ) then
                table.insert( rendition_errors, message )
			end

		end

        if #rendition_errors > 0 then
            local nice_error = output_path.filename .. '\n'
            nice_error = nice_error .. table.concat( rendition_errors, '\n\t' )
			table.insert( failures, nice_error )
        end
         
    end

	Debug.logn( '********* LIV RENDERING FINISHED ************' )
   
	if #failures > 0 then
		LrDialogs.message( 'Some errors occurred: ', table.concat( failures, '\n' ) )
	end
   
end


return LIVTask
