{
******************************************************
  DoubleFine Explorer
  Copyright (c) 2013 Bennyboy
  Http://quickandeasysoftware.net
******************************************************
}
{
  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License
  as published by the Free Software Foundation; either version 2
  of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
}

unit uDFExplorer_PCKManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib;

//https://github.com/moai/moai-dev/blob/master/src/zl-util/ZLZipFile.cpp
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
    function GetFileOffset(Index: integer): integer; override;
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
    property FileOffset[Index: integer]: integer read GetFileOffset;
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

function TPCKManager.GetFileOffset(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
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
var
  Version: integer;
begin
 if fBigEndian then //All LE reading auto converted to BE
    Log('Detected as : big endian');


  ParsePCKBundle;

end;

procedure TPCKManager.ParsePCKBundle;
var
  FileObject: TDFFile;

  NumFiles, Header, Crc32, CompressedSize, UncompressedSize, SigOrCRC: integer;
  BitFlag, CompressionMethod, FilenameLength, ExtraFieldLength: integer;
  KeepReading: boolean;
  I, J, XORVal: Integer;
  TempStr: string;
const
  StandardHeader: integer = 67305985; //0x01020304
  FileRecordsHeader: integer = 33620740; //0x04030102
  const BIT_HAS_DESCRIPTOR	= 1 shl $03;
begin
	//local file header signature		4 bytes ( 0x04034b50 )
	//version needed to extract			2 bytes
	//general purpose bit flag			2 bytes
	//compression method				2 bytes
	//last mod file time				2 bytes
	//last mod file date				2 bytes
	//crc-32							4 bytes
	//compressed size					4 bytes
	//uncompressed size					4 bytes
	//file name length					2 bytes
	//extra field length				2 bytes
	//file name							( variable size )
	//extra field						( variable size )

	//compressed bytes					( variable size )

  //Contains sequence of Files then the last section is the file records section
  fBundle.Position := 0;
  NumFiles := 0;
  KeepReading := true;
  Header := 0;

  while KeepReading = true do
  begin
    Header := fBundle.ReadDWord; //header
    if Header <> StandardHeader then
    begin
      if Header <> FileRecordsHeader then //Dont alert if its just the start of the records section
        Log('Unknown file header ' + inttostr(Header) + ' at offset ' + inttostr(fBundle.position - 4));

      break;
    end;

    fBundle.Seek(2, soFromCurrent); //version needed to extract
    BitFlag := fBundle.ReadWord;
    CompressionMethod := fBundle.ReadWord;
    fBundle.Seek(4, soFromCurrent); //last mod file and date
    Crc32 := fBundle.ReadDWord;
    CompressedSize := fBundle.ReadDWord;
    UncompressedSize := fBundle.ReadDWord;
    FilenameLength := fBundle.ReadWord;
    ExtraFieldLength := fBundle.ReadWord;

    if CompressedSize <> UncompressedSize then
    begin
      Log('Compressed and uncompressed size differ - check compression. File no ' + inttostr(NumFiles) + ' at offset ' + inttostr(fBundle.Position - 30));
    end;
    if CompressionMethod <> 0 then
    begin
      Log('Compressed method not 0!. File no ' + inttostr(NumFiles) + ' at offset ' + inttostr(fBundle.Position - 30));
    end;
    if FilenameLength <> 0 then
    begin
      Log('Filename length <> 0! File no ' + inttostr(NumFiles) + ' at offset ' + inttostr(fBundle.Position - 30));
      fBundle.Seek(FilenameLength, soFromCurrent);
    end;
    if ExtraFieldLength <> 0 then
    begin
      Log('ExtraField length <> 0! File no ' + inttostr(NumFiles) + ' at offset ' + inttostr(fBundle.Position - 30));
      fBundle.Seek(ExtraFieldLength, soFromCurrent);
    end;

    FileObject := TDFFile.Create;
    FileObject.UncompressedSize := UncompressedSize;
    FileObject.NameOffset := -1;
    FileObject.Offset := fBundle.Position;
    FileObject.Size := CompressedSize;
    FileObject.FileTypeIndex := -1;
    FileObject.CompressionType := CompressionMethod;
    FileObject.Compressed := CompressedSize <> UncompressedSize;
    FileObject.FileExtension := '';
    FileObject.FileName := inttostr(NumFiles + 1);
    FileObject.FileType := ft_Unknown;

    BundleFiles.Add(FileObject);
    inc(NumFiles);
    fBundle.Seek(CompressedSize, soFromCurrent);

    if BitFlag  and BIT_HAS_DESCRIPTOR <> 0 then
    begin
      SigOrCRC := fBundle.ReadDWord;
      //Crc32
      if SigOrCRC = StandardHeader then
        Crc32 := fBundle.ReadDWord
      else
        Crc32 := SigOrCRC;

      fBundle.Seek(8, soFromCurrent); //compressed and uncompressed size again?
    end;
  end;

  //Now there should be the file records section
  if Header <> FileRecordsHeader then
    Log('File records header expected but not found!')
  else
  begin
    //Seek back 4 bytes - so we are at the start of the header again
    fBundle.Seek(-4, soFromCurrent);

    //Parse file records
    for I := 0 to NumFiles- 1 do
    begin
      Header := fBundle.ReadDWord; //header
      if Header <> FileRecordsHeader then
          Log('Unknown file header ' + inttostr(Header) + ' at offset ' + inttostr(fBundle.position - 4));

      fBundle.Seek(24, soFromCurrent); //24 bytes mostly the same as the information thats already with the file crc,date, size, compressed size etc
      FilenameLength := fBundle.ReadDWord;
      fBundle.Seek(10, soFromCurrent); //Unknown
      XORVal := fBundle.ReadByte;
      fBundle.Seek(3, soFromCurrent); //Unknown

      //Its 128 for many files but for others they use the xorval
      if XORVal > 128 then
      else
        XORVal := 128; //$80

       //TDFFile(BundleFiles[i]).Offset := fBundle.Position;

      //Read the filename and decrypt it
      TempStr := PChar(fBundle.ReadString(FilenameLength));
      for J := 1 to Length(TempStr) do
        TempStr[J] := Chr( ord(TempStr[J]) xor XORVal);

      TDFFile(BundleFiles[i]).FileName := TempStr;

      //Now correct the file extension and file type in the record
      Tempstr := ExtractFileExt(TDFFile(BundleFiles[i]).FileName); //Dont want the . on the file extension
      if (length(Tempstr)>0) and (Tempstr[1]='.') then
        delete(Tempstr,1,1);
      TDFFile(BundleFiles[i]).FileExtension := TempStr;

      //Add file type
      TDFFile(BundleFiles[i]).FileType := GetFileTypeFromFileExtension( TDFFile(BundleFiles[i]).FileExtension, Uppercase(ExtractFileExt(TDFFile(BundleFiles[i]).Filename)) );
      if (TDFFile(BundleFiles[i]).FileType = ft_Unknown) and (ExtractFileExt(TDFFile(BundleFiles[i]).FileName) <> '') then
        Log('Unknown file type ' + TDFFile(BundleFiles[i]).FileExtension);

    end;
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

  SaveFile:=tfilestream.Create(IncludeTrailingPathDelimiter(DestDir)  + FileName, fmOpenWrite or fmCreate);
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
    ForceDirectories(extractfilepath(IncludeTrailingPathDelimiter(DestDir) + ExtractPartialPath( TDFFile(BundleFiles.Items[i]).FileName)));
    SaveFile:=TFileStream.Create(IncludeTrailingPathDelimiter(DestDir) +  TDFFile(BundleFiles.Items[i]).FileName , fmOpenWrite or fmCreate);
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
      DecompressZLib(TempStream, TDFFile(BundleFiles.Items[FileNo]).UnCompressedSize, DestStream);
    finally
      TempStream.Free;
    end
  end
  else
    DestStream.CopyFrom(fBundle, TDFFile(BundleFiles.Items[FileNo]).Size);

  DestStream.Position:=0;
end;

end.
