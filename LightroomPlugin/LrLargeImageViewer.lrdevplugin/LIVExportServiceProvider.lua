--[[----------------------------------------------------------------------------

LIVExportServiceProvider.lua
Export service provider description for LIV

--------------------------------------------------------------------------------

 Copyright 2013 David F. Burns
 All Rights Reserved.

------------------------------------------------------------------------------]]

livDebug = "true"
--livDebug = nil

require 'DFB'
DFB.logmsg( '********* LIV STARTUP ************' )

-- Lightroom SDK
-- local LrView = import 'LrView'

-- LargeImageViewer plug-in
require 'LIVExportDialogSections'
require 'LIVTask'


--============================================================================--

return {
	hideSections = { 'exportLocation', 'fileNaming', 'fileSettings', 'imageSettings', 'metadata', 'outputSharpening', 'video' },
	-- hidePrintResolution = true,
	-- disallowFileFormats = nil, -- nil equates to all available formats
	-- disallowColorSpaces = nil, -- nil equates to all color spaces
	exportPresetFields = {
		{ key = 'liv_tiler_BorderColor', default = 'none' },
		{ key = 'liv_tiler_TileJPEGQuality', default = 60 },
		{ key = 'liv_tiler_SharpenRadius', default = 0.5 },
		{ key = 'liv_tiler_SharpenAmount', default = 2 },
		{ key = 'liv_tiler_SharpenThreshold', default = 0.01 },
		{ key = 'liv_page_PageTitle', default = '' },
		{ key = 'liv_page_textOverlayTop', default = false },
		{ key = 'liv_page_textOverlayTopText', default = '' },
		{ key = 'liv_page_textOverlayBottom', default = false },
		{ key = 'liv_page_textOverlayBottomText', default = '' },
		{ key = 'liv_page_ImageDivID', default = 'largeImage' },
		{ key = 'liv_page_Size', default = 'fit' },
		{ key = 'liv_page_SizeCustomHeight', default = '500' },
		{ key = 'liv_page_SizeCustomWidth', default = '500' },
		{ key = 'liv_viewer_BackgroundColor', default = 'black' },
		{ key = 'liv_viewer_InitialZoom', default = 'fit' },
		{ key = 'liv_viewer_InitialX', default = 'center' },
		{ key = 'liv_viewer_InitialY', default = 'center' },
		{ key = 'liv_viewer_ZoomSize', default = 'default' },
		{ key = 'liv_viewer_ShowPanControl', default = false },
		{ key = 'liv_tiler_IMConvertPath', default = 'C:\\Program Files\\ImageMagick-6.6.7-Q16\\convert.exe' }, -- TODO: ifdef default for MAC
		{ key = 'liv_tiler_ExportPath', default = 'C:\\Users\\Dave\\Desktop\\livtest1' }, -- TODO: set more sensible default
	},
	startDialog = LIVExportDialogSections.startDialog,
	endDialog = LIVExportDialogSections.endDialog,
	sectionsForBottomOfDialog = LIVExportDialogSections.sectionsForBottomOfDialog,
	sectionsForTopOfDialog = LIVExportDialogSections.sectionsForTopOfDialog,
	updateExportSettings = LIVExportDialogSections.updateExportSettings,
	processRenderedPhotos = LIVTask.processRenderedPhotos 
}
