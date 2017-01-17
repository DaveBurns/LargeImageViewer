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
local LrTasks = import 'LrTasks'
--local LrFunctionContext = import 'LrFunctionContext'
local LrBinding = import 'LrBinding'
--local LrColor = import 'LrColor'

local utf8 = require 'utf8'

local DFB = { }


function DFB.isTableEmpty( t )
    return next( t ) == nil
end


function DFB.LrObservableTableToString( t, keysToSkip )
--    Debug.logn( 'LrObservableTableToString: ' .. DFB.tableToString( t ) )

    local function table_r ( t, name, indent )
        local out = {}	-- result
        local tag = ''

        if keysToSkip  and type( keysToSkip ) == 'table' then
            if keysToSkip[ name ] then
                return '\n'
            end
        end


        if name then
            tag = indent .. name .. ' = '
        end

        if type( t ) == "table" then
            table.insert( out, tag .. '{' )
            for key, value in t:pairs() do
                table.insert( out, table_r( value, key, indent .. '\t' ) )
            end
            table.insert( out, indent .. '}' )
        else
            local val

            if type( t ) == 'number' or type( t ) == 'boolean' then
                val = tostring( t )
            else
                val = '"' .. tostring( t ) .. '"'
            end
            table.insert( out, tag .. val .. ',' )
        end

        return table.concat( out, '\n' )
    end

    local result = table_r( t, nil, '' )

    Debug.logn( 'LrObservableTableToString result: ' .. result )

    return result
end


function DFB.maybeConvertToNativeLrObject( s )
    if type( s ) == 'string' then
        if s:find( '^AgColor' ) then
            local constructor = s:gsub( 'AgColor', 'LrColor' )
            return loadstring( 'local LrColor = import "LrColor"; return ' .. constructor )()
        end
    end

    return s
end


function DFB.StringToObservableTable( s, context )
    local t = loadstring( 'return ' .. s )()

    local properties = LrBinding.makePropertyTable( context ) -- make a table

    for k, v in pairs( t ) do
        v = DFB.maybeConvertToNativeLrObject( v )
        properties[ k ] = v
    end

    --Debug.logn( 'LrObservableTableToString: ' .. DFB.tableToString( properties ) )

    return properties
end


-- Split text into a list consisting of the strings in text,
-- separated by strings matching delimiter (which may be a pattern). 
-- example: strsplit(",%s*", "Anna, Bob, Charlie,Dolores")
--
-- from: http://lua-users.org/wiki/SplitJoin
function DFB.splitString(delimiter, text)
	local list = {}
	local pos = 1

	if string.find( '', delimiter, 1 ) then -- this would result in endless loops
		Debug.logn( 'delimiter matches empty string!' )
	end

	while 1 do
		local first, last = string.find( text, delimiter, pos )
		if first then -- found?
			table.insert( list, string.sub( text, pos, first - 1 ) )
			pos = last + 1
		else
			table.insert( list, string.sub( text, pos ) )
			break
		end
	end

	return list
end


function DFB.stringStarts( s, start )
    return string.sub( s, 1, string.len( start )) == start
end


function DFB.stringEnds( s, suffix )
    return suffix == '' or string.sub( s, -string.len( suffix ) ) == suffix
end


-- From: http://www.hpelbers.org/lua/print_r
-- Copyright 2009: hans@hpelbers.org
-- This is freeware
function DFB.tableToString( t, name, indent )
	local tableList = {}

	local function table_r (t, name, indent, full)
		local id = not full and name
			or type(name) ~= "number" and tostring(name) or '['..name..']'
		local tag = indent .. id .. ' = '
		local out = {}	-- result
		
		if type(t) == "table" then
			if tableList[t] ~= nil then table.insert(out, tag .. '{} -- ' .. tableList[t] .. ' (self reference)')
			else
				tableList[t]= full and (full .. '.' .. id) or id
			if next(t) then -- Table not empty
				table.insert(out, tag .. '{')
				for key,value in pairs(t) do 
					table.insert(out,table_r(value,key,indent .. '|  ',tableList[t]))
				end
				table.insert(out,indent .. '}')
			else table.insert(out,tag .. '{}') end
			end
		else 
			local val = type(t) ~= "number" and type(t) ~= "boolean" and '"' .. tostring( t ) .. '"' or tostring( t )
			table.insert(out, tag .. val)
		end

		return table.concat(out, "\n")
	end

	return table_r(t,name or 'Value',indent or '')
