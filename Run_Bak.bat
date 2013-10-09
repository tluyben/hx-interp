@echo off
bin\VM-debug.exe runscript -src ./script -main TestCommon -path C:/HaxeToolkit/haxe/std -path ./src -flag ios
pause

@echo off
bin\VM-debug.exe compile -out script.hxc -src ./script -main TestCommon -path C:/HaxeToolkit/haxe/std -path ./src -flag ios
bin\VM-debug.exe runbytes script.hxc
pause