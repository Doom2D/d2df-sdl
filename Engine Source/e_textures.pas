unit e_textures;

{ This unit provides interface to load 24-bit and 32-bit uncompressed images
  from Truevision Targa (TGA) graphic files, and create OpenGL textures
  from it's data. }

interface

uses
  GL, GLExt, SysUtils, e_log;

var
  fUseMipmaps: Boolean = False;
  TEXTUREFILTER: Integer = GL_NEAREST;

function CreateTexture( Width, Height, Format: Word; pData: Pointer ): Integer;  
  
// Standard set of images loading functions
function LoadTexture( Filename: String; var Texture: GLuint;
                      var pWidth, pHeight: Word; Fmt: PWord = nil ): Boolean;

function LoadTextureEx( Filename: String; var Texture: GLuint;
                        fX, fY, fWidth, fHeight: Word; Fmt: PWord = nil ): Boolean;

function LoadTextureMem( pData: Pointer; var Texture: GLuint;
                         var pWidth, pHeight: Word; Fmt: PWord = nil ): Boolean;

function LoadTextureMemEx( pData: Pointer; var Texture: GLuint;
                           fX, fY, fWidth, fHeight: Word; Fmt: PWord = nil ): Boolean;

implementation

uses BinEditor;

type
  TTGAHeader = packed record
    FileType:     Byte;
    ColorMapType: Byte;
    ImageType:    Byte;
    ColorMapSpec: array[0..4] of Byte;
    OrigX:        array[0..1] of Byte;
    OrigY:        array[0..1] of Byte;
    Width:        array[0..1] of Byte;
    Height:       array[0..1] of Byte;
    BPP:          Byte;
    ImageInfo:    Byte;
  end;

// This is auxiliary function that creates OpenGL texture from raw image data
function CreateTexture( Width, Height, Format: Word; pData: Pointer ): Integer;
var
  Texture: GLuint;
begin
  glGenTextures( 1, @Texture );
  glBindTexture( GL_TEXTURE_2D, Texture );

    {Texture blends with object background}
  glTexEnvi( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE );
    {Texture does NOT blend with object background}
 // glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);

  {
    Select a filtering type.
    BiLinear filtering produces very good results with little performance impact

    GL_NEAREST               - Basic texture (grainy looking texture)
    GL_LINEAR                - BiLinear filtering
    GL_LINEAR_MIPMAP_NEAREST - Basic mipmapped texture
    GL_LINEAR_MIPMAP_LINEAR  - BiLinear Mipmapped texture
  }

  // for GL_TEXTURE_MAG_FILTER only first two can be used
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, TEXTUREFILTER );
  // for GL_TEXTURE_MIN_FILTER all of the above can be used
  glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, TEXTUREFILTER );

  if Format = GL_RGBA then
  begin
    glTexImage2D( GL_TEXTURE_2D, 0, 4, Width, Height,
                  0, GL_RGBA, GL_UNSIGNED_BYTE, pData );
  end else
  begin
    glTexImage2D( GL_TEXTURE_2D, 0, 3, Width, Height,
                  0, GL_RGB, GL_UNSIGNED_BYTE, pData );
  end;
  
  glBindTexture(GL_TEXTURE_2D, 0);

  Result := Texture;
end;

function LoadTextureMem( pData: Pointer; var Texture: GLuint;
                         var pWidth, pHeight: Word; Fmt: PWord = nil ): Boolean;
var
  TGAHeader:     TTGAHeader;
  image:         Pointer;
  Width, Height: Integer;
  ImageSize:     Integer;
  i:             Integer;
  Front:         ^Byte;
  Back:          ^Byte;
  Temp:          Byte;
  BPP:           Byte;
  TFmt:           Word;

