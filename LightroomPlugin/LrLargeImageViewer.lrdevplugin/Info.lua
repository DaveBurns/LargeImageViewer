--[[----------------------------------------------------------------------------

Info.lua
Summary information for Large Image Viewer plug-in

--------------------------------------------------------------------------------

 Copyright 2013 David F. Burns
 All Rights Reserved.

------------------------------------------------------------------------------]]

return {
	LrSdkVersion = 3.0,
	LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'com.daveburnsphoto.lightroom.export.liv',
	LrPluginName = 'Large Image Viewer',
	LrPluginInfoUrl = 'http://www.daveburnsphoto.com/liv/', -- TODO: create this page

	VERSION = { major = 0, minor = 1, revision = 0, build = 1, display = 'Version 1 Beta' },

	LrExportServiceProvider = {
		title = "Large Image Viewer",
		file = 'LIVExportServiceProvider.lua',
		--      builtInPresetsDir = 'defaults',
	},

	-- LrHelpMenuItems = {
		-- title = 'DFB Unit Tests',
		-- file = 'DFBUnitTests.lua',
	-- }
}
