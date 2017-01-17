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

-- Lightroom SDK
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
local LrPrefs = import 'LrPrefs'

--============================================================================--

local LIVExportDialog = {}

-------------------------------------------------------------------------------


LIVExportDialog.startDialog = function( propertyTable )
    Debug.logn( 'start dialog' )
    local prefs = LrPrefs.prefsForPlugin()

    propertyTable.liv_tiler_IMConvertPath = prefs.IMPath or ''
    propertyTable.liv_page_GMapsApiKey = prefs.GMapsApiKey or ''
end


LIVExportDialog.endDialog = function( propertyTable, why )
    Debug.logn( 'end dialog: ' .. why )
	if Debug.enabled then
    	Debug.lognpp( propertyTable )
    end
end


-------------------------------------------------------------------------------

LIVExportDialog.updateExportSettings = function( exportSettings )
	Debug.logn( 'Enter updateExportSettings' )
	
--	Debug.logn( DFB.tableToString( exportSettings, 'exportSettings BEFORE' ) )

	-- These are default settings for controls that are not displayed in the LIV export dialog
	exportSettings.LR_format = 'TIFF'
	exportSettings.LR_export_colorSpace = 'sRGB'
	exportSettings.LR_export_bitDepth = 8
	exportSettings.LR_tiff_compressionMethod = 'compressionMethod_None'
	exportSettings.LR_size_doConstrain = false
	exportSettings.LR_outputSharpeningOn = false

	exportSettings.liv_viewer_InitialX = 'center'
	exportSettings.liv_viewer_InitialY = 'center'

--	Debug.logn( DFB.tableToString( exportSettings, 'exportSettings AFTER' ) )
end


-------------------------------------------------------------------------------

LIVExportDialog.sectionsForTopOfDialog = function( f, propertyTable )

    Debug.logn("sectionsForTopOfDialog");

	local bind = LrView.bind

	local result = {
	
		{
			title = "Export Location",
			synopsis = bind { key = 'liv_tiler_ExportPath', object = propertyTable },

			f:row {
				f:static_text {
					title= 'Export To:',
				},
				f:edit_field {
					value = bind 'liv_tiler_ExportPath',
					width_in_chars = 40
				},
				f:push_button {
					title = 'Browse...',
					action = function(button)
						local result
						result = LrDialogs.runOpenPanel(
												{
													title = 'Choose an output folder',
													prompt = 'Select',
													canChooseFiles = false,
													canChooseDirectories = true,
													canCreateDirectories = true,
												}
											)
						if ( result ) then
							propertyTable.liv_tiler_ExportPath = result[1]
						end
					end,
				},
			},
		}
		
	}
	
	return result
end


