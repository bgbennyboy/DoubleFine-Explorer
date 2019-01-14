{
******************************************************
  DoubleFine Explorer
  By Bennyboy
  Http://quickandeasysoftware.net
******************************************************
}
{
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.
}

unit uDFExplorer_Base;

interface

uses
  Classes, sysutils, windows, graphics,

  GR32, ImagingComponents, ZlibEx, ZlibExGz, ImagingTypes, Imaging,

  uDFExplorer_Types, uDFExplorer_BaseBundleManager, uMemReader, uDFExplorer_Funcs,
  uDFExplorer_FSBManager, uDFExplorer_PAKManager, uDFExplorer_PCKManager,
  uDFExplorer_PKGManager, uDFExplorer_PPAKManager, uDFExplorer_LABManager,
  uDFExplorer_LPAKManager, uVimaDecode;

type
  TDFExplorerBase = class
private
  fOnDebug: TDebugEvent;
  fOnProgress: TProgressEvent;
  fOnDoneLoading: TOnDoneLoading;
  fBundle: TBundleManager;
  fBundleFilename: string;
  function GetFileName(Index: integer): string;
  function GetFileSize(Index: integer): integer;
  function GetFileOffset(Index: integer): int64;
  function GetFileType(Index: integer): TFiletype;
  function GetFileExtension(Index: integer): string;
  function DrawImage(MemStream: TMemoryStream; OutImage: TBitmap32): boolean;
  procedure Log(Text: string);
  function WriteDDSToStream(SourceStream, DestStream: TStream): boolean;
  function WriteDOTTFontToStream(SourceStream, DestStream: TStream): boolean;
  function WriteHeaderlessTexDDSToStream(SourceStream, DestStream: TStream): boolean;
  function WriteHeaderlessPsychonautsDDSToStream(PsychoDDS: TPsychonautsDDS; SourceStream,
    DestStream: TStream): boolean;
  function WriteHeaderlessDOTT_DDSToStream(SourceStream, DestStream: TStream): boolean;
  function WriteHeaderlessDOTT_DDS_CostumeToStream(SourceStream, DestStream: TStream): boolean;
  function WriteHeaderlessFT_chnk_DDSToStream(SourceStream, DestStream: TStream): boolean;
  procedure AddDDSHeaderToStream(Width, Height, DataSize: integer; DXTType: TDXTTYPE;
    DestStream: TStream; IsCubemap: boolean = false);
public
  constructor Create(BundleFile: string; Debug: TDebugEvent);
  destructor Destroy; override;
  function DrawImageGeneric(FileIndex: integer; DestBitmap: TBitmap32): boolean;
  function DrawImageDOTTFont(FileIndex: integer; DestBitmap: TBitmap32): boolean;
  function DrawImageDDS(FileIndex: integer; DestBitmap: TBitmap32; DDSType:
    TDDSType = DDS_NORMAL): boolean;
  function SaveDDSToFile(FileIndex: integer; DestDir, FileName: string; DDSType:
    TDDSType = DDS_NORMAL): boolean;
  function SaveIMCToStream(FileNo: integer; DestStream: TStream): boolean;
  procedure Initialise;
  procedure SaveFile(FileNo: integer; DestDir, FileName: string; DoLog: boolean = true);
  procedure SaveFiles(DestDir: string);
  procedure SaveFileToStream(FileNo: integer; DestStream: TStream);
  procedure ReadText(FileIndex: integer; DestStrings: TStrings);
  procedure ReadCSVText(FileIndex: integer; DestStrings: TStrings);
  procedure ReadDelimitedText(FileIndex: integer; DestStrings: TStrings);
  property OnDebug: TDebugEvent read FOnDebug write FOnDebug;
  property OnDoneLoading: TOnDoneLoading read FOnDoneLoading write FOnDoneLoading;
  property OnProgress: TProgressEvent read FOnProgress write FOnProgress;
  property FileName[Index: integer]: string read GetFileName;
  property FileSize[Index: integer]: integer read GetFileSize;
  property FileOffset[Index: integer]: int64 read GetFileOffset;
  property FileType[Index: integer]: TFileType read GetFileType;
  property FileExtension[Index: integer]: string read GetFileExtension;
end;

implementation


constructor TDFExplorerBase.Create(BundleFile: string; Debug: TDebugEvent);
begin
  OnDebug:=Debug;
  fBundleFilename:=BundleFile;

  try
    if Uppercase( ExtractFileExt(BundleFile) ) = '.FSB' then
      fBundle:=TFSBManager.Create(BundleFile)
    else
    if Uppercase( ExtractFileExt(BundleFile) ) = '.PCK' then
      fBundle:=TPCKManager.Create(BundleFile)
    else
    if Uppercase( ExtractFileExt(BundleFile) ) = '.PKG' then
      fBundle:=TPKGManager.Create(BundleFile)
    else
    if Uppercase( ExtractFileExt(BundleFile) ) = '.PPF' then
      fBundle:=TPPAKManager.Create(BundleFile)
    else
    if Uppercase( ExtractFileExt(BundleFile) ) = '.LAB' then
      fBundle:=TLABManager.Create(BundleFile)
    else
    if Uppercase( ExtractFileExt(BundleFile) ) = '.CLE' then
      fBundle:=TLPAKManager.Create(BundleFile)
    else
    if Uppercase( ExtractFileExt(BundleFile) ) = '.DATA' then
      fBundle:=TLPAKManager.Create(BundleFile)
    else
      fBundle:=TPAKManager.Create(BundleFile);
  except on E: EInvalidFile do
    raise;
  end;

