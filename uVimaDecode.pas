{
******************************************************
  DoubleFine Explorer
  By Bennyboy
  Http://quickandeasysoftware.net
******************************************************
}
{
  Vima decoder
  Original code by Jimmi Thøgersen (Serge)
  (Very) minor tweaks by Bennyboy 2015
}
unit uVimaDecode;

interface

uses
  classes, sysutils, uMemReader, uWaveWriter;

type
  TCodec =  (codecNULL, codecVIMA, codec0x0000, codec0x0001, codec0x0002, codec0x0003, codec0x000A, codec0x000B, codec0x000C, codec0x000D, codec0x000F, codecUnknown);

function DecompressIMCToStream(SourceStream: TExplorerMemoryStream; DestStream: TStream): boolean;

implementation

const
  IMCTable1Size = 89;
  IMCTable1 : array[0..IMCTable1Size-1] of word = (
    $0007,$0008,$0009,$000A,$000B,$000C,$000D,$000E,$0010,$0011,
    $0013,$0015,$0017,$0019,$001C,$001F,$0022,$0025,$0029,$002D,
    $0032,$0037,$003C,$0042,$0049,$0050,$0058,$0061,$006B,$0076,
    $0082,$008F,$009D,$00AD,$00BE,$00D1,$00E6,$00FD,$0117,$0133,
    $0151,$0173,$0198,$01C1,$01EE,$0220,$0256,$0292,$02D4,$031C,
    $036C,$03C3,$0424,$048E,$0502,$0583,$0610,$06AB,$0756,$0812,
    $08E0,$09C3,$0ABD,$0BD0,$0CFF,$0E4C,$0FBA,$114C,$1307,$14EE,
    $1706,$1954,$1BDC,$1EA5,$21B6,$2515,$28CA,$2CDF,$315B,$364B,
    $3BB9,$41B2,$4844,$4F7E,$5771,$602F,$69CE,$7462,$7FFF
    );

  IMCTable2Size = 89;
  IMCTable2 : array[0..IMCTable2Size-1] of byte = (
    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,
    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,
    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,
    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04,
    $04, $04, $04, $04, $04, $05, $05, $05, $05, $05,
    $05, $05, $05, $05, $05, $05, $05, $05, $05, $06,
    $06, $06, $06, $06, $06, $06, $06, $06, $06, $06,
    $06, $06, $06, $06, $07, $07, $07, $07, $07, $07,
    $07, $07, $07, $07, $07, $07, $07, $07, $07
    );

 IMCOtherTable1Size = 8;
  IMCOtherTable1 : array[0..IMCOtherTable1Size-1] of byte = (
    $FF, $04, $FF, $04, $00, $00, $00, $00 );
  IMCOtherTable2Size = 8;
  IMCOtherTable2 : array[0..IMCOtherTable2Size-1] of byte = (
    $FF, $FF, $02, $06, $FF, $FF, $02, $06 );
  IMCOtherTable3Size = 16;
  IMCOtherTable3 : array[0..IMCOtherTable3Size-1] of byte = (
    $FF, $FF, $FF, $FF, $01, $02, $04, $06,
    $FF, $FF, $FF, $FF, $01, $02, $04, $06 );
  IMCOtherTable4Size = 32;
  IMCOtherTable4 : array[0..IMCOtherTable4Size-1] of byte = (
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $01, $01, $01, $02, $02, $04, $05, $06,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $01, $01, $01, $02, $02, $04, $05, $06 );
  IMCOtherTable5Size = 64;
  IMCOtherTable5 : array[0..IMCOtherTable5Size-1] of byte = (
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $01, $01, $01, $01, $01, $02, $02, $02,
    $02, $04, $04, $04, $05, $05, $06, $06,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $01, $01, $01, $01, $01, $02, $02, $02,
    $02, $04, $04, $04, $05, $05, $06, $06 );
  IMCOtherTable6Size = 128;
  IMCOtherTable6 : array[0..IMCOtherTable6Size-1] of byte = (
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $01, $01, $01, $01, $01, $01, $01, $01,
    $01, $01, $02, $02, $02, $02, $02, $02,
    $02, $02, $04, $04, $04, $04, $04, $04,
    $05, $05, $05, $05, $06, $06, $06, $06,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,
    $01, $01, $01, $01, $01, $01, $01, $01,
    $01, $01, $02, $02, $02, $02, $02, $02,
    $02, $02, $04, $04, $04, $04, $04, $04,
    $05, $05, $05, $05, $06, $06, $06, $06 );

  Offsets : array[0..7] of pointer =
 (nil,
  nil,
  @IMCOtherTable1,
  @IMCOtherTable2,
  @IMCOtherTable3,
  @IMCOtherTable4,
  @IMCOtherTable5,
  @IMCOtherTable6
  );