LIVExportDialog.sectionsForBottomOfDialog = function( f, propertyTable )

    Debug.logn( 'sectionsForBottomOfDialog' );

	local bind = LrView.bind

	local result = {
		{
			title = "Image & Tiler",
			synopsis = bind {
				keys = { 'liv_tiler_BorderColor', 'liv_tiler_TileJPEGQuality' },
				operation = Debug.showErrors( function( binder, values, fromTable )
					if fromTable then
						local syn_text = 'Border Color: ' .. values.liv_tiler_BorderColor
						syn_text = syn_text .. '   JPEG Quality: ' .. values.liv_tiler_TileJPEGQuality
						return syn_text
					end
					return LrBinding.kUnsupportedDirection
				end ),
			},

			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='Border color: ',
					alignment = 'right',
					width = LrView.share 'tiler_label_width',
				},
				f:popup_menu {
					title = 'Border color',
					value = bind 'liv_tiler_BorderColor',
					width_in_chars = 6,
					items = {
						{ title = 'None', value = 'none' },
						{ title = 'Aqua', value = 'aqua' },
						{ title = 'Black', value = 'black' },
						{ title = 'Blue', value = 'blue' },
						{ title = 'Fuchsia', value = 'fuchsia' },
						{ title = 'Gray', value = 'gray' },
						{ title = 'Green', value = 'green' },
						{ title = 'Lime', value = 'lime' },
						{ title = 'Maroon', value = 'maroon' },
						{ title = 'Navy', value = 'navy' },
						{ title = 'Olive', value = 'olive' },
						{ title = 'Purple', value = 'purple' },
						{ title = 'Red', value = 'red' },
						{ title = 'Silver', value = 'silver' },
						{ title = 'Teal', value = 'teal' },
						{ title = 'White', value = 'white' },
						{ title = 'Yellow', value = 'yellow' },
					},
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='JPEG quality: ',
					alignment = 'right',
					width = LrView.share 'tiler_label_width',
				},
				f:slider {
					value = bind 'liv_tiler_TileJPEGQuality',
					min = 0,
					max = 100,
					width = 200,
					integral = true,
				},
				f:edit_field {
					value = bind 'liv_tiler_TileJPEGQuality',
					width_in_digits = 5,
					min = 0,
					max = 100,
					precision = 0,					
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='Sharpening: ',
					alignment = 'right',
					width = LrView.share 'tiler_label_width',
				},
				f:static_text {
					title = 'Radius: ',
				},
				f:edit_field {
					value = bind 'liv_tiler_SharpenRadius',
					width_in_digits = 5,
					min = 0,
					max = 10,
					precision = 1,
				},
				f:static_text {
					title = 'Amount: ',
				},
				f:edit_field {
					value = bind 'liv_tiler_SharpenAmount',
					width_in_digits = 5,
					min = 0,
					max = 4,
					precision = 2,
				},
				f:static_text {
					title = 'Threshold: ',
				},
				f:edit_field {
					value = bind 'liv_tiler_SharpenThreshold',
					width_in_digits = 5,
					min = 0,
					max = 10,
					precision = 2
				},
			},
		},

		{
			title = 'Web Page',
			synopsis = bind {
				keys = { 'liv_page_PageTitle', 'liv_page_Size', 'liv_page_SizeCustomHeight', 'liv_page_SizeCustomWidth', 'liv_viewer_BackgroundColor' },
				operation = Debug.showErrors( function( binder, values, fromTable )
					if fromTable then
						local syn_text = 'Page Title: '
						if ( string.len( values.liv_page_PageTitle ) > 0 ) then
							syn_text = syn_text .. 'set,'
						else
							syn_text = syn_text .. 'not set,'
						end
						if ( values.liv_page_Size == 'fit' ) then
							syn_text = syn_text .. '   Viewer Size: fit,'
						else
							syn_text = syn_text .. '   Viewer Size: ' .. values.liv_page_SizeCustomHeight .. 'px x ' .. values.liv_page_SizeCustomWidth .. 'px,'
						end
						syn_text = syn_text .. '   Background Color: ' .. values.liv_viewer_BackgroundColor
						return syn_text
					end
					return LrBinding.kUnsupportedDirection
				end ),
			},

			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='Page title: ',
					alignment = 'right',
					width = LrView.share 'page_label_width',
				},
				f:edit_field {
					value = bind 'liv_page_PageTitle',
					width_in_chars = 40,
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title="Text overlay - Top: ",
					alignment = 'right',
					width = LrView.share 'page_label_width',
				},
				f:edit_field {
					value = bind 'liv_page_textOverlayTopText',
					width_in_chars = 40,
				},
			},
			f:row {
				spacing = f:label_spacing(),
                f:static_text {
                    title="Text overlay - Bottom: ",
                    alignment = 'right',
                    width = LrView.share 'page_label_width',
                },
				f:edit_field {
					value = bind 'liv_page_textOverlayBottomText',
					width_in_chars = 40,
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title="Viewer size: ",
					alignment = 'right',
					width = LrView.share 'page_label_width',
				},
				f:radio_button {
					title = 'Fit to browser window',
					value = bind 'liv_page_Size',
					checked_value = 'fit',
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:spacer {
					width = LrView.share 'page_label_width',
				},
				f:radio_button {
					title = 'Custom:',
					value = bind 'liv_page_Size',
					checked_value = 'custom',
				},
				f:static_text {
					title="Height:",
					enabled = LrBinding.keyEquals( 'liv_page_Size', 'custom' ),
				},
				f:edit_field {
					value = bind 'liv_page_SizeCustomHeight',
					min = 0,
					precision = 0,
					width_in_digits = 4,
					enabled = LrBinding.keyEquals( 'liv_page_Size', 'custom' ),
				},
				f:static_text {
					title="px",
					enabled = LrBinding.keyEquals( 'liv_page_Size', 'custom' ),
				},
				f:static_text {
					title="Width:",
					enabled = LrBinding.keyEquals( 'liv_page_Size', 'custom' ),
				},
				f:edit_field {
					value = bind 'liv_page_SizeCustomWidth',
					min = 0,
					precision = 0,
					width_in_digits = 4,
					enabled = LrBinding.keyEquals( 'liv_page_Size', 'custom' ),
				},
				f:static_text {
					title="px",
					enabled = LrBinding.keyEquals( 'liv_page_Size', 'custom' ),
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='Background color: ',
					alignment = 'right',
					width = LrView.share 'page_label_width',
				},
				f:popup_menu {
					title = 'Background color',
					value = bind 'liv_viewer_BackgroundColor',
					width_in_chars = 6,
					items = {
						{ title = 'Aqua', value = 'aqua' },
						{ title = 'Black', value = 'black' },
						{ title = 'Blue', value = 'blue' },
						{ title = 'Fuchsia', value = 'fuchsia' },
						{ title = 'Gray', value = 'gray' },
						{ title = 'Green', value = 'green' },
						{ title = 'Lime', value = 'lime' },
						{ title = 'Maroon', value = 'maroon' },
						{ title = 'Navy', value = 'navy' },
						{ title = 'Olive', value = 'olive' },
						{ title = 'Purple', value = 'purple' },
						{ title = 'Red', value = 'red' },
						{ title = 'Silver', value = 'silver' },
						{ title = 'Teal', value = 'teal' },
						{ title = 'White', value = 'white' },
						{ title = 'Yellow', value = 'yellow' },
					}
				},
			},
            f:row {
                spacing = f:label_spacing(),
                f:static_text {
                    title='Google Analytics ID: ',
                    alignment = 'right',
                    width = LrView.share 'page_label_width',
                },
                f:edit_field {
                    value = bind 'liv_page_GAPropertyID',
                    width_in_chars = 20,
                },
                f:static_text {
                    title='(leave blank for none)',
                },
            },
		},

		{
			title = 'User Interface',
			synopsis = bind {
				keys = { 'liv_viewer_InitialZoom' },
				operation = Debug.showErrors( function( binder, values, fromTable )
					if fromTable then
						local syn_text = 'Initial Zoom: '
						if ( values.liv_viewer_InitialZoom == 'fit' ) then
							syn_text = syn_text .. 'best fit'
						else
							syn_text = syn_text .. 'smallest'
						end

						return syn_text
					end
					return LrBinding.kUnsupportedDirection
				end ),
			},

			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='Initial zoom level: ',
					alignment = 'right',
					width = LrView.share 'ui_label_width',
				},
				f:radio_button {
					title = 'Best fit',
					value = bind 'liv_viewer_InitialZoom',
					checked_value = 'fit',
				},
				f:radio_button {
					title = 'Smallest',
					value = bind 'liv_viewer_InitialZoom',
					checked_value = '1',
				},
			},
		},

	}

	return result	
end

return LIVExportDialog
