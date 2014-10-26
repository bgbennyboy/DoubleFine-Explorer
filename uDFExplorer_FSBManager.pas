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

unit uDFExplorer_FSBManager;

interface

uses
  classes, sysutils, Contnrs, forms,
  uFileReader, uMemReader, uDFExplorer_BaseBundleManager, uDFExplorer_Types, uDFExplorer_Funcs,
  uWaveWriter, JCLSysInfo, JCLShell, Windows, uMPEGHeaderCheck;

type
  TFSBManager = class (TBundleManager)
  protected
    fBundle: TExplorerFileStream;
    fMemoryBundle: TExplorerMemoryStream;
    fBundleFileName: string;
    fEncrypted: boolean;
    function DetectBundle: boolean; override;
    function GetFilesCount: integer; override;
    function GetFileName(Index: integer): string; override;
    function GetFileSize(Index: integer): integer;  override;
    function GetFileOffset(Index: integer): integer; override;
    function DecryptFSB(InStream: TStream; Offset, Size: integer; OutStream: TStream; Key: Array of byte; KeyOffset: integer = -1): boolean;
    function GetFileType(Index: integer): TFiletype; override;
    function GetFileExtension(Index: integer): string; override;
    function GetFSB5Offset(InValue: Dword): DWord;
    procedure Log(Text: string); override;
    procedure ParseFSB5;
    procedure ParseFSB4;
    procedure SaveFixedMP3Stream(InStream, OutStream: TStream; FileSize, Channels: integer);
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
    FSBKey: array [0..9] of byte = ($44, $46, $6D, $33, $74, $34, $6C, $46, $54, $57); //DFm3t4lFTW
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
  FilesOffset: integer;
begin
  Result := false;
  fEncrypted := true;
  FilesOffset := 0;

  Temp := fBundle.ReadBlockName;
  if (Temp = 'FSB5') or (Temp = 'FSB4') then //Unencrypted
  begin
    fEncrypted := false;
    fMemoryBundle := TExplorerMemoryStream.Create;

    if Temp = 'FSB4' then
    begin
      //Read the size of the sample headers to work out where the header ends and file data starts
      fBundle.Position := 8;
      FilesOffset := fBundle.ReadDWord + 48;
    end
    else
    if Temp = 'FSB5' then
    begin
      //Read the size of the sample + name size headers to work out where the header ends and file data starts
      fBundle.Position := 12;
      FilesOffset := fBundle.ReadDWord + fBundle.ReadDWord + 60;
    end;

    //Then only copy out the header information
    fBundle.Position := 0;
    fMemoryBundle.CopyFrom(fBundle, FilesOffset); //Keep everything in memory - faster to read from and easier than dealing with different cases for file/memory stream
    Result := true;
  end
  else
  begin
    fBundle.Position := 0;
    fMemoryBundle := TExplorerMemoryStream.Create;

    if DecryptFSB(fBundle, 0, 4, fMemoryBundle, FSBKey) then
    begin
      //Then check again
      fMemoryBundle.Position := 0;
      Temp := fMemoryBundle.ReadBlockName;
      if (Temp = 'FSB5') or (Temp = 'FSB4') then
      begin
        Result := true;

        //Decrypt the first few bytes so we can work out how big the header is
        fMemoryBundle.Clear;
        DecryptFSB(fBundle, 0, 20, fMemoryBundle, FSBKey);

        if Temp = 'FSB4' then
        begin
          //Read the size of the sample headers to work out where the header ends and file data starts
          fMemoryBundle.Position := 8;
          FilesOffset := fMemoryBundle.ReadDWord + 48;
        end
        else
        if Temp = 'FSB5' then
        begin
          //Read the size of the sample + name size headers to work out where the header ends and file data starts
          fMemoryBundle.Position := 12;
          FilesOffset := fMemoryBundle.ReadDWord + fMemoryBundle.ReadDWord + 60;
        end;

        //Then decrypt the full header
        fMemoryBundle.Clear;
        DecryptFSB(fBundle, 0, FilesOffset, fMemoryBundle, FSBKey)
      end;
    end;
    //fMemoryBundle.SaveToFile('c:\users\ben\desktop\decrypted.fsb');
  end;
