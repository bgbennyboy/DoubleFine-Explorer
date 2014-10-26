//Taken from MP3FileUtils by Daniel Gaussmann http://www.gausi.de/
//

unit uMPEGHeaderCheck;

interface
type
    TMpegHeader = record
    version: byte;
    layer: byte;
    protection: boolean;
    bitrate: LongInt;
    samplerate: LongInt;
    channelmode: byte;
    extension: byte;
    copyright: boolean;
    original: boolean;
    emphasis: byte;
    padding: boolean;
    framelength: word;
    valid: boolean;
  end;

  TBuffer = Array of byte;

  const
  MPEG_BIT_RATES : array[1..3] of array[1..3] of array[0..15] of word =
    { Version 1, Layer I }
      (((0,32,64,96,128,160,192,224,256,288,320,352,384,416,448,0),
    { Version 1, Layer II }
      (0,32,48,56, 64, 80, 96,112,128,160,192,224,256,320,384,0),
    { Version 1, Layer III }
      (0,32,40,48, 56, 64, 80, 96,112,128,160,192,224,256,320,0)),
    { Version 2, Layer I }
      ((0,32,48, 56, 64, 80, 96,112,128,144,160,176,192,224,256,0),
    { Version 2, Layer II }
      (0, 8,16,24, 32, 40, 48, 56, 64, 80, 96, 112,128,144,160,0),
    { Version 2, Layer III }
      (0, 8,16,24, 32, 40, 48, 56, 64, 80, 96, 112,128,144,160,0)),
    { Version 2.5, Layer I }
      ((0,32,48, 56, 64, 80, 96,112,128,144,160,176,192,224,256,0),
    { Version 2.5, Layer II }
      (0, 8,16,24, 32, 40, 48, 56, 64, 80, 96, 112,128,144,160,0),
    { Version 2.5, Layer III }
      (0, 8,16,24, 32, 40, 48, 56, 64, 80, 96, 112,128,144,160,0)));

    sample_rates: array[1..3] of array [0..3] of word=
      ((44100,48000,32000,0),
      (22050,24000,16000,0),
      (11025,12000,8000,0));

  function GetFramelength(version:byte;layer:byte;bitrate:longint;Samplerate:longint;padding:boolean):integer;
  function GetValidatedHeader(aBuffer: TBuffer; position: integer): TMpegheader;

implementation

function GetFramelength(version:byte;layer:byte;bitrate:longint;Samplerate:longint;padding:boolean):integer;
begin
  if samplerate=0 then result := -2
  else
    if Layer=1 then
      result := trunc(12*bitrate*1000 / samplerate+Integer(padding)*4)
    else
      if Version = 1 then
        result :=  144 * bitrate * 1000 DIV samplerate + integer(padding)
      else
        result := 72 * bitrate * 1000 DIV samplerate + integer(padding)

end;

function GetValidatedHeader(aBuffer: TBuffer; position: integer): TMpegheader;
var bitrateindex, versionindex: byte;
    samplerateindex:byte;
    tmpLength: Integer;
begin
  // a mpeg-header starts with 11 (eleven) bits
  if (abuffer[position]<>$FF) OR (abuffer[position+1]<$E0)
  then
  begin
    result.valid := False;
    exit;
  end;

  //Byte 1 and 2: AAAAAAAA AAABBCCD
  //A=1 (11 Sync bytes) at the beginning
  //B: version, normally BB=11 (=MPEG1, Layer3), but some others are allowed
  //C: Layer, for layer III is CC=01
  //D: Protection BIT. If set, the header is followed by a 16bit CRC
  Versionindex := (abuffer[position+1] shr 3) and 3;
  case versionindex of
      0: result.version := 3; //version 2.5 actually - but I need an array-index. ;-)
      1: result.version := 0; //Reserved
      2: result.version := 2;
      3: result.version := 1;
  end;
  result.Layer := 4-((abuffer[position+1] shr 1) and 3);
  result.protection := (abuffer[position+1] AND 1)=0;

  // --->
  // bugfix by terryk from delphi-forum.de
  if (Result.version = 0) or (Result.Layer = 4) then
  begin
    Result.valid := False;
    Exit;
  end;
  // <---

  // Byte 3: EEEEFFGH
  // E: Bitrate-index
  // F: Samplerate-index
  // G: Padding bit
  // H: Private bit
  bitrateindex := (abuffer[position+2] shr 4) AND $F;
  result.bitrate := MPEG_BIT_RATES[result.version][result.layer][bitrateindex];
  if bitrateindex=$F then
  begin
    result.valid := false; // Bad Value !
    exit;
  end;
  samplerateindex := (abuffer[position+2] shr 2) AND $3;
  result.samplerate := sample_rates[result.version][samplerateindex];
  result.padding := ((abuffer[position+2] shr 1) AND $1) = 1;

  // Byte 4: IIJJKLMM
  // I: Channel mode
  // J: Mode extension (for Joint Stereo)
  // K: copyright
  // L: original
  // M: Emphasis   =0 in most cases
  result.channelmode := ((abuffer[position+3] shr 6) AND 3);
  result.extension := ((abuffer[position+3] shr 4) AND 3);
  result.copyright := ((abuffer[position+3] shr 3) AND 1)=1;
  result.original := ((abuffer[position+3] shr 2) AND 1)=1;
  result.emphasis := (abuffer[position+3] AND 3);

  // "For Layer II there are some combinations of bitrate and mode which are not allowed."
  if result.layer=2 then
      if ((result.bitrate=32) AND (result.channelmode<>3))
          OR ((result.bitrate=48) AND (result.channelmode<>3))
          OR ((result.bitrate=56) AND (result.channelmode<>3))
          OR ((result.bitrate=80) AND (result.channelmode<>3))
          OR ((result.bitrate=224) AND (result.channelmode=3))
          OR ((result.bitrate=256) AND (result.channelmode=3))
          OR ((result.bitrate=320) AND (result.channelmode=3))
          OR ((result.bitrate=384) AND (result.channelmode=3))
      then begin
        result.valid := false;
        exit;
      end;

  // calculate framelength
  tmpLength := GetFramelength(result.version, result.layer,
                              result.bitrate,
                              result.Samplerate,
                              result.padding);

  if tmpLength > 0 then
  begin
      result.valid := True;
      result.framelength := Word(tmpLength);
  end else
  begin
      result.valid := false;
      result.framelength := high(word);
  end;

end;
end.
