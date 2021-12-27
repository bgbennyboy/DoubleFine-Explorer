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
  File format seems to have changed in the newer steam and gog releases.
  UNFINISHED
}

unit uDFExplorer_PPAKManager;

interface

uses
  classes, sysutils, Contnrs, forms, math, system.IOUtils,
  uDFExplorer_BaseBundleManager, uFileReader, uMemReader, uDFExplorer_Types,
  uDFExplorer_Funcs, uZlib,
  RTTI;

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
    function GetFileOffset(Index: integer): int64; override;
    function GetFileType(Index: integer): TFiletype; override;
    function GetFileExtension(Index: integer): string; override;
    function GetPsychoDDS(Index: integer): TPsychonautsDDS;
    //function OLDCalculateMipmapSize(Mipmaps, TextureID, TextureSize: integer): integer;
    //function OLDCalculateMainTextureSize(TextureID, Width, Height: integer): integer;
    function CalculateIndividualTextureSize(TextureFormat: TDDSTextureFormat; Width, Height: integer): integer;
    function CalculateFullTextureSize(Mipmaps, Width, Height: integer; TextureFormat: TDDSTextureFormat): integer;
    procedure Log(Text: string); override;
    //procedure ParsePPAK_OLD_ATTEMPT;
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
    property FileOffset[Index: integer]: int64 read GetFileOffset;
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

function TPPAKManager.GetFileOffset(Index: integer): int64;
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

//New format RE'ed by John Peel https://github.com/JohnPeel/ppf/wiki/PPF-File-Format
procedure TPPAKManager.ParsePPAK;
var
  BundleVersion, LanguageID, LanguageSize, TextureCount, i, j, TextureSize,
  Path_ptr, Anim_ptr, PathLength, AnimFrameCount, CalculatedTextureSize,
  TextureWidth, TextureHeight, TextureNumMipmaps, Has_Palette, ResourceCount,
  TempWidth, TempHeight, ScriptsVersion, TextureDataStart: integer;
  TextureFormat: TDDSTextureFormat;
  TextureType: TPsychoTextureType;
  FileObject: TDFFile;
  LanguageHeader: word;
