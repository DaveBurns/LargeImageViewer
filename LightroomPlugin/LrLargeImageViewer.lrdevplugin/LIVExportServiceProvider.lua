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

local LrPathUtils = import 'LrPathUtils'


Debug.logn( '********* LIV STARTUP ***********' )


local LIVExportDialog = require 'LIVExportDialog'
local LIVTask = require 'LIVTask'


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
		{ key = 'liv_page_textOverlayTopText', default = '' },
		{ key = 'liv_page_textOverlayBottomText', default = '' },
		{ key = 'liv_page_Size', default = 'fit' },
		{ key = 'liv_page_SizeCustomHeight', default = '500' },
		{ key = 'liv_page_SizeCustomWidth', default = '500' },
		{ key = 'liv_page_GAPropertyID', default = '' },
		{ key = 'liv_viewer_BackgroundColor', default = 'black' },
		{ key = 'liv_viewer_InitialZoom', default = 'fit' },
		{ key = 'liv_viewer_InitialX', default = 'center' },
		{ key = 'liv_viewer_InitialY', default = 'center' },
		{ key = 'liv_tiler_ExportPath', default = LrPathUtils.getStandardFilePath( 'desktop' ) .. '/large_image' },
	},

	startDialog               = Debug.showErrors( LIVExportDialog.startDialog ),
	endDialog                 = Debug.showErrors( LIVExportDialog.endDialog ),
	sectionsForBottomOfDialog = Debug.showErrors( LIVExportDialog.sectionsForBottomOfDialog ),
	sectionsForTopOfDialog    = Debug.showErrors( LIVExportDialog.sectionsForTopOfDialog ),
	updateExportSettings      = Debug.showErrors( LIVExportDialog.updateExportSettings ),
	processRenderedPhotos     = Debug.showErrors( LIVTask.processRenderedPhotos ),
}
