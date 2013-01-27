require 'DFB'

local LrTasks = import 'LrTasks'

function testDFBExecAndCapture()
	DFB.logmsg( 'testDFBExecAndCapture: BEGIN' )

	local cmd = 'C:\\Program Files\\ImageMagick-6.6.7-Q16\\convert.exe'
--	local cmd = 'dir'
	local cmdLineArgs = {}
--	table.insert( cmdLineArgs, '/k dir' )
--	table.insert( cmdLineArgs, 'foo' )
	table.insert( cmdLineArgs, '/?' )

	local taskDone = false
	local execResult, stdoutTable, stderrTable 
	LrTasks.startAsyncTask(
		function()
			DFB.logmsg( 'begin result func ')

			LrTasks.startAsyncTask(
				function()
					DFB.logmsg( 'begin exec func' )
					execResult, stdoutTable, stderrTable = DFB.execAndCapture( cmd, cmdLineArgs, { debug = true } )
					taskDone = true
					DFB.logmsg( 'end exec func' )
				end
			)

			while not taskDone do
				LrTasks.yield()
			end
			
			DFB.logmsg( 'execResult: ' .. execResult )
			DFB.logmsg( 'STDOUT TABLE: ' .. DFB.tableToString( stdoutTable ) )
			DFB.logmsg( 'STDERR TABLE: ' .. DFB.tableToString( stderrTable ) )

			DFB.logmsg( 'end result func ')
		end
	)

	DFB.logmsg( 'testDFBExecAndCapture: END' )
end


DFB.logmsg( '----- DFB UNIT TESTS: BEGIN -----' )

testDFBExecAndCapture()

DFB.logmsg( '----- DFB UNIT TESTS: END -----' )

