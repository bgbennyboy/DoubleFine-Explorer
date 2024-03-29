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

unit uDFExplorer_PAKManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib, uXCompress;

type
  TPAKManager = class (TBundleManager)
  private
    fBigEndian: boolean;
  protected
    fBundle, fDataBundle: TExplorerFileStream;
    fBundleFileName: string;
    function DetectBundle: boolean;  override;
    function GetFilesCount: integer; override;
    function GetFileName(Index: integer): string; override;
    function GetFileSize(Index: integer): integer; override;
    function GetFileOffset(Index: integer): int64; override;
    function GetFileType(Index: integer): TFiletype; override;
    function GetFileExtension(Index: integer): string; override;
    procedure Log(Text: string); override;
    procedure ReadV2Bundle;
    procedure ReadV5Bundle;
    procedure ReadV6Bundle;
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


constructor TPAKManager.Create(ResourceFile: string);
var
  DataBundleNameAndPath: string;
begin
  try
    fBundle:=TExplorerFileStream.Create(ResourceFile);
  except on E: EInvalidFile do
    raise;
  end;

  //Now check if matching .p file is there and if we can open it
  DataBundleNameAndPath := ChangeFileExt(ResourceFile, '.~p');
  if FileExists( DataBundleNameAndPath ) = false then
    raise EInvalidFile.Create('Couldnt find matching .~p bundle');

  //Open the second bundle
  try
    fDataBundle:=TExplorerFileStream.Create(DataBundleNameAndPath);
  except on E: EInvalidFile do
    raise;
  end;


  fBundleFileName:=ExtractFileName(ResourceFile);
  BundleFiles:=TObjectList.Create(true);

  //Load it here just in case XMemcompress used
  XCompress_Load_DLL;

  if DetectBundle = false then
    raise EInvalidFile.Create( strErrInvalidFile );
end;

destructor TPAKManager.Destroy;
begin
  if BundleFiles <> nil then
  begin
    BundleFiles.Free;
    BundleFiles:=nil;
  end;

  if fBundle <> nil then
    fBundle.free;

  if fDataBundle <> nil then
    fDataBundle.free;

  inherited;
end;

function TPAKManager.DetectBundle: boolean;
var
  BlockName: string;
begin
  Result := false;
  BlockName := fBundle.ReadBlockName;

  if BlockName = 'dfpf' then
  begin
    Result := true;
    fBundle.BigEndian := true;
    fDataBundle.BigEndian := true;
    fBigEndian := true;
  end
end;

