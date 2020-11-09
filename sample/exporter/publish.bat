SET TexturePackerExe=%1
IF "%TexturePackerExe%"=="" (SET TexturePackerExe="%PROGRAMFILES%\CodeAndWeb\TexturePacker\bin\TexturePacker.exe")

%TexturePackerExe% .\sprites-aligned.tps --force-publish
%TexturePackerExe% .\sprites-scatter.tps --force-publish
%TexturePackerExe% .\sprites-semi-aligned.tps --force-publish