end;

function TFSBManager.DecryptFSB(InStream: TStream; Offset, Size: integer;
  OutStream: TStream; Key: Array of byte; KeyOffset: integer = -1): boolean;

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

  Instream.Position := Offset;

  if KeyOffset = -1 then
    KeyOffset := Offset; //If no key offset provided then we assume that we're dealing with the original file and calculate the key offset based on the file offset

  j := KeyOffset mod length(Key); //Calculate what part of the key to start from
  for i := 0 to Size - 1 do
  begin
    InStream.Read(TempByte, 1);
    TempByte := ReverseBitsInByte(TempByte) xor Key[j];
    inc(j);
    if j= length(Key) then j:= 0;

    OutStream.Write(TempByte, 1);
  end;

  if Size = OutStream.Size then result := true;
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
    Log('BIG ENDIAN MODE DETECTED: TODO - IMPLEMENT SUPPORT FOR THIS !!!!!');

  if(HeadMode and $00000002) <> 0 then
    Log('Basic headers detected in this FSB!');


  Mode := 0 ;
  Frequency := 0;
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
      FMOD_SOUND_FORMAT_PCM8:   FileExt := 'WAV';
      FMOD_SOUND_FORMAT_PCM16:  FileExt := 'WAV';
      FMOD_SOUND_FORMAT_MPEG:   FileExt := 'MP3'
    else
      begin
        Log('Unknown codec');
        FileExt := 'WAV';
      end;
    end;

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
    PrevOffsetAndSize        := FileObject.size +  FileObject.Offset;
    FileObject.FileName      := ChangeFileExt(Tempstr, '.' + Lowercase(FileExt));
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
  Len, NameOffset, Frequency: integer;

  Offset, Samples, TheType, TempDWord, Size, FileOff: dword;
  Channels: word;
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

    TheType := Offset and ((1 shl 7) -1);
    Offset := GetFSB5Offset(Offset);
    Channels := (TheType shr 5) + 1;

    case ((TheType shr 1) and ((1 shl 4) - 1)) of
      0:  Frequency := 4000;
      1:  Frequency := 8000;
      2:  Frequency := 11000;
      3:  Frequency := 12000;
      4:  Frequency := 16000;
      5:  Frequency := 22050;
      6:  Frequency := 24000;
      7:  Frequency := 32000;
      8:  Frequency := 44100;
      9:  Frequency := 48000;
      10: Frequency := 96000;
      else Frequency := 44100;
    end;
    {
    Gone in fsbext 0.3.3
    TheType := Offset and $FF;
    Offset := Offset shr 8;
    Offset := Offset * $40;} //64;

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
        2: Channels := fMemoryBundle.ReadByte; //fMemoryBundle.Seek(1, sofromcurrent); //channels
        4: Frequency := fMemoryBundle.ReadDWord;  //fMemoryBundle.Seek(4, sofromcurrent); //frequency
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
        Size := fBundle.Size; //Size of the original file (remember MemoryBundle only contains the header)
      end
      else
      begin
        {Size := Size shr 8;
        Size := Size * $40;
        Size := Size + (NameOffset + NameSize);} //base offset
        Size := GetFSB5Offset(Size) + (NameOffset + NameSize); //base offset
      end
    end
    else
    begin
      Size := fBundle.Size; //Size of the original file (remember MemoryBundle only contains the header)
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
    FileObject.Channels      := Channels;
    FileObject.FileExtension := 'MP3';
    FileObject.Codec         := FMOD_SOUND_FORMAT_MPEG; //TODO - other codec detection for FSB5 - not needed by any games seen so far

    BundleFiles.Add(FileObject);
  end;

end;

