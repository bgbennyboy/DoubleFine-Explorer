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
  Used in Psychonauts pc version for music/speech/sfx.
  Xbox version audio is different, its wavebanks, its supported in Psychonauts Explorer.
  TODO - Save raw files still does the decoding. Need to look at base class default parameter RawDump= for this maybe
}
unit uDFExplorer_ISBManager;

interface

uses
  classes, sysutils, contnrs, forms,
  JCLstrings, JCLFileUtils,
  uWaveWriter, uXboxAdpcmDecoder, uFileReader, uMemReader,
  uDFExplorer_BaseBundleManager, uDFExplorer_Types, uDFExplorer_Funcs;

type
  TAudioFormat = (
    PCM,
    OGG,
    XBOX_ADPCM
  );

  TISBAudio = class
    Format: TAudioFormat;
    Channels: integer;
    Samplerate: integer;
  end;

  TISBManager = class (TBundleManager)
  protected
    AudioInfos: TObjectList; //Stores info about each audio file for dumping later
    fMemoryBundle: TExplorerMemoryStream;
    function DetectBundle: boolean;  override;
    function GetFilesCount: integer; override;
    function GetFileName(Index: integer): string; override;
    function GetFileSize(Index: integer): integer; override;
    function GetFileOffset(Index: integer): int64; override;
    function GetFileType(Index: integer): TFiletype; override;
    function GetFileExtension(Index: integer): string; override;
    procedure Log(Text: string); override;
    procedure ParseISBFile;
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
    property FileOffset[Index: integer]: int64 read GetFileOffset;
    property FileType[Index: integer]: TFileType read GetFileType;
    property FileExtension[Index: integer]: string read GetFileExtension;

  end;

const
    strErrInvalidFile:          string  = 'Not a valid bundle';

implementation

constructor TISBManager.Create(ResourceFile: string);
begin
  try
    fBundle:=TExplorerFileStream.Create(ResourceFile);
  except on E: EInvalidFile do
    raise;
  end;

  fBundleFileName := ExtractFileName(ResourceFile);
  BundleFiles := TObjectList.Create(True);
  AudioInfos := TObjectList.Create(True);

  if DetectBundle = false then
    raise EInvalidFile.Create( strErrInvalidFile );
end;

destructor TISBManager.Destroy;
begin
  if BundleFiles <> nil then
  begin
    BundleFiles.Free;
    BundleFiles := nil;
  end;

  if AudioInfos <> nil then
  begin
    AudioInfos.Free;
    AudioInfos := nil;
  end;

  if fMemoryBundle <> nil then
    fMemoryBundle.free;

  if fBundle <> nil then
    fBundle.free;

  inherited;
end;

function TISBManager.DetectBundle: boolean;
begin
  Result := false;

  if fBundle.ReadBlockName = 'RIFF' then
  begin
    fBundle.Position := 8;
    if fBundle.ReadBlockName = 'isbf' then
    begin
      fBundle.BigEndian := false;
      fBigEndian := false;

      //Keep everything in memory - Biggest isb file is 92mb. Dumping is slow and this helps speed it up a little.
      fMemoryBundle := TExplorerMemoryStream.Create;
      fBundle.Position := 0;
      fMemoryBundle.CopyFrom(fBundle, fBundle.Size);
      fMemoryBundle.Position := 0;

      Result := true;
    end;
  end;
end;

