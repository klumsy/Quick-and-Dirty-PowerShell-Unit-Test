########################################################################
## Copyright (c) Karl Prosser, 2013
## Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
## Version 0.6
########################################################################
#quick and dirty PowerShell Unit Testing framework.
# if you want something more than this then look at PSAINT or PESTER or PSUNIT
#Goals
#    +Small
#    +No dependencies (can be as module or just copy and pasted, and tag along with a remoting scriptblock
#    +Flexible to deal with many real world scenarios in PS
#    +Data Centric, with history. the goal is the output will be objects that can be filtered, grouped, exported 
#     and compared with previous runs, using standard build in PS Cmdlets.      
#    +Many "tests" in one test, rather than redoing certian things, allow a progressions of tests, allowing
#     you to shortcircuit future tests when you know they will fail because the current on fails (-ForceStop..)
#    +Use global variables!!!! as a way to keep track of tests, and results.
#    + Work in V2 and V3 well (only testing in V3 so far)
#NonGoals
#   + Mocking. Its easy enough to mock PS because of function and alias precendence, and these can
#     easily added or remoted in the presetup and teardown scriptblocks. Also object mocking can be done
#     in many cases by exporting and importing CLIXML.
#   + Asserting Exceptions - PS exceptions with terminating, non terminating errors, dotnet, different 
#     behaviour in V2 and V3,errors over remoting boundaries, differences in content (like erroractionpreferences etc)#     
#     would make this quite complicated and not reliable, thus your tests should do their own exception handling
#     Basically if you need to test exceptions , do try/catch yourself, also if you are interested in terminating and non terminating
#     Errors you may have patterns of using erroraction on a scriptblock, or errorvariable, and may look and clear $global:error  
#     and all non caught exceptions are treated as fails.        
#   + Following any particular TDD or BDD philosophy, or strict purity.
#   + For Now documenting the cmdlets inline, maybe later i can have something that strips out the comments
#     upon some sort of build and checkin process, so users can choose.      


#TODO: Simple functions to do things like clear run history, or export it to a file.
#TODO: maybe helpers for certian things like exception managing.
#TODO: add categories.
#TODO: parameter to display data on screen in a pretty manner.
#TODO: put these comments inside PSV2 comment block and syntax using markdown for easy copy/paste to README.MD on GITHUB
#TODO: examples ,with out-gridview, with filtering and grouping, and comparing to historical runs, exporting to CLIXML and reimporting
#GLOBAL VARIABLES USED
#    $global:__QDPSgroups         - hashtable containing groups of defined tests currently in the system. 
#                                   defining a new one with the same name overrides the existing one
#    $global:__QDPSLastTestRun    - the results of the most recent last test run.
#    $global:__QDPSTestRunHistory - the aggregate results of all test runs this PS session. (group by RunID
#                                   to differentiate different runs)
#The follow global variables are used as implementation details during runs
#  $global:__QDPSCurrentTestGroup , $global:__QDPSruntimestamp

#NOTES
#returns pscustomobjects with properties, on screen it may be ugly but out-gridview is your friend.
#while it will be a module, it will use variables in global scope and can be copy/pasted embedded.

function Clear-QDPSTestGroups { $global:__QDPSgroups = @{} }
function Clear-QDPSTestHistory 
  { 
    $global:__QDPSLastTestRun = New-Object system.collections.arraylist 
    $global:__QDPSTestRunHistory = New-Object system.collections.arraylist 
  }
function Get-QDPSTestHistory
  {
    if (-not $global:__QDPSTestRunHistory ) { $global:__QDPSTestRunHistory = New-Object system.collections.arraylist }
    $global:__QDPSTestRunHistory 
  }
function Get-QDPSLastRun
 {
    if (-not $global:__QDPSLastTestRun ) { $global:__QDPSLastTestRun = New-Object system.collections.arraylist }
    $global:__QDPSLastTestRun 
 }