begin
  Result := False;
  pWidth := 0;
  pHeight := 0;

  CopyMemory( @TGAHeader, pData, SizeOf(TGAHeader) );

  if ( TGAHeader.ImageType <> 2 ) then
  begin
    e_WriteLog( 'Error loading texture: Bad ImageType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.ColorMapType <> 0 ) then
  begin
    e_WriteLog( 'Error loading texture: Bad ColorMapType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.BPP < 24 ) then
  begin
    e_WriteLog( 'Error loading texture: BPP less than 24', MSG_WARNING );
    Exit;
  end;

  Width  := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
  Height := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
  BPP := TGAHeader.BPP;

  ImageSize := Width * Height * (BPP div 8);

  GetMem( Image, ImageSize );
  CopyMemory( Image, PByte(pData) + SizeOf(TGAHeader), ImageSize );

  for i := 0 to Width * Height - 1 do
  begin
    Front := PByte(Image) + i*(BPP div 8);
    Back  := PByte(Image) + i*(BPP div 8) + 2;
    Temp   := Front^;
    Front^ := Back^;
    Back^  := Temp;
  end;

  if ( BPP = 24 ) then
    TFmt := GL_RGB
  else
    TFmt := GL_RGBA;
    
  Texture := CreateTexture( Width, Height, TFmt, Image );

  FreeMem( Image );
  
  if Fmt <> nil then Fmt^ := TFmt;

  pWidth := Width;
  pHeight := Height;

  Result := True;
end;

function LoadTextureMemEx( pData: Pointer; var Texture: GLuint;
                           fX, fY, fWidth, fHeight: Word; Fmt: PWord = nil ): Boolean;
var
  TGAHeader:     TTGAHeader;
  image, image2: Pointer;
  Width, Height: Integer;
  ImageSize:     Integer;
  i, a, b:       Integer;
  Front:         ^Byte;
  Back:          ^Byte;
  Temp:          Byte;
  BPP:           Byte;
  Base:          PByte;
  TFmt:          Word;

begin
  Result := False;

  CopyMemory( @TGAHeader, pData, SizeOf(TGAHeader) );

  if ( TGAHeader.ImageType <> 2 ) then
  begin
    e_WriteLog( 'Error loading texture: Bad ImageType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.ColorMapType <> 0 ) then
  begin
    e_WriteLog( 'Error loading texture: Bad ColorMapType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.BPP < 24 ) then
  begin
    e_WriteLog( 'Error loading texture: BPP less than 24', MSG_WARNING );
    Exit;
  end;

  Width  := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
  Height := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
  BPP := TGAHeader.BPP;

  if fX > Width then Exit;
  if fY > Height then Exit;
  if fX+fWidth > Width then Exit;
  if fY+fHeight > Height then Exit;

  ImageSize := Width * Height * (BPP div 8);
  GetMem( Image2, ImageSize );
  CopyMemory( Image2, PByte(pData) + SizeOf(TGAHeader), ImageSize );

  a := BPP div 8;

  for i := 0 to Width * Height - 1 do
  begin
    Front := PByte(Image2) + i * a;
    Back  := PByte(Image2) + i * a + 2;
    Temp   := Front^;
    Front^ := Back^;
    Back^  := Temp;
  end;

  fY := Height - (fY + fHeight);

  ImageSize := fHeight * fWidth * (BPP div 8);
  GetMem( Image, ImageSize );

  Base := PByte( Image2 ) + fY * Width * (BPP div 8) + fX * (BPP div 8);
  a := fWidth * (BPP div 8);
  b := Width * (BPP div 8);

  for i := 0 to fHeight-1 do
    CopyMemory( PByte(image) + a*i, Base + b*i, a );

  if ( BPP = 24 ) then
    TFmt := GL_RGB
  else
    TFmt := GL_RGBA;
    
  Texture := CreateTexture( fWidth, fHeight, TFmt, Image );

  FreeMem( Image );
  FreeMem( Image2 );
  
  if Fmt <> nil then Fmt^ := TFmt;

  Result := True;
end;

function LoadTexture( Filename: String; var Texture: GLuint;
                      var pWidth, pHeight: Word; Fmt: PWord = nil ): Boolean;
var
  TGAHeader:     TTGAHeader;
  TGAFile:       File;
  bytesRead:     Integer;
  image:         Pointer;
  Width, Height: Integer;
  ImageSize:     Integer;
  i:             Integer;
  Front:         ^Byte;
  Back:          ^Byte;
  Temp:          Byte;
  BPP:           Byte;
  TFmt:          Word;

begin
  Result := False;
  pWidth := 0;
  pHeight := 0;

  if not FileExists(Filename) then
  begin
    e_WriteLog('Texture ' + Filename + ' not found', MSG_WARNING);
    Exit;
  end;

  AssignFile( TGAFile, Filename );
  Reset( TGAFile, 1 );
  BlockRead( TGAFile, TGAHeader, SizeOf(TGAHeader) );

  if ( TGAHeader.ImageType <> 2 ) then
  begin
    CloseFile( TGAFile );
    e_WriteLog( 'Error loading texture: Bad ImageType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.ColorMapType <> 0 ) then
  begin
    CloseFile( TGAFile );
    e_WriteLog( 'Error loading texture: Bad ColorMapType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.BPP < 24 ) then
  begin
    CloseFile( TGAFile );
    e_WriteLog( 'Error loading texture: BPP less than 24', MSG_WARNING );
    Exit;
  end;

  Width  := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
  Height := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
  BPP := TGAHeader.BPP;

  ImageSize := Width * Height * (BPP div 8);

  GetMem( Image, ImageSize );

  BlockRead( TGAFile, image^, ImageSize, bytesRead );
  if ( bytesRead <> ImageSize ) then
  begin
    CloseFile( TGAFile );
    Exit;
  end;

  CloseFile( TGAFile );

  for i := 0 to Width * Height - 1 do
  begin
    Front := PByte(Image) + i * (BPP div 8);
    Back  := PByte(Image) + i * (BPP div 8) + 2;
    Temp   := Front^;
    Front^ := Back^;
    Back^  := Temp;
  end;

  if ( BPP = 24 ) then
    TFmt := GL_RGB
  else
    TFmt := GL_RGBA;
    
  Texture := CreateTexture( Width, Height, TFmt, Image );

  FreeMem( Image );
  
  if Fmt <> nil then Fmt^ := TFmt;

  pWidth := Width;
  pHeight := Height;

  Result := True;
end;

function LoadTextureEx( Filename: String; var Texture: GLuint;
                        fX, fY, fWidth, fHeight: Word; Fmt: PWord = nil ): Boolean;
var
  TGAHeader:     TTGAHeader;
  TGAFile:       File;
  image, image2: Pointer;
  Width, Height: Integer;
  ImageSize:     Integer;
  i:             Integer;
  Front:         ^Byte;
  Back:          ^Byte;
  Temp:          Byte;
  BPP:           Byte;
  Base:          PByte;
  TFmt:          Word;
  
begin
  Result := False;

  if not FileExists(Filename) then
  begin
    e_WriteLog( 'Texture ' + Filename + ' not found', MSG_WARNING );
    Exit;
  end;

  AssignFile( TGAFile, Filename );
  Reset( TGAFile, 1 );
  BlockRead( TGAFile, TGAHeader, SizeOf(TGAHeader) );

  if ( TGAHeader.ImageType <> 2 ) then
  begin
    CloseFile( TGAFile );
    e_WriteLog( 'Error loading texture: Bad ImageType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.ColorMapType <> 0 ) then
  begin
    CloseFile( TGAFile );
    e_WriteLog( 'Error loading texture: Bad ColorMapType', MSG_WARNING );
    Exit;
  end;

  if ( TGAHeader.BPP < 24 ) then
  begin
    CloseFile( TGAFile );
    e_WriteLog( 'Error loading texture: BPP less than 24', MSG_WARNING );
    Exit;
  end;

  Width  := TGAHeader.Width[0]  + TGAHeader.Width[1]  * 256;
  Height := TGAHeader.Height[0] + TGAHeader.Height[1] * 256;
  BPP := TGAHeader.BPP;

  if fX > Width then Exit;
  if fY > Height then Exit;
  if fX+fWidth > Width then Exit;
  if fY+fHeight > Height then Exit;

  ImageSize := Width * Height * (BPP div 8);
  GetMem( Image2, ImageSize );
  BlockRead( TGAFile, Image2^, ImageSize );

  CloseFile( TGAFile );

  for i := 0 to Width * Height - 1 do
  begin
    Front := PByte(Image2) + i * (BPP div 8);
    Back  := PByte(Image2) + i * (BPP div 8) + 2;
    Temp   := Front^;
    Front^ := Back^;
    Back^  := Temp;
  end;

  fY := Height - (fY + fHeight);

  ImageSize := fHeight * fWidth * (BPP div 8);
  GetMem( Image, ImageSize );

  Base := PByte(Image2) + fY * Width * (BPP div 8) + fX * (BPP div 8);

  for i := 0 to fHeight-1 do
  begin
    CopyMemory( PByte(image) + fWidth * (BPP div 8) * i,
                Base + Width * (BPP div 8) * i, fWidth * (BPP div 8) );
  end;

  if ( BPP = 24 ) then
    TFmt := GL_RGB
  else
    TFmt := GL_RGBA;

  Texture := CreateTexture( fWidth, fHeight, TFmt, Image );

  FreeMem( Image );
  FreeMem( Image2 );

  if Fmt <> nil then Fmt^ := TFmt;

  Result := True;
end;

end.