function TISBManager.GetFileExtension(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileExtension;
end;

function TISBManager.GetFileName(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileName;
end;

function TISBManager.GetFileOffset(Index: integer): int64;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=0
  else
     result:=TDFFile(BundleFiles.Items[Index]).offset;
end;

function TISBManager.GetFilesCount: integer;
begin
  if BundleFiles <> nil then
    result:=BundleFiles.Count
  else
    result:=0;
end;

function TISBManager.GetFileSize(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TDFFile(BundleFiles.Items[Index]).size;
end;

function TISBManager.GetFileType(Index: integer): TFileType;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ft_Unknown
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileType;
end;

procedure TISBManager.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;

procedure TISBManager.ParseFiles;
begin
 if fBigEndian then //All LE reading auto converted to BE
    Log('Detected as : big endian');

  ParseISBFile;
end;


procedure TISBManager.ParseISBFile;
var
  BlockSize, i, Samplerate, Channels: integer;
  BlockName, FileName, TempExt: string;
  NextChar: Char;
  FileObject: TDFFile;
  AudioObject: TISBAudio;
  TempFormat: TAudioFormat;
begin
  fMemoryBundle.Position := 16; //After 'isbftitle' string
  BlockSize := fMemoryBundle.ReadDWord; //Size of text block
  fMemoryBundle.Position := fMemoryBundle.Position + BlockSize; //Seek past the text block

  TempFormat := XBOX_ADPCM; //Default value. If its pcm or ogg this will get changed below
  Samplerate := 0;
  Channels := 0;
  while fMemoryBundle.Position < fMemoryBundle.Size do
  begin
    BlockName := fMemoryBundle.ReadBlockName;

    if BlockName = 'LIST' then
    begin
      fMemoryBundle.Seek(12, sofromcurrent); //list block size + ''isbftitl'' bytes
      BlockSize := fMemoryBundle.ReadDWord;

      FileName := '';
      for i := 0 to BlockSize - 1 do
      begin
        NextChar := chr(fMemoryBundle.ReadByte);
        if NextChar <> #0 then //Name string has null byte between each character
          FileName := FileName + NextChar;
      end;
    end
    else
    if blockname='sinf' then
    begin
      fMemoryBundle.Seek(12, sofromcurrent);
      Samplerate := fMemoryBundle.ReadDWord;
      fMemoryBundle.Seek(8, sofromcurrent);
    end
    else
    if blockname='chnk' then
    begin
      fMemoryBundle.Seek(4, sofromcurrent);
      Channels := fMemoryBundle.ReadDWord;
    end
    else
    if blockname='cmpi' then
    begin
      fMemoryBundle.Seek(24, sofromcurrent);
      if fMemoryBundle.ReadDWord = 1053609165 then
        TempFormat := PCM;
    end
    else
    if blockname='data' then
    begin
      BlockSize := fMemoryBundle.ReadDWord;
      if BlockSize mod 2 <> 0 then
        BlockSize := BlockSize +1;

      if fMemoryBundle.ReadBlockName='OggS' then
        TempFormat := OGG;

      fMemoryBundle.Seek(-4, sofromcurrent); //Now at start of audio data

      {Some filenames have 'loop' in the file extension eg .aif-loop
       Since the file extension gets stripped when they are dumped this means
       you can have 2 files with the same name eg AsylumExt.aif and AsylumExt.aif-loop
       both will have the same name when dumped. So:
       Delete loop from the file extension and add '-Loop' to the filename.
       }
      TempExt := ExtractFileExt( FileName );
      if stripos('loop', TempExt) > 0 then //It has 'loop' in the file extension.
      begin
        TempExt := StringReplace(TempExt, '-loop', '', [rfIgnoreCase]);
        Filename := PathExtractFileNameNoExt( FileName ) + '-Loop' + TempExt; //Add 'loop' to filename
      end;

      FileObject := TDFFile.Create;
      FileObject.Compressed := false;
      FileObject.FileTypeIndex := -1;
      //FileObject.FileName := FileName;
      FileObject.Offset := fMemoryBundle.Position;
      FileObject.Size := BlockSize;
      FileObject.FileType := ft_Audio;

      {Psychonauts uses .wav .aif. cdda for file extensions inside isb bundles.
        To avoid checks in the main form for different extensions its easiest to
        just change the extension to its actual type here
      }
      if TempFormat = OGG then
      begin
        FileObject.FileExtension := 'ogg';
        FileObject.FileName := ChangeFileExt(FileName, '.ogg');
      end
      else
      begin
        FileObject.FileExtension := 'wav';
        FileObject.FileName := ChangeFileExt(FileName, '.wav');
      end;
      BundleFiles.Add(FileObject);

      AudioObject := TISBAudio.Create;
      AudioObject.Channels := Channels;
      AudioObject.Samplerate := Samplerate;
      AudioObject.Format := TempFormat;
      AudioInfos.Add(AudioObject);

      //Reset the variables
      TempFormat := XBOX_ADPCM; //Want this to be the default value if PCM/OGG dont get set
      Channels := 0; //Not really necessary but helpful for debugging
      Samplerate := 0;

      fMemoryBundle.Seek(BlockSize, sofromcurrent);
    end
    else //Unknown block - seek past
    begin
      blocksize := fMemoryBundle.ReadDWord;
      fMemoryBundle.Seek(blocksize, sofromcurrent)
    end;
  end;

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(BundleFiles.Count);
end;

procedure TISBManager.SaveFile(FileNo: integer; DestDir, FileName: string);
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

  //Log(strSavingFile + FileName);

  SaveFile := tfilestream.Create(IncludeTrailingPathDelimiter(DestDir)  + FileName,
    fmOpenWrite or fmCreate);
  try
    SaveFileToStream(FileNo,SaveFile);
  finally
    SaveFile.Free;
  end;
end;

procedure TISBManager.SaveFiles(DestDir: string);
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

procedure TISBManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
var
  WavStream: TWaveStream;
  TempStream: TMemoryStream;
  XboxAdpcmDecoder: TXboxAdpcmDecoder;
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

  fMemoryBundle.Position := TDFFile(BundleFiles.Items[FileNo]).Offset;

  if TISBAudio(AudioInfos[FileNo]).Format = OGG then
  begin
    DestStream.CopyFrom(fMemoryBundle, TDFFile(BundleFiles.Items[FileNo]).Size);
  end
  else
  if TISBAudio(AudioInfos[FileNo]).Format = PCM then
  begin
    WavStream := TWaveStream.Create(DestStream,
      TISBAudio(AudioInfos[FileNo]).Channels, 16, TISBAudio(AudioInfos[FileNo]).Samplerate );
    try
      WavStream.CopyFrom(fMemoryBundle, TDFFile(BundleFiles.Items[FileNo]).Size);
    finally
      WavStream.Free;
    end;
  end
  else
  if TISBAudio(AudioInfos[FileNo]).Format = XBOX_ADPCM then
  begin
    WavStream := TWaveStream.Create(DestStream,
      TISBAudio(AudioInfos[FileNo]).Channels, 16, TISBAudio(AudioInfos[FileNo]).Samplerate );
    try
      XboxAdpcmDecoder := TXboxAdpcmDecoder.Create(TISBAudio(AudioInfos[FileNo]).Channels);
      try
        XboxAdpcmDecoder.Decode(fMemoryBundle, WavStream, fMemoryBundle.Position, TDFFile(BundleFiles.Items[FileNo]).Size);
      finally
        XboxAdpcmDecoder.Free;
      end;
    finally
      WavStream.Free;
    end;
  end
  else
  begin
    Log('Unknown audio format! Save aborted');
    exit;
  end;

  DestStream.Position:=0;
end;

end.
