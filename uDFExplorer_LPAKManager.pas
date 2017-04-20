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
  Used in DOTT Remastered - same format as used in MI Special Editions
}

unit uDFExplorer_LPAKManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib;

type
  TLPAKManager = class (TBundleManager)
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
  public
    BundleFiles: TObjectList;
    constructor Create(ResourceFile: string); override;
    destructor Destroy; override;
    procedure ParseFiles; override;
    procedure ParseFilesV1;
    procedure ParseFilesFullThrottle;
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


constructor TLPAKManager.Create(ResourceFile: string);
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

destructor TLPAKManager.Destroy;
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

function TLPAKManager.DetectBundle: boolean;
var
  Blockname: string;
begin
  Result := false;
  BlockName := fBundle.ReadBlockName;

  if BlockName = 'KAPL' then
  begin
    Result := true;
    fBundle.BigEndian := false;
    fBigEndian := false;
  end
  else
  if BlockName = 'LPAK' then
  begin
    Result := true;
    fBundle.BigEndian := true;
    fBigEndian := true;
  end;

end;

function TLPAKManager.GetFileExtension(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileExtension;
end;

function TLPAKManager.GetFileName(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileName;
end;

function TLPAKManager.GetFileOffset(Index: integer): LongWord;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=0
  else
     result:=TDFFile(BundleFiles.Items[Index]).offset;
end;

function TLPAKManager.GetFilesCount: integer;
begin
  if BundleFiles <> nil then
    result:=BundleFiles.Count
  else
    result:=0;
end;

function TLPAKManager.GetFileSize(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TDFFile(BundleFiles.Items[Index]).size;
end;

function TLPAKManager.GetFileType(Index: integer): TFileType;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ft_Unknown
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileType;
end;

procedure TLPAKManager.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;



procedure TLPAKManager.ParseFiles;
var
  version: word;
begin
  fBundle.Position := 6;
  version := fBundle.readword;
  if version >= 16320 then
    ParseFilesFullThrottle
  else
    ParseFilesV1;
end;

procedure TLPAKManager.ParseFilesV1; //Pre Full Throttle
var
  startOfFileEntries, startOfFileNames, sizeOfIndex, sizeOfFileEntries, sizeOfFileNames,
  sizeOfData: integer;
  startOfData: cardinal;
  numFiles, i, {nameOffs,} currNameOffset: integer;
  FileExt, FileName: string;
  FileObject: TDFFile;
  FileType: TFileType;
const
  sizeOfFileRecord: integer = 20;
begin
{	PakHeader	= record
    DWORD magic;                (* KAPL -> "LPAK" *)
    DWORD version;
    DWORD startOfIndex;         (* -> 1 DWORD per file *)
    DWORD startOfFileEntries;   (* -> 5 DWORD per file *)
    DWORD startOfFileNames;     (* zero-terminated string *)
    DWORD startOfData;
    DWORD sizeOfIndex;
    DWORD sizeOfFileEntries;
    DWORD sizeOfFileNames;
    DWORD sizeOfData;
 end;
	PakFileEntry	= record
    DWORD fileDataPos;          (* + startOfData *)
    DWORD fileNamePos;          (* + startOfFileNames *)
    DWORD dataSize;
    DWORD dataSize2;            (* real size? (always =dataSize) *)
    DWORD compressed;           (* compressed? (always 0) *)
 end;
 PakFileEntry	=	PakFileEntry;}

 if fBigEndian then  //All LE reading auto converted to BE
    Log('Detected as : big endian');


  //Read header
  fBundle.Position := 12;
  startOfFileEntries := fBundle.ReadDWord;
  startOfFileNames   := fBundle.ReadDWord;
  startOfData        := fBundle.ReadDWord;
  sizeOfIndex        := fBundle.ReadDWord;
  sizeOfFileEntries  := fBundle.ReadDWord;
  sizeOfFileNames    := fBundle.ReadDWord;
  sizeOfData         := fBundle.ReadDWord;

  numFiles :=  sizeOfFileEntries div sizeOfFileRecord;

  currNameOffset := 0;

  //Parse files
  for I := 0 to numFiles - 1 do
  begin
    fBundle.Position  := startOfFileEntries + (sizeOfFileRecord * i);
    FileObject        := TDFFile.Create;
    FileObject.Offset := fBundle.ReadDWord + startOfData;
    //nameOffs          := fBundle.ReadDWord;
    fBundle.Seek(4, soFromCurrent); //Past nameOffs
    FileObject.Size   := fBundle.ReadDWord;
    fBundle.Seek(4, soFromCurrent); // Compressed size?
    if fBundle.ReadDWord <> 0 then
    begin
      Log('Compressed file found in file ' +  inttostr(i) + ' at offset ' +
        inttostr(FileObject.Offset) + ' hurry up and add support for this!');
      FileObject.Compressed := true;
    end;

    //Get filename from filenames table
    //In MI2SE - nameOffs is broken - so just ignore it - luckily filenames are stored
    //in the same order as the entries in the file records
    fBundle.Position    := startOfFileNames + currNameOffset;
    FileName := PChar(fBundle.ReadString(255));
    inc(currNameOffset, length(FileName) + 1); //+1 because each filename is null terminated
    FileObject.FileName := FileName;

    //Correct the file extension
    FileExt := ExtractFileExt(FileName); //Dont want the . on the file extension
    if (length(FileExt)>0) and (FileExt[1]='.') then
      delete(FileExt,1,1);

    FileObject.FileExtension := FileExt;


    //Correct the file type
    FileType := GetFileTypeFromFileExtension( FileExt, Uppercase(ExtractFileExt(Filename)));
    //if (FileType = ft_Unknown) and (ExtractFileExt(FileName) <> '') then
    //  Log('Unknown file type ' + FileExt);

    FileObject.FileType := FileType;

    BundleFiles.Add(FileObject);
  end;


  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(numFiles);
end;

procedure TLPAKManager.ParseFilesFullThrottle;
var
  startOfFileEntries, startOfFileNames, sizeOfIndex, sizeOfFileEntries, sizeOfFileNames,
  sizeOfData: integer;
  startOfData: cardinal;
  numFiles, i, currNameOffset: integer;
  FileExt, FileName: string;
  FileObject: TDFFile;
  FileType: TFileType;
const
  sizeOfFileRecord: integer = 24; //4 bytes bigger than previously
begin
{
  Tweaked format - file records are now where index entries were, file record size larger and size field moved

  header
  file records    6 dwords per file
  Index entries	  1 dword per file
  File names
  File data


  Header:
  4	KAPL
  4	Version? BE?
  4	startOfFileEntries
  4	startOfIndex
  4	startOfFileNames
  4	startOfData
  4	sizeOfIndex
  4	sizeOfFileEntries
  4	sizeOfFileNames
  4	sizeOfData
  8	unknown
  }

 if fBigEndian then  //All LE reading auto converted to BE
    Log('Detected as : big endian');


  //Read header
  fBundle.Position := 8;
  startOfFileEntries := fBundle.ReadDWord;
  fBundle.Seek(4, soFromCurrent); //Past startOfIndex
  startOfFileNames   := fBundle.ReadDWord;
  startOfData        := fBundle.ReadDWord;
  sizeOfIndex        := fBundle.ReadDWord;
  sizeOfFileEntries  := fBundle.ReadDWord;
  sizeOfFileNames    := fBundle.ReadDWord;
  sizeOfData         := fBundle.ReadDWord;

  numFiles :=  sizeOfFileEntries div sizeOfFileRecord;

  currNameOffset := 0;

  //Parse files
  for I := 0 to numFiles - 1 do
  begin
    fBundle.Position  := startOfFileEntries + (sizeOfFileRecord * i);
    FileObject        := TDFFile.Create;
    FileObject.Offset := fBundle.ReadDWord + startOfData;
    fBundle.Seek(8, soFromCurrent); //Past nameOffs and 4 bytes that was size in old format
    FileObject.Size   := fBundle.ReadDWord;
    if fBundle.ReadDWord <> FileObject.Size then //If size and 'compressed size' differ
    begin
      Log('Compressed file found in file ' +  inttostr(i) + ' at offset ' +
        inttostr(FileObject.Offset) + ' hurry up and add support for this!');
      FileObject.Compressed := true;
    end;

    //Get filename from filenames table
    fBundle.Position    := startOfFileNames + currNameOffset;
    FileName := PChar(fBundle.ReadString(255));
    inc(currNameOffset, length(FileName) + 1); //+1 because each filename is null terminated
    FileObject.FileName := FileName;

    //Correct the file extension
    FileExt := ExtractFileExt(FileName); //Dont want the . on the file extension
    if (length(FileExt)>0) and (FileExt[1]='.') then
      delete(FileExt,1,1);

    FileObject.FileExtension := FileExt;


    //Correct the file type
    FileType := GetFileTypeFromFileExtension( FileExt, Uppercase(ExtractFileExt(Filename)));


    //if (FileType = ft_Unknown) and (ExtractFileExt(FileName) <> '') then
    //  Log('Unknown file type ' + FileExt);

    FileObject.FileType := FileType;

    BundleFiles.Add(FileObject);
  end;


  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(numFiles);
end;

procedure TLPAKManager.SaveFile(FileNo: integer; DestDir, FileName: string);
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

procedure TLPAKManager.SaveFiles(DestDir: string);
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

procedure TLPAKManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
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

  fBundle.Position := TDFFile(BundleFiles.Items[FileNo]).Offset;

  //TEMPORARY HACK FOR DECOMPRESSING TEX TEXTURES*************************************************************************
  {if TDFFile(BundleFiles.Items[FileNo]).FileExtension = 'tex' then
  begin
    TDFFile(BundleFiles.Items[FileNo]).Compressed := true;
    fBundle.Seek(16, soFromCurrent);
    TDFFile(BundleFiles.Items[FileNo]).UncompressedSize := fBundle.ReadDWord;
    fBundle.Seek(12, soFromCurrent);
  end;}
  //***********************************************************************************************************************


  //if TDFFile(BundleFiles.Items[FileNo]).UncompressedSize <> TDFFile(BundleFiles.Items[FileNo]).Size then
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
