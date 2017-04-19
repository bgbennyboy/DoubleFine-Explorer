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

{
  Psychonauts Pc Level pack files *.ppf
  File format seems to have changed slightly in the newer steam and gog releases.
}

unit uDFExplorer_PPAKManager;

interface

uses
  classes, sysutils, Contnrs, forms, math, system.IOUtils,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib;

type
  TPPAKManager = class (TBundleManager)
  private
    fBigEndian: boolean;
  protected
    fBundle: TExplorerFileStream;
    fBundleFileName: string;
    function DetectBundle: boolean;  override;
    function GetFilesCount: integer; override;
    function GetFileName(Index: integer): string; override;
    function GetFileSize(Index: integer): integer; override;
    function GetFileOffset(Index: integer): LongWord; override;
    function GetFileType(Index: integer): TFiletype; override;
    function GetFileExtension(Index: integer): string; override;
    function GetPsychoDDS(Index: integer): TPsychonautsDDS;
    function CalculateMipmapSize(Mipmaps, TextureID, TextureSize: integer): integer;
    function CalculateMainTextureSize(TextureID, Width, Height: integer): integer;
    procedure Log(Text: string); override;
    procedure ParsePPAK;
  public
    BundleFiles: TObjectList;
    constructor Create(ResourceFile: string); override;
    destructor Destroy; override;
    procedure ParseFiles; override;
    procedure SaveFile(FileNo: integer; DestDir, FileName: string); override;
    procedure SaveFileToStream(FileNo: integer; DestStream: TStream); override;
    procedure SaveFiles(DestDir: string); override;
    property Count: integer read GetFilesCount;
    property FileName[Index: integer]: string read GetFileName;
    property FileSize[Index: integer]: integer read GetFileSize;
    property FileOffset[Index: integer]: LongWord read GetFileOffset;
    property FileType[Index: integer]: TFileType read GetFileType;
    property FileExtension[Index: integer]: string read GetFileExtension;
    property PsychoDDS [Index: integer]: TPsychonautsDDS read GetPsychoDDS;
    property BigEndian: boolean read fBigEndian;
  end;

const
    strErrInvalidFile:          string  = 'Not a valid bundle';

implementation

{ TBundleManager }

constructor TPPAKManager.Create(ResourceFile: string);
begin
  try
    fBundle:=TExplorerFileStream.Create(ResourceFile);
  except on E: EInvalidFile do
    raise;
  end;

  fBundleFileName:=ExtractFileName(ResourceFile);
  BundleFiles:=TObjectList.Create(true);

  if DetectBundle = false then
    raise EInvalidFile.Create( strErrInvalidFile );
end;

destructor TPPAKManager.Destroy;
begin
  if BundleFiles <> nil then
  begin
    BundleFiles.Free;
    BundleFiles:=nil;
  end;

  if fBundle <> nil then
    fBundle.free;

  inherited;
end;

function TPPAKManager.DetectBundle: boolean;
var
  BlockHeader: integer;
begin
  Result := false;
  BlockHeader := fBundle.ReadDWord;

  if BlockHeader = 1262571600 then  //PPAK
  begin
    Result := true;
    fBundle.BigEndian := false;
    fBigEndian := false;
  end
end;

