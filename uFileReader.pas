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

unit uFileReader;

interface

uses
	Classes, SysUtils;

type
  TExplorerFileStream = class (TFileStream)

  private
    fBigEndian: boolean;
    function Swap8 (const i: uInt64): uInt64; register;
    procedure setBigEndian(const Value: boolean);
  public
    function ReadByte: byte; inline;
    function ReadWord: word; inline;
    function ReadWordBE: word; inline;
    function ReadDWord: longword; inline;
    function ReadDWordLE: longword; inline;
    function ReadDWordBE: longword; inline;
    function ReadQWord: uint64; inline;
    function ReadQWordBE: uint64; inline;
    function ReadTriByte: longword; inline;
    function ReadTriByteBE: longword; inline;
    function ReadBlockName: string; inline;
    function ReadString(Length: integer): string; inline;
    function ReadStringAlt(Length: integer): string; inline;
    constructor Create(FileName: string);
    destructor Destroy; override;
    property BigEndian: boolean read fBigEndian write setBigEndian;

end;

implementation

function TExplorerFileStream.ReadByte: byte;
begin
	Read(result,1);
end;

function TExplorerFileStream.ReadWord: word;
begin
  if fBigEndian then
    result :=ReadWordBE
  else
    Read(result,2);
end;

function TExplorerFileStream.ReadWordBE: word;
begin
	result:=ReadByte shl 8
   		    +ReadByte;
end;

function TExplorerFileStream.ReadDWord: longword;
begin
  if fBigEndian then
    result :=ReadDWordBE
  else
    Read(result,4);
end;

function TExplorerFileStream.ReadDWordBE: longword;
begin
	result:=ReadByte shl 24
          +ReadByte shl 16
   		    +ReadByte shl 8
          +ReadByte;
end;

function TExplorerFileStream.ReadDWordLE: longword;
begin
  Read(result,4);
end;

function TExplorerFileStream.ReadQWord: uint64;
begin
  if fBigEndian then
    result := ReadQWordBE
  else
    Read(result,8);
end;

function TExplorerFileStream.Swap8(const i: uInt64): uInt64;
asm
  mov edx, dword [i]
  bswap edx
  mov eax, dword [i+4]
  bswap eax
end;

function TExplorerFileStream.ReadQWordBE: uint64;
var
  i: uint64;
begin
  read(i, 8);
	result:= Swap8(i);
end;

function TExplorerFileStream.ReadBlockName: string;
begin
   result:=chr(ReadByte)+chr(ReadByte)+chr(ReadByte)+chr(ReadByte);
end;

function TExplorerFileStream.ReadString(Length: integer): string;
var
  n: longword;
begin
  SetLength(result,length);
  for n:=1 to length do
  begin
    result[n]:=Chr(ReadByte);
  end;
end;

function TExplorerFileStream.ReadStringAlt(Length: integer): string;
var //Replaces #0 chars with character
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

function TExplorerFileStream.ReadTriByte: longword;
begin
  if fBigEndian then
    result :=ReadTriByteBE
  else
    Read(result,3);
end;

function TExplorerFileStream.ReadTriByteBE: longword;
begin
  result:=ReadByte shl 16
          +ReadByte shl 8
   		    +ReadByte;
end;

procedure TExplorerFileStream.setBigEndian(const Value: boolean);
begin
  fBigEndian := Value;
end;

constructor TExplorerFileStream.Create(FileName: string);
begin
  inherited Create(Filename, fmopenread OR fmShareDenyNone);
  fBigEndian := false;
end;

destructor TExplorerFileStream.Destroy;
begin
  inherited;
end;

end.
