@echo off
REM This is a script to run writeAddresses and compare output
REM

set perlFile=writeAddresses.pl
set testDataDir=D:\Aberscan\PerlApplications\AAPSTagger\TestWriteAddressesDir
set taggedPhotoDir=%testDataDir%\tagged
set tagFile=%testDataDir%\testAddresses.csv

REM
REM First remove the tagged folder if one exists
DEL /F %taggedPhotoDir%
RMDIR %taggedPhotoDir%

REM
REM Run the perl script
perl %perlFile% -srcFolder "%testDataDir%" -destFolder "%testDataDir%" -tagFileName "%tagFile%"

REM
REM Compare the generated output map file with the golden output map file
FC %taggedPhotoDir%\aberscanPhotoMappings.txt %testDataDir%\goldenPhotoMappings.txt

exit /B 0