end


function DFB.replaceTokens( tokenTable, str )
	local numSubs, oldStr

	repeat
        oldStr = str
		str, numSubs = str:gsub( '{(.-)}', function( token )
            if ( tokenTable[ token ] ~= nil ) then
                return tostring( tokenTable[token] )
            else
                return nil -- this case allows for things wrapped in {}'s that are not meant to be tokens
            end
        end )
	until oldStr == str

	return str
end


-- This is function trim6() from http://lua-users.org/wiki/StringTrim
function DFB.trim( str )
    return str:match'^()%s*$' and '' or str:match'^%s*(.*%S)'
end


function DFB.quoteIfNecessary( s )
    if not s then return '' end

    if s:find ' ' and not DFB.stringStarts( s, '"' ) and not DFB.stringEnds( s, '"' ) then
        s = '"' .. s .. '"'
    end

    return s
end


function DFB.deleteFile( path, deleteDirectory )
	-- default values
	deleteDirectory = deleteDirectory or false -- default is to not allow deleting directories (Lr allows one to delete a dir even if it has files in it)

	Debug.logn( "Deleting path: " .. path )

	local result, message

	-- check for existence
	result = LrFileUtils.exists( path )
	if ( not result ) then
		return "fail", "Path does not exist"
	end

	-- if exists and is directory
	if ( result == "directory" ) then
		--  if deleteDirectory is false then fail
		if ( not deleteDirectory ) then
			return "fail", "Path is a directory but the deleteDirectory option is false"
		end
	end

	-- delete path and fail if returns false
	result, message = LrFileUtils.delete( path )
	if ( not result ) then
		return "fail", "ERROR: could not delete path: " .. message
	end

	-- check for existence again and fail if it exists
	result = LrFileUtils.exists( path )
	if ( result ) then
		return "fail", "ERROR: delete function succeeded but " .. result .. " still exists"
	end
end


-- TODO: require path to end or not end in a delimiter or deal with it quietly?
function DFB.createDirectory( path, failIfExists )
	-- default values
	failIfExists = failIfExists or false -- default is do not fail if it already exists. Just quietly return success.

	Debug.logn( "Creating directory: " .. path )

	local result, message

	-- check for existence
	result = LrFileUtils.exists( path )
	if ( result ) then
		if ( result == "file" ) then
			Debug.logn("\tAlready exists as a file" )
			return "fail", "File already exists"
		elseif ( result == "directory" ) then
			if ( failIfExists == "true" ) then
				Debug.logn("\tAlready exists as a directory" )
				return "fail", "Directory already exists"
			end
			-- directory exists already so just return now
			return "success", nil
		end
	end

	-- create the directory
	result, message = LrFileUtils.createAllDirectories( path )
	if ( result ) then
		Debug.logn("\tINFO: had to create one or more parent directories")
	end

	-- check for existence again since results of createAllDirectories is not clear
	result = LrFileUtils.exists( path )
	if ( not result ) then
		Debug.logn( "\tFailed" )
		return "fail", "ERROR: could not create directory"
	end

	Debug.logn( "\tsuccess" )
	return "success", nil
end


function DFB.splitPath( path )
	local path_table = {};

	path_table.filename = LrPathUtils.leafName( path )
	path_table.extension = LrPathUtils.extension( path )
	path_table.basename = LrPathUtils.removeExtension( path_table.filename )
	path_table.path = LrPathUtils.parent( path )

	--   return table containing volume, directories, basename, extension, list of dirs one by one?
	return path_table
end


