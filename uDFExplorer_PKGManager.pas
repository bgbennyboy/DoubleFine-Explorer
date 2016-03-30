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
  PKG files from Psychonauts (all pc releases)
}


unit uDFExplorer_PKGManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib;

type
  TPKGManager = class (TBundleManager)
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
    procedure Log(Text: string); override;
    procedure ParsePKGBundle;
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
    property BigEndian: boolean read fBigEndian;
  end;

const
    strErrInvalidFile:          string  = 'Not a valid bundle';

implementation

{ TBundleManager }


constructor TPKGManager.Create(ResourceFile: string);
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

destructor TPKGManager.Destroy;
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

function TPKGManager.DetectBundle: boolean;
var
  BlockHeader: integer;
begin
  Result := false;
  BlockHeader := fBundle.ReadDWord;

  if BlockHeader = 1196118106 then  //ZPKG
  begin
    Result := true;
    fBundle.BigEndian := false;
    fBigEndian := false;
  end
end;

function TPKGManager.GetFileExtension(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileExtension;
end;

function TPKGManager.GetFileName(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileName;
end;

function TPKGManager.GetFileOffset(Index: integer): LongWord;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=0
  else
     result:=TDFFile(BundleFiles.Items[Index]).offset;
end;

function TPKGManager.GetFilesCount: integer;
begin
  if BundleFiles <> nil then
    result:=BundleFiles.Count
  else
    result:=0;
end;

function TPKGManager.GetFileSize(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TDFFile(BundleFiles.Items[Index]).size;
end;

function TPKGManager.GetFileType(Index: integer): TFileType;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ft_Unknown
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileType;
end;

procedure TPKGManager.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;

procedure TPKGManager.ParseFiles;
begin
 if fBigEndian then //All LE reading auto converted to BE
    Log('Detected as : big endian');


  ParsePKGBundle;
end;

procedure TPKGManager.ParsePKGBundle;
var
  NumFiles, SecondDirOffset, NameDirOffset, FileExtDirOffset,
  FileExtensionOffset, FilenameOffset, i, OldPosition: integer;
  FileObject: TDFFile;
  TempName, Prevname: string;
  Unknown1, Unknown2, RecordID, StartIndex, EndIndex: integer;
begin
  fBundle.Position:=0;
  if fBundle.ReadBlockName <> 'ZPKG' then
  begin
    raise EInvalidFile.Create( strErrInvalidFile );
  end;

  //Read Header
  fBundle.seek(4, sofromcurrent); //version
  fBundle.seek(4, sofromcurrent); //first file offset
  NumFiles := fBundle.readdword;     //number of files
  SecondDirOffset := fBundle.readdword;  //offset of second directory structure
  fBundle.seek(4, sofromcurrent); //number of records in second directory
  NameDirOffset := fBundle.readdword;  //name dir offset
  FileExtDirOffset := fBundle.readdword;  //file extension dir offset

  //Parse File Records
  fBundle.Position := 512;

  for I := 0 to NumFiles do
  begin
    fBundle.seek(1, sofromcurrent); //null
    FileExtensionOffset := fBundle.ReadWord; //offset in file ext dir
    fBundle.seek(1, sofromcurrent); //null
    FilenameOffset := fBundle.ReadDWord; //offset in filename dir

    FileObject := TDFFile.Create;
    FileObject.Compressed := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex := -1;

    //Now get filename and filetype
    OldPosition := fBundle.Position;
    fBundle.Position := FileExtensionOffset + FileExtDirOffset;
    FileObject.FileExtension := Trim(PChar(fBundle.ReadString(5)));
    //Need to add the . in
    if FileObject.FileExtension <> '' then
      FileObject.FileExtension := '.' + FileObject.FileExtension;


    fBundle.Position := FilenameOffset + NameDirOffset;
    FileObject.FileName := PChar(fBundle.ReadString(100));

    //Correct the file type
    FileObject.FileType := GetFileTypeFromFileExtension( FileObject.FileExtension);
    if (FileObject.FileType = ft_Unknown) and (FileObject.FileExtension <> '') then
      Log('Unknown file type ' + FileObject.FileExtension);

    fBundle.Position := OldPosition;
    FileObject.Offset := fBundle.ReadDWord;
    FileObject.Size := fBundle.ReadDWord;
    FileObject.UncompressedSize := FileObject.Size; //Not compressed

    BundleFiles.Add(FileObject);
  end;

  //Directory names are broken so just ignore them
  {fBundle.Position:=SecondDirOffset;
  while fBundle.Position < NameDirOffset do
  begin
    TempName := TempName + chr(fBundle.ReadByte);
    if TempName='/' then TempName:=PrevName + '/';

    fBundle.Seek(1, SoFromCurrent); //null
    Unknown1:=fBundle.ReadWord;  //1 and 2 = if not nil = index of the end of this dir name? Eg 'sayline heads' starts on entry 257 in the dir table, Unknown1=269 and sayline heads is complete on entry 269 in the dir table.
    Unknown2:=fBundle.ReadWord;  //But..not always!?!?!?
    RecordID:=fBundle.ReadWord;
    StartIndex:=fBundle.ReadWord;
    EndIndex:=fBundle.ReadWord;

    Log('Unknown1: ' + inttostr(Unknown1) + ' Unknown2: ' + inttostr(Unknown2) + ' Start: ' + inttostr(StartIndex) + '  End: ' + inttostr(EndIndex) + ' ' + TempName);
    if (Startindex <> 0) or (EndIndex <> 0) then
    begin
      for I := Startindex to EndIndex -1 do
        TDFFile(BundleFiles[i]).FileName := TempName + '/' + TDFFile(BundleFiles[i]).FileName;

      PrevName:=TempName;
      TempName:='';
    end;

  end;}


  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(NumFiles);
end;

procedure TPKGManager.SaveFile(FileNo: integer; DestDir, FileName: string);
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

procedure TPKGManager.SaveFiles(DestDir: string);
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

procedure TPKGManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
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
