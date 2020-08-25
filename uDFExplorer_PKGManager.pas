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
    function GetFileOffset(Index: integer): int64; override;
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
    property FileOffset[Index: integer]: int64 read GetFileOffset;
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

function TPKGManager.GetFileOffset(Index: integer): int64;
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
  NumFiles, NumDirs, FolderDirOffset, NameDirOffset, FileExtDirOffset,
  FileExtensionOffset, FilenameOffset, i, j, OldPosition, ReturnPos1,
  ReturnPos2, StartIndex, EndIndex, ThisID: integer;
  FileObject: TDFFile;
  CurrName: string;
  Letter: char;
  ReturnNames, PathNames: TStringList;
  ReturnIDs, PathIDsStart, PathIDsEnd: array of integer;
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
  FolderDirOffset := fBundle.readdword;  //offset of folder directory
  NumDirs := fBundle.readdword; //number of records in folder directory
  NameDirOffset := fBundle.readdword;  //name dir offset
  FileExtDirOffset := fBundle.readdword;  //file extension dir offset

  //Parse File Records
  fBundle.Position := 512;

  for I := 0 to NumFiles -1 do
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
    FileObject.FileName := PChar(fBundle.ReadString(100)) + FileObject.FileExtension;

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

  //Now parse the folder Dir. Its 12 bytes per record
  //Algorithm by Watto https://github.com/bgbennyboy/DoubleFine-Explorer/issues/4
  fBundle.Position := FolderDirOffset;
  SetLength(ReturnIDs, NumDirs);
  CurrName := '';

  ReturnNames := TStringList.Create;
  PathNames := TStringList.Create;
  try
    for i := 0 to NumDirs -1 do
    begin
      Letter := chr(fBundle.ReadByte); //One letter of a dir string
      fBundle.Seek(1, soFromCurrent);  //Null byte after the letter

      ReturnPos1 := fBundle.ReadWord;
      if ReturnPos1 <> 0 then
      begin
        ReturnNames.Add(CurrName);
        ReturnIDs[ ReturnNames.Count -1 ] := returnPos1;
      end;

      ReturnPos2 := fBundle.ReadWord;
      if ReturnPos2 <> 0 then
      begin
        ReturnNames.Add(CurrName);
        ReturnIDs[ ReturnNames.Count -1 ] := returnPos2;
      end;

      CurrName := CurrName + Letter;  //CurrName contains the dir string we are building
      fBundle.Seek(2, soFromCurrent); //2 bytes - Character ID (incremental from 1)
      StartIndex := fBundle.ReadWord; //2 bytes - First File ID in this Folder
      EndIndex := fBundle.ReadWord;   //2 bytes- Last File ID in this Folder

      if (StartIndex <> 0) and (EndIndex <> 0) then
      begin
        PathNames.Add(CurrName);
        SetLength(PathIDsStart, PathNames.Count); //messy way of doing this - todo have array of records instead
        SetLength(PathIDsEnd, PathNames.Count);
        PathIDsStart[PathNames.Count-1] := StartIndex;
        PathIDsEnd[PathNames.Count-1] := EndIndex;
      end;

      //Process the returns now
      ThisID := i + 1;
      for j := 0 to  ReturnNames.Count -1 do
      begin
        if ReturnIDs[j] = thisID then //Found one
        begin
          currName := ReturnNames.Strings[j];

          //Shuffle the return arrays to remove this entry
          if j <>  ReturnNames.Count -1 then
          begin
            returnIDs[j] := returnIDs[ ReturnNames.Count -1];
            returnNames[j] := returnNames[ ReturnNames.Count -1];
          end;
        end;
      end;
    end;

    //Sanitise the directory strings
    for i := 0 to pathNames.Count -1 do
    begin
      PathNames[i] := IncludeTrailingPathDelimiter(PathNames[i]);
      PathNames[i] := StringReplace(PathNames[i], '/', '\', [rfReplaceAll])
    end;

    //Match the dir string to each file
    for i := 0 to PathNames.Count -1 do
    begin
      //Get each folder string, then loop through the path IDs associated with it and append the dir to each name
      for j := PathIDsStart[i]-1 to PathIDsEnd[i]-1 do //-1 because pathids start from 1 and our list starts from 0
        TDFFile(BundleFiles[j]).FileName := pathNames[i] + TDFFile(BundleFiles[j]).FileName;
    end;

  finally
    ReturnNames.Free;
    PathNames.Free;
  end;

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(NumFiles);
end;

procedure TPKGManager.SaveFile(FileNo: integer; DestDir, FileName: string);
var
  SaveFile: TFileStream;
begin
  if TDFFile(BundleFiles.Items[FileNo]).Size <= 0 then
  begin
    Log(strErrFileSize + FileName);
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
    Log(strErrFileSize + TDFFile(BundleFiles.Items[FileNo]).FileName);
    exit;
  end;

  if (FileNo < 0) or (FileNo > BundleFiles.Count) then
  begin
    Log(strErrFileNo);
    exit;
  end;

  Ext:=Uppercase(ExtractFileExt(TDFFile(BundleFiles.Items[FileNo]).FileName));

  fBundle.Position := TDFFile(BundleFiles.Items[FileNo]).Offset;


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