-- At this time, destPath must be a full path with filename
function DFB.copyFile( sourcePath, destPath, overwrite, createDestPath )
	-- default values
	overwrite = overwrite or false -- default is to fail if destPath already exists
	createDestPath = createDestPath or false -- default is to fail if destPath's dir does not exist

	Debug.logn( "Copy file from source: " .. sourcePath )
	Debug.logn( "\tto dest: " .. destPath )

	local result, message

	-- check that the source exists
	result = LrFileUtils.exists( sourcePath )
	if ( not result ) then
		Debug.logn( "\tERROR: source path does not exist" )
		return "fail", "Source path does not exist"
	elseif ( result == "directory" ) then
		Debug.logn( "\tERROR: source path is a directory, not a file" )
		return "fail", "Source path is a directory, not a file"
	end

	-- check that the dest file does not exist
	result = LrFileUtils.exists( destPath )
	if ( result ) then
		if ( result == "directory" ) then
			Debug.logn( "\tERROR: destPath is a directory. It must have a filename as well." )
			return "fail", "destPath is a directory. It must have a filename as well."
		elseif ( result == "file" ) then
			if ( not overwrite ) then
				Debug.logn( "\tERROR: dest file already exists" )
				return "fail", "dest file already exists"
			end
			result, message = LrFileUtils.moveToTrash( destPath )
			if ( not result ) then
				Debug.logn( "\tERROR: could not move existing dest file to trash" )
				return "fail", message
			end
		end
	end

	-- check that the dest path exists
	result = LrFileUtils.exists( LrPathUtils.parent( destPath ) )
	if ( not result ) then
		if ( not createDestPath ) then
			Debug.logn( "\tERROR: destination directory does not exist" )
			return "fail", "Destination directory does not exist"
		end
		result, message = DFB.createDirectory( LrPathUtils.parent( destPath ) )
		if ( result == "fail" ) then
			Debug.logn( "\tERROR: could not create destination directory" )
			return result, message
		end
	end

	-- copy the file
	result = LrFileUtils.copy( sourcePath, destPath )
	-- It's not clear whether the copy function will actually return nil upon failure
	if ( not result ) then
		Debug.logn( "\tERROR: the file copy failed" )
		return "fail", "copy failed"
	end

	-- check that dest exists
	result = LrFileUtils.exists( destPath )
	if ( not result ) then
		Debug.logn( "\tERROR: Copy failed" )
		return "fail", "Error when copying file"
	end

	Debug.logn( "\tsuccess" )
	return "success", nil
end


