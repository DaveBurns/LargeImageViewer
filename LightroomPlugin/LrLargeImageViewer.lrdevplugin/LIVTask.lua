--[[----------------------------------------------------------------------------

LIVTask.lua

--------------------------------------------------------------------------------

 Copyright 2013 David F. Burns
 All Rights Reserved.

------------------------------------------------------------------------------]]

-- Lightroom API
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrErrors = import 'LrErrors'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrProgressScope = import 'LrProgressScope'

--============================================================================--

LIVTask = {}

function LIVCheckFreeDiskSpace( path, extents )
	DFB.logmsg( "Checking free disk space" )

	local volumeAttributes = LrFileUtils.volumeAttributes( path )
	local volumeFreeSpace = volumeAttributes.fileSystemFreeSize
	DFB.logmsg("\tFree space: " .. volumeFreeSpace)

	local numTiles = calcNumTiles( extents )
	-- TODO: weak approximation. What if JPEG quality varies?
	local expectedTileFileSize = 60 * 1024;

	if (volumeFreeSpace < (numTiles * expectedTileFileSize)) then
		DFB.logmsg( "\tFail: need an estimated " .. ( numTiles * expectedTileFileSize ) )
		return "fail", "Not enough free space on disk"
	end

	DFB.logmsg( "\tsuccess" )
	return "success", nil
end


function LIVCreateOutputDirectories( basePath )
	DFB.logmsg( "Creating output directories" )

	local result, message

	result, message = DFB.createDirectory( basePath )
	if ( result == "fail" ) then
		-- TODO: collect errors here or alert immediately?
	end
   
	result, message = DFB.createDirectory( LrPathUtils.child( basePath, 'tiles' ) )
	if ( result == 'fail' ) then
		-- TODO: collect errors here (or alert immediately?)
	end

	DFB.logmsg( '\tsuccess' )
	return 'success', nil
end


function LIVCopyStaticFiles( outputDir )
	DFB.logmsg( 'Copying static files' )

	local result, message

	result, message = DFB.copyFile( _PLUGIN:resourceId( 'jquery.largeimageviewer.js' ), LrPathUtils.child( outputDir, 'jquery.largeimageviewer.js' ), true )
	if ( result == 'fail' ) then
		-- TODO: collect errors here or fail immediately
	end
   
	DFB.logmsg( '\tsuccess' )
	return 'success', nil
end


function LIVGenerateHTMLFromTemplate( outputDir, tokenTable )
	DFB.logmsg( "Generating HTML from template" )

	local infile, errMsg, errCode = io.open( _PLUGIN:resourceId( 'index.template.html' ), 'r' )
	if ( not infile ) then
		return 'fail', 'could not open input file. ' .. errMsg .. ' code: ' .. errCode
	end

	local outfile = io.open( LrPathUtils.child( outputDir, 'index.html' ), 'w' )
	if ( not outfile ) then
		return 'fail', 'could not open output file. ' .. errMsg .. ' code: ' .. errCode
	end
	
	for line in infile:lines() do
		line = DFB.replaceTokens( tokenTable, line )
		outfile:write(line .. '\n')  -- TODO: handle nil on error
	end

	local r1 = infile:close()
	local r2 = outfile:close()

	DFB.logmsg( "\tsuccess" )
	return "success", nil
end


