{
  TWaveStream class
  (c) 2005 Benjamin Haisch
  Writes stuff to wave files without ACM etc
}

unit uWaveWriter;

interface

uses
  Classes, SysUtils;

const
  WAVE_FORMAT_PCM = $0001;

type
  TWaveHeader = record
    riff,
    totallen,
    wave,
    fmt,
    wavelen: cardinal;
    wFormatTag,
    wChannels: word;
    dwSamplesPerSec,
    dwAvgBytesPerSec: cardinal;
    wBlockAlign,
    wBitsPerSample: word;
    data,
    datalen: cardinal;
  end;

type
  TWaveStream = class(TStream)
  private
    FDest: TStream;
    FStartOfs: integer;
    FWaveHeader: TWaveHeader;
  public
    constructor Create(Dest: TStream; Channels, Bits, Freq: integer);
    destructor Destroy; override;

    procedure WriteBuffer(Buf: Pointer; Size: longint);
    function Write(const Buffer; Count: Longint): Longint; override;
    function Read(var Buffer; Count: Longint): Longint; override;

    function CopyFrom(Source: TStream; Count: Int64): Int64;

  end;

implementation

function MakeID(Str: ansistring): cardinal;
begin
  Move(Str[1], Result, 4);
end;

constructor TWaveStream.Create(Dest: TStream; Channels, Bits, Freq: integer);
begin
  FDest:= Dest;
  FStartOfs:= FDest.Position;

  with FWaveHeader do begin
    riff:= MakeID('RIFF');
    totallen:= SizeOf(TWaveHeader) - 8;
    wave:= MakeID('WAVE');
    fmt:= MakeID('fmt ');
    wavelen:= 16;
    wFormatTag:= WAVE_FORMAT_PCM;
    wChannels:= Channels;
    dwSamplesPerSec:= Freq;
    wBlockAlign:= Channels * (Bits div 8);
    dwAvgBytesPerSec:= wBlockAlign * Freq;
    wBitsPerSample:= Bits;
    data:= MakeID('data');
    datalen:= 0;
  end;

  FDest.Write(FWaveHeader, SizeOf(TWaveHeader));

end;

destructor TWaveStream.Destroy;
var
  SavePos: Cardinal;
begin
  SavePos := FDest.Position;
  FDest.Seek(FStartOfs, soFromBeginning);
  FDest.Write(FWaveHeader, SizeOf(TWaveHeader));
  FDest.Position := SavePos;
end;

procedure TWaveStream.WriteBuffer(Buf: Pointer; Size: longint);
begin
  FDest.Write(Buf^, Size);
  Inc(FWaveHeader.DataLen, Size);
  Inc(FWaveHeader.TotalLen, Size);
end;

function TWaveStream.Write(const Buffer; Count: Longint): Longint;
begin
  WriteBuffer(@Buffer, Count);
  Result := Count;
end;

function TWaveStream.Read(var Buffer; Count: Longint): Longint; 
begin
  Result := 0;
end;

function TWaveStream.CopyFrom(Source: TStream; Count: Int64): Int64;
const
  MaxBufSize = $F000;
var
  BufSize, N: Integer;
  Buffer: PChar;
begin
  Result := Count;
  if Count > MaxBufSize then BufSize := MaxBufSize else BufSize := Count;
  GetMem(Buffer, BufSize);
  try
    while Count <> 0 do
    begin
      if Count > BufSize then N := BufSize else N := Count;
      Source.ReadBuffer(Buffer^, N);
      WriteBuffer(Buffer, N);
      Dec(Count, N);
    end;
  finally
    FreeMem(Buffer, BufSize);
  end;
end;

end.
