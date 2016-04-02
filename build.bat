@echo off
cd "./Game Source"
fpc -MDELPHI -O2 -FE../Bin -FU../Temp Doom2DF.dpr
cd ".."
pause