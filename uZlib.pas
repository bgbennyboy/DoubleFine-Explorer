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

unit uZlib;

interface

uses
  Classes, ZlibEx;


procedure DecompressZlib(Source: TStream; UnCompressedSize: integer;
  Dest: TStream);

implementation

function Private_DecompressZLib(Source: TStream; UnCompressedSize, WindowBits: integer;
  Dest: TStream): boolean;
var
  DeCompressionStream: TZDecompressionStream;
begin
  Result := false;

  DeCompressionStream := TZDecompressionStream.Create(Source, WindowBits);
    try
      try
        Dest.CopyFrom(DeCompressionStream, UnCompressedSize);
        Result := true;
      except on E: EZDecompressionError do
      end;
    finally
      DeCompressionStream.Free;
    end;
end;

procedure DecompressZlib(Source: TStream; UnCompressedSize: integer;
  Dest: TStream);
var
  SourcePos: integer;
begin
  SourcePos := Source.Position;
  if Private_DecompressZLib(Source, UncompressedSize, 0, Dest) = false then
  begin
    Source.Position := SourcePos;
    if Private_DecompressZLib(Source, UncompressedSize, -15, Dest) = false then
      raise EZDecompressionError.Create('Decompression error!');
  end;

end;


{procedure DecompressZlib(Source: TStream; UnCompressedSize: integer;
  Dest: TStream);
var
  DeCompressionStream: TZDecompressionStream;
begin
  DecompressionStream:=TZDecompressionStream.Create(Source);
  try
    Dest.CopyFrom(DecompressionStream, UnCompressedSize);
  finally
    DecompressionStream.Free;
  end;
end;}
end.