function New-QDPSTestGroup{
[CmdletBinding()] param (
    [Parameter(Mandatory = $true)]
    [string] $name,
    [Parameter(Mandatory = $true)]
    [scriptblock]$Scriptblock,
    [string] $description,
    [scriptblock]$PreCleanUp,
    [scriptblock]$PostCleanUp,
    [scriptblock]$PrereqCheck
)
if (-not $global:__QDPSgroups) { $global:__QDPSgroups = @{} }
$global:__QDPSgroups.$name = New-Object pscustomobject -Property @{name = $name;description = $description;code = $Scriptblock;
    precleanup = $PreCleanUp;postcleanup = $PostCleanUp;prereq = $PrereqCheck }
}

function Add-QDPSTestResult {
[CmdletBinding()] param (
   [Parameter(Mandatory = $true)]
   [string] $name,
   [Parameter(Mandatory = $true)]
   [string] $testgroup,
   [Parameter(Mandatory = $true)]
   [bool] $passed,
   [Parameter(Mandatory = $true)]
   [Guid] $RunID,
   [Parameter(Mandatory = $true)]
   [DateTime] $RunTimeStamp,
   [string] $message, 
   [string] $description  
)
$global:__QDPSLastTestRun += new-object pscustomobject  -Property @{            
            passed = $passed
            name = $name
            testgroup = $testgroup
            description = $description
            message = $message
            runID = $runID
            runTimeStamp = $runtimestamp
        }
}

function Assert-QDPSTest {
[CmdletBinding()] param (
    [Parameter(Mandatory = $true)]
    [string] $name,
    [Parameter(Mandatory = $true)]
    [scriptblock]$condition,    
    [Parameter(Mandatory = $true)]
    [string] $failmessage,
    [string] $passmessage,
    [string] $description,
    [switch] $forcestopOnFail    
    )
    $local:pass = $false
    try {
     if (&$condition) { $local:pass = $true}
     Add-QDPSTestResult -passed  $local:pass `
                        -name  $name `
                        -testgroup  $global:__QDPSCurrentTestGroup `
                        -description  $description `
                        -message $(if($local:pass) {$passmessage } else {$failmessage } ) `
                        -runID $global:__QDPSrunID `
                        -runTimeStamp  $global:__QDPSruntimestamp        
    }
    catch {    
    $local:pass = $false
    Add-QDPSTestResult  -passed  $false `
                        -name  $name `
                        -testgroup $global:__QDPSCurrentTestGroup `
                        -description  $description `
                        -message "Exception occuring during Assert calculation $_" `
                        -runID $global:__QDPSrunID `
                        -runTimeStamp  $global:__QDPSruntimestamp
                    
    }
    if($forcestopOnFail -and -not $local:pass ) { throw "__QDPSDontCarryOn" }        

}


function Assert-QDPSFail {
[CmdletBinding()] param (
    [Parameter(Mandatory = $true)]
    [string] $name,    
    [Parameter(Mandatory = $true)]
    [string] $failmessage,
    [string] $description,
    [switch] $forcestop    
)
    Add-QDPSTestResult  -passed $false `
                        -name  $name `
                        -testgroup  $global:__QDPSCurrentTestGroup `
                        -description $description `
                        -message  $failmessage `
                        -runID  $global:__QDPSrunID `
                        -runTimeStamp  $global:__QDPSruntimestamp
            
if($forcestop) { throw "__QDPSDontCarryOn" }
}


function Assert-QDPSPass {
[CmdletBinding()] param (
    [Parameter(Mandatory = $true)]
    [string] $name,
    [Parameter(Mandatory = $true)]
    [string] $passmessage,
    [string] $description,
    [switch] $forcestop    
)
Add-QDPSTestResult  -passed = $true `
                    -name  $name `
                    -testgroup  $global:__QDPSCurrentTestGroup `
                    -description  $description `
                    -message  $passmessage `
                    -runID  $global:__QDPSrunID `
                    -runTimeStamp  $global:__QDPSruntimestamp
            
if($forcestop) { throw "__QDPSDontCarryOn" }
}


