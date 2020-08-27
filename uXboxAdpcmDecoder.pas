{
  TXboxAdpcmDecoder class
  (c) 2005 Benjamin Haisch

  Revision 2 with stereo support

}

unit uXboxAdpcmDecoder;

interface

uses
  Classes, SysUtils;

type
  TAdpcmState = packed record
    Index, StepSize: Integer;
    Predictor: SmallInt;
  end;
  TXboxAdpcmDecoder = class
  private
    FChannels,
    FBlockSize: Word;
    FAdpcmState: array[0..1] of TAdpcmState;
    function DecodeSample(Code: Byte; var State: TAdpcmState): Integer;
  public
    constructor Create(AChannels: Word);
    destructor Destroy; override;

    procedure Decode(ASource, ADest: TStream; SourcePos, SourceSize: integer);

  end;

implementation

const
  StepTable: array[0..88] of Integer = (
    $7, $8, $9, $0A, $0B, $0C, $0D, $0E, $10, $11, $13, $15, $17, $19, $1C,
    $1F, $22, $25, $29, $2D, $32, $37, $3C, $42, $49, $50, $58, $61, $6B,
    $76, $82, $8F, $9D, $0AD, $0BE, $0D1, $0E6, $0FD, $117, $133, $151,
    $173, $198, $1C1, $1EE, $220, $256, $292, $2D4, $31C, $36C, $3C3,
    $424, $48E, $502, $583, $610, $6AB, $756, $812, $8E0, $9C3, $0ABD,
    $0BD0, $0CFF, $0E4C, $0FBA, $114C, $1307, $14EE, $1706, $1954, $1BDC,
    $1EA5, $21B6, $2515, $28CA, $2CDF, $315B, $364B, $3BB9, $41B2, $4844,
    $4F7E, $5771, $602F, $69CE, $7462, $7FFF
  );

  IndexTable: array[0..15] of Integer =(
    -1, -1, -1, -1, 2, 4, 6, 8,
    -1, -1, -1, -1, 2, 4, 6, 8
  );

constructor TXboxAdpcmDecoder.Create(AChannels: Word);
begin
  case AChannels of
    1: FBlockSize := $20;
    2: FBlockSize := $40;
  end;
  FChannels := AChannels;
end;

destructor TXboxAdpcmDecoder.Destroy;
begin
end;

procedure TXboxAdpcmDecoder.Decode(ASource, ADest: TStream; SourcePos, SourceSize: integer);
var
  i, j: Integer;
  Channel: Byte;
  CodeBuf: Cardinal;
  Buffers: array[0..1] of array[0..7] of SmallInt;

  procedure PrepareAdpcmState(var AdpcmState: TAdpcmState);
  begin
    AdpcmState.Predictor := 0;
    AdpcmState.Index := 0;
    ASource.Read(AdpcmState.Predictor, 2);
    ASource.Read(AdpcmState.Index, 1);
    ASource.Seek(1, soFromCurrent);
    ADest.Write(AdpcmState.Predictor, 2);
    AdpcmState.StepSize := StepTable[AdpcmState.Index];
  end;

begin
  while ASource.Position < SourcePos + SourceSize do begin
    // read the adpcm header
    PrepareAdpcmState(FAdpcmState[0]);
    if FChannels = 2 then
      PrepareAdpcmState(FAdpcmState[1]);
    // decode the stuff
    for i := 0 to 7 do begin
      // decode channel 1 data
      Channel := 0;
      ASource.Read(CodeBuf, 4);
      for j := 0 to 7 do begin
        Buffers[Channel,j] := DecodeSample(CodeBuf and $0F, FAdpcmState[Channel]);
        CodeBuf := CodeBuf shr 4;
      end;
      // decode channel 2 data if available
      if FChannels = 2 then begin
        Channel := 1;
        ASource.Read(CodeBuf, 4);
        for j := 0 to 7 do begin
          Buffers[Channel,j] := DecodeSample(CodeBuf and $0F, FAdpcmState[Channel]);
          CodeBuf := CodeBuf shr 4;
        end;
      end;
      // write the decoded samples
      for j := 0 to 7 do begin
        ADest.Write(Buffers[0,j], 2);
        if FChannels = 2 then
          ADest.Write(Buffers[1,j], 2);
      end;
    end;
  end;
end;

function TXboxAdpcmDecoder.DecodeSample(Code: Byte; var State: TAdpcmState): Integer;
var
  Delta: Integer;
begin
  // get the delta value
  Delta := 0;
  if Code and 4 = 4 then Inc(Delta, State.StepSize);
  if Code and 2 = 2 then Inc(Delta, State.StepSize shr 1);
  if Code and 1 = 1 then Inc(Delta, State.StepSize shr 2);
  Inc(Delta, State.StepSize shr 3);
  // sign bit set?
  if Code and 8 = 8 then Delta := -Delta;
  Result := State.Predictor + Delta;
  // clip the sample
  if Result > High(SmallInt) then
    Result := High(SmallInt)
  else if Result < Low(SmallInt) then
    Result := Low(SmallInt);
  Inc(State.Index, IndexTable[Code]);
  // clip the index
  if State.Index < 0 then State.Index := 0
  else if State.Index > 88 then State.Index := 88;
  // get the new stepsize
  State.StepSize := StepTable[State.Index];
  State.Predictor := Result;
end;

end.

