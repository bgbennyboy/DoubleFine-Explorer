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

unit uMemReader;

interface

uses
	Classes, SysUtils;

type
  TExplorerMemoryStream = class (TMemoryStream)

  private

  public
    function ReadByte: byte;
    function ReadWord: word;
    function ReadWordBE: word;
    function ReadDWord: longword;
    function ReadDWordBE: longword;
    function ReadBlockName: string;
    function ReadBuffer(var Buffer; Count: longint): longint;
    function ReadString(Length: integer): string; inline;
    function ReadAnsiString(Length: integer): ansistring; inline;
    function ReadStringAlt(Length: integer): string; inline;
    function FindFileHeader(Header: string; StartSearchAt, EndSearchAt: cardinal): longint;
    constructor Create;
    destructor Destroy; override;

end;

implementation

function TExplorerMemoryStream.ReadByte: byte;
begin
	Read(result,1);
end;

function TExplorerMemoryStream.ReadWord: word;
begin
  Read(result,2);
end;

function TExplorerMemoryStream.ReadWordBE: word;
begin
	result:=ReadByte shl 8
   		    +ReadByte;
end;

function TExplorerMemoryStream.ReadDWord: longword;
begin
  Read(result,4);
end;


function TExplorerMemoryStream.ReadDWordBE: longword;
begin
	result:=ReadByte shl 24
          +ReadByte shl 16
   		    +ReadByte shl 8
          +ReadByte;
end;

function TExplorerMemoryStream.ReadBlockName: string;
begin
   result:=chr(ReadByte)+chr(ReadByte)+chr(ReadByte)+chr(ReadByte);
end;

function TExplorerMemoryStream.ReadBuffer(var Buffer; Count:longint): longint;
begin
	result:=Read(Buffer,Count);
end;

function TExplorerMemoryStream.ReadString(Length: integer): string;
var
  n: longword;
begin
  SetLength(result,length);
  for n:=1 to length do
  begin
    result[n]:=Chr(ReadByte);
  end;
end;

function TExplorerMemoryStream.ReadAnsiString(Length: integer): ansistring;
var
  n: longword;
begin
  SetLength(result,length);
  for n:=1 to length do
  begin
    result[n]:=Ansichar(Chr(ReadByte));
  end;

end;

function TExplorerMemoryStream.ReadStringAlt(Length: integer): string;
var //Replaces #0 chars
  n: longword;
  Rchar: char;
begin
  SetLength(result,length);
  for n:=0 to length -1 do
  begin
    RChar:=Chr(ReadByte);
    if RChar=#0 then
      result[n]:='x'
    else
    result[n]:=rchar;
  end;
end;

constructor TExplorerMemoryStream.Create;
begin
  inherited Create;
end;

destructor TExplorerMemoryStream.Destroy;
begin
  inherited;
end;

function TExplorerMemoryStream.FindFileHeader(Header: string; StartSearchAt,
  EndSearchAt: cardinal): longint;
var
  HeaderLength, Index: integer;
begin
  Result:=-1;
  Index:=1;
  if EndSearchAt > self.Size then
    EndSearchAt:=self.Size;

  HeaderLength:=Length(Header);
  if HeaderLength <= 0 then exit;


  Self.Position:=StartSearchAt;
  while Self.Position < EndSearchAt do
  begin
    if Chr(ReadByte) <> Header[Index] then
    begin
      if Index > 1 then
        Self.Position := Self.Position  -1;

      Index:=1;
      continue;
    end;

    inc(Index);
    if index > HeaderLength then
    begin
      Result:=Self.Position - HeaderLength;
      exit;
    end;
  end;


end;

end.