function invoke-QDPStest {
[CmdletBinding()] param (
[string[]] $name,
[scriptblock]$batchreqreq
)
if(-not $global:__QDPSgroups) { throw "No Test Groups defined" }
if ($name -eq $Null -or 
     ($name.Length -eq 1 -and $name[0].trim() -eq [string]::Empty) -or 
     ($name.Length -eq 1 -and $name[0].trim() -eq "*")
   )
  {
  $local:TeststoRun = $global:__QDPSgroups
  }
else
 {
        $local:TeststoRun = @{}
        $name | % {
            if ($global:__QDPSgroups.$_) { $local:TeststoRun.$_ =  $global:__QDPSgroups.$_ }
            }
 }
if ($local:TeststoRun.Count -lt 1 ) { throw "No matching test groups for $name found " }
if (-not $global:__QDPSLastTestRun ) { $global:__QDPSLastTestRun = New-Object system.collections.arraylist }
if (-not $global:__QDPSTestRunHistory ) { $global:__QDPSTestRunHistory = New-Object system.collections.arraylist }
$global:__QDPSTestRunHistory.AddRange($global:__QDPSLastTestRun)
$global:__QDPSLastTestRun = New-Object system.collections.arraylist 
$global:__QDPSrunID = [guid]::NewGuid()
$global:__QDPSruntimestamp = [datetime]::Now

try 
    {
        if ($batchreqreq) { & $batchreqreq | out-null } 
    }
catch 
    {
        Add-QDPSTestResult  -passed $false `
                            -name "BatchPreReqCheck" `
                            -testgroup "BATCH PREREQ" `
                            -description "" `
                            -message "Batch prereq check threw exception [ $_ ]" `
                            -runID $global:__QDPSrunID `
                            -runTimeStamp $global:__QDPSruntimestamp
        $local:TeststoRun = @{} #don't run anything else
    }

foreach ($testgroupkey in $local:TeststoRun.GetEnumerator())
 {
    $testgroup = $testgroupkey.Value
    $global:__QDPSCurrentTestGroup =  $testgroup.name
    
    
    try {if ($testgroup.Prereq) { & $testgroup.Prereq | out-null}}
    catch 
    {
        Add-QDPSTestResult  -passed $false `
                            -name "PreReqCheck" `
                            -testgroup $global:__QDPSCurrentTestGroup `
                            -description "" `
                            -message "prereq check for test group '$global:__QDPSCurrentTestGroup' threw exception [ $_ ]" `
                            -runID $global:__QDPSrunID `
                            -runTimeStamp $global:__QDPSruntimestamp
            
        continue
    }
    try {if ($testgroup.precleanup) { & $testgroup.precleanup| out-null}}
    catch 
    {
        Add-QDPSTestResult  -passed $false `
                            -name "precleanup" `
                            -testgroup $global:__QDPSCurrentTestGroup `
                            -description  "" `
                            -message "precleanup for test group '$global:__QDPSCurrentTestGroup' threw exception [ $_ ]" `
                            -runID $global:__QDPSrunID `
                            -runTimeStamp $global:__QDPSruntimestamp
            
        continue
    }
    #run the test
    try {
    & $testgroup.code | out-null
    }

    catch {
    
    if ($_.exception.message -ne "__QDPSDontCarryOn") 
     {
         Add-QDPSTestResult -passed $false `
                            -name "uncaughtexception" `
                            -testgroup $global:__QDPSCurrentTestGroup `
                            -description "" `
                            -message "uncaught exception for test group '$global:__QDPSCurrentTestGroup' threw exception [ $_ ]" `
                            -runID $global:__QDPSrunID `
                            -runTimeStamp $global:__QDPSruntimestamp    
            
     }
    }

    try {if ($testgroup.postcleanup) { & $testgroup.postcleanup| out-null}}
    catch 
    {
        Add-QDPSTestResult  -passed $false `
                            -name "postcleanup" `
                            -testgroup $global:__QDPSCurrentTestGroup `
                            -description "" `
                            -message "postcleanup for test group '$global:__QDPSCurrentTestGroup' threw exception [ $_ ]" `
                            -runID $global:__QDPSrunID `
                            -runTimeStamp $global:__QDPSruntimestamp
            
        continue
    }

 }
$global:__QDPSTestRunHistory.AddRange(  $global:__QDPSLastTestRun ) | out-null
$global:__QDPSLastTestRun
}

set-alias assert Assert-QDPSTest
set-alias pass Assert-QDPSPass
set-alias testgroup New-QDPSTestGroup
set-alias fail Assert-QDPSFail
Clear-QDPSTestHistory