end;

destructor TDFExplorerBase.Destroy;
begin
  if fBundle <> nil then
    FreeandNil(fBundle);

  inherited;
end;

//Deal with delimited text and format it nicely
procedure TDFExplorerBase.ReadDelimitedText(FileIndex: integer;
  DestStrings: TStrings);

  function GetIndent(IndentLevel: integer): String; inline;
  var
    i: integer;
  begin
    result :='';
    for i := 0 to IndentLevel - 1 do
      result := result + '    ';//chr(9); //tab
  end;

var
  TempStream: TExplorerMemoryStream;
  TextLen, i, IndentLevel, SquareBracketLevel: integer;
  TempStr: String;
  SourceStr: AnsiString;
begin
  TempStream:=TExplorerMemoryStream.Create;
  DestStrings.BeginUpdate;
  try
    fBundle.SaveFileToStream(Fileindex, TempStream);
    TextLen := TempStream.ReadDWord;
    Sourcestr :='';

    //Costume Quest 2 doesnt have the 4 byte length and '1' string value.
    if TextLen <> TempStream.Size - TempStream.Position then
    begin
      TempStream.Position := 0;
      TextLen := TempStream.Size;
    end;

    SourceStr := TempStream.ReadAnsiString(TextLen);

    IndentLevel := 0;
    SquareBracketLevel := 0;
    TempStr := '';
    for I := 0 to Length(SourceStr) - 1 do
    begin
      //Remove the 1 character at the start of every file
      if (i=1) and (SourceStr[i] = '1') then
      begin
        //Swallow it and do nothing
        continue;
      end
      else
      if SourceStr[i] = '{' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        DestStrings.Add(GetIndent(IndentLevel) + '{');
        inc(IndentLevel);
      end
      else
      if SourceStr[i] = '}' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        dec(IndentLevel);
        DestStrings.Add(GetIndent(IndentLevel) + '}');
      end
      else
      if SourceStr[i] = '[' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        DestStrings.Add(GetIndent(IndentLevel) + '[');
        inc(IndentLevel);
        inc(SquareBracketLevel);
      end
      else
      if SourceStr[i] = ']' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        dec(IndentLevel);
        DestStrings.Add(GetIndent(IndentLevel) + ']');
        dec(SquareBracketLevel);
      end
      else
      if SourceStr[i] = ';' then //new line
      begin
        DestStrings.Add(GetIndent(IndentLevel) + TempStr);
        TempStr := '';
      end
      else
      if SourceStr[i] = #0 then
        //ignore newline char
        continue
      else
      if (SquareBracketLevel > 0) and (SourceStr[i] = ',')  then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;
        //Swallow the comma so its a newline
      end
      else
        Tempstr := TempStr + String(SourceStr[i]);

    end;

  finally
    TempStream.Free;
    DestStrings.EndUpdate;
  end;
end;

procedure TDFExplorerBase.ReadText(FileIndex: integer; DestStrings: TStrings);
var
  TempStream: TExplorerMemoryStream;
begin
  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(Fileindex, TempStream);
    DestStrings.LoadFromStream(TempStream);
  finally
    TempStream.Free;
  end;
end;

procedure TDFExplorerBase.ReadCSVText(FileIndex: integer;
  DestStrings: TStrings);
var
  TempStream: TExplorerMemoryStream;
begin
  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(Fileindex, TempStream);
    DestStrings.LoadFromStream(TempStream);
    DestStrings.CommaText := DestStrings.Text; //Probably very slow but...
  finally
    TempStream.Free;
  end;

end;

function TDFExplorerBase.DrawImage(MemStream: TMemoryStream;
  OutImage: TBitmap32): boolean;
var
  ImgBitmap : TImagingBitmap;
begin
  Result := false;
  MemStream.Position:=0;

  ImgBitmap := TImagingBitmap.Create;
  try
    MemStream.Position :=0;
    ImgBitmap.LoadFromStream(MemStream);
    if ImgBitmap.Empty then
      Exit;

    OutImage.Assign(ImgBitmap);
    Result := true;
  finally
    ImgBitmap.Free;
  end;
end;

function TDFExplorerBase.DrawImageDOTTFont(FileIndex: integer;
  DestBitmap: TBitmap32): boolean;
var
  TempStream, ImageStream: TExplorerMemoryStream;