function DecompressIMCToStream(SourceStream: TExplorerMemoryStream; DestStream: TStream): boolean;
type
  PCompInfo = ^TCompInfo;
  TCompInfo = record
    codec: TCodec;
    CompSize: cardinal;
    DecompSize: cardinal;
  end;
  THugeBuffer = array[0..$7FFFFFFF-1] of byte;
var
  DestTablePos : longint;
  DestTableStartPos: longint;
  Incer: longint;
  TableValue: longint;
  Count: longint;
  Put: word;
  DestTable: array[0..5785] of word;

  SBytes  : array[0..3] of byte;
  SWords  : array[0..3] of word;
  SourcePos: longint;
  DestPos: longint;
  SBytesPos: longint;
  SWordsPos: longint;
  CurrTablePos: longint;
  DecLength: longint;
  DestOffs: longint;
  SWordsOffs: longint;
  SourceBuffer: pointer;
  EntrySize: cardinal;
  NoOfEntries: cardinal;
  TableEntry: cardinal;
  DestPos_SWordsPos: cardinal;
  DecsToDo: cardinal;
  DecsLeft:cardinal;
  BytesToDec: cardinal;
  CurrTableVal: cardinal;
  var40: cardinal;
  NoOfEntriesDeced: cardinal;
  OutputWord: longint;
  Disp: longint;

  FRMTOffs, RIFFOffs: longint;
  DATAOffs: longint;
  DATASize: cardinal;
  BitsPerSample: cardinal;
  SampleRate: cardinal;
  Channels: cardinal;
  BytesPerSec: cardinal;
  BlockAlign: cardinal;
  NoOfCompEntries: cardinal;
  CompList: TList;
  CompInfo: PCompInfo;
  CodecNo: cardinal;
  CodecName: string;
  CodecPos: cardinal;
  CodecOffset: cardinal;
  n: cardinal;
  CurrSourcePos: cardinal;
  Buffer: pointer;
  BufferPos: cardinal;
  IMCTable1Pos: cardinal;
  PrevOffset: cardinal;

  WaveStream: TWaveStream;
begin
  result := false;

  try
    DestTablePos:=0;
    DestTableStartPos:=0;
    Incer:=0;
    repeat
      //Label3
      IMCTable1Pos:=0;
      repeat
        TableValue:=IMCTable1[IMCTable1Pos];
        Count:=32;
        Put:=0;
        repeat
          if (Incer and Count) <> 0 then
          begin
            Put:=Put+TableValue;
          end;
          TableValue:=TableValue shr 1;
          Count:=Count shr 1;
        until Count=0;
        DestTable[DestTablePos]:=Put and $0000FFFF;
