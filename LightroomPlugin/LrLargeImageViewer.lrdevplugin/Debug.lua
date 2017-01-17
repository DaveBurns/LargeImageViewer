--[[----------------------------------------------------------------------------
12345678901234567890123456789012345678901234567890123456789012345678901234567890

Debug 

Copyright 2010-2012, John R. Ellis -- You may use this script for any purpose, as
long as you include this notice in any versions derived in whole or part from
this file.

This module provides an interactive debugger, a prepackaged LrLogger with some
simple utility functions, and a rudimentary elapsed-time functin profiler. For
an introductory overview, see the accompanying "Debugging Toolkit.htm".

Overview of the public interface; for details, see the particular function:

namespace init ([boolean enable])
    Initializes the interactive debugger.
    
boolean enabled
    True if the interactive debugging is enabled.

function showErrors (function)
    Wraps a function with an error handler that invokes the debugger.

string pp (value, int indent, int maxChars, int maxLines)
    Pretty prints an arbitrary Lua value.
    
LrLogger log
    A log file that outputs to "debug.log" in the plugin directory.
    
void setLogFilename (string)    
    Changes the filename of "log".
    
void logn (...)    
    Writes the arguments to "log", converted to strings and space-separated.
    
void lognpp (...)    
    Pretty prints the arguments to "log", separated by spaces or newlines.
    
void stackTrace ()
    Writes a stack trace to "log".
------------------------------------------------------------------------------]]

local Debug = {}

local LrApplication = import 'LrApplication'
local LrDate = import 'LrDate'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrLogger = import 'LrLogger'
local LrPathUtils = import 'LrPathUtils'
local LrTasks = import 'LrTasks'

-- Forward references
local
    lineCount, logFilename, logPush, parseParams,
    showErrors, showWindow, sourceLines, upPush

local Newline = WIN_ENV and "\r\n" or "\n"
    --[[ A  platform-indepent newline. Unfortunately, some controls (e.g.
    edit_field) need to have the old-fashioned \r\n supplied in strings to
    display newlines properly on Windows. ]]

--[[----------------------------------------------------------------------------
public namespace 
init ([boolean enable])

Re-initializes the interactive debugger, discarding breaks and cached source
lines.

If "enable" is true or if it is nil and the plugin directory ends with
".lrdevplugin", then debugging is enabled.  Otherwise, debugging is disabled,
and calls to Debug.pause, Debug.pauseIf, Debug.breakFunc, and Debug.unbreakFunc
will be ignored. 

This lets you leave calls to the debugging functions in your code and just
enable or disable the debugger via the call to Debug.init.  Further, calling
Debug.init() with no parameters automatically enables debugging only when
running from a ".lrdevplugin" directory; in released code (".lrplugin"),
debugging will be disabled.

When Debug is loaded, it does an implicit Debug.init().  That is, debugging
will be enabled if the plugin directory ends with ".lrdevplugin", disabled
otherwise.

Returns the Debug module.
------------------------------------------------------------------------------]]

function Debug.init (enable)
    if enable == nil then enable = _PLUGIN.path:sub (-12) == ".lrdevplugin" end
    
    Debug.enabled = enable
    
    return Debug
    end


--[[----------------------------------------------------------------------------
public boolean enabled

True if debugging has been enabled by Debug.init, false otherwise.
------------------------------------------------------------------------------]]

Debug.enabled = false


--[[----------------------------------------------------------------------------
public function 
showErrors (function)

Returns a function wrapped around "func" such that if any errors occur from
calling "func", the debugger window is displayed.  If debugging was disabled by
Debug.init, then instead of displaying the debugger window, the standard
Lightroom error dialog is displayed.
------------------------------------------------------------------------------]]

function Debug.showErrors (func)
    if type (func) ~= "function" then 
        error ("Debug.showErrors argument must be a function", 2)
        end

    if not Debug.enabled then return showErrors (func) end
    
--    local fi = getFuncInfo (func)
    local fi
    if not fi then return showErrors (func) end
    
    return function (...)
        local args = {...}
        args.n = select("#", ...)
        
        local function onReturn (success, ...)
            if not success then 
                local err = select (1, ...)
                if err ~= Debug.DebugTerminatedError then 
                    showWindow ("failed", fi.parameters, args, nil, err, 
                        getStackInfo (4, fi.funcName, fi.filename, 
                                      fi.lineNumber, err))
                    end
                error (err, 0)
            else
                return ...
                end
            end 
        
        if LrTasks.canYield () then
            return onReturn (LrTasks.pcall (func, ...))
        else
            return onReturn (pcall (func, ...))
            end
        end           
    end
    

--[[----------------------------------------------------------------------------
private func showErrors (func)

Returns a function wrapped around "func" such that if any errors occur from
calling "func", the standard Lightroom error dialog is displayed.  By default,
Lightroom doesn't show an error dialog for callbacks from LrView controls or for
tasks created by LrTasks.
------------------------------------------------------------------------------]]

function showErrors (func)
    return function (...)
        return LrFunctionContext.callWithContext("wrapped", 
            function (context)
                LrDialogs.attachErrorDialogToFunctionContext (context)
                return func (unpack (arg))
                end)
        end 
    end


--[[----------------------------------------------------------------------------
private boolean
isSDKObject (x)

Returns true if "x" is an object implemented by the LR SDK. In LR 3, those
objects are tables with a string for a metatable, but in LR 4 beta,
getmetatable() raises an error for such objects.

NOTE: This is also in Util.lua.
------------------------------------------------------------------------------]]

local majorVersion = LrApplication.versionTable ().major

local function isSDKObject (x)
    if type (x) ~= "table" then
        return false
    elseif majorVersion < 4 then
        return type (getmetatable (x)) == "string"
    else
        local success, value = pcall (getmetatable, x)
        return not success or type (value) == "string"
    end