begin
  //Initialise these here to stop compiler warnings. Todo refactor this procedure.
  TextureType := TPsychoTextureType(0);
  TextureFormat := TDDSTextureFormat(0);
  TextureWidth  := 0;
  TextureHeight := 0;
  TextureNumMipmaps := 0;
  TextureDataStart := 0;

  fBundle.Position:= 0;

  if fBundle.ReadBlockName <> 'PPAK' then
  begin
    raise EInvalidFile.Create( strErrInvalidFile );
  end;

  //Version section marker 0xFDFD
  if fBundle.ReadWord() = $FDFD then
    BundleVersion := fBundle.ReadWord() //1
  else
    fBundle.Seek(-2, soFromCurrent); //If identifier not there this whole section doesnt exist

  {Language section marker 0xFFFF
   If languages block is present then there's often multiple language blocks each with multiple textures eg in BBA1.ppf.
   No counter for how many language blocks there are so just keep repeating until we dont get a 0xFFFF language header - meaning we are then onto the MPAK section.}
  LanguageHeader := 0;
  repeat
    LanguageHeader := fBundle.ReadWord();
    if LanguageHeader = $FFFF then
    begin
      LanguageID := fBundle.ReadWord();
      LanguageSize := fBundle.ReadDWord();
    end
    else
      fBundle.Seek(-2, soFromCurrent); //If identifier not there this whole section doesnt exist

    TextureCount := fBundle.ReadWord();

    //Log(IntToStr(TextureCount));
    //Log('Bundle pos before textures' + inttostr(fBundle.Position));

    for i := 0 to TextureCount -1 do
    begin
      FileObject                 := TDFFile.Create;
      FileObject.Compressed      := false;
      FileObject.CompressionType := 0;
      FileObject.FileTypeIndex   := -1;
      FileObject.FileExtension   := '';
      FileObject.Offset          := fBundle.Position;
      FileObject.FileType        := ft_HeaderlessPsychoDDSImage;

      if BundleVersion = 1 then
      begin
        if fBundle.ReadDWord <> $31545820 then  //' XT1' identifier
          raise EInvalidFile.Create( 'XT1 header expected but not found!' );

        TextureSize := fBundle.ReadDWord;
        FileObject.Size := TextureSize;
      end
      else
        Log('WARNING bundle version 0 so texturesize + fileobjectsize potentially not set!*****************');

      fBundle.Seek(12, soFromCurrent); // element_id, texture_handle, palette_handle
      Path_ptr := fBundle.ReadDWord;
      Anim_ptr := fBundle.ReadDWord;
      fBundle.Seek(20, soFromCurrent); // density, visual_importance, memory_importance, unknown0, flags

      //If there's a path
      if Path_ptr <> 0 then
      begin
        PathLength := fBundle.ReadWord;
        FileObject.FileName := PChar(fBundle.ReadString(PathLength)); //Null terminated
        FileObject.FileExtension := ExtractFileExt( FileObject.FileName );
      end;

      //If its an animation
      if Anim_ptr <> 0 then
      begin
        AnimFrameCount := fBundle.ReadDWord;
        fBundle.Seek(24, soFromCurrent); //Rest of anim info
      end
      else
        AnimFrameCount := 1;

      if AnimFrameCount = 0 then
      begin
        Log('Anim frame count is 0!');
        raise EInvalidFile.Create( strErrInvalidFile );
        exit;
      end;

      //Multiple animation frames means we have to parse them all. First file in common.ppf for example
      for j := 0 to AnimFrameCount -1 do
      begin
        //Now at texture structure
        fBundle.Seek(4, soFromCurrent); //element_id
        TextureFormat     := TDDSTextureFormat(fBundle.ReadDWord);
        TextureType       := TPsychoTextureType(fBundle.ReadDWord);
        fBundle.Seek(4, soFromCurrent); //Flags
        TextureWidth      := fBundle.ReadDWord;
        TextureHeight     := fBundle.ReadDWord;
        TextureNumMipmaps := fBundle.ReadDWord;
        fBundle.Seek(16, soFromCurrent);


        if TextureFormat = PAL8 then
        begin
          Has_Palette := fBundle.ReadWord;
          if Has_Palette <> 0 then
            fBundle.Seek(4, soFromCurrent); //Seek past the palette
        end;



        //Store current pos for where texture data actually begins
        if j=0 then
          TextureDataStart := fBundle.Position - FileObject.Offset;

        //Correct for mipmaps being 0 when...they arent.
        if TextureNumMipmaps = 0 then
        begin
          //Log('Mipmaps=0 so correcting...');
          TempWidth := TextureWidth;
          TempHeight := TextureHeight;
          while (TempWidth > 0) and (TempHeight > 0) do
          begin
            TempWidth := TempWidth shr 1;
            TempHeight := TempHeight shr 1;
            TextureNumMipmaps := TextureNumMipmaps + 1;
          end;
        end;

        //Log(FileObject.FileName + ' TextureSize=' + IntToStr(TextureSize) + ' Width=' + IntToStr(TextureWidth) + ' Height=' + IntToStr(TextureHeight) + ' HasPalette=' + inttostr(Has_Palette) + ' AnimFrameCount=' + IntToStr(AnimFrameCount) + ' TextureType=' + TRttiEnumerationType.GetName(TextureType) + ' TextureFormat=' + TRttiEnumerationType.GetName(TextureFormat) + ' TextureNumMipmaps=' + inttostr(TextureNumMipmaps));

        CalculatedTextureSize := CalculateFullTextureSize(TextureNumMipmaps, TextureWidth, TextureHeight, TextureFormat);

        if TextureType = Cubemap then
          CalculatedTextureSize := CalculatedTextureSize * 6;

        //Log('Offset before seek past texture=' +  inttostr(fBUndle.Position) + ' CalculatedTextureSize=' + inttostr(CalculatedTextureSize ));

        fBundle.Seek(CalculatedTextureSize, soFromCurrent); //Seek past the texture
      end;

      //Now texture data
      FileObject.PsychonautsDDS := TPsychonautsDDS.Create;
      FileObject.PsychonautsDDS.TextureType := TextureFormat;
      FileObject.PsychonautsDDS.Width       := TextureWidth;
      FileObject.PsychonautsDDS.Height      := TextureHeight;
      FileObject.PsychonautsDDS.Mipmaps     := TextureNumMipmaps;
      FileObject.PsychonautsDDS.DataOffset  := TextureDataStart; //fBundle.Position - FileObject.Offset;
      FileObject.PsychonautsDDS.MainTextureSize := CalculateIndividualTextureSize(TextureFormat, TextureWidth, TextureHeight);
      FileObject.PsychonautsDDS.IsCubemap := (TextureType = Cubemap);  //TODO swap for enum TPsychoTextureType and just store that

      //Log('Offset=' +  inttostr(fBUndle.Position) + ' CalculatedTextureSize=' + inttostr(CalculatedTextureSize ));

      BundleFiles.Add(FileObject);
    end;
  until LanguageHeader <>  $FFFF;

  //MPAK section
  if fBundle.ReadBlockName <> 'MPAK' then
  begin
    Log('MPAK header not found!');
    exit;
  end;

  ResourceCount := fBundle.ReadWord;
  //Log('NUM MPAK Files ' + inttostr(numfiles));
  for I := 0 to ResourceCount -1 do
  begin
    FileObject                 := TDFFile.Create;
    FileObject.Compressed      := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex   := -1;
    FileObject.FileExtension   := '';
    FileObject.FileType        := ft_other;

    PathLength := fBundle.ReadWord;
    FileObject.FileName := PChar(fBundle.ReadString(PathLength)); //Null terminated
    FileObject.FileExtension := ExtractFileExt( FileObject.FileName );
    fBundle.Seek(2, sofromcurrent); //??

    FileObject.Size := fBundle.ReadDWord;
    FileObject.Offset := fBundle.Position;
    fBundle.Seek(FileObject.Size, sofromcurrent);

    BundleFiles.Add(FileObject);
  end;


  //ScriptsVersion section
  if fBundle.ReadWord() = $FCFC then
    ScriptsVersion := fBundle.ReadWord //Version = 1
  else
    fBundle.Seek(-2, soFromCurrent); //If identifier not there this whole section doesnt exist

  //Global section
  ResourceCount := fBundle.ReadWord;
  for i := 0 to ResourceCount -1 do
  begin
    FileObject                 := TDFFile.Create;
    FileObject.Compressed      := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex   := -1;
    FileObject.FileExtension   := '';
    FileObject.FileType        := ft_other;


    PathLength := fBundle.ReadWord;
    FileObject.FileName := PChar(fBundle.ReadString(PathLength)); //Null terminated
    FileObject.FileExtension := '.lua'; //ExtractFileExt( FileObject.FileName );
    FileObject.Size := fBundle.ReadDWord;
    FileObject.Offset := fBundle.Position;
    fBundle.Seek(FileObject.Size, sofromcurrent);
    BundleFiles.Add(FileObject);
  end;

  //Scripts section
  ResourceCount := fBundle.ReadWord;
  for i := 0 to ResourceCount -1 do
  begin
    FileObject                 := TDFFile.Create;
    FileObject.Compressed      := false;
    FileObject.CompressionType := 0;
    FileObject.FileTypeIndex   := -1;
    FileObject.FileExtension   := '';
    FileObject.FileType        := ft_other;

    if ScriptsVersion = 1 then //This path section only exists if ScriptsVersion is 1
    begin
      PathLength := fBundle.ReadWord;
      FileObject.FileName := PChar(fBundle.ReadString(PathLength)); //Null terminated
    end
    else
      FileObject.FileName := 'UnnamedScript' + inttostr(i);

    FileObject.FileExtension := '.lua';
    FileObject.Size := fBundle.ReadDWord;
    FileObject.Offset := fBundle.Position;
    fBundle.Seek(FileObject.Size, sofromcurrent);
    BundleFiles.Add(FileObject);
  end;

  //Level section
  FileObject                 := TDFFile.Create;
  FileObject.Compressed      := false;
  FileObject.CompressionType := 0;
  FileObject.FileTypeIndex   := -1;
  FileObject.FileType        := ft_Other;

  FileObject.FileName := TPath.GetFileNameWithoutExtension (fBundleFileName) + ' level file.plb';
  FileObject.FileExtension   := '.plb';
  FileObject.Size := fBundle.Size - fBundle.Position;
  FileObject.Offset := fBundle.Position;
  BundleFiles.Add(FileObject);

  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(BundleFiles.Count);