//        DestTable[DestTablePos]:=word(Put);
        Inc(IMCTable1Pos);
        Inc(DestTablePos,64);
      until IMCTable1Pos>=IMCTable1Size;
      Inc(Incer);
      Inc(DestTableStartPos);
      DestTablePos:=DestTableStartPos;
    until DestTableStartPos>=64;


    SourceStream.Position := 0;
    if SourceStream.ReadBlockName <> 'MCMP' then
      exit;


    SourceStream.Position := 4;
    NoOfCompEntries:= SourceStream.ReadWordBE;
    CodecOffset:={Chunk.Offset+}NoOfCompEntries*9+8;
    CompList:=TList.Create;
    for n:=0 to NoOfCompEntries - 1 do
    begin
      CompInfo:=PCompInfo(new(PCompInfo));
      SourceStream.Position := 6+9*n;
      CodecNo:= SourceStream.ReadByte;
      CodecName:='';
      for CodecPos:=CodecOffset+CodecNo*5 to CodecOffset+CodecNo*5+3 do
      begin
        SourceStream.Position := CodecPos;
        CodecName:=CodecName+chr(SourceStream.ReadByte);
      end;
      if CodecName = 'VIMA' then
        CompInfo^.Codec:=codecVIMA;
      if CodecName = 'NULL' then
        CompInfo^.Codec:=codecNULL;
      if (CodecName <> 'NULL') and (CodecName <> 'VIMA') then
        CompInfo^.Codec:=codecUnknown;

      SourceStream.Position := 7+9*n;
      CompInfo^.DecompSize:= SourceStream.ReadDWordBE;
      SourceStream.Position := 11+9*n;
      CompInfo^.CompSize:= SourceStream.ReadDWordBE;
      CompList.Add(CompInfo);
    end;
    SourceStream.Position := CodecOffset-2;
    CurrSourcePos:=CodecOffset+ SourceStream.ReadWordBE;


    //Find the offsets of our 2 info blocks
    FRMTOffs:= SourceStream.FindFileHeader('FRMT', 0, SourceStream.Size);
    RIFFOffs := SourceStream.FindFileHeader('RIFF', 0, SourceStream.Size);

    if FRMTOffs > -1 then
    begin
      SourceStream.Position := FRMTOffs+16;
      BitsPerSample:= SourceStream.ReadDWordBE;
      SourceStream.Position := FRMTOffs+20;
      SampleRate:= SourceStream.ReadDWordBE;
      SourceStream.Position := FRMTOffs+24;
      Channels:= SourceStream.ReadDWordBE;
    end
    else
    if RIFFOffs>-1 then  //Speech files use RIFF block
    begin
       SourceStream.Position := RIFFOffs+22;
      Channels:= SourceStream.ReadByte;
      SourceStream.Seek(1, soFromCurrent);
      SampleRate := SourceStream.ReadDWord;
      SourceStream.Seek(6, soFromCurrent);
      BitsPerSample := SourceStream.ReadByte;
    end
    else //Assume these values as no FRMT or RIFF blocks
    begin
      BitsPerSample:=16;
      SampleRate:=22050;
      Channels:=2;
    end;

    WaveStream := TWaveStream.Create(DestStream, Channels, BitsPerSample, SampleRate);


    try
    for n:=0 to CompList.Count-1 do
    begin
      CompInfo:=CompList.Items[n];
      Buffer:=AllocMem(CompInfo^.DecompSize);
      case CompInfo^.Codec of
        codecNULL : begin
                      for BufferPos:=0 to CompInfo^.CompSize - 1 do
                      begin
                        SourceStream.Position := CurrSourcePos+BufferPos;
                        THugeBuffer(Buffer^)[BufferPos]:= SourceStream.ReadByte;
                      end;
                    end;
        codecVIMA : begin
                      SourceBuffer:=AllocMem(CompInfo^.CompSize);
                      for BufferPos:=0 to CompInfo^.CompSize - 1 do
                      begin
                        SourceStream.Position := CurrSourcePos+BufferPos;
                        THugeBuffer(SourceBuffer^)[BufferPos]:= SourceStream.ReadByte;
                      end;
                      DecLength:=CompInfo^.DecompSize;
                      DestOffs:=integer(Buffer);
                      asm
                        PUSH    esp
                        PUSH    ebp
                        PUSH    ebx
                        PUSH    esi
                        PUSH    edi

                        MOV     ecx,SourceBuffer
                        MOV     esi,1
                        MOV     al,[ecx]
                        INC     ecx
                        TEST    al,al
                        MOV     byte ptr SBytes[0],al
                        JGE     @ReadWords
                        NOT     al
                        MOV     byte ptr SBytes[0],al
                        MOV     esi,2

                        @ReadWords:
                        MOV     ax,[ecx]
                        XOR     edx,edx
                        MOV     dh,al
                        ADD     ecx,2
                        MOV     dl,ah
                        CMP     esi,1
                        MOV     word ptr SWords[0],dx
                        JBE     @OneWord
                        MOV     al,[ecx]
                        INC     ecx
                        MOV     byte ptr SBytes[1],al
                        XOR     edx,edx
                        MOV     ax,[ecx]
                        ADD     ecx,2
                        MOV     dh,al
                        MOV     dl,ah
                        MOV     word ptr SWords[2],dx

                        @OneWord:
                        MOV     eax,DecLength
                        MOV     CurrTablePos,1
                        MOV     EntrySize,esi
                        ADD     esi,esi
                        XOR     edx,edx
                        DIV     esi
                        MOV     DecsToDo,eax
                        MOV     SourcePos,ecx

                        XOR     ebx,ebx

                        MOV     eax,CurrTablePos
                        XOR     edi,edi
                        CMP     eax,edi
                        JNZ     @Label1
                        MOV     SBytes[1],0
                        MOV     SBytes[0],0
                        MOV     word ptr SWords[2],di
                        MOV     word ptr SWords[0],di

                        @Label1:
                        MOV     esi,SourcePos
                        MOV     edx,EntrySize
                        XOR     ecx,ecx
                        MOV     ch,[esi]
                        LEA     eax,[esi+1]
                        XOR     esi,esi
                        MOV     cl,[eax]
                        INC     eax
                        CMP     edx,edi
                        MOV     TableEntry,ecx
                        MOV     SourcePos,eax
                        MOV     SBytesPos,esi
                        JBE     @ExitMainDec
                        MOV     edi,DestOffs
                        LEA     eax,SWords
                        SUB     edi,eax
                        MOV     SWordsPos,eax
                        MOV     DestPos_SWordsPos,edi

                        @NextByte:
                        LEA     ecx,[edi+eax]
                        MOV     DestPos,ecx
                        MOVSX   ecx,byte ptr SBytes[esi]
                        MOV     CurrTablePos, ecx
                        MOVSX   ecx, word ptr [eax]
                        MOV     OutputWord,ecx
                        MOV     ecx,DecsToDo
                        TEST    ecx,ecx
                        JZ      @Done
                        ADD     edx,edx
                        MOV     DecsLeft,ecx
                        MOV     BytesToDec,edx

                        @NextDec:
                        MOV     eax,CurrTablePos
                        MOV     edx,1
                        MOV     cl,byte ptr IMCTable2[eax]
                        MOV     byte ptr CurrTableVal,cl
                        MOV     esi,CurrTableVal
                        AND     esi,$FF
                        ADD     ebx,esi
                        LEA     ecx,[esi-1]
                        MOV     DestOffs,ebx
                        SHL     edx,cl
                        MOV     cl,$10
                        SUB     cl,bl
                        MOV     al,dl
                        DEC     al
                        MOV     byte ptr var40,al
                        MOV     eax,TableEntry
                        MOV     edi,var40
                        AND     eax,$FFFF
                        SHR     eax,cl
                        AND     edi,$FF
                        MOV     ecx,edx
                        OR      ecx,edi
                        AND     eax,ecx
                        CMP     ebx,7
                        JLE     @Label2
                        MOV     ebx,SourcePos
                        XOR     ecx,ecx
                        MOV     ch,byte ptr TableEntry
                        MOVZX   bx,byte ptr [ebx]
                        OR      ecx,ebx
                        MOV     ebx,SourcePos
                        INC     ebx
                        MOV     TableEntry,ecx
                        MOV     SourcePos,ebx
                        MOV     ebx,DestOffs
                        SUB     ebx,8
                        MOV     DestOffs,ebx
                        JMP     @Label3

                        @Label2:
                        MOV     ecx,TableEntry

                        @Label3:
                        TEST    eax,edx
                        JZ      @ClearEDX
                        XOR     eax,edx
                        JMP     @NoClear

                        @ClearEDX:
                        XOR     edx,edx

                        @NoClear:
                        CMP     eax,edi
                        JNZ     @Label4
                        MOV     edx,ecx
                        MOV     ecx,ebx
                        SHL     edx,cl
                        MOV     ecx,SourcePos
                        MOVZX   di,byte ptr [ecx]
                        PUSH    ecx
                        //MOVSX  ebp,dx
                        MOVSX   ecx,dx
                        XOR     edx,edx
                        AND     ecx,$FFFFFF00
                        MOV     OutputWord,ecx
                        POP     ecx
                        MOV     dh,byte ptr TableEntry
                        OR      edx,edi
                        INC     ecx
                        MOV     SourcePos,ecx
                        MOV     cx,8
                        SUB     cx,bx
                        MOV     edi,edx
                        SHR     di,cl
                        XOR     ecx,ecx
                        MOV     ebx,DestOffs
                        MOV     ch,dl
                        MOV     edx,ecx
                        MOV     ecx,SourcePos
                        AND     edi,$FF
                        PUSH    ecx
                        // OR     ebp,edi
                        MOV     ecx,OutputWord
                        OR      ecx,edi
                        MOV     OutputWord,ecx
                        POP     ecx
                        MOVZX   di,byte ptr [ecx]

                        OR      edx,edi
                        INC     ecx
                        MOV     TableEntry,edx
                        MOV     SourcePos,ecx
                        JMP     @WriteDec

                        @Label4:
                        MOV     ecx,7
                        MOV     edi,eax
                        SUB     ecx,esi
                        SHL     edi,cl
                        MOV     ecx,CurrTablePos
                        SHL     ecx,6
                        OR      edi,ecx
                        XOR     ecx,ecx
                        TEST    eax,eax
                        MOV     cx,word ptr DestTable[edi*2]
                        MOV     DestOffs,ecx
                        JZ      @Label5
                        MOV     edi,CurrTablePos
                        XOR     ecx,ecx
                        MOV     cx,word ptr IMCTable1[edi*2]
                        MOV     edi,ecx
                        LEA     ecx,[esi-1]
                        SHR     edi,cl
                        MOV     ecx,DestOffs
                        ADD     ecx,edi

                        @Label5:
                        TEST    edx,edx
                        JZ      @Label6
                        NEG     ecx

                        @Label6:
                        MOV     edx,OutputWord
                        ADD     edx,ecx
                        CMP     edx,$FFFF8000
                        JGE     @Label7
                        MOV     edx,$FFFF8000
                        MOV     OutputWord,edx
                        JMP     @WriteDec

                        @Label7:
                        CMP     edx,$7FFF
                        MOV     OutputWord,edx
                        JLE     @WriteDec
                        MOV     edx,$7FFF
                        MOV     OutputWord,edx

                        @WriteDec:
                        MOV     ecx,DestPos
                        MOV     edx,BytesToDec
                        PUSH    eax
                        MOV     eax,OutputWord
                        MOV     [ecx],ax
                        ADD     ecx,edx
                        MOV     edx,dword ptr Offsets[esi*4]
                        MOV     DestPos,ecx
                        MOV     ecx,CurrTablePos
                        POP     eax
                        MOVSX   eax,byte ptr [edx+eax]
                        ADD     ecx,eax
                        MOV     CurrTablePos,ecx
                        JNS     @Label8
                        MOV     CurrTablePos,0
                        JMP     @Done

                        @Label8:
                        MOV     ecx,CurrTablePos
                        MOV     eax,$58
                        CMP     ecx,eax
                        JLE     @Done
                        MOV     CurrTablePos,eax

                        @Done:
                        MOV     eax,DecsLeft
                        DEC     eax
                        MOV     DecsLeft,eax
                        JNZ     @NextDec
                        MOV     edx,EntrySize
                        MOV     esi,SBytesPos
                        MOV     eax,SWordsPos
                        MOV     edi,DestPos_SWordsPos
                        MOV     cl,byte ptr CurrTablePos
                        ADD     eax,2
                        MOV     byte ptr SBytes[esi],cl
                        PUSH    ebx
                        MOV     ebx,OutputWord
                        MOV     [eax-2],bx
                        POP     ebx
                        INC     esi
                        MOV     SWordsPos,eax
                        CMP     esi,edx
                        MOV     SBytesPos,esi
                        JB      @NextByte

                        @ExitMainDec:
                        POP     edi
                        POP     esi
                        POP     ebx
                        POP     ebp
                        POP     esp
                      end;
                      FreeMem(SourceBuffer);
                    end;
      end;
      Inc(CurrSourcePos,CompInfo^.CompSize);
      if (n>0) {or (UpperCase(ExtractFileExt(InputFileName))='.WAV')} then
        WaveStream.Write(Buffer^,CompInfo^.DecompSize);
      FreeMem(Buffer);
    end;
    finally
      WaveStream.Free;
      result := true;
    end;

    for n:=0 to CompList.Count-1 do
    begin
      CompInfo:=CompList.Items[n];
      Dispose(CompInfo);
    end;
    CompList.Free;
  finally
    //MainForm.StatusBar.Panels[0].GaugeAttrs.Position:=0;
    //MainForm.Status(0,' ');
    //Screen.Cursor:=crDefault;
  end;
end;

end.