begin
  Result:=false;

  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(FileIndex, TempStream);
    TempStream.Position:=0;

    ImageStream:=TExplorerMemoryStream.Create;
    try
      if WriteDOTTFontToStream(TempStream, ImageStream) = false then
      begin
        Log('Image Decode failed! ' + fBundle.FileName[FileIndex]);
        Exit;
      end;

      DestBitmap.Clear();
      destbitmap.CombineMode:=cmBlend;
      destBitmap.DrawMode:=dmOpaque;
      if DrawImage(ImageStream, DestBitmap)=false then
      begin
        Log('Image Decode failed! ' + fBundle.FileName[FileIndex]);
        Exit;
      end;

      Result:=true;
    finally
      ImageStream.Free;
    end;
  finally
    TempStream.Free;
  end;

end;

function TDFExplorerBase.WriteDOTTFontToStream(SourceStream,
  DestStream: TStream): boolean;
var
  BlockHeader: dword;
  Temp, Height, Width: word;
  Datasize, Dataoffset: integer;
  TempStream: TMemoryStream;
  Img: TImageData;
begin
{
  DOTT FTX format is similar to DOTT '.tex' textures
  4 bytes FTX1 or FXT2
  2 bytes width
  2 bytes height
  4 bytes uncompressed texture size
  4 bytes unknown
  x bytes Gzipped texture

  Texture isn't DXT -
    For FXT1 its 8bpp greyscale or RGB233 (unsure which, probably greyscale as its fonts)
    For FXT2 its 16bpp
}
  Result := false;
  SourceStream.Position := 0;
  SourceStream.Read(BlockHeader, 4);
  if (BlockHeader = 827872326) or (BlockHeader = 844649542) then //FXT1 FXT2
  else
  begin
    Log('Unrecognised header in DOTT font texture!');
    exit;
  end;

  Sourcestream.Read(Width, 2);
  if fBundle.BigEndian then Width := SwapEndianWord(Width);

  Sourcestream.Read(Height, 2);
  if fBundle.BigEndian then Height := SwapEndianWord(Height);

  Sourcestream.Seek(4, soFromCurrent); //Uncompressed size
  Sourcestream.Seek(4, soFromCurrent); //Unknown

  //Check here if gzipped. DOTT always? has a gzipped dxt texture after the header
  SourceStream.Read(Temp, 2);
  SourceStream.Seek(-2, soFromCurrent);
  if Temp = 35615 {1F8B} then
  begin
    TempStream := TMemoryStream.Create;
    try
      TempStream.CopyFrom(SourceStream, SourceStream.Size - 16);
      Tempstream.Position := 0;
      SourceStream.Size := 16;
      GZDecompressStream(tempstream, sourcestream);
      {GZDecompressStream(sourcestream, tempstream);
      TempStream.SaveToFile('c:\users\ben\desktop\decomp1');}
    finally
      TempStream.Free;
    end;
  end;

  if BlockHeader = 827872326 then //FXT1
    Datasize := Width * Height
  else if BlockHeader = 844649542 then //FXT2
    Datasize := (Width * Height) *2
  else
    Datasize := 0;

  Dataoffset := 16;
  SourceStream.Position := Dataoffset;
  DestStream.Position := 0;
  DestStream.CopyFrom(SourceStream, DataSize);


  InitImage(Img);
  try
  if BlockHeader = 827872326 then //FXT1
      NewImage(Width, Height, ifGray8, Img)
  else if BlockHeader = 844649542 then //FXT2
    NewImage(Width, Height, ifA1R5G5B5, Img);

    DestStream.Position := 0;
    DestStream.Read(Img.Bits^, Datasize);
    DestStream.Size := 0;
    SaveImageToStream('PNG', DestStream, Img);
    Result := true;
  finally
   FreeImage(Img);
  end;

end;

function TDFExplorerBase.DrawImageDDS(FileIndex: integer;
  DestBitmap: TBitmap32; DDSType: TDDSType = DDS_NORMAL): boolean;
var
  TempStream, DDSStream: TExplorerMemoryStream;
  DecodeResult: Boolean;
begin
  Result:=false;
  DecodeResult := false;

  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(FileIndex, TempStream);
    TempStream.Position:=0;

    DDSStream:=TExplorerMemoryStream.Create;
    try
      case DDSType of
        DDS_NORMAL:                  DecodeResult :=
            WriteDDSToStream(Tempstream, DDSStream);
        DDS_HEADERLESS:              DecodeResult :=
            WriteHeaderlessTexDDSToStream(Tempstream, DDSStream);
        DDS_HEADERLESS_PSYCHONAUTS:  DecodeResult :=
            WriteHeaderlessPsychonautsDDSToStream(
              TPPAKManager(fBundle).PsychoDDS[FileIndex], Tempstream, DDSStream);
        DDS_HEADERLESS_DOTT:         DecodeResult :=
            WriteHeaderlessDOTT_DDSToStream(TempStream, DDSStream);
        DDS_HEADERLESS_DOTT_COSTUME: DecodeResult :=
            WriteHeaderlessDOTT_DDS_CostumeToStream(TempStream, DDSStream);
        DDS_HEADERLESS_FT_CHNK:      DecodeResult :=
            WriteHeaderlessFT_chnk_DDSToStream(TempStream, DDSStream);
      end;

      if DecodeResult = false then
      begin
        Log('DDS Decode failed! ' + fBundle.FileName[FileIndex]);
        Exit;
      end;

      DestBitmap.Clear();
      destbitmap.CombineMode:=cmBlend;
      destBitmap.DrawMode:=dmOpaque;
      if DrawImage(DDSStream, DestBitmap)=false then
      begin
        Log('DDS Decode failed! ' + fBundle.FileName[FileIndex]);
        Exit;
      end;

      Result:=true;
    finally
      DDSStream.Free;
    end;
  finally
    TempStream.Free;
  end;
