{
******************************************************
  DoubleFine Explorer
  By Bennyboy
  Http://quickandeasysoftware.net
******************************************************
}

//Adapted from https://github.com/indirivacua/RAGE-Console-Texture-Editor/blob/master/Compression.LZX.pas

unit uXCompress;

interface

uses
  Classes, Windows, Sysutils,
  MemoryModule;

type
  EXCompressDecompressionError = class (exception);
  LZXBlockSize = record
    UnCompressedSize,
    CompressedSize: WORD;
  end;
var
  DllLib : TMemoryModule;
  XDecompress: function(inData: PAnsiChar;  inlen: integer;  outdata: PAnsiChar;  outlen: integer): integer; cdecl;
  LZXinit: function (window: integer): Integer; cdecl;
  procedure XCompress_Load_DLL;
  procedure DecompressXCompress(Source: TStream; Dest: TStream; UncompressedSize: integer);

implementation

procedure XCompress_Load_DLL;
var
  ResStream: TResourceStream;
begin
  if DllLib <> nil then
    exit; //already loaded

  //Load it from resource into memory
  ResStream := TResourceStream.Create(hInstance, 'XMEMDLL', RT_RCDATA);
  try
    ResStream.Position := 0;
    DllLib := MemoryLoadLibary(ResStream.Memory);
  finally
    ResStream.Free;
  end;

  if DllLib = nil then
  begin
    raise Exception.Create('XCompress dll load failed!');
    exit;
  end;

  XDecompress := MemoryGetProcAddress(DllLib, PAnsiChar('LZXdecompress'));
  if not Assigned (XDecompress) then
  begin
    raise Exception.Create('Couldnt find decompression function in DLL');
  end;

  LZXinit := MemoryGetProcAddress(DllLib, PAnsiChar('LZXinit'));
  if not Assigned (LZXinit) then
  begin
    raise Exception.Create('Couldnt find LZXinit function in DLL');
  end;
end;

function ReadBlockSize(Stream: TStream): LZXBlockSize;
var
  b0, b1, b2, b3, b4: Byte;
begin
 Stream.Read(b0,1);
 if b0 = $FF then
  begin
   Stream.Read(b1,1);
   Stream.Read(b2,1);
   Stream.Read(b3,1);
   Stream.Read(b4,1);
   Result.UnCompressedSize:= b2 or b1 shl 8; //(b1 shl 8)+b2;
   Result.CompressedSize:= b4 or b3 shl 8; //(b3 shl 8)+b4;
  end
 else
  begin
   Stream.Read(b1,1);
   Result.UnCompressedSize:= $8000;
   Result.CompressedSize:= b1 or b0 shl 8; //(b0 shl 8)+b1;
  end;
end;

procedure DecompressXCompress(Source: TStream; Dest: TStream; UncompressedSize: integer);
var
  //OutResult : integer;
  Identifier: byte;
  BlockSize: LZXBlockSize;
  pDataIn, pDataOut: PAnsiChar;
begin
  LZXinit(17);
  {Source.Read(Identifier, 1);
  if Identifier <> $FF then raise EXCompressDecompressionError.Create('Decompression Failed not XMemCompress compressed data'); //Always first byte FF?
  Source.Seek(-1, soFromCurrent);}

  while (Dest.Size <> UncompressedSize) do
  begin
   BlockSize:= ReadBlockSize(Source);
   GetMem(pDataIn, BlockSize.CompressedSize);
   try
     GetMem(pDataOut, BlockSize.UnCompressedSize);
     try
       Source.ReadBuffer(pDataIn^,BlockSize.CompressedSize);
       {OutResult :=} XDecompress(pDataIn, BlockSize.CompressedSize, pDataOut, BlockSize.UnCompressedSize);
       {if OutResult <> 0 then //Unsure about this, it seems to return 0 if uncompressed ok
       begin
        raise EXCompressDecompressionError.Create('XMemCompress Decompression Failed. Result was ' + inttostr(OutResult));
        end;}
       Dest.WriteBuffer(pDataOut^,BlockSize.UnCompressedSize);
     finally
      FreeMem(pDataOut, BlockSize.UnCompressedSize);
     end;
   finally
    FreeMem(pDataIn, BlockSize.CompressedSize);
   end;
  end;
  Dest.Position := 0;
end;

Initialization
  DllLib := nil;
finalization
  if DllLib <> nil then
    MemoryFreeLibrary(DllLib);

end.