function TPPAKManager.GetFileExtension(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileExtension;
end;

function TPPAKManager.GetFileName(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileName;
end;

function TPPAKManager.GetFileOffset(Index: integer): LongWord;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=0
  else
     result:=TDFFile(BundleFiles.Items[Index]).offset;
end;

function TPPAKManager.GetFilesCount: integer;
begin
  if BundleFiles <> nil then
    result:=BundleFiles.Count
  else
    result:=0;
end;

function TPPAKManager.GetFileSize(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TDFFile(BundleFiles.Items[Index]).size;
end;

function TPPAKManager.GetFileType(Index: integer): TFileType;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ft_Unknown
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileType;
end;

function TPPAKManager.GetPsychoDDS(Index: integer): TPsychonautsDDS;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= nil
  else
     result:=TDFFile(BundleFiles.Items[Index]).PsychonautsDDS;
end;

procedure TPPAKManager.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;

procedure TPPAKManager.ParseFiles;
begin
 if fBigEndian then //All LE reading auto converted to BE
    Log('Detected as : big endian');

  ParsePPAK;
end;

function TPPAKManager.CalculateMainTextureSize(TextureID, Width,
  Height: integer): integer;
begin
  result := 0;

  case TextureID of
    0:  result := (Width * Height) * 4;
    6:  result := (Width * Height);
    9:  result := (Width * Height) div 2;
    10: result := (Width * Height);
    11: result := (Width * Height);
    12: result := (Width * Height) * 2;
    14: result := (Width * Height) * 2;
  else
    Log('Unsupported ID in CalculateMainTextureSize: ' + inttostr(TextureID));
    exit;
  end;
end;

function TPPAKManager.CalculateMipmapSize(Mipmaps, TextureID, TextureSize: integer): integer;
var
  MinimumBytes, TempSize, i: integer;
begin
  result := 0;

  case TextureID of
    0:  MinimumBytes := 1;
    6:  MinimumBytes := 16;
    9:  MinimumBytes := 8;
    10: MinimumBytes := 16;
    11: MinimumBytes := 16;
    12: MinimumBytes := 1;
    14: MinimumBytes := 1
  else
    Log('Unsupported ID in CalculateMipmapSize: ' + inttostr(TextureID));
    exit;
  end;

  if Mipmaps < 2 then
    result := 0
  else
  begin
    TempSize := TextureSize;
    for i := 0 to mipmaps -2 do
    begin
      if TempSize div 4 < MinimumBytes then
        inc(result, MinimumBytes)
      else
      begin
        TempSize := TempSize div 4;
        inc(result, TempSize);
      end;
    end;
  end;

end;

procedure TPPAKManager.ParsePPAK;
var
  TotalNumFiles, NumFiles, i, FileSize, StringLength: integer;
  FileObject: TDFFile;
  Unknown1, Unknown2, TextureID, TextureWidth, TextureHeight, TextureNumMipmaps,
  AnimTextureID: integer;
begin
  fBundle.Position:=0;
  if fBundle.ReadBlockName <> 'PPAK' then
  begin
    raise EInvalidFile.Create( strErrInvalidFile );
  end;

  //Annoyingly in some bundles there's an extra 8 bytes in the header and numfiles isnt correct Eg in BBA1.ppf, BBLT.ppf
  //And in those bundles the dds file size sometimes has extra 8/10? bytes at the end of the header before the ' XT1' starts
  //Looks like in these bundles dword at offset 12 is different - not sure what it does though - isnt block size I dont think



  //fBundle.Position := 12;
  TotalNumFiles := fBundle.ReadWord;
  Log('TOTAL NUM FILES: ' + inttostr(TotalNumFiles));
  fBundle.seek(2, sofromcurrent); //?
  NumFiles := fBundle.ReadWord;
  Log('NUM DDS Files ' + inttostr(numfiles));




  for I := 0 to NumFiles -1 do
  begin
    FileObject                 := TDFFile.Create;
    FileObject.Compressed      := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex   := -1;
    FileObject.FileExtension   := '';
    FileObject.Offset          := fBundle.Position;
    FileObject.FileType        := ft_HeaderlessPsychoDDSImage;

    if fBundle.ReadDWord <> 827611168 then //' XT1'
    begin
      Log(' XT1 header missing at ' + inttostr( fBundle.Position - 4) + ' this must be one of the new weird ppf files - exiting.' );
      exit;
      //Log('i here is ' + inttostr(i));
      //FileObject.Free;
      //fBundle.seek(2, sofromcurrent);
      //continue;

      {//Out by 10 bytes?
      fBundle.Seek(6, soFromCurrent);
      if fBundle.ReadDWord <> 827611168 then //' XT1'
      begin
        Log('Moved 6 bytes but still XT1 header missing at ' + inttostr( fBundle.Position - 4) );
        Log('Moved 6 bytes and i here is ' + inttostr(i));
        NumFiles := i;
        break;
      end;}
    end;

    FileSize := fBundle.ReadDWord; //Size of this file excluding the 8 bytes
    FileObject.Size := FileSize + 8; //Size of this file + the 8 bytes we've already read
    FileObject.UncompressedSize := FileObject.Size; //Not compressed
    fBundle.seek(40, sofromcurrent); //?
    StringLength := fBundle.ReadWord;
    FileObject.FileName := PChar(fBundle.ReadString(StringLength)); //Null terminated
    FileObject.FileExtension := ExtractFileExt( FileObject.FileName );

    //Then a 42 byte header
    //Unknown1          := fBundle.ReadWord;
    fBundle.Seek(2,   soFromCurrent); //Unknown 1
    Unknown2          := fBundle.ReadWord;
    TextureID         := fBundle.ReadWord; //DDS texture ID corresponds to different dds types
    fBundle.Seek(10,  soFromCurrent); //??
    TextureWidth      := fBundle.ReadDWord;
    TextureHeight     := fBundle.ReadDWord;
    TextureNumMipmaps := fBundle.ReadDWord;
    fBundle.Seek(4,   soFromCurrent); //?
    AnimTextureID     := fBundle.ReadWord; //Used only if animated DDS
    fBundle.Seek(10,  soFromCurrent); //??

    if (Unknown2 = 0) and (TextureID = 0) then  //Animated DDS with multiple frames of DDS images within this structure
    begin
      Log('Animation found in file ' + FileObject.FileName + ' only the first frame will be viewed/dumped.');
      TextureWidth:=fBundle.ReadDWord;
      TextureHeight:=fBundle.ReadDWord;
      TextureNumMipmaps:=fBundle.ReadDWord;
      fBundle.seek(16, sofromcurrent);

      TextureID := AnimTextureID; // Assign it the proper texture id for parsing below + so later its just treated as a normal dds
      //TODO look at parsemultipledds in Psychonauts Explorer - have each frame as a separate file entry?
    end;

    //Correct the mipmaps for some texture IDs
    if (TextureID = 0)  or (TextureID = 14) then
    begin
      if Pos('fonts', FileObject.FileName) > 0 then //fonts dont need mipmaps correcting
      else
      if (TextureNumMipmaps = 0) or (TextureWidth <> TextureHeight) then
      begin
        case Min(TextureWidth, TextureHeight) of
          512:  TextureNumMipmaps := 10;
          256:  TextureNumMipmaps := 9;
          128:  TextureNumMipmaps := 8;
          64:   TextureNumMipmaps := 7;
          32:   TextureNumMipmaps := 6;
          16:   TextureNumMipmaps := 5;
          8:    TextureNumMipmaps := 4;
          4:    TextureNumMipmaps := 3;
          2:    TextureNumMipmaps := 2;
          1:    TextureNumMipmaps := 1
          else
            TextureNumMipmaps := 1;
        end;
      end;
    end;


    //Store the texture info - for decoding later
    FileObject.PsychonautsDDS := TPsychonautsDDS.Create;
    FileObject.PsychonautsDDS.TextureID := TextureID;
    FileObject.PsychonautsDDS.Width     := TextureWidth;
    FileObject.PsychonautsDDS.Height    := TextureHeight;
    FileObject.PsychonautsDDS.Mipmaps   := TextureNumMipmaps;
    FileObject.PsychonautsDDS.DataOffset := fBundle.Position - FileObject.Offset;
    //FileObject.PsychonautsDDS.MipmapSize := CalculateMipmapSize(TextureNumMipmaps, TextureID, FileObject.Size - FileObject.PsychonautsDDS.DataOffset);
    FileObject.PsychonautsDDS.MainTextureSize := CalculateMainTextureSize(TextureID,
      TextureWidth, TextureHeight);
    FileObject.PsychonautsDDS.IsCubemap := pos('cubemaps', FileObject.FileName) > 0;


    fBundle.Seek(FileObject.Size - (fBundle.Position - FileObject.Offset), soFromCurrent); //FileSize - 42 - StringLength - 44 , soFromCurrent); //Seek past texture data

    BundleFiles.Add(FileObject);
  end;

  //MPAK section
  if fBundle.ReadBlockName <> 'MPAK' then
  begin
    Log('MPAK header not found!');
    exit;
  end;

  NumFiles := fBundle.ReadWord;
  //Log('NUM MPAK Files ' + inttostr(numfiles));

  for I := 0 to NumFiles -1 do
  begin
    FileObject                 := TDFFile.Create;
    FileObject.Compressed      := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex   := -1;
    FileObject.FileExtension   := '';
    FileObject.FileType        := ft_other;

    StringLength := fBundle.ReadWord;
    FileObject.FileName := PChar(fBundle.ReadString(StringLength)); //Null terminated
    FileObject.FileExtension := ExtractFileExt( FileObject.FileName );
    fBundle.Seek(2, sofromcurrent); //??

    FileObject.Size := fBundle.ReadDWord;
    FileObject.Offset := fBundle.Position;
    fBundle.Seek(FileObject.Size, sofromcurrent);

    BundleFiles.Add(FileObject);
  end;

  //Named scripts section
  fBundle.Seek(4, soFromCurrent); //4 extra bytes in newer mPPAK versions??
  NumFiles := fBundle.ReadWord;
  //Log('NUM Named Script Files ' + inttostr(numfiles));

  for I := 0 to NumFiles -1 do
  begin
    FileObject                 := TDFFile.Create;
    FileObject.Compressed      := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex   := -1;
    FileObject.FileExtension   := '';
    FileObject.FileType        := ft_lua;

    StringLength := fBundle.ReadWord;
    FileObject.FileName := PChar(fBundle.ReadString(StringLength)) + '.lua'; //Null terminated
    FileObject.FileExtension := ExtractFileExt( FileObject.FileName );

    FileObject.Size := fBundle.ReadDWord;
    FileObject.Offset := fBundle.Position;
    fBundle.Seek(FileObject.Size, sofromcurrent);

    BundleFiles.Add(FileObject);
  end;

  //Unnamed scripts section  - but now has names in this version! !?"?
  NumFiles := fBundle.ReadWord;
  //Log('NUM Unnamed Script Files (named in newer versions!?)' + inttostr(numfiles));

  for I := 0 to NumFiles -1 do
  begin
    FileObject                 := TDFFile.Create;
    FileObject.Compressed      := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex   := -1;
    FileObject.FileExtension   := '';
    FileObject.FileType        := ft_lua;

    StringLength := fBundle.ReadWord;
    FileObject.FileName := PChar(fBundle.ReadString(StringLength)); //Null terminated
    FileObject.FileExtension := ExtractFileExt( FileObject.FileName );

    FileObject.Size := fBundle.ReadDWord;
    FileObject.Offset := fBundle.Position;
    fBundle.Seek(FileObject.Size, sofromcurrent);

    BundleFiles.Add(FileObject);
  end;

  //Level section
  //Some files dont have this section
  if fBundle.Position >= fBundle.Size then
  begin
    if (assigned(FOnDoneLoading)) then
      FOnDoneLoading(BundleFiles.count);
    exit;
  end;

  FileObject                 := TDFFile.Create;
  FileObject.Compressed      := false;
  FileObject.CompressionType := 0;
  FileObject.FileTypeIndex   := -1;
  FileObject.FileType        := ft_Other;

  FileObject.FileName := TPath.GetFileNameWithoutExtension (fBundleFileName)
    + ' level file.plb';
  FileObject.FileExtension   := '.plb';
  FileObject.Size := fBundle.Size - fBundle.Position;
  FileObject.Offset := fBundle.Position;
  BundleFiles.Add(FileObject);

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(BundleFiles.Count);
end;

procedure TPPAKManager.SaveFile(FileNo: integer; DestDir, FileName: string);
var
  SaveFile: TFileStream;
begin
  if TDFFile(BundleFiles.Items[FileNo]).Size <= 0 then
  begin
    Log(strErrFileSize);
    exit;
  end;

  if (FileNo < 0) or (FileNo > BundleFiles.Count) then
  begin
    Log(strErrFileNo);
    exit;
  end;

  SaveFile:=tfilestream.Create(IncludeTrailingPathDelimiter(DestDir)  + FileName,
    fmOpenWrite or fmCreate);
  try
    SaveFileToStream(FileNo,SaveFile);
  finally
    SaveFile.Free;
  end;

end;

procedure TPPAKManager.SaveFiles(DestDir: string);
var
  i: integer;
  SaveFile: TFileStream;
begin
  for I := 0 to BundleFiles.Count - 1 do
  begin
    ForceDirectories(extractfilepath(IncludeTrailingPathDelimiter(DestDir) +
      ExtractPartialPath( TDFFile(BundleFiles.Items[i]).FileName)));

    SaveFile:=TFileStream.Create(IncludeTrailingPathDelimiter(DestDir) +
      TDFFile(BundleFiles.Items[i]).FileName , fmOpenWrite or fmCreate);
    try
      SaveFileToStream(i, SaveFile);
    finally
      SaveFile.free;
      if Assigned(FOnProgress) then FOnProgress(GetFilesCount -1, i);
      Application.Processmessages;
    end;
  end;

end;

procedure TPPAKManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
var
  Ext: string;
  TempStream: TMemoryStream;
begin
  if TDFFile(BundleFiles.Items[FileNo]).Size <= 0 then
  begin
    Log(strErrFileSize);
    exit;
  end;

  if (FileNo < 0) or (FileNo > BundleFiles.Count) then
  begin
    Log(strErrFileNo);
    exit;
  end;

  Ext:=Uppercase(ExtractFileExt(TDFFile(BundleFiles.Items[FileNo]).FileName));

  fBundle.Seek(TDFFile(BundleFiles.Items[FileNo]).Offset, sofrombeginning);


  if TDFFile(BundleFiles.Items[FileNo]).Compressed then
  begin
    TempStream := tmemorystream.Create;
    try
      TempStream.CopyFrom(fBundle, TDFFile(BundleFiles.Items[FileNo]).Size);
      //tempstream.SaveToFile('c:\users\ben\desktop\testfile');
      Tempstream.Position := 0;
      DecompressZLib(TempStream, TDFFile(BundleFiles.Items[FileNo]).UnCompressedSize,
        DestStream);
    finally
      TempStream.Free;
    end
  end
  else
    DestStream.CopyFrom(fBundle, TDFFile(BundleFiles.Items[FileNo]).Size);

  DestStream.Position:=0;
end;

end.
