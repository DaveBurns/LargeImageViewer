--[[----------------------------------------------------------------------------

LIVExportDialogSections.lua
Export dialog customization for LIV

--------------------------------------------------------------------------------

 Copyright 2013 David F. Burns
 All Rights Reserved.

------------------------------------------------------------------------------]]

-- Lightroom SDK
local LrBinding = import 'LrBinding'
local LrView = import 'LrView'
local LrDialogs = import 'LrDialogs'
--local LrFtp = import 'LrFtp'

--============================================================================--

LIVExportDialogSections = {}  -- TODO: for clarity, should rename to just LIVExportDialog

-------------------------------------------------------------------------------

local updateExportStatus = function( propertyTable, ... )
	
	local message = nil
	
	repeat
		-- use a repeat loop to allow easy way to "break" out.
		-- (It only goes through once.)
		
		if propertyTable.ftpPreset == nil then
            -- TODO: fix this
			message = LOC "$$$/FtpUpload/ExportDialog/Messages/SelectPreset=Select or Create an FTP preset"
			break
		end
		
		if propertyTable.putInSubfolder and ( propertyTable.path == "" or propertyTable.path == nil ) then
            -- TODO: fix this
			message = LOC "$$$/FtpUpload/ExportDialog/Messages/EnterSubPath=Enter a destination path"
			break
		end
		
		local fullPath = propertyTable.ftpPreset.path or ""
		
		if propertyTable.putInSubfolder then
			fullPath = LrFtp.appendFtpPaths( fullPath, propertyTable.path )
		end
		
		propertyTable.fullPath = fullPath
		
	until true
	
	if message then
		propertyTable.message = message
		propertyTable.hasError = true
		propertyTable.hasNoError = false
		propertyTable.LR_canExport = false
		propertyTable.LR_cantExportBecause = message
	else
		propertyTable.message = nil
		propertyTable.hasError = false
		propertyTable.hasNoError = true
		propertyTable.LR_canExport = true
	end
	
	
end

-------------------------------------------------------------------------------

function LIVExportDialogSections.startDialog( propertyTable )
   DFB.logmsg("start dialog");

--[[	
	propertyTable:addObserver( 'items', updateExportStatus )
	propertyTable:addObserver( 'path', updateExportStatus )
	propertyTable:addObserver( 'putInSubfolder', updateExportStatus )
	propertyTable:addObserver( 'ftpPreset', updateExportStatus )

	updateExportStatus( propertyTable )
	--]]	
end

function LIVExportDialogSections.endDialog( propertyTable, why )
   DFB.logmsg("end dialog");
end


-------------------------------------------------------------------------------

function LIVExportDialogSections.updateExportSettings( exportSettings )
	DFB.logmsg( 'Enter updateExportSettings' )
	
--	DFB.logmsg( DFB.tableToString( exportSettings, 'exportSettings BEFORE' ) )

	-- These are default settings for controls that are not displayed in the LIV export dialog
	exportSettings.LR_format = 'TIFF'
	exportSettings.LR_export_colorSpace = 'sRGB'
	exportSettings.LR_export_bitDepth = 8
	exportSettings.LR_tiff_compressionMethod = 'compressionMethod_None'
	exportSettings.LR_size_doConstrain = false
	exportSettings.LR_outputSharpeningOn = false

	exportSettings.liv_viewer_InitialX = 'center'
	exportSettings.liv_viewer_InitialY = 'center'

--	DFB.logmsg( DFB.tableToString( exportSettings, 'exportSettings AFTER' ) )
end


-------------------------------------------------------------------------------

