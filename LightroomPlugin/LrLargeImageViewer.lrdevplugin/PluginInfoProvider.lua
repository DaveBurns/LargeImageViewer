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

local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrFunctionContext = import 'LrFunctionContext'
local LrFileUtils = import 'LrFileUtils'
local LrColor = import 'LrColor'
local LrHttp = import 'LrHttp'
local LrPrefs = import 'LrPrefs'

local DFB = require 'DFB'


local function readFileIntoString( fileName )
    local lines = {}

    local exists = LrFileUtils.exists( fileName )
    if ( not exists ) then
        Debug.logn( 'WARNING: non-fatal error:  file does not exist: ' .. fileName )
        table.insert( lines, 'File ' .. fileName .. ' was not found.' )
    else
        for line in io.lines( fileName ) do
            table.insert( lines, line )
        end
    end

    return table.concat( lines, '\n' )
end


local function showTextInADialog( title, text )

    LrFunctionContext.callWithContext( "showTextInADialog", Debug.showErrors( function( context )
        local f = LrView.osFactory()
        local _, numLines = text:gsub( '\n', '\n' )
        local c
        local thresholdForScrollable = 30

        -- Create the contents for the dialog.
        -- if it's a short license, just show a static control. Else, put the static control in a scrollable view.
        if numLines <= thresholdForScrollable then
            c = f:row {
                f:static_text {
                    selectable = true,
                    title = text,
                    size = 'small',
                }
            }
        else
            c = f:row {
                f:scrolled_view {
                    horizontal_scroller = false,
                    width = 600,
                    height = thresholdForScrollable * 14,
                    f:static_text {
                        selectable = true,
                        title = text,
                        size = 'small',
                        height_in_lines = -1,
                        width = 550,
                    }
                }
            }
        end

        LrDialogs.presentModalDialog {
            title = title,
            contents = c,
            cancelVerb = '< exclude >',
        }


    end ) )

end


local function startDialog( propertyTable )
    local prefs = LrPrefs.prefsForPlugin()

    Debug.logn( 'PLUGIN MANAGER: startDialog' )
--    Debug.lognpp( propertyTable )

    propertyTable.IMPath = prefs.IMPath or ''
    propertyTable.GMapsApiKey = prefs.GMapsApiKey or ''
end


local function endDialog( propertyTable )
    local prefs = LrPrefs.prefsForPlugin()

    Debug.logn( 'PLUGIN MANAGER: endDialog' )
--    Debug.lognpp( propertyTable )

    prefs.IMPath = propertyTable.IMPath
    prefs.GMapsApiKey = propertyTable.GMapsApiKey
end


-- Section for the top of the dialog.
local function sectionsForTopOfDialog( f, propertyTable )
    local bind = LrView.bind
    local share = LrView.share

    local IMMessage    -- TODO: set this to an error message if there's a problem with the path (doesn't exist, etc.)
    local ApiKeyMessage    -- TODO: set this to an error message if there's a problem with the API Key (doesn't exist, etc.)

    Debug.logn( 'PLUGIN MANAGER: sectionsForTopOfDialog' )
