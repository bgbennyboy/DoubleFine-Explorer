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

unit uDFExplorer_PAKManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib;

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
    function GetFileOffset(Index: integer): integer; override;
    function GetFileType(Index: integer): TFiletype; override;
    function GetFileExtension(Index: integer): string; override;
    procedure Log(Text: string); override;
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

function TPAKManager.GetFileOffset(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
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
  FileObject: TDFFile;

  Version,  NameDirSize, NumFiles: integer;

  FileExtensionOffset, NameDirOffset, JunkDataOffset, FileRecordsOffset: uint64;

  FileExtensionCount, Marker1, Marker2, FooterOffset1, FooterOffset2, Unknown,
  BlankBytes1, BlankBytes2, BlankBytes3: integer;

  i, j, tempint: integer;

  FileExtensions: TStringList;
  strTemp: string;
const
  sizeOfFileRecord: integer = 16;
begin
{old
  //Read header
  fBundle.Position := 4;
  Unknown1          := fBundle.ReadDWord;
  Unknown2          := fBundle.ReadDWord;
  OtherDataOffset   := fBundle.ReadDWord;  //Or alignment?   table 1 - type table pointer
  Unknown3          := fBundle.ReadDWord;
  NameDirOffset     := fBundle.ReadDWord;                    //fn table pointer
  Unknown4          := fBundle.ReadDWord;                    //number of types
  NameDirSize       := fBundle.ReadDWord; //Wrong!           //size of fn table
  numFiles          := fBundle.ReadDWord;                    //file count
  Unknown5          := fBundle.ReadDWord;                    //MARKER 23A1CEABh
  BlankBytes1       := fBundle.ReadDWord;
  BlankBytes2       := fBundle.ReadDWord;
  BlankBytes3       := fBundle.ReadDWord;
  JunkDataOffset    := fBundle.ReadDWord;  //start of extra bytes in .~p file?    //16 blank bytes including this
  Unknown6          := fBundle.ReadDWord;
  FileRecordsOffset := fBundle.ReadDWord;                  //p table
  Unknown7          := fBundle.ReadDWord;
  Unknown8          := fBundle.ReadDWord;
  Unknown9          := fBundle.ReadDWord;
  Unknown10         := fBundle.ReadDWord;
  Unknown11         := fBundle.ReadDWord;
  Unknown12         := fBundle.ReadDWord;                    //marker again  23A1CEABh

  Log(' Unknown1 ' + inttostr(Unknown1 ) );
  Log(' Unknown2 ' + inttostr( Unknown2) );
  Log(' OtherDataOffset ' + inttostr( OtherDataOffset) );
  Log(' Unknown3 ' + inttostr( Unknown3) );
  Log(' NameDirOffset ' + inttostr(NameDirOffset ) );
  Log(' Unknown4 ' + inttostr( Unknown4) );
  Log(' NameDirSize ' + inttostr(NameDirSize ) );
  Log(' numFiles ' + inttostr(numFiles ) );
  Log(' Unknown5 ' + inttostr(Unknown5 ) );
  Log(' BlankBytes1 ' + inttostr(BlankBytes1 ) );
  Log(' BlankBytes2 ' + inttostr(BlankBytes2 ) );
  Log(' BlankBytes3 ' + inttostr(BlankBytes3 ) );
  Log(' Junk data offset ' + inttostr(JunkDataOffset ) );
  Log(' Unknown6 ' + inttostr( Unknown6) );
  Log(' FileRecordsOffset ' + inttostr(FileRecordsOffset ) );
  Log(' Unknown7 ' + inttostr(Unknown7 ) );
  Log(' Unknown8 ' + inttostr(Unknown8 ) );
  Log(' Unknown9 ' + inttostr( Unknown9) );
  Log(' Unknown10 ' + inttostr(Unknown10 ) );
  Log(' Unknown11 ' + inttostr( Unknown11) );
  Log(' Unknown12 ' + inttostr( Unknown12) );

  //info size = numfiles shl 4
}
{
dfpf 4
get DUMMY long
get DUMMY long
get DUMMY long  # align?  offset to some data
get DUMMY long
get NAME_OFF long
get DUMMY long
get DUMMY long   is the size in bytes of the NAME_OFF data
get FILES long
the INFO_OFF value is at offset 0x3C   60
}
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



 if fBigEndian then //All LE reading auto converted to BE
    Log('Detected as : big endian');


  //Read header
  fBundle.Position      := 4;
  Version               := fBundle.ReadByte; //not dword man_trivial on the cave has other stuff after byte 1
  fBundle.Seek(3, soFromCurrent);

  if Version <> 5 then //Check version and warn if unknown
    Log('WARNING: Unknown DFPF version: ' + inttostr(Version));

  FileExtensionOffset   := fBundle.ReadQWord;  //Or alignment?   table 1 - type table pointer
  NameDirOffset         := fBundle.ReadQWord;                    //fn table pointer
  FileExtensionCount    := fBundle.ReadDWord;                    //number of types
  NameDirSize           := fBundle.ReadDWord; //Wrong!           //size of fn table
  numFiles              := fBundle.ReadDWord;                    //file count
  Marker1               := fBundle.ReadDWordLe;                  //MARKER 23A1CEABh
  BlankBytes1           := fBundle.ReadDWord;
  BlankBytes2           := fBundle.ReadDWord;
  JunkDataOffset        := fBundle.ReadQWord;  //start of extra bytes in .~p file?
  FileRecordsOffset     := fBundle.ReadQWord;                  //p table
  FooterOffset1         := fBundle.ReadQWord;
  FooterOffset2         := fBundle.ReadQWord;
  Unknown               := fBundle.ReadDWord;
  Marker2               := fBundle.ReadDWordLe;                    //marker again  23A1CEABh

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

    fBundle.Position                := FileRecordsOffset + (sizeOfFileRecord * i);
    FileObject.UnCompressedSize     :=  (fBundle.ReadDWord shr 8) ; //fBundle.ReadTriByte;   //when decompressed
    fBundle.Seek(-1, sofromcurrent);
    FileObject.NameOffset           := (fBundle.ReadDWord)shr 11; //(fbundle.ReadTriByte shr 11); specs wrong - from from byte 3 not 4
    fBundle.Seek(1, sofromcurrent);
    FileObject.Offset               := fBundle.ReadDWord shr 3;
    fBundle.Seek(-1, soFromCurrent);
    FileObject.Size                 := (fBundle.ReadDWord shl 5) shr 9; //Size in the p file
    fBundle.Seek(-1, soFromCurrent);
    FileObject.FileTypeIndex        := (fBundle.ReadDWord shl 4) shr 24;
    if Version = 5 then
      FileObject.FileTypeIndex      := FileObject.FileTypeIndex shr 1; //normalise it
    fBundle.Seek(-3, soFromCurrent);
    FileObject.CompressionType      := fBundle.ReadByte {and 15}; //Unsure about anding with 15. This field of more use in xbox games where compression will sometimes need XBDecompress. Until we encounter that - just compare compessed vs decompressed sizes when dumping.


    //Get filename from filenames table
    fBundle.Position    := NameDirOffset + FileObject.NameOffset;
    FileObject.FileName := PChar(fBundle.ReadString(255));


    BundleFiles.Add(FileObject);

    {Log('');
    Log(inttostr(i+1));
    Log(FileObject.FileName);
    Log('Size when decompressed ' + inttostr(FileObject.UnCompressedSize));
    Log('Name offset ' + inttostr(FileObject.NameOffset));
    Log('Uncomp Size ' + inttostr(FileObject.UncompressedSize));
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
       TDFFile(BundleFiles[i]).FileExtension := Trim(FileExtensions[TDFFile(BundleFiles[i]).FileTypeIndex]);

       //Add file type
       TDFFile(BundleFiles[i]).FileType := GetFileTypeFromFileExtension( TDFFile(BundleFiles[i]).FileExtension, Uppercase(ExtractFileExt(TDFFile(BundleFiles[i]).Filename)) );
       if TDFFile(BundleFiles[i]).FileType = ft_Unknown then Log('Unknown file type ' + TDFFile(BundleFiles[i]).FileExtension);


       //Now add file extensions to the files
       //TCaveFile(BundleFiles[i]).FileName := TCaveFile(BundleFiles[i]).FileName + '.' + TCaveFile(BundleFiles[i]).FileExtension;
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

  Log(strSavingFile + FileName);

  SaveFile:=tfilestream.Create(IncludeTrailingPathDelimiter(DestDir)  + FileName, fmOpenWrite or fmCreate);
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

procedure TPAKManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
var
  Ext: string;
  TempStream: TMemoryStream;
  //Temp: word;
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

  //Temp := fDataBundle.ReadWord;
  //fDataBundle.Seek(-2, soFromCurrent);
  //if Temp = 30938 {78DA Big Endian} then
  if TDFFile(BundleFiles.Items[FileNo]).UncompressedSize <> TDFFile(BundleFiles.Items[FileNo]).Size then  //compressed TODO check with compressed field once I see files compressed with something other than zlib
  begin
    TempStream := tmemorystream.Create;
    try
      TempStream.CopyFrom(fDataBundle, TDFFile(BundleFiles.Items[FileNo]).Size);
      //tempstream.SaveToFile('c:\users\ben\desktop\testfile');
      Tempstream.Position := 0;
      DecompressZLib(TempStream, TDFFile(BundleFiles.Items[FileNo]).UnCompressedSize, DestStream);
      //Log('Decompressed');
    finally
      TempStream.Free;
    end
  end
  else
    DestStream.CopyFrom(fDataBundle, TDFFile(BundleFiles.Items[FileNo]).Size);

  DestStream.Position:=0;
end;

end.
