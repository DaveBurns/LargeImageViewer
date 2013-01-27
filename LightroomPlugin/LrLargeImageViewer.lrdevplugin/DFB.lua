-- Lightroom API
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrErrors = import 'LrErrors'
local LrTasks = import 'LrTasks'
local LrLogger = import 'LrLogger'
local LrFunctionContext = import 'LrFunctionContext'

DFB = { }

DFB.livLogger = LrLogger( 'DFB' )
DFB.livLogger:enable( 'print' )

-- Split text into a list consisting of the strings in text,
-- separated by strings matching delimiter (which may be a pattern). 
-- example: strsplit(",%s*", "Anna, Bob, Charlie,Dolores")
--
-- from: http://lua-users.org/wiki/SplitJoin
function DFB.splitString(delimiter, text)
	local list = {}
	local pos = 1

	if string.find( '', delimiter, 1 ) then -- this would result in endless loops
		livLogger:error( 'delimiter matches empty string!' )
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

-- TODO: make this detect if message is a table and call tableToString implicitly on it
function DFB.logmsg( message )
    if type( message ) == "table" then
        message = DFB.tableToString( message )
    end

	local output = DFB.splitString( '\n', message )

	for i,v in ipairs( output ) do
		DFB.livLogger:trace( v )
	end
end

-- From: http://www.hpelbers.org/lua/print_r
-- Copyright 2009: hans@hpelbers.org
-- This is freeware
function DFB.tableToString( t, name, indent )
	local tableList = {}

	function table_r (t, name, indent, full)
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
			local val = type(t)~="number" and type(t)~="boolean" and '"'..tostring(t)..'"' or tostring(t)
			table.insert(out, tag .. val)
		end

		return table.concat(out, "\n")
	end

	return table_r(t,name or 'Value',indent or '')
end


function DFB.replaceTokens( tokenTable, str )
	local numSubs

	repeat
		str, numSubs = str:gsub( '{(.-)}', function( token ) return tostring( tokenTable[token] ) end )
	until numSubs == 0

	return str
end


-- TODO: this should check to see if the quotes are already there before adding them
function DFB.quoteIfNecessary( v )
    if not v then return ''
    else
        if v:find ' ' then v = '"'..v..'"' end
    end
    return v
end


function DFB.deleteFile( path, deleteDirectory )
	-- default values
	deleteDirectory = deleteDirectory or false -- default is to not allow deleting directories (Lr allows one to delete a dir even if it has files in it)

	DFB.logmsg( "Deleting path: " .. path )

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

	DFB.logmsg( "Creating directory: " .. path )

	local result, message

	-- check for existence
	result = LrFileUtils.exists( path )
	if ( result ) then
		if ( result == "file" ) then
			DFB.logmsg("\tAlready exists as a file" )
			return "fail", "File already exists"
		elseif ( result == "directory" ) then
			if ( failIfExists == "true" ) then
				DFB.logmsg("\tAlready exists as a directory" )
				return "fail", "Directory already exists"
			end
			-- directory exists already so just return now
			return "success", nil
		end
	end

	-- create the directory
	result, message = LrFileUtils.createAllDirectories( path )
	if ( result ) then
		DFB.logmsg("\tINFO: had to create one or more parent directories")
	end

	-- check for existence again since results of createAllDirectories is not clear
	result = LrFileUtils.exists( path )
	if ( not result ) then
		DFB.logmsg( "\tFailed" )
		return "fail", "ERROR: could not create directory"
	end

	DFB.logmsg( "\tsuccess" )
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

	DFB.logmsg( "Copy file from source: " .. sourcePath )
	DFB.logmsg( "\tto dest: " .. destPath )

	local result, message

	-- check that the source exists
	result = LrFileUtils.exists( sourcePath )
	if ( not result ) then
		DFB.logmsg( "\tERROR: source path does not exist" )
		return "fail", "Source path does not exist"
	elseif ( result == "directory" ) then
		DFB.logmsg( "\tERROR: source path is a directory, not a file" )
		return "fail", "Source path is a directory, not a file"
	end

	-- check that the dest file does not exist
	result = LrFileUtils.exists( destPath )
	if ( result ) then
		if ( result == "directory" ) then
			DFB.logmsg( "\tERROR: destPath is a directory. It must have a filename as well." )
			return "fail", "destPath is a directory. It must have a filename as well."
		elseif ( result == "file" ) then
			if ( not overwrite ) then
				DFB.logmsg( "\tERROR: dest file already exists" )
				return "fail", "dest file already exists"
			end
			result, message = LrFileUtils.moveToTrash( destPath )
			if ( not result ) then
				DFB.logmsg( "\tERROR: could not move existing dest file to trash" )
				return "fail", message
			end
		end
	end

	-- check that the dest path exists
	result = LrFileUtils.exists( LrPathUtils.parent( destPath ) )
	if ( not result ) then
		if ( not createDestPath ) then
			DFB.logmsg( "\tERROR: destination directory does not exist" )
			return "fail", "Destination directory does not exist"
		end
		result, message = DFB.createDirectory( LrPathUtils.parent( destPath ) )
		if ( result == "fail" ) then
			DFB.logmsg( "\tERROR: could not create destination directory" )
			return result, message
		end
	end

	-- copy the file
	result = LrFileUtils.copy( sourcePath, destPath )
	-- It's not clear whether the copy function will actually return nil upon failure
	if ( not result ) then
		DFB.logmsg( "\tERROR: the file copy failed" )
		return "fail", "copy failed"
	end

	-- check that dest exists
	result = LrFileUtils.exists( destPath )
	if ( not result ) then
		DFB.logmsg( "\tERROR: Copy failed" )
		return "fail", "Error when copying file"
	end

	DFB.logmsg( "\tsuccess" )
	return "success", nil
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

	-- default options
	options.debug = options.debug or false
	options.workingDir = options.workingDir or nil
	options.stderrToStdoutFile = options.stderrToStdoutFile or false

	-- put the shell command line together

	local localParams = { }

	-- begin the command line with the executable

	table.insert( localParams, DFB.quoteIfNecessary( executable ) )