-- Replaces html entities on the selected text
-- From: http://lua-users.org/files/wiki_insecure/users/WalterCruz/htmlentities.lua
-- if I ever need to encode these entries in decimal myself, this site has all the codes:
-- http://www.utf8-chartable.de/unicode-utf8-table.pl?utf8=dec&unicodeinhtml=dec&htmlent=1
function DFB.encodeHTMLEntities( str )
    local entities = {
--        [' '] = '&nbsp;' ,
        ['¡'] = '&iexcl;' ,
        ['¢'] = '&cent;' ,
        ['£'] = '&pound;' ,
        ['¤'] = '&curren;' ,
        ['¥'] = '&yen;' ,
        ['¦'] = '&brvbar;' ,
        ['§'] = '&sect;' ,
        ['¨'] = '&uml;' ,
--        ['\194\169'] = '&copy;' ,
        ['©'] = '&copy;' ,
        ['ª'] = '&ordf;' ,
        ['«'] = '&laquo;' ,
        ['¬'] = '&not;' ,
        ['­'] = '&shy;' ,
        ['®'] = '&reg;' ,
        ['¯'] = '&macr;' ,
        ['°'] = '&deg;' ,
        ['±'] = '&plusmn;' ,
        ['²'] = '&sup2;' ,
        ['³'] = '&sup3;' ,
        ['´'] = '&acute;' ,
        ['µ'] = '&micro;' ,
        ['¶'] = '&para;' ,
        ['·'] = '&middot;' ,
        ['¸'] = '&cedil;' ,
        ['¹'] = '&sup1;' ,
        ['º'] = '&ordm;' ,
        ['»'] = '&raquo;' ,
        ['¼'] = '&frac14;' ,
        ['½'] = '&frac12;' ,
        ['¾'] = '&frac34;' ,
        ['¿'] = '&iquest;' ,
        ['À'] = '&Agrave;' ,
        ['Á'] = '&Aacute;' ,
        ['Â'] = '&Acirc;' ,
        ['Ã'] = '&Atilde;' ,
        ['Ä'] = '&Auml;' ,
        ['Å'] = '&Aring;' ,
        ['Æ'] = '&AElig;' ,
        ['Ç'] = '&Ccedil;' ,
        ['È'] = '&Egrave;' ,
        ['É'] = '&Eacute;' ,
        ['Ê'] = '&Ecirc;' ,
        ['Ë'] = '&Euml;' ,
        ['Ì'] = '&Igrave;' ,
        ['Í'] = '&Iacute;' ,
        ['Î'] = '&Icirc;' ,
        ['Ï'] = '&Iuml;' ,
        ['Ð'] = '&ETH;' ,
        ['Ñ'] = '&Ntilde;' ,
        ['Ò'] = '&Ograve;' ,
        ['Ó'] = '&Oacute;' ,
        ['Ô'] = '&Ocirc;' ,
        ['Õ'] = '&Otilde;' ,
        ['Ö'] = '&Ouml;' ,
        ['×'] = '&times;' ,
        ['Ø'] = '&Oslash;' ,
        ['Ù'] = '&Ugrave;' ,
        ['Ú'] = '&Uacute;' ,
        ['Û'] = '&Ucirc;' ,
        ['Ü'] = '&Uuml;' ,
        ['Ý'] = '&Yacute;' ,
        ['Þ'] = '&THORN;' ,
        ['ß'] = '&szlig;' ,
        ['à'] = '&agrave;' ,
        ['á'] = '&aacute;' ,
        ['â'] = '&acirc;' ,
        ['ã'] = '&atilde;' ,
        ['ä'] = '&auml;' ,
        ['å'] = '&aring;' ,
        ['æ'] = '&aelig;' ,
        ['ç'] = '&ccedil;' ,
        ['è'] = '&egrave;' ,
        ['é'] = '&eacute;' ,
        ['ê'] = '&ecirc;' ,
        ['ë'] = '&euml;' ,
        ['ì'] = '&igrave;' ,
        ['í'] = '&iacute;' ,
        ['î'] = '&icirc;' ,
        ['ï'] = '&iuml;' ,
        ['ð'] = '&eth;' ,
        ['ñ'] = '&ntilde;' ,
        ['ò'] = '&ograve;' ,
        ['ó'] = '&oacute;' ,
        ['ô'] = '&ocirc;' ,
        ['õ'] = '&otilde;' ,
        ['ö'] = '&ouml;' ,
        ['÷'] = '&divide;' ,
        ['ø'] = '&oslash;' ,
        ['ù'] = '&ugrave;' ,
        ['ú'] = '&uacute;' ,
        ['û'] = '&ucirc;' ,
        ['ü'] = '&uuml;' ,
        ['ý'] = '&yacute;' ,
        ['þ'] = '&thorn;' ,
        ['ÿ'] = '&yuml;' ,
        ['"'] = '&quot;' ,
        ["'"] = '&#39;' ,
        ['<'] = '&lt;' ,
        ['>'] = '&gt;' ,
        ['&'] = '&amp;'
    }

    return utf8.replace( str, entities )
end

--    -- Here we search for non standard characters and replace them if
--    -- we have a translation. The regexp could be changed to include an
--    -- exact list with the above characters [áéíó...] and then remove
--    -- the 'if' below, but it's easier to maintain like this...
--    return string.gsub( str, "[^a-zA-Z0-9 _]",
--        function (v)
--            if entities[v] then return entities[v] else return v end
--        end)
--end