function LIVGenerateTiles( tilerProgressScope, extents, outputDir, exportParams, path, filename, width, height )
	DFB.logmsg( 'Generating ' .. #extents .. ' levels of tiles.' )

	DFB.logmsg( 'outputDir: ' .. outputDir )
	DFB.logmsg( 'path: ' .. path )
	DFB.logmsg( 'filename: ' .. filename )
	
	for i, v in ipairs( extents ) do
		DFB.logmsg( "\tTiling zoom level: " .. (i - 1) )

		if ( tilerProgressScope:isCanceled() ) then
			DFB.logmsg( '\tTiler canceled' )
			break
		end
		
		local tile_dir = outputDir .. "/tiles"
      
		local IMConvertParams = {}
		local execOptions = {}
		
		-- order of params is important here because it tells IM what order to perform the operations
      
		if ( livDebug ) then
--			table.insert( IMConvertParams, "-monitor" )		-- enabling this slows IM down a LOT
		end
      
		table.insert( IMConvertParams, path )
      
		if ( ( extents[i].widthInPixels ~= width ) or ( extents[i].heightInPixels ~= height ) ) then
			table.insert( IMConvertParams, "-resize" )
			table.insert( IMConvertParams, extents[i].widthInPixels .. "x" .. extents[i].heightInPixels )
		end
      
		table.insert( IMConvertParams, "-unsharp" )
		local sigma = exportParams.liv_tiler_SharpenRadius
		if ( sigma > 1 ) then
			sigma = math.sqrt( exportParams.liv_tiler_SharpenRadius )
		end
		table.insert( IMConvertParams, exportParams.liv_tiler_SharpenRadius .. "x" .. sigma .. "+" .. exportParams.liv_tiler_SharpenAmount .. "+" .. exportParams.liv_tiler_SharpenThreshold )

		-- add border if asked for
		if ( exportParams.liv_tiler_BorderColor ~= 'none' ) then
			-- must set border color first since the border command executes immediately
			table.insert( IMConvertParams, '-bordercolor ' .. exportParams.liv_tiler_BorderColor )
			table.insert( IMConvertParams, '-border 1' )
		end

		table.insert( IMConvertParams, "-background " .. exportParams.liv_viewer_BackgroundColor )
      
		table.insert( IMConvertParams, "-extent" )
		local w = extents[i].widthInTiles * 256
		local h = extents[i].heightInTiles * 256
		table.insert( IMConvertParams, w .. "x" .. h)

		table.insert( IMConvertParams, "-gravity northwest" )

		table.insert( IMConvertParams, "-crop 256x256" )

		table.insert( IMConvertParams, "-quality " .. exportParams.liv_tiler_TileJPEGQuality )

		table.insert( IMConvertParams, '-set filename:tile "%[fx:page.x/256]_%[fx:page.y/256]"' )

        local pathDelimiter
        if ( WIN_ENV == true ) then
            pathDelimiter = '\\'
        else
            pathDelimiter = '/'
        end

        table.insert( IMConvertParams, '"' .. tile_dir .. pathDelimiter .. 'tile_' .. (i - 1) .. '_%[filename:tile].jpg"' )

--        DFB.logmsg( DFB.tableToString( IMConvertParams ) )

		execOptions.workingDir = LrPathUtils.parent( path )
		
		DFB.logmsg( "\t\tRunning tiler" )
		local execResult, stdoutTable, stderrTable = DFB.execAndCapture( exportParams.liv_tiler_IMConvertPath, IMConvertParams, execOptions )
      
		DFB.logmsg( "\t\t\tthe result is: " .. execResult );
		if ( execResult ~= 0 ) then
			DFB.logmsg( 'ERROR. Aborting tiling process.' )
			break
		end
		if ( #stdoutTable > 0 ) then
			DFB.logmsg( 'STDOUT: ')
			DFB.logmsg( DFB.tableToString( stdoutTable ) )
		end
		if ( #stderrTable > 0 ) then
			DFB.logmsg( 'STDERR: ')
			DFB.logmsg( DFB.tableToString( stderrTable ) )
		end

		tilerProgressScope:setPortionComplete( i, #extents )
	end
	
	tilerProgressScope:done()
	
end



--------------------------------------------------------------------------------

function calcImageZoomExtents( origWidth, origHeight, tileSize )
	DFB.logmsg("Calculating zoom extents: " .. origWidth .. " x " .. origHeight)
   
	local nextWidth = origWidth
	local nextHeight = origHeight
	local divisor = 1
	local extentList = {}

	local extent

	while ( ( nextWidth > tileSize ) or ( nextHeight > tileSize ) ) do
		nextWidth = math.ceil( origWidth / divisor )
		nextHeight = math.ceil( origHeight / divisor )

		extent = {}
		extent["widthInPixels"] = nextWidth
		extent["heightInPixels"] = nextHeight
		extent["widthInTiles"] = math.ceil( nextWidth / tileSize )
		extent["heightInTiles"] = math.ceil( nextHeight / tileSize )

		table.insert( extentList, 1, extent )

		divisor = divisor * 2
	end
   
	DFB.logmsg( DFB.tableToString( extentList, 'IMAGE EXTENT TABLE: extentList' ) )

	return extentList
end


function calcNumTiles( extents )
	DFB.logmsg("BEGIN calcNumTiles")

	local total = 0

	for k,v in pairs( extents ) do
		total = total + v["widthInTiles"] * v["heightInTiles"]
	end

	DFB.logmsg( "\tNumber of tiles: " .. total )

	return total
end


function LIVTask.processRenderedPhotos( functionContext, exportContext )
   
	-- Make a local reference to the export parameters.

	local exportSession = exportContext.exportSession
	local exportParams = exportContext.propertyTable

	-- Set progress title.

	local nPhotos = exportSession:countRenditions()

	local progressScope = exportContext:configureProgress {
		title = nPhotos > 1
		and LOC( "$$$/FtpUpload/Upload/Progress=Creating LIV for ^1 photos", nPhotos ) -- TODO: fix these LOC id's
		or LOC "$$$/FtpUpload/Upload/Progress/One=Creating LIV for one photo",
	}
   
	DFB.logmsg( DFB.tableToString (exportParams, 'EXPORT PARAMS: ') )

	-- Iterate through photo renditions.
   
	local failures = {}
   
	for i, rendition in exportContext:renditions{ stopIfCanceled = true } do
      
		-- Get next photo.
      
		local photo = rendition.photo
		local success, pathOrMessage = rendition:waitForRender()

		-- Check for cancellation again after photo has been rendered.

		if progressScope:isCanceled() then break end

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

			DFB.logmsg( '----- METADATA' )
			local metadataTable = photo:getFormattedMetadata( nil )
			DFB.logmsg( DFB.tableToString ( metadataTable ) )
			DFB.logmsg( '----- METADATA' )

			metadataTable.PAGETITLE = exportParams.liv_page_PageTitle
			metadataTable.IMGWIDTH = croppedDimensions.width
			metadataTable.IMGHEIGHT = croppedDimensions.height
			metadataTable.IMGTILESIZE = 256
			metadataTable.BACKGROUNDCOLOR = exportParams.liv_viewer_BackgroundColor
			metadataTable.INITIALZOOM = exportParams.liv_viewer_InitialZoom
			metadataTable.INITIALX = exportParams.liv_viewer_InitialX
			metadataTable.INITIALY = exportParams.liv_viewer_InitialY
			metadataTable.ZOOMSIZE = exportParams.liv_viewer_ZoomSize
			metadataTable.SHOWPANCONTROL = exportParams.liv_viewer_ShowPanControl
			if ( exportParams.liv_page_Size == 'fit' ) then
				metadataTable.DIVSIZE = 'height: 100%;'
			else
				metadataTable.DIVSIZE = 'height: ' .. exportParams.liv_page_SizeCustomHeight .. 'px; width: ' .. exportParams.liv_page_SizeCustomWidth .. 'px;'
			end
			metadataTable.TEXTOVERLAYCLASS1 = ''
			metadataTable.TEXTOVERLAYTEXT1 = ''
			if ( exportParams.liv_page_textOverlayTop ) then
				metadataTable.TEXTOVERLAYCLASS1 = 'livTextTopCenter'
				metadataTable.TEXTOVERLAYTEXT1 = exportParams.liv_page_textOverlayTopText
			end
			metadataTable.TEXTOVERLAYCLASS2 = ''
			metadataTable.TEXTOVERLAYTEXT2 = ''
			if ( exportParams.liv_page_textOverlayBottom ) then
				metadataTable.TEXTOVERLAYCLASS2 = 'livTextBottomCenter'
				metadataTable.TEXTOVERLAYTEXT2 = exportParams.liv_page_textOverlayBottomText
			end

			local result, message
			local base_output_path = DFB.splitPath( pathOrMessage )
			--	 DFB.logmsg( to_string( base_output_path ) )
			local output_path = LrPathUtils.child( exportParams.liv_tiler_ExportPath, base_output_path.basename )

			-- check disk free space
			result, message = LIVCheckFreeDiskSpace( output_path, zoomExtents )
			if ( result == "fail" ) then
				-- TODO: collect errors here (or alert immediately?)
			end

			-- create output directories: the base dir and tile subdirs
			result, message = LIVCreateOutputDirectories( output_path )
			if ( result == "fail" ) then
				-- TODO: collect errors here (or alert immediately?)
			end

			-- copy files
			result, message = LIVCopyStaticFiles( output_path )
			if ( result == "fail" ) then
				-- TODO: collect errors here (or alert immediately?)
			end

			-- generate web page via template
			result, message = LIVGenerateHTMLFromTemplate( output_path, metadataTable )
			if ( result == "fail" ) then
				-- TODO: collect errors here (or alert immediately?)
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
			if ( result == "fail" ) then
				-- TODO: collect errors here (or alert immediately?)
			end

		end

--       if not success then
--			table.insert( failures, output_path.filename )
--       end
         
	end
   
	DFB.logmsg ("********* LIV RENDERING FINISHED ************")
   
	if #failures > 0 then
		local message
		if #failures == 1 then
			message = LOC "$$$/FtpUpload/Upload/Errors/OneFileFailed=1 file failed to upload correctly." -- TODO: fix these LOC id's
		else
			message = LOC ( "$$$/FtpUpload/Upload/Errors/SomeFileFailed=^1 files failed to upload correctly.", #failures )
		end
		LrDialogs.message( message, table.concat( failures, '\n' ) )
	end
   
end