end;

function TDFExplorerBase.WriteDDSToStream(SourceStream, DestStream: TStream): boolean;
const
  DDSMagic: cardinal = 542327876; //542327876 = 'DDS '
  SearchOffsets: array [0..8] of integer = (0, 28, 36, 40, 48, 68, 144, 156, 180);
var
  DDSnum: cardinal;
  FoundPos, i: integer;
begin
  result := false;
  FoundPos := -1;

  for I := 0 to High(SearchOffsets) do
  begin
    SourceStream.Position := SearchOffsets[i];
    SourceStream.Read(DDSnum, 4);
    if DDSnum = DDSMagic then
    begin
      FoundPos := SourceStream.Position - 4;
      break;
    end;
  end;

  if FoundPos > -1 then
  begin
    SourceStream.Seek(FoundPos, soFromBeginning);
    DestStream.CopyFrom(SourceStream, SourceStream.Size - Sourcestream.Position);
    result := true;
  end
  else
    Log('DDS decode failed! Couldnt find identifier!');

  //DestStream.SaveToFile('C:\Users\Ben\Desktop\test.dds');
end;

function TDFExplorerBase.WriteHeaderlessDOTT_DDSToStream(SourceStream,
  DestStream: TStream): boolean;
var
  Height, Width, Datasize, Dataoffset: integer;
  Temp: word;
  TempStream: TMemoryStream;
  Img: TImageData;
  Info: TImageFormatInfo;