-- From: http://lua-users.org/files/wiki_insecure/users/WalterCruz/htmlunentities.lua
function DFB.decodeHTMLEntities( str )
    local entities = {
        nbsp = ' ' ,
        iexcl = '¡' ,
        cent = '¢' ,
        pound = '£' ,
        curren = '¤' ,
        yen = '¥' ,
        brvbar = '¦' ,
        sect = '§' ,
        uml = '¨' ,
        copy = '©' ,
        ordf = 'ª' ,
        laquo = '«' ,
        ['not'] = '¬' ,
        shy = '­' ,
        reg = '®' ,
        macr = '¯' ,
        ['deg'] = '°' ,
        plusmn = '±' ,
        sup2 = '²' ,
        sup3 = '³' ,
        acute = '´' ,
        micro = 'µ' ,
        para = '¶' ,
        middot = '·' ,
        cedil = '¸' ,
        sup1 = '¹' ,
        ordm = 'º' ,
        raquo = '»' ,
        frac14 = '¼' ,
        frac12 = '½' ,
        frac34 = '¾' ,
        iquest = '¿' ,
        Agrave = 'À' ,
        Aacute = 'Á' ,
        Acirc = 'Â' ,
        Atilde = 'Ã' ,
        Auml = 'Ä' ,
        Aring = 'Å' ,
        AElig = 'Æ' ,
        Ccedil = 'Ç' ,
        Egrave = 'È' ,
        Eacute = 'É' ,
        Ecirc = 'Ê' ,
        Euml = 'Ë' ,
        Igrave = 'Ì' ,
        Iacute = 'Í' ,
        Icirc = 'Î' ,
        Iuml = 'Ï' ,
        ETH = 'Ð' ,
        Ntilde = 'Ñ' ,
        Ograve = 'Ò' ,
        Oacute = 'Ó' ,
        Ocirc = 'Ô' ,
        Otilde = 'Õ' ,
        Ouml = 'Ö' ,
        times = '×' ,
        Oslash = 'Ø' ,
        Ugrave = 'Ù' ,
        Uacute = 'Ú' ,
        Ucirc = 'Û' ,
        Uuml = 'Ü' ,
        Yacute = 'Ý' ,
        THORN = 'Þ' ,
        szlig = 'ß' ,
        agrave = 'à' ,
        aacute = 'á' ,
        acirc = 'â' ,
        atilde = 'ã' ,
        auml = 'ä' ,
        aring = 'å' ,
        aelig = 'æ' ,
        ccedil = 'ç' ,
        egrave = 'è' ,
        eacute = 'é' ,
        ecirc = 'ê' ,
        euml = 'ë' ,
        igrave = 'ì' ,
        iacute = 'í' ,
        icirc = 'î' ,
        iuml = 'ï' ,
        eth = 'ð' ,
        ntilde = 'ñ' ,
        ograve = 'ò' ,
        oacute = 'ó' ,
        ocirc = 'ô' ,
        otilde = 'õ' ,
        ouml = 'ö' ,
        divide = '÷' ,
        oslash = 'ø' ,
        ugrave = 'ù' ,
        uacute = 'ú' ,
        ucirc = 'û' ,
        uuml = 'ü' ,
        yacute = 'ý' ,
        thorn = 'þ' ,
        yuml = 'ÿ' ,
        quot = '"' ,
        lt = '<' ,
        gt = '>' ,
        amp = ''
    }

    return string.gsub( str, "&%a+;",
        function ( entity )
            return entities[string.sub(entity, 2, -2)] or entity
        end)
end


-- input:
--		executable: string. path/name of executable
--		arguments: table. cmd line arguments
--		options. table.
--			debug: string. if false then no debug
--			stdoutPattern: string. regex to filter out output lines
--			stderrPattern: string. regex to filter out output lines
--			stderrToStdoutFile: if true then collect stderr same file/table as stdout
--			TODO: Windows console window options
--
-- output:
--		status of execute
--		table of stdout and maybe stderr lines
--		table of stderr lines depending on options