function LIVExportDialogSections.sectionsForTopOfDialog( f, propertyTable )

	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share

	DFB.logmsg("sectionsForTopOfDialog");

	local result = {
	
		{
			title = "Export Location",
			synopsis = bind { key = 'liv_tiler_ExportPath', object = propertyTable },

			f:row {
				f:static_text {
					title="Export To:",
				},
				f:edit_field {
					value = bind "liv_tiler_ExportPath",
					width_in_chars = 40
				},
				f:push_button {
					title = "Browse...",
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


function LIVExportDialogSections.sectionsForBottomOfDialog( f, propertyTable )

	local f = LrView.osFactory()
	local bind = LrView.bind
	local share = LrView.share

	DFB.logmsg("sectionsForBottomOfDialog");

	local result = {
		{
			title = "Image & Tiler",
			synopsis = bind {
				keys = { 'liv_tiler_BorderColor', 'liv_tiler_TileJPEGQuality' },
				operation = function( binder, values, fromTable )
					if fromTable then
						syn_text = 'Border Color: ' .. values.liv_tiler_BorderColor
						syn_text = syn_text .. '   JPEG Quality: ' .. values.liv_tiler_TileJPEGQuality
						return syn_text
					end
					return LrBinding.kUnsupportedDirection
				end,
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
--					tooltip = 'This is a tooltip', -- TODO
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
				operation = function( binder, values, fromTable )
					if fromTable then
						syn_text = 'Page Title: '
						if ( string.len( values.liv_page_PageTitle ) > 0 ) then
							syn_text = syn_text .. 'set,'
						else
							syn_text = syn_text .. 'not set,'
						end
						if ( values.liv_page_Size == 'fit' ) then
							syn_text = syn_text .. '   View Size: fit,'
						else
							syn_text = syn_text .. '   View Size: ' .. values.liv_page_SizeCustomHeight .. 'px x ' .. values.liv_page_SizeCustomWidth .. 'px,'
						end
						syn_text = syn_text .. '   Background Color: ' .. values.liv_viewer_BackgroundColor
						return syn_text
					end
					return LrBinding.kUnsupportedDirection
				end,
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
					title="Text overlays: ",
					alignment = 'right',
					width = LrView.share 'page_label_width',
				},
				f:checkbox {
					spacing = f:label_spacing(),
					alignment = 'right',
					width = LrView.share 'overlay_label_width',
					title = 'Top: ',
					value = bind 'liv_page_textOverlayTop',
					checked_value = true,
				},
				f:edit_field {
					value = bind 'liv_page_textOverlayTopText',
					width_in_chars = 40,
					enabled = LrBinding.keyEquals( 'liv_page_textOverlayTop', true ),
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:spacer {
					width = LrView.share 'page_label_width',
				},
				f:checkbox {
					spacing = f:label_spacing(),
					alignment = 'right',
					width = LrView.share 'overlay_label_width',
					title = 'Bottom: ',
					value = bind 'liv_page_textOverlayBottom',
					checked_value = true,
				},
				f:edit_field {
					value = bind 'liv_page_textOverlayBottomText',
					width_in_chars = 40,
					enabled = LrBinding.keyEquals( 'liv_page_textOverlayBottom', true ),
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title="View size: ",
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
		},

		{
			title = 'User Interface',
			synopsis = bind {
				keys = { 'liv_viewer_InitialZoom', 'liv_viewer_ZoomSize', 'liv_viewer_ShowPanControl' },
				operation = function( binder, values, fromTable )
					if fromTable then
						syn_text = 'Initial Zoom: '
						if ( values.liv_viewer_InitialZoom == 'fit' ) then
							syn_text = syn_text .. 'best fit,'
						else
							syn_text = syn_text .. 'smallest,'
						end
						syn_text = syn_text .. '   Zoom Control: ' .. values.liv_viewer_ZoomSize .. ',   Pan Control: '
						if ( values.liv_viewer_ShowPanControl ) then
							syn_text = syn_text .. 'show'
						else
							syn_text = syn_text .. 'hide'
						end
						return syn_text
					end
					return LrBinding.kUnsupportedDirection
				end,
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
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='Zoom control: ',
					alignment = 'right',
					width = LrView.share 'ui_label_width',
				},
				f:popup_menu {
					title = 'Zoom control',
					value = bind 'liv_viewer_ZoomSize',
					width_in_chars = 6,
					items = {
						{ title = 'Default', value = 'default' },
						{ title = 'Small', value = 'small' },
						{ title = 'Large', value = 'large' }
					},
				},
			},
			f:row {
				spacing = f:label_spacing(),
				f:static_text {
					title='Pan control: ',
					alignment = 'right',
					width = LrView.share 'ui_label_width',
				},
				f:checkbox {
					title="Show",
					value = bind 'liv_viewer_ShowPanControl',					
				},
			},
		},

		{
			title = "ImageMagick Location",
			synopsis = bind { key = 'liv_tiler_IMConvertPath', object = propertyTable },

			f:row {
				f:static_text {
					title="Path to ImageMagick convert program",
				},
				f:edit_field {
					value = bind "liv_tiler_IMConvertPath",
					width_in_chars = 25
				},
				f:push_button {
					title = "Browse...",
					action = function(button)
                                local options =
                                {
                                    title = 'Find the ImageMagick convert program:',
                                    prompt = 'Select',
                                    canChooseFiles = true,
                                    canChooseDirectories = false,
                                    canCreateDirectories = false,
                                    allowsMultipleSelection = false,
                                }
                                if ( WIN_ENV == true ) then
                                    options.fileTypes = 'exe'
                                else
                                    options.fileTypes = ''
                                end
                                local result
								result = LrDialogs.runOpenPanel( options )
								if ( result ) then
									propertyTable.liv_tiler_IMConvertPath = result[1]
								end
							end
				},
			},
		},
	}

	return result	
end
