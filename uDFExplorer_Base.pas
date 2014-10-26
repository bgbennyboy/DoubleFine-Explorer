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

  GR32, ImagingComponents, ZlibEx,

  uDFExplorer_Types, uDFExplorer_BaseBundleManager, uMemReader, uDFExplorer_Funcs,
  uDFExplorer_FSBManager, uDFExplorer_PAKManager, uDFExplorer_PCKManager,
  uDFExplorer_PKGManager, uDFExplorer_PPAKManager;

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
  function GetFileOffset(Index: integer): integer;
  function GetFileType(Index: integer): TFiletype;
  function GetFileExtension(Index: integer): string;
  function DrawImage(MemStream: TMemoryStream; OutImage: TBitmap32): boolean;
  procedure Log(Text: string);
  function WriteDDSToStream(SourceStream, DestStream: TStream): boolean;
  function WriteHeaderlessDDSToStream(SourceStream, DestStream: TStream): boolean;
  procedure AddDDSHeaderToStream(Width, Height, DataSize: integer; DestStream: TStream);
public
  constructor Create(BundleFile: string; Debug: TDebugEvent);
  destructor Destroy; override;
  function DrawImageGeneric(FileIndex: integer; DestBitmap: TBitmap32): boolean;
  function DrawImageDDS(FileIndex: integer; DestBitmap: TBitmap32; HeaderlessDDS: boolean = false): boolean;
  function SaveDDSToFile(FileIndex: integer; DestDir, FileName: string; HeaderlessDDS: boolean = false): boolean;
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
  property FileOffset[Index: integer]: integer read GetFileOffset;
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
    ImgBitmap.LoadFromStream(MemStream);
    if ImgBitmap.Empty then
      Exit;

    OutImage.Assign(ImgBitmap);
    Result := true;
  finally
    ImgBitmap.Free;
  end;
end;

function TDFExplorerBase.DrawImageDDS(FileIndex: integer;
  DestBitmap: TBitmap32; HeaderlessDDS: boolean = false): boolean;
var
  TempStream, DDSStream: TExplorerMemoryStream;
begin
  Result:=false;

  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(FileIndex, TempStream);
    TempStream.Position:=0;

    DDSStream:=TExplorerMemoryStream.Create;
    try
      if HeaderlessDDS then
        WriteHeaderlessDDSToStream(Tempstream, DDSStream)
      else
        WriteDDSToStream(Tempstream, DDSStream);

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
  SearchOffsets: array [0..5] of integer = (0, 36, 40, 68, 144, 180);
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

function TDFExplorerBase.WriteHeaderlessDDSToStream(SourceStream,
  DestStream: TStream): boolean;
var
  TempInt,  FirstCompChunkSize, FirstChunkDecompressedSize, SecondChunkCompSize, SecondChunkDecompressedSize: integer;
  Width, Height: word;
  TempStream: TMemoryStream;
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

  There isn't always a second image. If this is the case then the first image is used but the width and height need halving since the width and height in the header apply to the second image.
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
    //Have to decompress the stream first - we need to know the size of the data to be able to write the DDS header
    try
      if (SecondChunkCompSize > 0) and (SecondChunkCompSize = SecondChunkDecompressedSize) then //Not compressed
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


    //Correct for images with mipmaps - remove them - they sometimes crash the internal dds reader
    if TempStream.Size > (Width * Height) then //DXT5 with mipmap
      Tempstream.Size := (Width * Height);

    if TempStream.Size < (Width * Height) then //DXT1 with mipmap
      TempStream.Size := ((Width * Height) div 2);

    AddDDSHeaderToStream(Width, Height, TempStream.Size, DestStream);
    TempStream.Position := 0;
    DestStream.CopyFrom(TempStream, TempStream.Size);
    Result := true;
  finally
    TempStream.Free;
  end;

end;

procedure TDFExplorerBase.AddDDSHeaderToStream(Width, Height, DataSize: integer;
  DestStream: TStream);
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
  Header.SurfaceFormat.dwFlags := DDSD_CAPS or DDSD_HEIGHT or DDSD_WIDTH or DDSD_PIXELFORMAT or DDSD_LINEARSIZE;
  Header.SurfaceFormat.dwHeight := Height;
  Header.SurfaceFormat.dwWidth := Width;

  Header.SurfaceFormat.dwMipMapCount := 1;

  //Check for mipmaps
  {if Datasize > (Width * Height) then
    if (Width * Height) + ( (Width * Height) div 2)  = Datasize then
        Header.SurfaceFormat.dwMipMapCount := 2;}

  Header.SurfaceFormat.dwDepth := 1;
  Header.SurfaceFormat.dwPitchOrLinearSize := Datasize;
  Header.SurfaceFormat.ddpfPixelFormat.dwSize := 32;
  Header.SurfaceFormat.ddpfPixelFormat.dwFlags := DDPF_FOURCC; // or DDPF_ALPHAPIXELS;
  //Header.SurfaceFormat.ddpfPixelFormat.dwRGBAlphaBitMask := $FF000000;

  if Datasize < ((Width * Height)) then
    TempFourCC := 827611204 //DXT1
  else
    TempFourCC := 894720068; //DXT5

  Header.SurfaceFormat.ddpfPixelFormat.dwFourCC :=  TempFourCC;
  Header.SurfaceFormat.ddsCaps.dwCaps1 := DDSCAPS_TEXTURE;
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

function TDFExplorerBase.GetFileOffset(Index: integer): integer;
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
  FileName: string; HeaderlessDDS: boolean = false): boolean;
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

    SaveFile:=tfilestream.Create(IncludeTrailingPathDelimiter(DestDir)  + FileName, fmOpenWrite or fmCreate);
    try
      if HeaderlessDDS then
        Result := WriteHeaderlessDDSToStream(Tempstream, SaveFile)
      else
        Result := WriteDDSToStream(Tempstream, SaveFile);
    finally
      SaveFile.Free;
    end;
  finally
    TempStream.Free;
  end;
end;

procedure TDFExplorerBase.SaveFile(FileNo: integer; DestDir, FileName: string; DoLog: boolean = true);
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


end.
