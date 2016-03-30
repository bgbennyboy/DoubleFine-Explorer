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

unit uDFExplorer_PCKManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib;

type
  TPCKManager = class (TBundleManager)
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
    procedure ParsePCKBundle;
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


constructor TPCKManager.Create(ResourceFile: string);
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

destructor TPCKManager.Destroy;
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

function TPCKManager.DetectBundle: boolean;
var
  BlockHeader: integer;
begin
  Result := false;
  BlockHeader := fBundle.ReadDWord;

  if BlockHeader = 67305985 then  //0x01020304
  begin
    Result := true;
    fBundle.BigEndian := false;
    fBigEndian := false;
  end
end;

function TPCKManager.GetFileExtension(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileExtension;
end;

function TPCKManager.GetFileName(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileName;
end;

function TPCKManager.GetFileOffset(Index: integer): LongWord;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=0
  else
     result:=TDFFile(BundleFiles.Items[Index]).offset;
end;

function TPCKManager.GetFilesCount: integer;
begin
  if BundleFiles <> nil then
    result:=BundleFiles.Count
  else
    result:=0;
end;

function TPCKManager.GetFileSize(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TDFFile(BundleFiles.Items[Index]).size;
end;

function TPCKManager.GetFileType(Index: integer): TFileType;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ft_Unknown
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileType;
end;

procedure TPCKManager.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;

procedure TPCKManager.ParseFiles;
begin
 if fBigEndian then //All LE reading auto converted to BE
    Log('Detected as : big endian');


  ParsePCKBundle;
end;

{
PCK File Format:
File data with headers
File records
Footer - with file info

Footer at end of file
The last 22 bytes of the file

4 'PACK'
4 0?
2 num files
2 num files again?
4 size of file records section
4 offset of file records section
2 0?

File data for each file

local file header signature		4 bytes ( 0x04034b50 )
version needed to extract			2 bytes
general purpose bit flag			2 bytes
compression method				2 bytes
last mod file time				2 bytes
last mod file date				2 bytes
crc-32							4 bytes
compressed size					4 bytes
uncompressed size					4 bytes
file name length					2 bytes
extra field length				2 bytes
file name							( variable size )
extra field						( variable size )
compressed bytes					( variable size )


File records section

4 0x04030102
2 version needed to extract
2 version needed to extract	(again?)
2 general purpose bit flag
2 compression method
2	last mod file time
2	last mod file date
4 CRC32
4 compressed size
4 uncompressed size
4 filename length
10 unknown
4 offset of file data - 1st byte of this dword is xorval for some filenames
x filename
}


procedure TPCKManager.ParsePCKBundle;
var
  NumFiles, FileRecordsOffset, CompressedSize, UnCompressedSize, FilenameLength,
  ExtraFieldLength, FileDataOffset, I, J, OldPosition: integer;
  XORval: byte;
  FileName, FileExt: string;
  FileType: TFileType;
  FileObject: TDFFile;
const
  FileDataHeader: integer = 67305985; //0x01020304
  FileRecordsHeader: integer = 33620740; //0x04030102
begin
{********************************Footer section********************************}
  fBundle.Position := fBundle.Size - 22;

  if fBundle.ReadBlockName <> 'PACK' then
  begin
    Log('Footer BLOCK not found!');
    raise EInvalidFile.Create( strErrInvalidFile );
  end;

  fBundle.Seek(4, soFromCurrent); //4 0 bytes
  NumFiles := fBundle.ReadWord;
  fBundle.Seek(6, soFromCurrent); //numfiles again and size of file records
  FileRecordsOffset := fBundle.ReadDWord;


{*****************************File Records section*****************************}
  fBundle.Seek(FileRecordsOffset, soFromBeginning);
  for I := 0 to NumFiles - 1 do
  begin
    if fBundle.ReadDWord <> FileRecordsHeader then
    begin
      Log('File records header expected but not found!');
      raise EInvalidFile.Create( strErrInvalidFile );
    end;

    fBundle.Seek(16, soFromCurrent); //Info that we dont need to dump files
    CompressedSize := fBundle.ReadDWord;
    UnCompressedSize := fBundle.ReadDWord;

    if CompressedSize <> UncompressedSize then
      Log('Compressed and uncompressed size differ - check compression. File no ' +
        inttostr(i) + ' at offset ' + inttostr(fBundle.Position - 22));

    FilenameLength := fBundle.ReadDWord;
    fBundle.Seek(10, soFromCurrent); //Unknown
    FileDataOffset := fBundle.ReadDWord;

    //Filename is xor'ed by first byte of the offset dword
    XORVal := FileDataOffset AND $FF; //get first byte of the dword;

    if XORVal > 128 then //Values under 128 are just xor'ed by 128
    else
      XORVal := 128;

    //Decode the filename
    FileName := PChar(fBundle.ReadString(FilenameLength));
    for J := 1 to Length(FileName) do
    begin
      FileName[J] := Chr( ord(FileName[J]) xor XORVal);
    end;


    //Correct the file extension
    FileExt := ExtractFileExt(FileName); //Dont want the . on the file extension
    if (length(FileExt)>0) and (FileExt[1]='.') then
      delete(FileExt,1,1);


    //Correct the file type
    FileType := GetFileTypeFromFileExtension( FileExt, Uppercase(ExtractFileExt(Filename)));
    if (FileType = ft_Unknown) and (ExtractFileExt(FileName) <> '') then
      Log('Unknown file type ' + FileExt);


    //Parse the file data to get the actual offset of the data - the size of the header for each file is variable
    OldPosition := fBundle.Position;
    fBundle.Position := FileDataOffset;
    if fBundle.ReadDWord <> FileDataHeader then
    begin
      Log('File data header expected but not found!');
      raise EInvalidFile.Create( strErrInvalidFile );
    end;
    fBundle.Seek(22, soFromCurrent);
    FilenameLength := fBundle.ReadWord;
    ExtraFieldLength := fBundle.ReadWord;
    fBundle.Seek(FilenameLength, soFromCurrent);
    fBundle.Seek(ExtraFieldLength, soFromCurrent);
    FileDataOffset := fBundle.Position; //Correct the offset
    fBundle.Position := OldPosition;


    //Add a new FileObject
    FileObject := TDFFile.Create;
    FileObject.UncompressedSize := UncompressedSize;
    FileObject.Offset := FileDataOffset;
    FileObject.Size := CompressedSize;
    FileObject.Compressed := CompressedSize <> UncompressedSize;
    FileObject.FileExtension := FileExt;
    FileObject.FileType := FileType;
    FileObject.FileName := FileName;
    FileObject.FileTypeIndex := -1;
    FileObject.CompressionType := 0;
    FileObject.NameOffset := -1;

    BundleFiles.Add(FileObject);
  end;

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(NumFiles);
end;

procedure TPCKManager.SaveFile(FileNo: integer; DestDir, FileName: string);
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

procedure TPCKManager.SaveFiles(DestDir: string);
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

procedure TPCKManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
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
