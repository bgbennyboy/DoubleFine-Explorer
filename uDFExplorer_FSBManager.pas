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

unit uDFExplorer_FSBManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uFileReader, uMemReader, uDFExplorer_BaseBundleManager, uDFExplorer_Types, uDFExplorer_Funcs,
  uWaveWriter, JCLSysInfo, JCLShell, Windows;

type
  TFSBManager = class (TBundleManager)
  protected
    fBundle: TExplorerFileStream;
    fMemoryBundle: TExplorerMemoryStream;
    fBundleFileName: string;
    function DetectBundle: boolean; override;
    function GetFilesCount: integer; override;
    function GetFileName(Index: integer): string; override;
    function GetFileSize(Index: integer): integer;  override;
    function GetFileOffset(Index: integer): integer; override;
    function DecryptFSB(InStream, OutStream: TStream; Key: Array of byte): boolean;
    function GetFileType(Index: integer): TFiletype; override;
    function GetFileExtension(Index: integer): string; override;
    procedure Log(Text: string); override;
    procedure ParseFSB5;
    procedure ParseFSB4;
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
  end;

const
    strErrInvalidFile:  string  = 'Not a valid FSB file';
    Key1: array [0..9] of byte = ($44, $46, $6D, $33, $74, $34, $6C, $46, $54, $57); //DFm3t4lFTW
var
    WaveBankVersion: integer;

implementation


constructor TFSBManager.Create(ResourceFile: string);
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

destructor TFSBManager.Destroy;
begin
  if BundleFiles <> nil then
  begin
    BundleFiles.Free;
    BundleFiles:=nil;
  end;

  if fMemoryBundle <> nil then
    fMemoryBundle.free;

  if fBundle <> nil then
    fBundle.free;

  inherited;
end;

function TFSBManager.DetectBundle: boolean;
var
  Temp: string;
  TempStream: TMemoryStream;
begin
  Result := false;

  Temp := fBundle.ReadBlockName;
  if (Temp = 'FSB5') or (Temp = 'FSB4') then //Unencrypted
  begin
    fMemoryBundle := TExplorerMemoryStream.Create;
    fBundle.Position := 0;
    fMemoryBundle.CopyFrom(fBundle, fBundle.Size); //Keep everything in memory - faster to read from and easier than dealing with different cases for file/memory stream
    Result := true;
  end
  else
  begin
    tempstream:= tmemorystream.Create; //Doing the decryption from memory is MUCH faster than reading from disk
    try
      fBundle.Position := 0;
      TempStream.CopyFrom(fBundle, fBundle.Size);
      TempStream.Position :=0;
      fMemoryBundle := TExplorerMemoryStream.Create;

      if DecryptFSB(TempStream, fMemoryBundle, Key1) then
      begin
        //Then check again
        fMemoryBundle.Position := 0;
        Temp := fMemoryBundle.ReadBlockName;
        if (Temp = 'FSB5') or (Temp = 'FSB4') then
          Result := true;
      end;
      //fMemoryBundle.SaveToFile('c:\users\ben\desktop\decrypted');
    finally
      tempstream.Free;
    end;
  end;
end;

function TFSBManager.DecryptFSB(InStream, OutStream: TStream;
  Key: array of byte): boolean;

  function ReverseBitsInByte(input: byte): byte; inline;
  var
    i: integer;
  begin
    result := 0;
    for I := 0 to 7 do
    begin
      result := result shl 1;
      result := result or (input and 1);
      input := input shr 1;
    end;
  end;

var //TODO - read it in blocks and write whole lot at once
  i, j: integer;
  TempByte: byte;
begin
  Result := false;

  j:=0;
  for i := 0 to InStream.Size - 1 do
  begin
    InStream.Read(TempByte, 1);
    TempByte := ReverseBitsInByte(TempByte) xor Key[j];
    inc(j);
    if j= length(Key) then j:= 0;

    OutStream.Write(TempByte, 1);
  end;

  if InStream.Size = OutStream.Size then result := true;
end;

