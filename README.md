# D2DF-SDL
[Doom 2D Forever](https://github.com/pss88/DF) adapted for use with the FreePascal Compiler and ported to SDL 1.2.

# SDL2 Port
This port has been abandoned in favor of the [SDL2 port](http://repo.or.cz/d2df-sdl.git), which is currently in development.
For further information, see [the official forums](http://doom2d.org/forum).

# Building

## Requirements
* FPC >= 2.6.4, 32-bit (with the "sdl", "gl" and "hash" packages installed);
* FMODEx >= 4.26.xx;
* libenet >= 1.3.13;
* SDL >= 1.2.xx.

## Instructions
### Windows
Run build.bat.
If it builds fine, the executable will be output to "./Bin/Doom2DF.exe".
Don't forget that it will require SDL.dll, FMODEx.dll and ENet.dll to run.
### Linux
Run
```
fpc -MDELPHI -O2 -FE../Bin -FU../Temp Doom2DF.dpr
```
in the "Game Source" directory.