function TFSBManager.GetFSB5Offset(InValue: Dword): DWord;
begin
  result := (InValue shr 7) * $20;
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
  TempStream: TMemoryStream;
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

  //Fill fMemoryBundle with the new file - decrypting if necessary
  fMemoryBundle.Clear;
  if fEncrypted then
  begin
    //much quicker to copy to memory then decrypt than do it from disk
    TempStream := TMemoryStream.Create;
    try
      fBundle.Position := TFSBFile(BundleFiles.Items[FileNo]).Offset;
      TempStream.CopyFrom(fBundle, TFSBFile(BundleFiles.Items[FileNo]).size);
      DecryptFSB(Tempstream, 0, TempStream.size, fMemoryBundle, FSBKey, TFSBFile(BundleFiles.Items[FileNo]).Offset); //Provide the offset as last param so we know where the key should start from in the original file
    finally
      TempStream.Free;
    end;
  end
  else
  begin
    fBundle.Position := TFSBFile(BundleFiles.Items[FileNo]).Offset;
    fMemoryBundle.CopyFrom(fBundle, TFSBFile(BundleFiles.Items[FileNo]).size);
  end;

  fMemoryBundle.Position := 0;

  Ext:=Uppercase(ExtractFileExt(TFSBFile(BundleFiles.Items[FileNo]).FileName));

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
  if (TFSBFile(BundleFiles.Items[FileNo]).Codec = FMOD_SOUND_FORMAT_MPEG) then //fix broken mp3's
  begin
    SaveFixedMP3Stream(fMemoryBundle, DestStream, TFSBFile(BundleFiles.Items[FileNo]).Size, TFSBFile(BundleFiles.Items[FileNo]).Channels);
  end
  else
    DestStream.CopyFrom(fMemoryBundle, TFSBFile(BundleFiles.Items[FileNo]).Size);


  DestStream.Position:=0;
end;

function ShouldDownmixChannels(Channels, Frame: integer): boolean;
var
	ChansResult: integer;
begin
	if (Channels and 1) = 1 then
		ChansResult := Channels
	else
		ChansResult := Channels div 2;

	ChansResult := frame mod ChansResult;

	if (Channels <= 2) or (ChansResult = 0) then
		result := true
	else
		result := false;
end;

procedure TFSBManager.SaveFixedMP3Stream(InStream, OutStream: TStream; FileSize, Channels: integer);
var
	Frame, FrameSize, n: integer;
  Buffer: TBuffer;
	TempBuffer: TBuffer;
	tmpMpegHeader: TMpegHeader;
	TempByte: Byte;
begin
	Frame := 0;
	while FileSize > 0 do
	begin
    SetLength(buffer, 3);
		if InStream.Read(Buffer[0], 3) <> 3 then  //bytes read
			break;

		Dec(FileSize, 3);
		FrameSize := 0;
    //read 3 bytes, if invalid header then read another and shuffle the bytes up in the buffer and check again.
		while FileSize > 0 do
		begin
      tmpMpegHeader := GetValidatedHeader(Buffer, 0);
		  FrameSize := tmpMpegHeader.framelength;
      if tmpMpegHeader.valid = true then
        if FrameSize > 0 then break;

      if InStream.Size - InStream.Position < 1 then //Just in case
      begin
        Log('Tried to read beyond stream in SaveFixedMP3Stream()');
        exit;
      end;
      InStream.Read(TempByte, 1);

		  Dec(FileSize, 1);

		  Buffer[0] := Buffer[1];
		  Buffer[1] := Buffer[2];
		  Buffer[2] := tempbyte;
		end;

		if FileSize < 0 then break;

		dec(FrameSize, 3);

		if ShouldDownmixChannels(Channels, Frame) then
      Outstream.Write(Buffer[0], 3);

    if FrameSize > 0 then
    begin
      SetLength(TempBuffer,FrameSize);
      n := InStream.Read(TempBuffer[0], FrameSize);
      dec(FileSize, n);

      if ShouldDownmixChannels(Channels, Frame) then
        OutStream.Write(TempBuffer[0], n);

      if n <> FrameSize then
        break;
    end;

		inc(Frame);
	end;

end;

end.