--    Debug.lognpp( propertyTable )

    return {
        {
            title = 'License Info',
            synopsis = 'Expand for license info',

            f:row {
                f:push_button {
                    title = "Show license...",
                    action = Debug.showErrors( Debug.showErrors( function( _ )
                        showTextInADialog(
                            'License for LrLargeImageViewer',
                            readFileIntoString( _PLUGIN.path .. '/LICENSE' )
                        ) end ) ),
                },
            },

            f:row {
                f:separator {
                    fill_horizontal = 1,
                },
            },

            f:row {
                f:static_text {
                    title = 'This plugin makes use of code from 3rd parties:',
                },
            },
            f:row {
                f:static_text {
                    title = 'ImageMagick',
                },

                f:static_text {
                    title = '(See license at IM site)',
                    font = {
                        name = "<system/small>",
                        size = 'mini',
                    },
                    text_color = LrColor( 'blue' ),
                    mouse_down = function() LrHttp.openUrlInBrowser( 'http://www.imagemagick.org/script/license.php' ) end
                },

                f:push_button {
                    title = "Show license...",
                    action = Debug.showErrors( function( _ )
                        showTextInADialog(
                            'License for ImageMagick',
                            readFileIntoString( _PLUGIN.path .. '/LICENSE.ImageMagick' )
                        ) end ),
                },
            },

            f:row {
                f:static_text {
                    title = 'UTF 8 Lua Library',
                },

                f:push_button {
                    title = "Show license...",
                    action = Debug.showErrors( function( _ )
                        showTextInADialog(
                            'License for Lua UTF-8 Library',
                            readFileIntoString( _PLUGIN.path .. '/LICENSE.utf8' )
                        ) end ),
                },
            }
        },

        {
            title = 'Location of ImageMagick',
            synopsis = function()
                if #propertyTable.IMPath > 0 then
                    return propertyTable.IMPath
                else
                    return 'Using default'
                end
            end,


            f:column {
                spacing = f:control_spacing(),
                fill = 1,

                f:static_text {
                    title = "By default, LargeImageViewer uses a bundled version of ImageMagick. You can override this and use your own if necessary. Only do this if you have good reason. Otherwise, leave this blank.",
                    fill_horizontal = 1,
                    width_in_chars = 55,
                    height_in_lines = 2,
                    size = 'small',
                },

                IMMessage and f:static_text {
                    title = IMMessage,
                    fill_horizontal = 1,
                    width_in_chars = 55,
                    height_in_lines = 2,
                    size = 'small',
                    text_color = import 'LrColor'( 1, 0, 0 ),
                } or 'skipped item',

                f:row {
                    spacing = f:label_spacing(),

                    f:static_text {
                        title="Path to ImageMagick's magick:",
                        alignment = 'right',
                        width = share 'title_width',
                    },
                    f:edit_field {
                        value = bind { key = 'IMPath', object = propertyTable },
                        fill_horizontal = 1,
                        width_in_chars = 25,
                        validate = function( view, value )
                            local errorMessage

                            -- assume success for now
                            value = DFB.trim( value )

                            return true, value, errorMessage
                        end
                    },
                    f:push_button {
                        title = "Browse...",
                        action = Debug.showErrors( function( button )
                            local options =
                            {
                                title = 'Find the ImageMagick magick program:',
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
                                propertyTable.IMPath = DFB.trim( result[ 1 ] )
                            end
                        end )
                    },
                },
            },
        },

        {
            title = 'Google Maps API Key',
            synopsis = function()
                            -- TODO: come up with a better test for valid API key
                           if #propertyTable.GMapsApiKey > 0 then
                               return 'Api key is SET'
                           else
                               return 'Api key is NOT SET'
                           end
                       end,

            f:column {
                spacing = f:control_spacing(),
                fill = 1,

                f:static_text {
                    title = 'Google will let you use Maps only a limited number of times without an API Key. ' ..
                            'If you will put a large image on the web, you should obtain a free API key from Google. Here is how:',
                    fill_horizontal = 1,
                    width_in_chars = 55,
                    height_in_lines = 2,
                },

                f:static_text {
                    title = 'First, go to http://console.developers.google.com.',
                    text_color = LrColor( 'blue' ),
                    mouse_down = function() LrHttp.openUrlInBrowser( 'https://console.developers.google.com/' ) end
                },

                f:static_text {
                    height_in_lines = 6,
                    title = '* Under Google Maps Apis choose Google Maps JavaScript API\n' ..
                            '* Enable the API if not already enabled.\n' ..
                            '* Click the Credentials section on the left.\n' ..
                            '* Click the Create Credentials button and choose API Key from the dropdown menu that appears.\n' ..
                            '* Copy the string of letters and digits that appear and paste it into the text field below.',
                },


                -- TODO: is this going to be needed?
                ApiKeyMessage and f:static_text {
                    title = ApiKeyMessage,
                    fill_horizontal = 1,
                    width_in_chars = 55,
                    height_in_lines = 2,
                    size = 'small',
                    text_color = import 'LrColor'( 1, 0, 0 ),
                } or 'skipped item',

                f:row {
                    f:static_text {
                        title="Google Maps API Key:",
                    },

                    f:edit_field {
                        value = bind { key = 'GMapsApiKey', object = propertyTable },
                        fill_horizontal = 1,
                        width_in_chars = 25,
                        validate = function( view, value )
                            local errorMessage

                            -- assume success for now
                            value = DFB.trim( value )

                            return true, value, errorMessage
                        end
                    },
                },
            },
        },
    }
end


return {
    sectionsForTopOfDialog = sectionsForTopOfDialog,
    startDialog = startDialog,
    endDialog = endDialog,
}