--	table.insert( localParams, executable )

	-- append arguments table to param table here

	DFB.logmsg( "\t\tAppending arguments" )
	for i, v in ipairs( arguments ) do
		table.insert( localParams, v )
	end

	-- append the shell redirections

	DFB.logmsg( "\t\tAppending shell redirections" )

	-- a) create temp file names for output files here

	local stdTempPath = LrPathUtils.getStandardFilePath( 'temp' )

	local stdoutFile = LrPathUtils.child( stdTempPath, 'livStdoutTemp.txt' )
	stdoutFile = LrFileUtils.chooseUniqueFileName( stdoutFile )
	DFB.logmsg( "\t\t\tstdoutFile: " .. stdoutFile );

	local stderrFile = LrPathUtils.child( stdTempPath, 'livStderrTemp.txt' )
	stderrFile = LrFileUtils.chooseUniqueFileName( stderrFile )
	DFB.logmsg( "\t\t\tstderrFile: " .. stderrFile );

	-- b) redirect stdout and stderr

	table.insert( localParams, '> ' )
	table.insert( localParams, stdoutFile )
	if ( options.stderrToStdoutFile ) then
		table.insert( localParams, "2>&1" )
	else
		table.insert( localParams, '2>' )
		table.insert( localParams, stderrFile )
	end

	--      DFB.logmsg( to_string( localParams ) )
   
	local execString = table.concat( localParams, ' ' )
	if ( WIN_ENV ) then
		execString = '"' .. execString .. '"'
	end

	DFB.logmsg( '\t\tshell command: ' .. execString )

	-- launch the executable
   
	DFB.logmsg( "\t\tRunning executable" )
	local execResult

	if ( not LrTasks.pcall(	function()
								execResult = LrTasks.execute( execString )
							end
							) ) then
		DFB.logmsg( 'Error trying to execute external shell command' )
		return 1, execResult
	end

	if ( execResult ~= 0 ) then
		DFB.logmsg( '\t\t\texecResult = ' .. execResult )
	end

	-- parse the output file(s)

	DFB.logmsg( "\t\tReading output file(s)" )

	-- read the stdout file into the stdout table

	local stdoutTable = { }
	-- check for existence
	result = LrFileUtils.exists( stdoutFile )
	if ( not result ) then
		DFB.logmsg( 'WARNING: non-fatal error: stdout file does not exist' )
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
		result = LrFileUtils.exists( stdoutFile )
		if ( not result ) then
			DFB.logmsg( 'WARNING: non-fatal error: stderr file does not exist' )
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
		DFB.logmsg( "\t\tNONFATAL ERROR: could not delete temp file (" .. message .. "): " .. stdoutFile )
	end
	if ( not options.stderrToStdoutFile ) then
		result, message = DFB.deleteFile( stderrFile )
		if ( result == "fail" ) then
			DFB.logmsg( "\t\tNONFATAL ERROR: could not delete temp file (" .. message .. "): " .. stdoutFile )
		end
	end
	
	return execResult, stdoutTable, stderrTable
end

return DFB
