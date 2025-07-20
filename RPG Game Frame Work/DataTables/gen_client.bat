set WORKSPACE=..
set GEN_CLIENT=%WORKSPACE%\Tools\Luban\Luban.dll
set CONF_ROOT=.

dotnet %GEN_CLIENT% ^
    -t client ^
    -c cs-bin ^
    -d bin ^
    --conf %CONF_ROOT%\luban.conf ^
    -x outputCodeDir=%WORKSPACE%\Assets\Data\Gen ^
    -x outputDataDir=%WORKSPACE%\Assets\Data\GenerateData\Bin

pause