end


--[[----------------------------------------------------------------------------
public string
pp (value, int indent, int maxChars, int maxLines)

Returns "value" pretty printed into a string.  The string is guaranteed not
to end in a newline.

indent (default 4): If "indent" is greater than zero, then it is the number of
characters to use for indenting each level.  If "indent" is 0, then the value is
pretty-printed all on one line with no newlines.

maxChars (default maxLines * 100): The output is guaranteed to be no longer than
this number of characters.  If it exceeds maxChars - 3, then the last three
characters will be "..." to indicate truncation.

maxLines (default 5000): The output is guaranteed to have no more than this many
lines. If it is truncated, the last line will end with "..."

------------------------------------------------------------------------------]]

function Debug.pp (value, indent, maxChars, maxLines)
    if not indent then indent = 4 end
    if not maxLines then maxLines = 5000 end
    if not maxChars then maxChars = maxLines * 100 end
    
    local s = ""
    local lines = 1
    local tableLabel = {}
    local nTables = 0    

    local function addNewline (i)
        if #s >= maxChars or lines >= maxLines then return true end
        if indent > 0 then
            s = s .. "\n" .. string.rep (" ", i)
            lines = lines + 1
            end
        return false
        end

    local function pp1 (x, i)
        if type (x) == "string" then
            s = s .. string.format ("%q", x):gsub ("\n", "n")
            
        elseif type (x) ~= "table" then
            s = s .. tostring (x)
            
        elseif isSDKObject (x) then
            s = s .. tostring (x)
            
        else
            if tableLabel [x] then
                s = s .. tableLabel [x] 
                return false
                end
            
            local isEmpty = true
            for _, _ in pairs (x) do isEmpty = false; break end
            if isEmpty then 
                s = s .. "{}"
                return false
                end

            nTables = nTables + 1
            local label = "table: " .. nTables
            tableLabel [x] = label
            
            s = s .. "{" 
            if indent > 0 then s = s .. "--" .. label end
            local first = true
            for k, v in pairs (x) do
                if first then
                    first = false
                else
                    s = s .. ", "
                    end
                if addNewline (i + indent) then return true end 
                if type (k) == "string" and k:match ("^[_%a][_%w]*$") then
                    s = s .. k
                else 
                    s = s .. "["
                    if pp1 (k, i + indent) then return true end
                    s = s .. "]"
                    end
                s = s .. " = "
                if pp1 (v, i + indent) then return true end
                end
            s = s .. "}"
            end

        return false
        end
    
    local truncated = pp1 (value, 0)
    if truncated or #s > maxChars then 
        s = s:sub (1, math.max (0, maxChars - 3)) .. "..."
        end
    return s
    end
        
--[[----------------------------------------------------------------------------
public LrLogger log

The "log" is an LrLogger log file that by default writes to the file "debug.log"
in the current plugin directory.
------------------------------------------------------------------------------]]

Debug.log = LrLogger ("com.daveburnsphoto.log")
    --[[ This apparently must be unique across all of Lightroom and plugins.]]

logFilename = LrPathUtils.child (_PLUGIN.path, "debug.log")

Debug.log:enable (function (msg)
    local f = io.open (logFilename, "a")
    if f == nil then return end
    f:write (
        LrDate.timeToUserFormat (LrDate.currentTime (), "%y/%m/%d %H:%M:%S"), 
        msg, Newline)
    f:close ()
    end)
    

--[[----------------------------------------------------------------------------
public void
setLogFilename (string)

Sets the filename of the log to be something other than the default
(_PLUGIN.path/debug.log).
------------------------------------------------------------------------------]]

function Debug.setLogFilename (filename)
    logFilename = filename
    end


--[[----------------------------------------------------------------------------
public void
logn (...)

Writes all of the arguments to the log, separated by spaces on a single line,
using tostring() to convert to a string.  Useful for low-level debugging.
------------------------------------------------------------------------------]]

function Debug.logn (...)
    local s = ""
    for i = 1, select ("#", ...) do
        local v = select (i, ...)
        s = s .. (i > 1 and " " or "") .. tostring (v) 
        end
    Debug.log:trace (s)
    end

--[[----------------------------------------------------------------------------
public void
lognpp (...)

Pretty prints all of the arguments to the log, separated by spaces or newlines.  Useful
------------------------------------------------------------------------------]]

function Debug.lognpp (...)
    local s = ""
    local sep = " "
    for i = 1, select ("#", ...) do
        local v = select (i, ...)
        local pp = Debug.pp (v)
        s = s .. (i > 1 and sep or "") .. pp
        if lineCount (pp) > 1 then sep = "\n" end
        end
    Debug.log:trace (s)
    end

--[[----------------------------------------------------------------------------
private int
lineCount (string s)

Counts the number of lines in "s".  The last line may or may not end
with a newline, but it counts as a line.
------------------------------------------------------------------------------]]

function lineCount (s)
    local l = 0
    for i = 1, #s do if s:sub (i, i) == "\n" then l = l + 1 end end
    if #s > 0 and s:sub (-1, -1) ~= "\n" then l = l + 1 end
    return l
    end

--[[----------------------------------------------------------------------------
public void
stackTrace ()

Write a raw stack trace to the log.
------------------------------------------------------------------------------]]

function Debug.stackTrace ()
    local s = "\nStack trace:"
    local i = 2
    while true do
        local info = debug.getinfo (i)
        if not info then break end
        s = string.format ("%s\n%s [%s %s]", s, info.name, info.source, 
                           info.currentline)
        i = i + 1
        end
    Debug.log:trace (s)
    end


return Debug    