function TFSBManager.GetFileExtension(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TFSBFile(BundleFiles.Items[Index]).FileExtension;
end;

function TFSBManager.GetFileName(Index: integer): string;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ''
  else
     result:=TFSBFile(BundleFiles.Items[Index]).FileName;
end;

function TFSBManager.GetFileOffset(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TFSBFile(BundleFiles.Items[Index]).offset;
end;

function TFSBManager.GetFilesCount: integer;
begin
  if BundleFiles <> nil then
    result:=BundleFiles.Count
  else
    result:=0;
end;

function TFSBManager.GetFileSize(Index: integer): integer;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
    result:=-1
  else
     result:=TFSBFile(BundleFiles.Items[Index]).size;
end;

function TFSBManager.GetFileType(Index: integer): TFiletype;
begin
  if (not assigned(BundleFiles)) or
     (index < 0) or
     (index > GetFilesCount) then
     result:= ft_Unknown
  else
     result:=TFSBFile(BundleFiles.Items[Index]).FileType;
end;

procedure TFSBManager.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;

procedure TFSBManager.ParseFiles;
var
  strMagic: string;
begin
  fMemoryBundle.Position := 0; 
  strMagic := fMemoryBundle.ReadBlockName;
  fMemoryBundle.Position := 0; 

  if strMagic ='FSB5' then
    ParseFSB5
  else
  if strMagic ='FSB4' then
    ParseFSB4;
    
  if (Assigned(FOnDoneLoading)) then
	  FOnDoneLoading(BundleFiles.Count);
end;


procedure TFSBManager.ParseFSB4;
//Based on FSBExt by Luigi Auriemma
const
  FSB_FileNameLength: integer = 30;
  FSOUND_DELTA = $00000200;
  FSOUND_8BITS = $00000008;
  FSOUND_16BITS = $00000010;
  FSOUND_MONO = $00000020;
  FSOUND_STEREO = $00000040;
var
  TempStr, FileExt: string;
  FileObject: TFSBFile;
  RecordSize, NumSamples, Mode, SampleHeaderSize, Datasize, NameOffset,
    FileOffset, i, Size, Samples, PrevOffsetAndSize, Channels, Bits, Frequency: integer;
  Version, HeadMode: longword;
  Codec: TFSBCodec;
begin
  fMemoryBundle.Position := 0;
  TempStr := fMemoryBundle.ReadBlockName;
  if TempStr <> 'FSB4' then
  begin
    Log('Not an FSB4 header!: ' + TempStr);
    raise EInvalidFile.Create( strErrInvalidFile );
  end;


  NumSamples        := fMemoryBundle.ReadDWord;
  SampleHeaderSize  := fMemoryBundle.ReadDWord;
  Datasize          := fMemoryBundle.ReadDWord;
  Version           := fMemoryBundle.ReadDWord;
  HeadMode          := fMemoryBundle.ReadDWord;
  fMemoryBundle.Seek(24, soFromCurrent); //8x zero bytes + hash

  NameOffset := 48; //size of initial header
  FileOffset := 48 + SampleHeaderSize;
  PrevOffsetAndSize := 0;
  
  if (HeadMode and $08) <> 0 then
    Log('BIG ENDIAN MODE DETECTED: IMPLEMENT SUPPORT FOR THIS !!!!!');

  if(HeadMode and $00000002) <> 0 then
    Log('Basic headers detected in this FSB!');
  
  for I := 0 to NumSamples - 1 do
  begin  
    if ((HeadMode and $00000002) <> 0) and (i <> 0) then
    begin
      //Log('Basic headers mode');
      Samples :=  fMemoryBundle.ReadDWord;
      Size :=     fMemoryBundle.ReadDWord;
      TempStr := inttostr(i);
      //freq, chans, mode and moresize are the same as the first file
    end
    else
    begin
      RecordSize :=fMemoryBundle.ReadWord; //size of this record, inclusive
      TempStr := PChar(fMemoryBundle.ReadString(FSB_FileNameLength));
      Samples :=  fMemoryBundle.ReadDWord;
      Size :=  fMemoryBundle.ReadDWord;
      fMemoryBundle.Seek(8, soFromCurrent); //loopstart and loopend
      Mode := fMemoryBundle.ReadDWord;
      Frequency := fMemoryBundle.ReadDWord;
      fMemoryBundle.Seek(24, soFromCurrent); //Unused data for this
      if RecordSize > 80 then //Some files have extra data
        fMemoryBundle.Seek(RecordSize - 80, soFromCurrent);
    end;

    //Now work out the codec it uses - for DF games its almost always MPEG
    Codec := FMOD_SOUND_FORMAT_PCM16;
    if (Mode and FSOUND_DELTA) <> 0 then
      Codec := FMOD_SOUND_FORMAT_MPEG
    else
    if ((Mode and FSOUND_8BITS) <> 0) and (Codec = FMOD_SOUND_FORMAT_PCM16) then
      Codec := FMOD_SOUND_FORMAT_PCM8;

    //Match codec to file extension
    case Codec of
      FMOD_SOUND_FORMAT_PCM8:   FileExt := '.wav';
      FMOD_SOUND_FORMAT_PCM16:  FileExt := '.wav';
      FMOD_SOUND_FORMAT_MPEG:   FileExt := '.mp3'
    else
      begin
        Log('Unknown codec');
        FileExt := '.wav';
      end;
    end;

    if fBundleFileName = 'GUI.fsb' then
      Log('GUI.FSB in Iron Brigade...known problems with this file - sounds probably wont dump correctly.');


    //Get no of channels
    Channels := 1;
    if (Mode and FSOUND_MONO) <> 0 then
      Channels := 1
    else
    if (Mode and FSOUND_STEREO) <> 0 then
      Channels := 2;

    //Get bits
    Bits := 16;
    if (Mode and FSOUND_8BITS) <> 0 then
      Bits := 8
    else
    if (Mode and FSOUND_16BITS) <> 0 then
      Bits := 16;

    FileObject               := TFSBFile.Create;
    FileObject.size          := Size;
    if i = 0 then
      FileObject.offset      := FileOffset
    else
      FileObject.offset      := PrevOffsetAndSize;
    PrevOffsetAndSize        :=  FileObject.size +  FileObject.Offset;
    FileObject.FileName      := ChangeFileExt(Tempstr, FileExt);
    FileObject.FileType      := ft_Audio;
    FileObject.FileExtension := FileExt;
    FileObject.Codec         := Codec;
    FileObject.Channels      := Channels;
    FileObject.Bits          := Bits;
    FileObject.Freq          := Frequency;

    BundleFiles.Add(FileObject);
  end;
end;

procedure TFSBManager.ParseFSB5;
//Based on FSBExt by Luigi Auriemma - doesnt include all FSB5 dumping stuff - just enough to work for known DF FSB files
var
  Version, NumSamples, SampleHeaderSize, NameSize, Datasize, Mode, i,
  Len, NameOffset: integer;

  Offset, Samples, TheType, TempDWord, Size, FileOff: dword;
  TempQWord: uint64;
  TempStr: string;
  FileObject: TFSBFile;
begin
  fMemoryBundle.Position := 0;
  TempStr := fMemoryBundle.ReadBlockName;
  if TempStr <> 'FSB5' then
  begin
    Log('Not an FSB5 header!: ' + TempStr);
    raise EInvalidFile.Create( strErrInvalidFile );
  end;

  Version           := fMemoryBundle.ReadDWord;
  NumSamples        := fMemoryBundle.ReadDWord;
  SampleHeaderSize  := fMemoryBundle.ReadDWord;
  NameSize          := fMemoryBundle.ReadDWord;
  Datasize          := fMemoryBundle.ReadDWord;
  Mode              := fMemoryBundle.ReadDWord;
  NameOffset        := 60 + SampleHeaderSize; //60 is first header size

  {Log('Version ' + inttostr(Version));
  Log('NumSamples ' + inttostr(NumSamples));
  Log('SampleHeaderSize ' + inttostr(SampleHeaderSize));
  Log('NameSize ' + inttostr(NameSize));
  Log('Datasize ' + inttostr(Datasize));
  Log('Mode ' + inttostr(Mode));}



  fMemoryBundle.Seek(32, sofromcurrent); //now at end of file header

  for I := 0 to NumSamples - 1 do
  begin
    Offset := fMemoryBundle.ReadDWord;
    Samples := fMemoryBundle.ReadDWord shr 2;  //Used in XMA
    TheType := Offset and $FF;
    Offset := Offset shr 8;
    Offset := Offset * $40; //64;

    {Log('Offset '  + Inttostr( Offset));
    Log('Samples ' + Inttostr( Samples));
    Log('Type '    + Inttostr( TheType));}

    while (TheType and 1 > 0) do
    begin
      TempDWord := fMemoryBundle.ReadDWord;
      TheType := TempDWord and 1;
      Len := (TempDWord and $ffffff) shr 1;
      TempDWord := TempDWord shr 24;
      TempQWord := fMemoryBundle.Position;
      case TempDWord of
        2: fMemoryBundle.Seek(1, sofromcurrent); //channels
        4: fMemoryBundle.Seek(4, sofromcurrent); //frequency
        6: begin
            fMemoryBundle.Seek(4, sofromcurrent); //unknown
            fMemoryBundle.Seek(4, sofromcurrent); //unknown
          end;
        20: ;//xwma data
      end;

      TempQWord := TempQWord + Len;
      fMemoryBundle.Seek(TempQWord, sofrombeginning);
    end;


    TempQWord := fMemoryBundle.Position;
    if fMemoryBundle.Position < NameOffset then  //nameoffset
    begin
      Size := fMemoryBundle.ReadDWord;
      if Size = 0 then  //not sure about this
      begin
        fMemoryBundle.Position := fMemoryBundle.Size; //Seek till the end?
        Size := fMemoryBundle.Position;
      end
      else
      begin
        Size := Size shr 8;
        Size := Size * $40;
        Size := Size + (NameOffset + NameSize); //base offset
      end
    end
    else
    begin
      fMemoryBundle.Position := fMemoryBundle.Size; //Seek till the end?
      Size := fMemoryBundle.Position;
    end;

    fMemoryBundle.Seek(TempQWord, sofrombeginning);
    FileOff := (NameOffset + NameSize) + Offset; //offset + base offset
    Size := Size - FileOff;


    //Now get name if there is one
    //TODO check flags to make sure there is a name in the FSB
    TempQWord := fMemoryBundle.Position; //store old position
    fMemoryBundle.Position := NameOffset + (i * 4); //nameoff
    fMemoryBundle.Seek(NameOffset + fMemoryBundle.ReadDWord, soFromBeginning);
    Tempstr := PChar(fMemoryBundle.ReadString(255));
    fMemoryBundle.Position := TempQWord; //seek back to old position


    FileObject               := TFSBFile.Create;
    FileObject.size          := Size;
    FileObject.offset        := FileOff;
    FileObject.FileName      := Tempstr + '.mp3';
    FileObject.FileType      := ft_Audio;
    FileObject.FileExtension := '.MP3';
    FileObject.Codec         := FMOD_SOUND_FORMAT_MPEG; //TODO - other codec detection for FSB5 - not needed by any games seen so far

    BundleFiles.Add(FileObject);
  end;

end;

procedure TFSBManager.SaveFile(FileNo: integer; DestDir, FileName: string);
var
  SaveFile: TFileStream;
begin
  if TFSBFile(BundleFiles.Items[FileNo]).Size <= 0 then
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

procedure TFSBManager.SaveFiles(DestDir: string);
var
  i: integer;
  SaveFile: TFileStream;
begin
  for I := 0 to BundleFiles.Count - 1 do
  begin
    ForceDirectories(extractfilepath(IncludeTrailingPathDelimiter(DestDir) + ExtractPartialPath( TFSBFile(BundleFiles.Items[i]).FileName)));
    SaveFile:=TFileStream.Create(IncludeTrailingPathDelimiter(DestDir) +  TFSBFile(BundleFiles.Items[i]).FileName , fmOpenWrite or fmCreate);
    try
      SaveFileToStream(i, SaveFile);
    finally
      SaveFile.free;
      if Assigned(FOnProgress) then FOnProgress(GetFilesCount -1, i);
      Application.Processmessages;
    end;
  end;

end;

procedure TFSBManager.SaveFileToStream(FileNo: integer; DestStream: TStream);
var
  Ext: string;
  WavStream: TWaveStream;
begin
  if TFSBFile(BundleFiles.Items[FileNo]).Size <= 0 then
  begin
    Log(strErrFileSize);
    exit;
  end;

  if (FileNo < 0) or (FileNo > BundleFiles.Count) then
  begin
    Log(strErrFileNo);
    exit;
  end;

  Ext:=Uppercase(ExtractFileExt(TFSBFile(BundleFiles.Items[FileNo]).FileName));

  fMemoryBundle.Seek(TFSBFile(BundleFiles.Items[FileNo]).Offset, sofrombeginning);

  if (TFSBFile(BundleFiles.Items[FileNo]).Codec = FMOD_SOUND_FORMAT_PCM8) or ((TFSBFile(BundleFiles.Items[FileNo]).Codec = FMOD_SOUND_FORMAT_PCM16)) then
  begin
    WavStream := TWaveStream.Create(DestStream, TFSBFile(BundleFiles.Items[FileNo]).Channels, TFSBFile(BundleFiles.Items[FileNo]).Bits, TFSBFile(BundleFiles.Items[FileNo]).Freq );
    try
      WavStream.CopyFrom(fMemoryBundle, TFSBFile(BundleFiles.Items[FileNo]).Size);
    finally
      WavStream.Free;
    end;
  end
  else
    DestStream.CopyFrom(fMemoryBundle, TFSBFile(BundleFiles.Items[FileNo]).Size);

  DestStream.Position:=0;
end;



end.
