quick and dirty PowerShell Unit Testing framework.
---------------------------------------------------
 Copyright (c) Karl Prosser, 2013
 Free for use under MS-PL, MS-RL, GPL 2, or BSD license. Your choice. 
 
 Version 0.6

quick and dirty PowerShell Unit Testing framework.
if you want something more than this, then look at PSAINT or PESTER or PSUNIT
+ Goals
    + Small
    + No dependencies (can be as module or just copy and pasted, and tag along with a remoting scriptblock
    + Flexible to deal with many real world scenarios in PS
    + Data Centric, with history. the goal is the output will be objects that can be filtered, grouped, exported 
      and compared with previous runs, using standard build in PS Cmdlets.      
    + Many "tests" in one test, rather than redoing certian things, allow a progressions of tests, allowing
      you to shortcircuit future tests when you know they will fail because the current on fails (-ForceStop..)
    + Use global variables!!!! as a way to keep track of tests, and results.
    + Work in V2 and V3 well (only testing in V3 so far)
+ NonGoals
   + Mocking. Its easy enough to mock PS because of function and alias precendence, and these can
     easily added or remoted in the presetup and teardown scriptblocks. Also object mocking can be done
     in many cases by exporting and importing CLIXML.
   + Asserting Exceptions - PS exceptions with terminating, non terminating errors, dotnet, different 
     behaviour in V2 and V3,errors over remoting boundaries, differences in content (like erroractionpreferences etc)#     
     would make this quite complicated and not reliable, thus your tests should do their own exception handling
     Basically if you need to test exceptions , do try/catch yourself, also if you are interested in terminating and non terminating
     Errors you may have patterns of using erroraction on a scriptblock, or errorvariable, and may look and clear $global:error  
     and all non caught exceptions are treated as fails.        
   + Following any particular TDD or BDD philosophy, or strict purity.
   + For Now documenting the cmdlets inline, maybe later i can have something that strips out the comments
     upon some sort of build and checkin process, so users can choose.      