function TPAKManager.GetFileExtension(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileExtension;
end;

function TPAKManager.GetFileName(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileName;
end;

function TPAKManager.GetFileOffset(Index: integer): int64;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:=0
  else
     result:=TDFFile(BundleFiles.Items[Index]).offset;
end;

function TPAKManager.GetFilesCount: integer;
begin
  if BundleFiles <> nil then
    result:=BundleFiles.Count
  else
    result:=0;
end;

function TPAKManager.GetFileSize(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TDFFile(BundleFiles.Items[Index]).size;
end;

function TPAKManager.GetFileType(Index: integer): TFileType;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ft_Unknown
  else
     result:=TDFFile(BundleFiles.Items[Index]).FileType;
end;

procedure TPAKManager.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;

procedure TPAKManager.ParseFiles;
var
  Version: integer;
begin
 if fBigEndian then //All LE reading auto converted to BE
    Log('Detected as : big endian');


  //Read header
  fBundle.Position      := 4;
  Version               := fBundle.ReadByte; //not dword

  if Version = 2 then
    ReadV2Bundle //Costume quest
  else
  if Version = 5 then
    ReadV5Bundle
  else
  if Version = 6  then
    ReadV6Bundle
  else
  begin
    Log('WARNING: Unknown DFPF version: ' + inttostr(Version));
    if (Version > 5) and (Version <  10) then
      ReadV6Bundle; //Give it a try - probably wont work but...
  end;

end;

procedure TPAKManager.ReadV2Bundle;
var
  FileObject: TDFFile;

  {NameDirSize} NumFiles: integer;

  FileExtensionOffset, NameDirOffset, {JunkDataOffset,} FileRecordsOffset: uint64;

  {Marker1, Marker2, FooterOffset1, FooterOffset2, Unknown, BlankBytes1, BlankBytes2: integer;}

  i, tempint, FileExtensionCount: integer;

  FileExtensions: TStringList;
const
  sizeOfFileRecord: integer = 16;
begin
  fBundle.Position      := 8;

  FileExtensionOffset   := fBundle.ReadQWord;  //Or alignment?   table 1 - type table pointer
  NameDirOffset         := fBundle.ReadQWord;                    //fn table pointer
  FileExtensionCount    := fBundle.ReadDWord;                    //number of types
  fBundle.Seek(4 , sofromcurrent);        //NameDirSize           := fBundle.ReadDWord; //Wrong!           //size of fn table
  numFiles              := fBundle.ReadDWord;                    //file count
  fBundle.Seek(4 , sofromcurrent);        //Marker1               := fBundle.ReadDWordLe;                  //MARKER 23A1CEABh
  fBundle.Seek(4 , sofromcurrent);        //BlankBytes1           := fBundle.ReadDWord;
  fBundle.Seek(4 , sofromcurrent);        //BlankBytes2           := fBundle.ReadDWord;
  fBundle.Seek(8 , sofromcurrent);        //JunkDataOffset        := fBundle.ReadQWord;  //start of extra bytes in .~p file?
  FileRecordsOffset     := fBundle.ReadQWord;                  //p table
  fBundle.Seek(8 , sofromcurrent);        //FooterOffset1         := fBundle.ReadQWord;
  fBundle.Seek(8 , sofromcurrent);        //FooterOffset2         := fBundle.ReadQWord;
  fBundle.Seek(4 , sofromcurrent);        //Unknown               := fBundle.ReadDWord;
  fBundle.Seek(4 , sofromcurrent);        //Marker2               := fBundle.ReadDWordLe;                    //marker again  23A1CEABh



  //Parse files
  for I := 0 to numFiles - 1 do   //16 bytes
  begin
    fBundle.Position  := FileRecordsOffset + (sizeOfFileRecord * i);
    FileObject        := TDFFile.Create;

    FileObject.UnCompressedSize     := (fBundle.ReadDWord shr 9) ;
    fBundle.Seek(1, soFromCurrent);
    FileObject.Size                 := (fBundle.ReadDWord shl 1) shr 10; //Size in the p file
    fBundle.Seek(-2, soFromCurrent);
    FileObject.Offset               := (fBundle.ReadQWord shl 7) shr 34; //read 8 bytes not 4 because we need 30 bits starting at byte 7, bit 7 - so doing shl 7 means we only get 25 bits remaining out of a dword
    fBundle.Seek(-3, soFromCurrent);
    FileObject.NameOffset           := (fBundle.ReadDWord) shr 11;
    fBundle.Seek(-2, soFromCurrent);
    FileObject.FileTypeIndex        := (fBundle.ReadDWord shl 5) shr 25;
    fBundle.Seek(-3, soFromCurrent);
    FileObject.CompressionType      := fBundle.ReadByte and 15;

    case FileObject.CompressionType of
      2: FileObject.Compressed := false;
      4: FileObject.Compressed := true;
    else Log('Unknown compression type! ' + inttostr(FileObject.CompressionType));
    end;


    //Get filename from filenames table
    fBundle.Position    := NameDirOffset + FileObject.NameOffset;
    FileObject.FileName := PChar(fBundle.ReadString(255));


    BundleFiles.Add(FileObject);

    {Log('');
    Log(inttostr(i+1));
    Log(FileObject.FileName);
    Log('Size when decompressed ' + inttostr(FileObject.UnCompressedSize));
    Log('Name offset ' + inttostr(FileObject.NameOffset));
    Log('Size ' + inttostr(FileObject.Size));
    Log('Offset ' + inttostr(FileObject.Offset));
    Log('Filetype index ' + inttostr(FileObject.FileTypeIndex));
    Log('Comp type ' + inttostr(FileObject.CompressionType));}
  end;


  //Parse the 'other data' File Extension table
  FileExtensions := TStringList.Create;
  try
    fBundle.Position := FileExtensionOffset;
    for I := 0 to FileExtensionCount - 1 do
    begin
      TempInt := fBundle.ReadDWord;
      FileExtensions.Add(Trim(fBundle.ReadString( TempInt)));
      fBundle.Seek(12, soFromCurrent); //12 unknown bytes
      //Log(FileExtensions[i]);
    end;


    //Match filetype index and populate FileType
    for I := 0 to BundleFiles.Count -1 do
    begin
       //Add file extension
       TDFFile(BundleFiles[i]).FileExtension :=
        Trim(FileExtensions[TDFFile(BundleFiles[i]).FileTypeIndex]);

       //Add file type
       TDFFile(BundleFiles[i]).FileType := GetFileTypeFromFileExtension(
        TDFFile(BundleFiles[i]).FileExtension,
        Uppercase(ExtractFileExt(TDFFile(BundleFiles[i]).Filename)) );

       if TDFFile(BundleFiles[i]).FileType = ft_Unknown then
        Log('Unknown file type ' + TDFFile(BundleFiles[i]).FileExtension);
    end;

  finally
    FileExtensions.Free;
  end;

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(numFiles);


end;

procedure TPAKManager.ReadV5Bundle;
var
  FileObject: TDFFile;

  {NameDirSize} NumFiles: integer;

  FileExtensionOffset, NameDirOffset, {JunkDataOffset,} FileRecordsOffset: uint64;

  {Marker1, Marker2, FooterOffset1, FooterOffset2, Unknown, BlankBytes1, BlankBytes2: integer;}

  i, tempint, FileExtensionCount: integer;

  FileExtensions: TStringList;
const
  sizeOfFileRecord: integer = 16;
begin
{
Think this is the structure
  Header
  always? 88 blank bytes
  Other data offset that looks like this
    (
      uint32 nameLength;
      char name[nameLength];
      uint32 unknown[3];
    )
  File records
  Name directory
  Blank bytes on end - but sometimes not - eg rgb_stuff
}


  //Read header
  fBundle.Position      := 8;

  FileExtensionOffset   := fBundle.ReadQWord;  //Or alignment?   table 1 - type table pointer
  NameDirOffset         := fBundle.ReadQWord;                    //fn table pointer
  FileExtensionCount    := fBundle.ReadDWord;                    //number of types
  fBundle.Seek(4 , sofromcurrent);        //NameDirSize           := fBundle.ReadDWord; //Wrong!           //size of fn table
  numFiles              := fBundle.ReadDWord;                    //file count
  fBundle.Seek(4 , sofromcurrent);        //Marker1               := fBundle.ReadDWordLe;                  //MARKER 23A1CEABh
  fBundle.Seek(4 , sofromcurrent);        //BlankBytes1           := fBundle.ReadDWord;
  fBundle.Seek(4 , sofromcurrent);        //BlankBytes2           := fBundle.ReadDWord;
  fBundle.Seek(8 , sofromcurrent);        //JunkDataOffset        := fBundle.ReadQWord;  //start of extra bytes in .~p file?
  FileRecordsOffset     := fBundle.ReadQWord;                  //p table
  fBundle.Seek(8 , sofromcurrent);        //FooterOffset1         := fBundle.ReadQWord;
  fBundle.Seek(8 , sofromcurrent);        //FooterOffset2         := fBundle.ReadQWord;
  fBundle.Seek(4 , sofromcurrent);        //Unknown               := fBundle.ReadDWord;
  fBundle.Seek(4 , sofromcurrent);        //Marker2               := fBundle.ReadDWordLe;                    //marker again  23A1CEABh

  {Log(' Version '             + inttostr(Version ) );
  Log(' FileExtensionOffset ' + inttostr( FileExtensionOffset) );
  Log(' NameDirOffset '       + inttostr(NameDirOffset ) );
  Log(' FileExtension count ' + inttostr( FileExtensionCount) );
  Log(' NameDirSize '         + inttostr(NameDirSize ) );
  Log(' numFiles '            + inttostr(numFiles ) );
  Log(' Marker 1 '            + inttostr(Marker1 ) );
  Log(' BlankBytes1 '         + inttostr(BlankBytes1 ) );
  Log(' BlankBytes2 '         + inttostr(BlankBytes2 ) );
  Log(' Junk data offset '    + inttostr(JunkDataOffset ) );
  Log(' FileRecordsOffset '   + inttostr(FileRecordsOffset ) );
  Log(' Footer offset 1 '     + inttostr(FooterOffset1 ) );
  Log(' Footer offset 2 '     + inttostr(FooterOffset2 ) );
  Log(' Unknown '             + inttostr( Unknown) );
  Log(' Marker 2 '            + inttostr( Marker2) );
  Log('');}


  //Parse files
  for I := 0 to numFiles - 1 do   //16 bytes
  begin
    fBundle.Position  := FileRecordsOffset + (sizeOfFileRecord * i);
    FileObject        := TDFFile.Create;

    FileObject.UnCompressedSize     :=  (fBundle.ReadDWord shr 8) ; //fBundle.ReadTriByte;   //when decompressed
    fBundle.Seek(-1, sofromcurrent);
    FileObject.NameOffset           := (fBundle.ReadDWord)shr 11; //(fbundle.ReadTriByte shr 11); specs wrong - from byte 3 not 4
    fBundle.Seek(1, sofromcurrent);
    FileObject.Offset               := fBundle.ReadDWord shr 3;
    fBundle.Seek(-1, soFromCurrent);
    FileObject.Size                 := (fBundle.ReadDWord shl 5) shr 9; //Size in the p file
    fBundle.Seek(-1, soFromCurrent);
    FileObject.FileTypeIndex        := (fBundle.ReadDWord shl 4) shr 24;
      FileObject.FileTypeIndex      := FileObject.FileTypeIndex shr 1; //normalise it
    fBundle.Seek(-3, soFromCurrent);
    FileObject.CompressionType      := fBundle.ReadByte and 15; //Unsure about anding with 15. This field of more use in xbox games where compression will sometimes need XBDecompress. Until we encounter that - just compare compressed vs decompressed sizes when dumping.

    case FileObject.CompressionType of
      4: FileObject.Compressed := false;
      8: FileObject.Compressed := true; //ZLIB
     12: FileObject.Compressed := true; //XMemCompress Xbox
    else Log('Unknown compression type! ' + inttostr(FileObject.CompressionType));
    end;

    //Get filename from filenames table
    fBundle.Position    := NameDirOffset + FileObject.NameOffset;
    FileObject.FileName := PChar(fBundle.ReadString(255));


    BundleFiles.Add(FileObject);

    {Log('');
    Log(inttostr(i+1));
    Log(FileObject.FileName);
    Log('Size when decompressed ' + inttostr(FileObject.UnCompressedSize));
    Log('Name offset ' + inttostr(FileObject.NameOffset));
    Log('Size ' + inttostr(FileObject.Size));
    Log('Offset ' + inttostr(FileObject.Offset));
    Log('Filetype index ' + inttostr(FileObject.FileTypeIndex));
    Log('Comp type ' + inttostr(FileObject.CompressionType));}
  end;


  //Parse the 'other data' File Extension table
  FileExtensions := TStringList.Create;
  try
    fBundle.Position := FileExtensionOffset;
    for I := 0 to FileExtensionCount - 1 do
    begin
      TempInt := fBundle.ReadDWord;
      FileExtensions.Add(Trim(fBundle.ReadString( TempInt)));
      fBundle.Seek(12, soFromCurrent); //12 unknown bytes
      //Log(FileExtensions[i]);
    end;


    //Match filetype index and populate FileType
    for I := 0 to BundleFiles.Count -1 do
    begin
       //Add file extension
       TDFFile(BundleFiles[i]).FileExtension :=
        Trim(FileExtensions[TDFFile(BundleFiles[i]).FileTypeIndex]);

       //Add file type
       TDFFile(BundleFiles[i]).FileType := GetFileTypeFromFileExtension(
        TDFFile(BundleFiles[i]).FileExtension,
        Uppercase(ExtractFileExt(TDFFile(BundleFiles[i]).Filename)) );

       if TDFFile(BundleFiles[i]).FileType = ft_Unknown then
        Log('Unknown file type ' + TDFFile(BundleFiles[i]).FileExtension);

       //Now add file extensions to the files
       //TCaveFile(BundleFiles[i]).FileName := TCaveFile(BundleFiles[i]).FileName + '.' + TCaveFile(BundleFiles[i]).FileExtension;
    end;

  finally
    FileExtensions.Free;
  end;

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(numFiles);
end;

procedure TPAKManager.ReadV6Bundle;
var
  FileObject: TDFFile;

  NameDirSize, NumFiles: integer;

  FileExtensionOffset, NameDirOffset, JunkDataOffset, FileRecordsOffset: uint64;

  Marker1, Marker2, FooterOffset1, FooterOffset2, Unknown, BlankBytes1, BlankBytes2: integer;

  i, tempint, FileExtensionCount, fileflags: integer;

  FileExtensions: TStringList;
const
  sizeOfFileRecord: integer = 16;
begin
  //Read header
  fBundle.Position      := 8;


  FileExtensionOffset   := fBundle.ReadQWord;
  NameDirOffset         := fBundle.ReadQWord;
  FileExtensionCount    := fBundle.ReadDWord;
  NameDirSize           := fBundle.ReadDWord;
  numFiles              := fBundle.ReadDWord;
  {Marker1               := fBundle.ReadDWordLe;                  //MARKER 23A1CEABh
  BlankBytes1           := fBundle.ReadDWord;
  BlankBytes2           := fBundle.ReadDWord;
  JunkDataOffset        := fBundle.ReadQWord;}  //start of extra bytes in .~p file?
  fBundle.Seek(20, soFromCurrent);
  FileRecordsOffset     := fBundle.ReadQWord;                  //p table
  {FooterOffset1         := fBundle.ReadQWord;
  FooterOffset2         := fBundle.ReadQWord;
  Unknown               := fBundle.ReadDWord;
  Marker2               := fBundle.ReadDWordLe;}                    //marker again  23A1CEABh



  {Log(' FileExtensionOffset ' + inttostr( FileExtensionOffset) );
  Log(' NameDirOffset '       + inttostr(NameDirOffset ) );
  Log(' FileExtension count ' + inttostr( FileExtensionCount) );
  Log(' NameDirSize? '         + inttostr(NameDirSize ) );
  Log(' numFiles '            + inttostr(numFiles ) );
  Log(' Marker 1 '            + inttostr(Marker1 ) );
  Log(' BlankBytes1 '         + inttostr(BlankBytes1 ) );
  Log(' BlankBytes2 '         + inttostr(BlankBytes2 ) );
  Log(' Junk data offset '    + inttostr(JunkDataOffset ) );
  Log(' FileRecordsOffset '   + inttostr(FileRecordsOffset ) );
  Log(' Footer offset 1 '     + inttostr(FooterOffset1 ) );
  Log(' Footer offset 2 '     + inttostr(FooterOffset2 ) );
  Log(' Unknown '             + inttostr( Unknown) );
  Log(' Marker 2 '            + inttostr( Marker2) );
  Log(''); }


  //Parse files
  //Data stored in bitfields that arent aligned to bytes
  for I := 0 to numFiles - 1 do
  begin
    //Read dwords and shift around rather than read tribyte because with tribyte bits can fall off the end

    fBundle.Position  := FileRecordsOffset + (sizeOfFileRecord * i);
    FileObject        := TDFFile.Create;

    FileObject.UnCompressedSize     :=  (fBundle.ReadDWord shr 5); //Size when decompressed  - 3 bytes + 5 bits of next byte

    fBundle.Seek(-2, soFromCurrent);
    FileObject.NameOffset           := (fBundle.ReadDWord shl 13) shr 13; //Last 3 bits of byte 4 and next 2 bytes

    fBundle.Seek(2, soFromCurrent);  //Unknown 2 bytes

    FileObject.Offset               := fBundle.ReadDWord shr 1;

    fBundle.Seek(-1, soFromCurrent);
    FileObject.Size                 := (fBundle.ReadDWord shl 7) shr 7;  //Raw size in the p file - uses last bit of byte 11 + next 3 bytes

    FileObject.FileTypeIndex        := fBundle.ReadByte shr 2; //Index in filetype table - first 6 bits

    fBundle.Seek(-1, soFromCurrent);
    FileObject.CompressionType      := Byte(fBundle.ReadByte shl 6) shr 6; //Last 2 bits - have to cast to byte here https://stackoverflow.com/questions/21362455/what-is-the-behaviour-of-shl-and-shr-for-non-register-sized-operands


     //Get filename from filenames table
    fBundle.Position    := NameDirOffset + FileObject.NameOffset;
    FileObject.FileName := PChar(fBundle.ReadString(255));

    case FileObject.CompressionType of
      1: FileObject.Compressed := false;
      2: FileObject.Compressed := true;
    else Log('Unknown compression type! ' + inttostr(FileObject.CompressionType) + ' ' + FileObject.FileName);
    end;


    BundleFiles.Add(FileObject);

    {Log('');
    Log(inttostr(i+1));
    Log('Start offset in file of record info: ' + inttostr(FileRecordsOffset + (sizeOfFileRecord * i)));
    Log(FileObject.FileName);
    Log('Size when decompressed ' + inttostr(FileObject.UnCompressedSize));
    Log('Name offset ' + inttostr(FileObject.NameOffset));
      Log('File flags: ' + inttostr(fileflags));
    Log('Size ' + inttostr(FileObject.Size));
    Log('Offset ' + inttostr(FileObject.Offset));
    Log('Filetype index ' + inttostr(FileObject.FileTypeIndex));
    Log('Comp type ' + inttostr(FileObject.CompressionType));
    Log('');}
  end;


  //Parse the 'other data' File Extension table
  FileExtensions := TStringList.Create;
  try
    fBundle.Position := FileExtensionOffset;
    for I := 0 to FileExtensionCount - 1 do
    begin
      TempInt := fBundle.ReadDWord;
      FileExtensions.Add(Trim(fBundle.ReadString( TempInt)));
      fBundle.Seek(12, soFromCurrent); //12 unknown bytes
      //Log(FileExtensions[i]);
    end;


    //Match filetype index and populate FileType
    for I := 0 to BundleFiles.Count -1 do
    begin
       //Add file extension
       TDFFile(BundleFiles[i]).FileExtension :=
        Trim(FileExtensions[TDFFile(BundleFiles[i]).FileTypeIndex]);

       //Add file type
       TDFFile(BundleFiles[i]).FileType := GetFileTypeFromFileExtension(
        TDFFile(BundleFiles[i]).FileExtension,
        Uppercase(ExtractFileExt(TDFFile(BundleFiles[i]).Filename)) );

       if TDFFile(BundleFiles[i]).FileType = ft_Unknown then
        Log('Unknown file type ' + TDFFile(BundleFiles[i]).FileExtension);
    end;

  finally
    FileExtensions.Free;
  end;

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(numFiles);
end;

procedure TPAKManager.SaveFile(FileNo: integer; DestDir, FileName: string);
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


  SaveFile:=tfilestream.Create(IncludeTrailingPathDelimiter(DestDir) +
    FileName, fmOpenWrite or fmCreate);
  try
    SaveFileToStream(FileNo,SaveFile);
  finally
    SaveFile.Free;
  end;

end;

procedure TPAKManager.SaveFiles(DestDir: string);
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

procedure TPAKManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
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

  fDataBundle.Seek(TDFFile(BundleFiles.Items[FileNo]).Offset, sofrombeginning);

  //if TDFFile(BundleFiles.Items[FileNo]).UncompressedSize <> TDFFile(BundleFiles.Items[FileNo]).Size then
  if TDFFile(BundleFiles.Items[FileNo]).Compressed then
  begin
    TempStream := tmemorystream.Create;
    try
      TempStream.CopyFrom(fDataBundle, TDFFile(BundleFiles.Items[FileNo]).Size);
      //tempstream.SaveToFile('c:\users\ben\desktop\testfile');
      Tempstream.Position := 0;

      //Comp type 12 is Xbox XMemDecompress. Others are ZLib
      if TDFFile(BundleFiles.Items[FileNo]).CompressionType = 12 then
        DecompressXCompress(TempStream, DestStream, TDFFile(BundleFiles.Items[FileNo]).Size, TDFFile(BundleFiles.Items[FileNo]).UnCompressedSize)
      else
        DecompressZLib(TempStream, TDFFile(BundleFiles.Items[FileNo]).UnCompressedSize, DestStream);
    finally
      TempStream.Free;
    end
  end
  else
    DestStream.CopyFrom(fDataBundle, TDFFile(BundleFiles.Items[FileNo]).Size);

  DestStream.Position:=0;
end;

end.
