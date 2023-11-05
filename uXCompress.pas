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

  XMEMCODEC_TYPE = ( XMEMCODEC_DEFAULT = 0, XMEMCODEC_LZX = 1 );
  XMEMCODEC_PARAMETERS_LZX = packed record
    Flags: Integer;
    WindowSize: Integer;
    CompressionPartitionSize: Integer;
  end;

var
  DllLib : PMemoryModule;
  XMemCreateDecompressionContext: function(CodecType: XMEMCODEC_TYPE; pCodecParams: Pointer; Flags: Integer; pContext: PInteger): HRESULT; stdcall;
  XMemDestroyDecompressionContext: procedure (Context: Integer); stdcall;
  XMemResetDecompressionContext: function(Context: Integer): HRESULT; stdcall;
  XMemDecompressStream: function(Context: Integer; pDestination: Pointer; pDestSize: PInteger; pSource: Pointer; pSrcSize: PInteger): HRESULT; stdcall;


  XDecompress: function(inData: PAnsiChar;  inlen: integer;  outdata: PAnsiChar;  outlen: integer): integer; cdecl;
  LZXinit: function (window: integer): Integer; cdecl;
  procedure XCompress_Load_DLL;
  procedure DecompressXCompress_Old(Source: TStream; Dest: TStream; UncompressedSize: integer);
  procedure DecompressXCompress(Source: TStream; Dest: TStream; CompressedSize, UncompressedSize: integer);



const
  XMEMCOMPRESS_STREAM = $00000001;

implementation

procedure XCompress_Load_DLL;
var
  ResStream: TResourceStream;
begin
  if DllLib <> nil then
    exit; //already loaded

  //Load it from resource into memory
  ResStream := TResourceStream.Create(hInstance, 'xcompressdll', RT_RCDATA);
  try
    ResStream.Position := 0;
    if MemoryLoadLibrary(ResStream.Memory, DLLLib) < 0 then
    begin
      raise Exception.Create('XCompress dll load failed!');
      exit;
    end;
  finally
    ResStream.Free;
  end;



  {XDecompress := MemoryGetProcAddress(DllLib, PAnsiChar('LZXdecompress'));
  if not Assigned (XDecompress) then
  begin
    raise Exception.Create('Couldnt find decompression function in DLL');
  end;

  LZXinit := MemoryGetProcAddress(DllLib, PAnsiChar('LZXinit'));
  if not Assigned (LZXinit) then
  begin
    raise Exception.Create('Couldnt find LZXinit function in DLL');
  end;}

  XMemCreateDecompressionContext := MemoryGetProcAddress(DllLib, PAnsiChar('XMemCreateDecompressionContext'));
  if not Assigned (XMemCreateDecompressionContext) then
  begin
    raise Exception.Create('Couldnt find XMemCreateDecompressionContext function in DLL');
  end;

  XMemDestroyDecompressionContext := MemoryGetProcAddress(DllLib, PAnsiChar('XMemDestroyDecompressionContext'));
  if not Assigned (XMemDestroyDecompressionContext) then
  begin
    raise Exception.Create('Couldnt find XMemDestroyDecompressionContext function in DLL');
  end;

  XMemResetDecompressionContext := MemoryGetProcAddress(DllLib, PAnsiChar('XMemResetDecompressionContext'));
  if not Assigned (XMemResetDecompressionContext) then
  begin
    raise Exception.Create('Couldnt find XMemResetDecompressionContext function in DLL');
  end;

  XMemDecompressStream := MemoryGetProcAddress(DllLib, PAnsiChar('XMemDecompressStream'));
  if not Assigned (XMemDecompressStream) then
  begin
    raise Exception.Create('Couldnt find XMemDecompressStream function in DLL');
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

procedure DecompressXCompress_Old(Source: TStream; Dest: TStream; UncompressedSize: integer);
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

procedure DecompressXCompress(Source: TStream; Dest: TStream; CompressedSize, UncompressedSize: integer);
var
 Contex: Integer;
 Result: HRESULT;
 codec_parameters: XMEMCODEC_PARAMETERS_LZX;
 pSource, pDest: Pointer;
 dwInSize, dwOutSize: DWORD;
 tmp: integer;
begin
   Contex:=0;
   Result:= XMemCreateDecompressionContext(XMEMCODEC_LZX, @codec_parameters, XMEMCOMPRESS_STREAM, @Contex);
   if Succeeded(Result) then
    begin
      Result:= XMemResetDecompressionContext(Contex);
      dwInSize := CompressedSize;
      dwOutSize := UncompressedSize;
      GetMem(pSource, dwInSize);
      ZeroMemory(pSource, dwInSize);
      Source.Read(pSource^, dwInSize);
      pDest:= GetMemory(dwOutSize);
      ZeroMemory(pDest, dwOutSize);
      tmp:=dwOutSize;
      Result:= XMemDecompressStream(Contex, pDest, @dwOutSize, pSource, @dwInSize);
      if Succeeded(Result) then
        begin
          dwOutSize:=tmp;
          Dest.Write(pDest^, dwOutSize);
          FreeMemory(pDest);
          FreeMemory(pSource);
        end;
      XMemDestroyDecompressionContext(Contex);
      Dest.Position := 0;
    end;
end;

Initialization
  DllLib := nil;
finalization
  if DllLib <> nil then
    MemoryFreeLibrary(DllLib);

end.