function DFB.execAndCapture( executable, arguments, options )

    if not LrTasks.canYield() then
        return false, 'Can\'t yield. execAndCapture must be called within a task.'
    end

	-- default options
	options.debug = options.debug or false
	options.workingDir = options.workingDir or nil
	options.stderrToStdoutFile = options.stderrToStdoutFile or false

	-- put the shell command line together

	local localParams = { }

	-- begin the command line with the executable

	table.insert( localParams, DFB.quoteIfNecessary( executable ) )

	-- append arguments table to param table here

	for _, v in ipairs( arguments ) do
		table.insert( localParams, v )
	end

	-- append the shell redirections

	Debug.logn( "Appending shell redirections" )

	-- a) create temp file names for output files here

	local stdTempPath = LrPathUtils.getStandardFilePath( 'temp' )

	local stdoutFile = LrPathUtils.child( stdTempPath, 'dfbStdoutTemp.txt' )
	stdoutFile = LrFileUtils.chooseUniqueFileName( stdoutFile )
	Debug.logn( "\tstdoutFile: " .. stdoutFile );

	local stderrFile = LrPathUtils.child( stdTempPath, 'dfbStderrTemp.txt' )
	stderrFile = LrFileUtils.chooseUniqueFileName( stderrFile )
	Debug.logn( "\tstderrFile: " .. stderrFile );

	-- b) redirect stdout and stderr

	table.insert( localParams, '> ' )
	table.insert( localParams, stdoutFile )
	if ( options.stderrToStdoutFile ) then
		table.insert( localParams, "2>&1" )
	else
		table.insert( localParams, '2>' )
		table.insert( localParams, stderrFile )
	end

	--      Debug.logn( to_string( localParams ) )
   
	local execString = table.concat( localParams, ' ' )
	if ( WIN_ENV ) then
		execString = '"' .. execString .. '"'
	end

	Debug.logn( 'Shell command: ' .. execString )

	-- launch the executable
   
	Debug.logn( "Running executable" )
	local execResult

	if ( not LrTasks.pcall(	Debug.showErrors( function()
								execResult = LrTasks.execute( execString )
							end )
							) ) then
		Debug.logn( 'Error trying to execute external shell command' )
		return 1, execResult
	end

	if ( execResult ~= 0 ) then
		Debug.logn( 'execResult = ' .. execResult )
	end

	-- parse the output file(s)

	Debug.logn( "Reading output file(s)" )

	-- read the stdout file into the stdout table

	local stdoutTable = { }
	-- check for existence
	local result = LrFileUtils.exists( stdoutFile )
	if ( not result ) then
		Debug.logn( 'WARNING: non-fatal error: stdout file does not exist' )
	else
		for line in io.lines( stdoutFile ) do
			-- filter according to regex if defined
			if ( not options.stdoutPattern or string.match( line, options.stdoutPattern ) ~= nil ) then
				table.insert( stdoutTable, line )
			end
		end
	end

   -- read the stderr file into the stderr table     

	local stderrTable = { }
	if ( not options.stderrToStdoutFile ) then
		result = LrFileUtils.exists( stderrFile )
		if ( not result ) then
			Debug.logn( 'WARNING: non-fatal error: stderr file does not exist' )
		else
			for line in io.lines( stderrFile ) do
				-- filter according to regex if defined
				if ( not options.stderrPattern or string.match( line, options.stderrPattern ) ~= nil ) then
					table.insert( stderrTable, line )
				end
			end
		end
	end

	-- delete the temp output file(s)
	local result, message = DFB.deleteFile( stdoutFile )
	if ( result == "fail" ) then
		Debug.logn( "\t\tNONFATAL ERROR: could not delete temp file (" .. message .. "): " .. stdoutFile )
	end
	if ( not options.stderrToStdoutFile ) then
		result, message = DFB.deleteFile( stderrFile )
		if ( result == "fail" ) then
			Debug.logn( "\t\tNONFATAL ERROR: could not delete temp file (" .. message .. "): " .. stdoutFile )
		end
	end
	
	return execResult, stdoutTable, stderrTable
end

return DFB