begin
{
  DOTT:
  4 bytes MXT5
  4 bytes width
  4 bytes height
  4 bytes Some identifier - mipmaps?
  X bytes Rest of file is gzipped image

  Unzipped image:
  Has mipmaps - there's extra texture data after the main texture
  DXT5 texture but is swizzled and stored in YCoCg colour space
  If just put into a DDS container then blue channel appears missing -
  need to convert the colour space

  Full Throttle:
  4 bytes DXT5
  4 bytes width
  4 bytes height
  X bytes zlib deflate data (without the 78DA header
}

  //First get the width and height and data size
  SourceStream.Position := 4;
  Sourcestream.Read(Width, 4);
  if fBundle.BigEndian then Width := SwapEndianDWord(Width);

  Sourcestream.Read(Height, 4);
  if fBundle.BigEndian then Height := SwapEndianDWord(Height);

  Sourcestream.Seek(4, soFromCurrent); //Unknown - mipmaps maybe?

  //Check if gzipped. DOTT always has gzipped dxt files after the 16 byte header
  SourceStream.Read(Temp, 2);
  SourceStream.Seek(-2, soFromCurrent);
  if Temp = 35615 {1F8B} then
  begin
    Dataoffset := 16;
    TempStream := tmemorystream.Create;
    try
      TempStream.CopyFrom(SourceStream, SourceStream.Size - 16);
      Tempstream.Position := 0;
      SourceStream.Size := 16;
      GZDecompressStream(tempstream, sourcestream);

      //GZDecompressStream(sourcestream, tempstream);
      //TempStream.SaveToFile('c:\users\ben\desktop\decomp1');
    finally
      TempStream.Free;
    end;
  end
  else
  //Assume its Full Throttle where its deflate without the 78DA header.
  begin
    Dataoffset := 12;
    Sourcestream.Seek(-4, soFromCurrent); //FT doesnt have the extra 4 bytes in the header
    TempStream := tmemorystream.Create;
    try
      TempStream.CopyFrom(SourceStream, SourceStream.Size - 12);
      Tempstream.Position := 0;
      SourceStream.Size := 12;
      ZDecompressStream2(tempstream, sourcestream, -15);
    finally
      TempStream.Free;
    end;
  end;

  Datasize := Width * Height;  //The header on the dxt files is only 16 bytes long


  AddDDSHeaderToStream(Width, Height, Datasize, DXT5, DestStream, false);
  SourceStream.Position := Dataoffset;
  DestStream.CopyFrom(SourceStream, DataSize);

  //If Full Throttle can quit here
  if Dataoffset = 12 then
  begin
    Result := true;
    exit;
  end;

  //DOTT needs colour space conversion
  DestStream.Position := 0;
  InitImage(Img);
  try
    LoadImageFromStream(DestStream, Img);
    ConvertImage(Img, ifA8R8G8B8); //Convert from DXT block format to normal ARGB 8bpp
    GetImageFormatInfo( img.Format, Info );
    ConvertYCoCgToRGB(Img.Bits, Width * Height, Info.BytesPerPixel); //Convert each pixel colour
    DestStream.Size := 0;
    SaveImageToStream('DDS', DestStream, Img);
    Result := true;
  finally
   FreeImage(Img);
  end;
end;

function TDFExplorerBase.WriteHeaderlessDOTT_DDS_CostumeToStream(SourceStream,
  DestStream: TStream): boolean;
var
  TempStreamJustMXT5: TExplorerMemoryStream;
  HeaderIndex: integer;
begin
  Result:=false;


  SourceStream.Position:=0;

  //Not all DOTT XML costumes have an image inside them but many do
  HeaderIndex := FindFileHeader(SourceStream, 0, SourceStream.Size, 'MXT5');
  if HeaderIndex = -1 then
  begin
    Log('XML doesnt contain costume image (not all of them do). In Full Throttle none of them do!');
    Exit;
  end;


  TempStreamJustMXT5 := TExplorerMemoryStream.Create;
  try
    //Copy it out to a new stream which we can pass to the decoder -
    //it expects a stream thats just a MXT5 texture with no additional header
    SourceStream.Position := HeaderIndex;
    TempStreamJustMXT5.CopyFrom(SourceStream, SourceStream.Size - SourceStream.Position);
    TempStreamJustMXT5.Position := 0;

    if WriteHeaderlessDOTT_DDSToStream(TempStreamJustMXT5, DestStream) = false then
      Exit;

    Result:=true;
  finally
    TempStreamJustMXT5.Free;
  end;
end;

function TDFExplorerBase.WriteHeaderlessFT_chnk_DDSToStream(SourceStream,
  DestStream: TStream): boolean;
var
  HeaderIndex, Width, Height, Datasize: integer;
  TempStream: TMemoryStream;
  DXT: TDXTTYPE;
begin
  result := false;

  if SourceStream.Size < 12 then
  begin
    Log('No DDS image in this chunk - its too small');
    exit;
  end;


  SourceStream.Position:=0;

  //Find the DXT1 or DXT5 header
  HeaderIndex := FindFileHeader(SourceStream, 0, SourceStream.Size, 'DXT5');
  DXT := DXT5;
  if HeaderIndex = -1 then
  begin
    HeaderIndex := FindFileHeader(SourceStream, 0, SourceStream.Size, 'DXT1');
    DXT := DXT1;
    if HeaderIndex = -1 then
    begin
      Exit;
    end;
  end;


  Sourcestream.Position := HeaderIndex + 4;
  SourceStream.Read(Width, 4);
  SourceStream.Read(Height, 4);

  begin
    //Sourcestream.Position := HeaderIndex + 12; //start of compressed data
    TempStream := tmemorystream.Create;
    try
      TempStream.CopyFrom(SourceStream, SourceStream.Size - Sourcestream.Position);
      Tempstream.Position := 0;
      SourceStream.Size := 0;
      ZDecompressStream2(tempstream, sourcestream, -15);
    finally
      TempStream.Free;
    end;
  end;

  Datasize := Width * Height;  //The header on the dxt files is only 16 bytes long

  //Tempstream.Position := 0;
  //SourceStream.Position := 0;
  //TempStream.CopyFrom(SourceStream, SourceStream.Size);
  //TempStream.SaveToFile('c:\users\ben\desktop\testfile');


  AddDDSHeaderToStream(Width, Height, Datasize, DXT, DestStream, false);
  SourceStream.Position :=  0;
  DestStream.CopyFrom(SourceStream, SourceStream.Size);
  DestStream.Position := 0;
  result := true;
end;

function TDFExplorerBase.WriteHeaderlessTexDDSToStream(SourceStream,
  DestStream: TStream): boolean;
var
  TempInt,  FirstCompChunkSize, FirstChunkDecompressedSize, SecondChunkCompSize,
  SecondChunkDecompressedSize: integer;
  Width, Height: word;
  TempStream: TMemoryStream;
  DXTType: TDXTType;
begin
{
  4 bytes "TEX "
  2 bytes Width
  2 bytes Height
  4 bytes Unknown
  4 bytes Compressed size of 1st image
  4 bytes Uncompressed size of 1st image
  4 bytes Compressed size of 2nd image
  4 bytes Uncompressed size of 2nd image
  4 bytes Unknown
  x bytes 1st compressed image
  x bytes 2nd compressed image

  File has a 32 byte header then (usually) 2 zlib compressed images.
  1st image is a smaller version of the second image (mipmap?) - its half the size anyway.

  There isn't always a second image. If this is the case then the first image is used but
  the width and height need halving since the width and height in the header apply to the
  second image.
  Sometimes the second image has a mipmap as part of the data.
  A few files arent compressed. They have no first image and an uncompressed second image.
}

  result := false;
  SourceStream.Position := 0;
  SourceStream.Read(TempInt, 4);
  if TempInt <> 542655828 then //'TEX ' header
  begin
    Log('Couldnt find TEX identifier in headerless dds!');
    exit;
  end;

  SourceStream.Read(Width, 2);
  SourceStream.Read(Height, 2);
  SourceStream.Seek(4, soFromCurrent); //Unknown
  SourceStream.Read(FirstCompChunkSize, 4);
  SourceStream.Read(FirstChunkDecompressedSize, 4);
  SourceStream.Read(SecondChunkCompSize, 4);
  SourceStream.Read(SecondChunkDecompressedSize, 4);
  SourceStream.Seek(4, soFromCurrent); //Unknown

  //Some files dont have a second compressed image
  if SecondChunkCompSize = 0 then //Decompress the first image instead
  begin
    if Width * Height > FirstChunkDecompressedSize then //correct the dimensions
    begin
      Width := Width div 2;
      Height := Height div 2;
    end;
  end
  else //seek to the second compressed image
    SourceStream.Seek(FirstCompChunkSize, soFromCurrent);


  TempStream := TMemoryStream.Create;
  try
    //Have to decompress the stream first - we need to know the size of the data to be
    //able to write the DDS header
    try
      if (SecondChunkCompSize > 0) and (SecondChunkCompSize = SecondChunkDecompressedSize)
      then //Not compressed
        TempStream.CopyFrom(SourceStream, SourceStream.Size - SourceStream.Position)
      else
        ZDecompressStream2(SourceStream, TempStream, -15);
    except on EZDecompressionError do
      begin
        Log('Decompression failed in headerless DDS.');
        exit;
      end;
    end;

    if SecondChunkCompSize = 0 then
      if FirstChunkDecompressedSize <>  TempStream.Size then
        Log('Decompressed size mismatch!');



    //Correct for images with mipmaps - remove them - they sometimes crash the
    //internal dds reader
    if TempStream.Size > (Width * Height) then //DXT5 with mipmap
    begin
      Tempstream.Size := (Width * Height);
      DXTType := DXT5;
    end
    else
    if TempStream.Size < (Width * Height) then //DXT1 with mipmap
    begin
      TempStream.Size := ((Width * Height) div 2);
      DXTType := DXT1;
    end
    else
    begin
      //Log('Unknown DXT type! Assuming DXT5');
      DXTType := DXT5;
    end;

    AddDDSHeaderToStream(Width, Height, TempStream.Size, DXTType, DestStream);
    TempStream.Position := 0;
    DestStream.CopyFrom(TempStream, TempStream.Size);
    Result := true;
  finally
    TempStream.Free;
  end;

end;

function TDFExplorerBase.WriteHeaderlessPsychonautsDDSToStream(PsychoDDS: TPsychonautsDDS;
  SourceStream, DestStream: TStream): boolean;
var
  TextureSize: integer;
  DXTType : TDXTType;
begin
  result := false;

  case PsychoDDS.TextureID of
    0: DXTType := NO_FOURCC;
    //6:  DXTType := DXT5; //??
    9:  DXTType := DXT1;
    10: DXTType := DXT3;
    11: DXTType := DXT5;
    //12: DXTType := 0; //24 bit??
    //14: DXTType := DXT5; //CHECK - 14 special case
    else
    begin
      Log('Texture ID not yet supported ' + inttostr(PsychoDDS.TextureID));
      exit;
    end;
  end;

  SourceStream.Position := PsychoDDS.DataOffset;

  //Just main texture - ignore any mipmaps
  TextureSize := PsychoDDS.MainTextureSize;

  //Parsing textureid 0 is not always correct and very hacky
  if (SourceStream.Size - SourceStream.Position) < TextureSize then
    TextureSize := SourceStream.Size - SourceStream.Position;

  AddDDSHeaderToStream(PsychoDDS.Width, PsychoDDS.Height, TextureSize, DXTType,
    DestStream, PsychoDDS.IsCubemap);

  DestStream.CopyFrom(SourceStream, TextureSize);
  Result := true;
end;

procedure TDFExplorerBase.AddDDSHeaderToStream(Width, Height, DataSize: integer;
  DXTType: TDXTTYPE; DestStream: TStream; IsCubemap: boolean = false);
const
  DDSD_CAPS =                       $00000001;
  DDSD_HEIGHT =                     $00000002;
  DDSD_WIDTH =                      $00000004;
  DDSD_PITCH =                      $00000008;
  DDSD_PIXELFORMAT =                $00001000;
  DDSD_MIPMAPCOUNT =                $00020000;
  DDSD_LINEARSIZE =                 $00080000;
  DDSD_DEPTH =                      $00800000;
  DDPF_ALPHAPIXELS =                $00000001;
  DDPF_FOURCC =                     $00000004;
  DDPF_RGB =                        $00000040;
  DDSCAPS_COMPLEX =                 $00000008;
  DDSCAPS_TEXTURE =                 $00001000;
  DDSCAPS_MIPMAP =                  $00400000;
  DDSCAPS2_CUBEMAP =                $00000200;
  DDSCAPS2_CUBEMAP_POSITIVEX =      $00000400;
  DDSCAPS2_CUBEMAP_NEGATIVEX =      $00000800;
  DDSCAPS2_CUBEMAP_POSITIVEY =      $00001000;
  DDSCAPS2_CUBEMAP_NEGATIVEY =      $00002000;
  DDSCAPS2_CUBEMAP_POSITIVEZ =      $00004000;
  DDSCAPS2_CUBEMAP_NEGATIVEZ =      $00008000;
  DDSCAPS2_VOLUME =                 $00200000;
  DDSMAGIC = 542327876; //'DDS '
  FOURCC_DXT1 = $31545844; // 'DXT1'
  FOURCC_DXT3 = $33545844; // 'DXT3'
  FOURCC_DXT5 = $35545844; // 'DXT5'

type
  TDDPIXELFORMAT = record
    dwSize,
    dwFlags,
    dwFourCC,
    dwRGBBitCount,
    dwRBitMask,
    dwGBitMask,
    dwBBitMask,
    dwRGBAlphaBitMask : Cardinal;
  end;

  TDDCAPS2 = record
    dwCaps1,
    dwCaps2 : Cardinal;
    Reserved : array[0..1] of Cardinal;
  end;

  TDDSURFACEDESC2 = record
    dwSize,
    dwFlags,
    dwHeight,
    dwWidth,
    dwPitchOrLinearSize,
    dwDepth,
    dwMipMapCount : Cardinal;
    dwReserved1 : array[0..10] of Cardinal;
    ddpfPixelFormat : TDDPIXELFORMAT;
    ddsCaps : TDDCAPS2;
    dwReserved2 : Cardinal;
  end;

  TDDSHeader = record
    Magic : Cardinal;
    SurfaceFormat : TDDSURFACEDESC2;
  end;

var
  Header : TDDSHeader;
  TempFourCC: Cardinal;
begin
  FillChar(header, SizeOf(TDDSHeader), 0);
  Header.magic := DDSMAGIC;
  Header.SurfaceFormat.dwSize := 124;
  Header.SurfaceFormat.dwFlags := DDSD_CAPS or DDSD_HEIGHT or DDSD_WIDTH or
                                  DDSD_PIXELFORMAT or DDSD_LINEARSIZE;
  Header.SurfaceFormat.dwHeight := Height;
  Header.SurfaceFormat.dwWidth := Width;
  //Header.SurfaceFormat.dwMipMapCount := 0;
  //Header.SurfaceFormat.dwDepth := 1;
  Header.SurfaceFormat.ddpfPixelFormat.dwSize := 32;

  if DXTType = NO_FOURCC then
  begin
    Header.SurfaceFormat.dwFlags := Header.SurfaceFormat.dwFlags or DDSD_PITCH;
    Header.SurfaceFormat.ddpfPixelFormat.dwFlags := DDPF_RGB or DDPF_ALPHAPIXELS;
    Header.SurfaceFormat.ddpfPixelFormat.dwRGBBitCount := 32;
    Header.SurfaceFormat.ddpfPixelFormat.dwRBitMask := $00FF0000;
    Header.SurfaceFormat.ddpfPixelFormat.dwGBitMask := $0000FF00;
    Header.SurfaceFormat.ddpfPixelFormat.dwBBitMask := $000000FF;
    Header.SurfaceFormat.ddpfPixelFormat.dwRGBAlphaBitMask := $FF000000;
    Header.SurfaceFormat.dwPitchOrLinearSize := Cardinal(Height) *
      (Header.SurfaceFormat.ddpfPixelFormat.dwRGBBitCount div 8) * Cardinal(Width);
  end
  else
  begin
    Header.SurfaceFormat.ddpfPixelFormat.dwFlags := DDPF_FOURCC;
    Header.SurfaceFormat.dwPitchOrLinearSize := Datasize;
  end;



  TempFourCC := 0;
  case DXTType of
    DXT1:      TempFourCC := FOURCC_DXT1;
    DXT3:      TempFourCC := FOURCC_DXT3;
    DXT5:      TempFourCC := FOURCC_DXT5;
    NO_FOURCC: TempFourCC := 0;
  end;


  Header.SurfaceFormat.ddpfPixelFormat.dwFourCC :=  TempFourCC;
  Header.SurfaceFormat.ddsCaps.dwCaps1 := DDSCAPS_TEXTURE {or DDSCAPS_COMPLEX};
  if IsCubeMap=true then
  begin
    Header.SurfaceFormat.ddsCaps.dwCaps1 := Header.SurfaceFormat.ddsCaps.dwCaps1 or
                                             DDSCAPS_COMPLEX;
    Header.SurfaceFormat.ddsCaps.dwCaps2 :=  DDSCAPS2_CUBEMAP or
                                             DDSCAPS2_CUBEMAP_POSITIVEX or
                                             DDSCAPS2_CUBEMAP_NEGATIVEX or
                                             DDSCAPS2_CUBEMAP_POSITIVEY or
                                             DDSCAPS2_CUBEMAP_NEGATIVEY or
                                             DDSCAPS2_CUBEMAP_POSITIVEZ or
                                             DDSCAPS2_CUBEMAP_NEGATIVEZ;
  end;


  DestStream.Position := 0;
  DestStream.Write(header, SizeOf(TDDSHeader));
end;

function TDFExplorerBase.DrawImageGeneric(FileIndex: integer;
  DestBitmap: TBitmap32): boolean;
var
  TempStream: TExplorerMemoryStream;
begin
  result:=true;

  TempStream:=TExplorerMemoryStream.Create;
  try
    DestBitmap.Clear();
    destbitmap.CombineMode:=cmBlend;
    destBitmap.DrawMode:=dmOpaque;
    fBundle.SaveFileToStream(FileIndex, TempStream);
    if DrawImage(TempStream, DestBitmap) = false then
    begin
      Log('Image decode failed! ' + fBundle.FileName[FileIndex]);
      result:=false;
    end;
  finally
    TempStream.Free;
  end;
end;

function TDFExplorerBase.GetFileExtension(Index: integer): string;
begin
  result:=fBundle.FileExtension[Index];
end;

function TDFExplorerBase.GetFileName(Index: integer): string;
begin
  result:=fBundle.FileName[Index];
end;

function TDFExplorerBase.GetFileOffset(Index: integer): int64;
begin
  result:=fBundle.FileOffset[Index];
end;

function TDFExplorerBase.GetFileSize(Index: integer): integer;
begin
  result:=fBundle.FileSize[Index];
end;

function TDFExplorerBase.GetFileType(Index: integer): TFiletype;
begin
  result:=fBundle.FileType[Index];
end;

procedure TDFExplorerBase.Initialise;
begin
  if assigned(FOnDoneLoading) then
    fBundle.OnDoneLoading:=FOnDoneLoading;
  if assigned(FOnDebug) then
    fBundle.OnDebug:=FOnDebug;

  fBundle.ParseFiles;
end;

procedure TDFExplorerBase.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;



function TDFExplorerBase.SaveDDSToFile(FileIndex: integer; DestDir,
  FileName: string; DDSType: TDDSType = DDS_NORMAL): boolean;
var
  TempStream: TExplorerMemoryStream;
  SaveFile: TFileStream;
begin
  result:=false;

  if (FileIndex < 0) or (FileIndex > fBundle.Count) then
  begin
    Log('Invalid file number! Save cancelled.');
    exit;
  end;


  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(FileIndex, TempStream);
    TempStream.Position:=0;

    SaveFile:=tfilestream.Create(IncludeTrailingPathDelimiter(DestDir) + FileName,
      fmOpenWrite or fmCreate);
    try
      case DDSType of
        DDS_NORMAL:
          Result := WriteDDSToStream(Tempstream, SaveFile);
        DDS_HEADERLESS:
          Result := WriteHeaderlessTexDDSToStream(Tempstream, SaveFile);
        DDS_HEADERLESS_PSYCHONAUTS:
          Result := WriteHeaderlessPsychonautsDDSToStream(
            TPPAKManager(fBundle ).PsychoDDS[FileIndex], Tempstream, SaveFile);
        DDS_HEADERLESS_DOTT:
          Result := WriteHeaderlessDOTT_DDSToStream(Tempstream, SaveFile);
        DDS_HEADERLESS_DOTT_COSTUME:
          Result := WriteHeaderlessDOTT_DDS_CostumeToStream(Tempstream, SaveFile);
        DDS_HEADERLESS_FT_CHNK:
          Result := WriteHeaderlessFT_chnk_DDSToStream(TempStream, SaveFile);
      end;
    finally
      SaveFile.Free;
      if Result = false then
        Sysutils.DeleteFile(IncludeTrailingPathDelimiter(DestDir) + FileName);

    end;
  finally
    TempStream.Free;
  end;
end;

procedure TDFExplorerBase.SaveFile(FileNo: integer; DestDir, FileName: string;
  DoLog: boolean = true);
begin
  if DoLog then
    Log(strSavingFile + FileName);

  fBundle.SaveFile(FileNo, DestDir, Filename);
end;

procedure TDFExplorerBase.SaveFiles(DestDir: string);
begin
  fBundle.SaveFiles(DestDir);
end;



procedure TDFExplorerBase.SaveFileToStream(FileNo: integer;
  DestStream: TStream);
begin
  fBundle.SaveFileToStream(FileNo, DestStream);
end;


function TDFExplorerBase.SaveIMCToStream(FileNo: integer;
  DestStream: TStream): boolean;
var
  TempStream: TExplorerMemoryStream;
begin
  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(FileNo, TempStream);
    TempStream.Position:=0;

    result := DecompressIMCToStream(TempStream, DestStream);

  finally
    TempStream.free;
  end;
end;

end.
