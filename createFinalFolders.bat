@echo on
REM This script copies the 10 batch folders into a jpg folder and a tif folder, then creates the tagged folders
REM

set jpgFolder=K:\AAPSProject\jpgs
set tifFolder=K:\AAPSProject\tifs
set tagFile="L:\aberscan\AAPSProject\2013-07-16-1979-Addresses.csv"

set batch01=L:\aberscan\AAPSProject\Batch01
set batch02=L:\aberscan\AAPSProject\Batch02
set batch03=L:\aberscan\AAPSProject\Batch03
set batch04=L:\aberscan\AAPSProject\Batch04
set batch05=L:\aberscan\AAPSProject\Batch05
set batch06=L:\aberscan\AAPSProject\Batch06
set batch07=L:\aberscan\AAPSProject\Batch07
set batch08=L:\aberscan\AAPSProject\Batch08
set batch09=L:\aberscan\AAPSProject\Batch09
set batch10=L:\aberscan\AAPSProject\Batch10
set perlFile=D:\aberscan\perlApplications\AAPSTagger\writeAddresses.pl



REM
REM First empty the jpg folder
REM DEL /F %jpgFolder%

REM
REM First empty the tif folder
DEL /F %tifFolder%

REM
REM copy the various batch jpg photos into the jpg folder
REM XCOPY %batch01%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch02%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch03%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch04%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch05%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch06%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch07%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch08%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch09%\EnhancedJpgScans %jpgFolder%
REM XCOPY %batch10%\EnhancedJpgScans %jpgFolder%

REM
REM Create the tagged folder
REM perl %perlFile% -srcFolder "%jpgFolder%" -tagFileName "%tagFile%"



REM
REM copy the various batch tif photos into the tif folder
XCOPY %batch01%\EnhancedTifScans %tifFolder%
XCOPY %batch02%\EnhancedTifScans %tifFolder%
XCOPY %batch03%\EnhancedTifScans %tifFolder%
XCOPY %batch04%\EnhancedTifScans %tifFolder%
XCOPY %batch05%\EnhancedTifScans %tifFolder%
XCOPY %batch06%\EnhancedTifScans %tifFolder%
XCOPY %batch07%\EnhancedTifScans %tifFolder%
XCOPY %batch08%\EnhancedTifScans %tifFolder%
XCOPY %batch09%\EnhancedTifScans %tifFolder%
XCOPY %batch10%\EnhancedTifScans %tifFolder%

REM
REM Create the tagged folder
perl %perlFile% -srcFolder "%tifFolder%" -tagFileName "%tagFile%"

exit /B 0
