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
  {
  Older TT games have no history window.
  Starting with sam and max 301 they've hidden the zlib header so
  history window is -15
  }

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