end;


function TPPAKManager.CalculateIndividualTextureSize(
  TextureFormat: TDDSTextureFormat; Width, Height: integer): integer;
begin
  result := 0;

  case TextureFormat of
    A8R8G8B8, V16U16:                           result := (Width * Height) * 4;
    R8G8B8:                                     result := (Width * Height) * 3;
    A4R4G4B4, A1R5G5B5, X1R5G5B5, R5G6B5, V8U8: result := (Width * Height) * 2;
    L8,A8, AL8, PAL8:                           result := (Width * Height);
    DXT1:                                       result := Max(1, ((Width + 3) div 4)) * Max(1, ((Height + 3) div 4)) * 8;
    DXT3, DXT5:                                 result := Max(1, ((Width + 3) div 4)) * Max(1, ((Height + 3) div 4)) * 16;
    else
      Log('Texture size not calculated for ' + TRttiEnumerationType.GetName(TextureFormat));
  end
end;

function TPPAKManager.CalculateFullTextureSize(Mipmaps, Width, Height: integer;
  TextureFormat: TDDSTextureFormat): integer;
var
  i: Integer;
begin
  result := 0;

  for i := 0 to Mipmaps -1 do
  begin
    result := result + CalculateIndividualTextureSize(TextureFormat, Width, Height);
    Width := Width shr 1;
    Height := Height shr 1;
  end;

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
