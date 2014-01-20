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

unit uDFExplorer_Base;

interface

uses
  Classes, sysutils, windows, graphics,

  GR32, ImagingComponents, ZlibExGz,

  uDFExplorer_Types, uDFExplorer_BaseBundleManager, uMemReader, uDFExplorer_Funcs,
  uDFExplorer_FSBManager, uDFExplorer_PAKManager, uDFExplorer_PCKManager;

type
  TDFExplorerBase = class
private
  fOnDebug: TDebugEvent;
  fOnProgress: TProgressEvent;
  fOnDoneLoading: TOnDoneLoading;
  fBundle: TBundleManager;
  fBundleFilename: string;
  function GetFileName(Index: integer): string;
  function GetFileSize(Index: integer): integer;
  function GetFileOffset(Index: integer): integer;
  function GetFileType(Index: integer): TFiletype;
  function GetFileExtension(Index: integer): string;
  function DrawImage(MemStream: TMemoryStream; OutImage: TBitmap32): boolean;
  procedure Log(Text: string);
  function WriteDDSToStream(SourceStream, DestStream: TStream): boolean;
public
  constructor Create(BundleFile: string; Debug: TDebugEvent);
  destructor Destroy; override;
  function DrawImageGeneric(FileIndex: integer; DestBitmap: TBitmap32): boolean;
  function DrawImageDDS(FileIndex: integer; DestBitmap: TBitmap32): boolean;
  function SaveDDSToFile(FileIndex: integer; DestDir, FileName: string): boolean;
  procedure Initialise;
  procedure SaveFile(FileNo: integer; DestDir, FileName: string);
  procedure SaveFiles(DestDir: string);
  procedure SaveFileToStream(FileNo: integer; DestStream: TStream);
  procedure ReadText(FileIndex: integer; DestStrings: TStrings);
  procedure ReadCSVText(FileIndex: integer; DestStrings: TStrings);
  procedure ReadDelimitedText(FileIndex: integer; DestStrings: TStrings);
  property OnDebug: TDebugEvent read FOnDebug write FOnDebug;
  property OnDoneLoading: TOnDoneLoading read FOnDoneLoading write FOnDoneLoading;
  property OnProgress: TProgressEvent read FOnProgress write FOnProgress;
  property FileName[Index: integer]: string read GetFileName;
  property FileSize[Index: integer]: integer read GetFileSize;
  property FileOffset[Index: integer]: integer read GetFileOffset;
  property FileType[Index: integer]: TFileType read GetFileType;
  property FileExtension[Index: integer]: string read GetFileExtension;
end;

implementation


constructor TDFExplorerBase.Create(BundleFile: string; Debug: TDebugEvent);
begin
  OnDebug:=Debug;
  fBundleFilename:=BundleFile;

  try
    if Uppercase( ExtractFileExt(BundleFile) ) = '.FSB' then
      fBundle:=TFSBManager.Create(BundleFile)
    else
    if Uppercase( ExtractFileExt(BundleFile) ) = '.PCK' then
      fBundle:=TPCKManager.Create(BundleFile)
    else
      fBundle:=TPAKManager.Create(BundleFile);
  except on E: EInvalidFile do
    raise;
  end;

end;

destructor TDFExplorerBase.Destroy;
begin
  if fBundle <> nil then
    FreeandNil(fBundle);

  inherited;
end;

//Deal with delimited text and format it nicely
procedure TDFExplorerBase.ReadDelimitedText(FileIndex: integer;
  DestStrings: TStrings);

  function GetIndent(IndentLevel: integer): String; inline;
  var
    i: integer;
  begin
    result :='';
    for i := 0 to IndentLevel - 1 do
      result := result + '    ';//chr(9); //tab
  end;

var
  TempStream: TExplorerMemoryStream;
  TextLen, i, IndentLevel, SquareBracketLevel: integer;
  TempStr: String;
  SourceStr: AnsiString;
begin
  TempStream:=TExplorerMemoryStream.Create;
  DestStrings.BeginUpdate;
  try
    fBundle.SaveFileToStream(Fileindex, TempStream);
    TextLen := TempStream.ReadDWord;
    Sourcestr :='';
    SourceStr := TempStream.ReadAnsiString(TextLen);

    IndentLevel := 0;
    SquareBracketLevel := 0;
    TempStr := '';
    for I := 0 to Length(SourceStr) - 1 do
    begin
      //Remove the 1 character at the start of every file
      if (i=1) and (SourceStr[i] = '1') then
      begin
        //Swallow it and do nothing
        continue;
      end
      else
      if SourceStr[i] = '{' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        DestStrings.Add(GetIndent(IndentLevel) + '{');
        inc(IndentLevel);
      end
      else
      if SourceStr[i] = '}' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        dec(IndentLevel);
        DestStrings.Add(GetIndent(IndentLevel) + '}');
      end
      else
      if SourceStr[i] = '[' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        DestStrings.Add(GetIndent(IndentLevel) + '[');
        inc(IndentLevel);
        inc(SquareBracketLevel);
      end
      else
      if SourceStr[i] = ']' then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;

        dec(IndentLevel);
        DestStrings.Add(GetIndent(IndentLevel) + ']');
        dec(SquareBracketLevel);
      end
      else
      if SourceStr[i] = ';' then //new line
      begin
        DestStrings.Add(GetIndent(IndentLevel) + TempStr);
        TempStr := '';
      end
      else
      if SourceStr[i] = #0 then
        //ignore newline char
        continue
      else
      if (SquareBracketLevel > 0) and (SourceStr[i] = ',')  then
      begin
        //First add any previous string if there is one
        if Length(TempStr) > 0 then
        begin
          DestStrings.Add(GetIndent(IndentLevel) + TempStr);
          TempStr := '';
        end;
        //Swallow the comma so its a newline
      end
      else
        Tempstr := TempStr + String(SourceStr[i]);

    end;

  finally
    TempStream.Free;
    DestStrings.EndUpdate;
  end;
end;

procedure TDFExplorerBase.ReadText(FileIndex: integer; DestStrings: TStrings);
var
  TempStream: TExplorerMemoryStream;
begin
  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(Fileindex, TempStream);
    DestStrings.LoadFromStream(TempStream);
  finally
    TempStream.Free;
  end;
end;

procedure TDFExplorerBase.ReadCSVText(FileIndex: integer;
  DestStrings: TStrings);
var
  TempStream: TExplorerMemoryStream;
begin
  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(Fileindex, TempStream);
    DestStrings.LoadFromStream(TempStream);
    DestStrings.CommaText := DestStrings.Text; //Probably very slow but...
  finally
    TempStream.Free;
  end;

end;

function TDFExplorerBase.DrawImage(MemStream: TMemoryStream;
  OutImage: TBitmap32): boolean;
var
  ImgBitmap : TImagingBitmap;
begin
  Result := false;
  MemStream.Position:=0;

  ImgBitmap := TImagingBitmap.Create;
  try
    ImgBitmap.LoadFromStream(MemStream);
    if ImgBitmap.Empty then
      Exit;

    OutImage.Assign(ImgBitmap);
    Result := true;
  finally
    ImgBitmap.Free;
  end;
end;

function TDFExplorerBase.DrawImageDDS(FileIndex: integer;
  DestBitmap: TBitmap32): boolean;
var
  TempStream, DDSStream: TExplorerMemoryStream;
begin
  Result:=false;

  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(FileIndex, TempStream);
    TempStream.Position:=0;

    DDSStream:=TExplorerMemoryStream.Create;
    try
      WriteDDSToStream(Tempstream, DDSStream);

      DestBitmap.Clear();
      destbitmap.CombineMode:=cmBlend;
      destBitmap.DrawMode:=dmOpaque;
      if DrawImage(DDSStream, DestBitmap)=false then
      begin
        Log('DDS Decode failed! ' + fBundle.FileName[FileIndex]);
        Exit;
      end;

      Result:=true;
    finally
      DDSStream.Free;
    end;
  finally
    TempStream.Free;
  end;
end;

function TDFExplorerBase.WriteDDSToStream(SourceStream, DestStream: TStream): boolean;
var
  DDSnum: dword;  //542327876 = 'DDS '
begin
  result := false;
  SourceStream.Position := 40;
  SourceStream.Read(DDSnum, 4);
  if DDSnum = 542327876 then
  begin
    SourceStream.Seek(-4, soFromCurrent);
    DestStream.CopyFrom(SourceStream, SourceStream.Size - Sourcestream.Position);
    result := true;
  end
  else
  begin
    SourceStream.Position := 68;
    SourceStream.Read(DDSnum, 4);
    if DDSnum = 542327876 then
    begin
      SourceStream.Seek(-4, soFromCurrent);
      DestStream.CopyFrom(SourceStream, SourceStream.Size - Sourcestream.Position);
      result := true;
    end
    else
    begin
      SourceStream.Position := 180;
      SourceStream.Read(DDSnum, 4);
      if DDSnum = 542327876 then
      begin
        SourceStream.Seek(-4, soFromCurrent);
        DestStream.CopyFrom(SourceStream, SourceStream.Size - Sourcestream.Position);
        result := true;
      end
      else
        Log('DDS decode failed! Couldnt find identifier!');
    end;
  end;

  //DestStream.SaveToFile('C:\Users\Ben\Desktop\test.dds');
end;

function TDFExplorerBase.DrawImageGeneric(FileIndex: integer;
  DestBitmap: TBitmap32): boolean;
var
  TempStream: TExplorerMemoryStream;
begin
  result:=true;

  TempStream:=TExplorerMemoryStream.Create;
  try
    DestBitmap.Clear();
    destbitmap.CombineMode:=cmBlend;
    destBitmap.DrawMode:=dmOpaque;
    fBundle.SaveFileToStream(FileIndex, TempStream);
    if DrawImage(TempStream, DestBitmap) = false then
    begin
      Log('Image decode failed! ' + fBundle.FileName[FileIndex]);
      result:=false;
    end;
  finally
    TempStream.Free;
  end;
end;

function TDFExplorerBase.GetFileExtension(Index: integer): string;
begin
  result:=fBundle.FileExtension[Index];
end;

function TDFExplorerBase.GetFileName(Index: integer): string;
begin
  result:=fBundle.FileName[Index];
end;

function TDFExplorerBase.GetFileOffset(Index: integer): integer;
begin
  result:=fBundle.FileOffset[Index];
end;

function TDFExplorerBase.GetFileSize(Index: integer): integer;
begin
  result:=fBundle.FileSize[Index];
end;

function TDFExplorerBase.GetFileType(Index: integer): TFiletype;
begin
  result:=fBundle.FileType[Index];
end;

procedure TDFExplorerBase.Initialise;
begin
  if assigned(FOnDoneLoading) then
    fBundle.OnDoneLoading:=FOnDoneLoading;
  if assigned(FOnDebug) then
    fBundle.OnDebug:=FOnDebug;

  fBundle.ParseFiles;
end;

procedure TDFExplorerBase.Log(Text: string);
begin
  if assigned(fOnDebug) then fOnDebug(Text);
end;



function TDFExplorerBase.SaveDDSToFile(FileIndex: integer; DestDir,
  FileName: string): boolean;
var
  TempStream: TExplorerMemoryStream;
  SaveFile: TFileStream;
begin
  result:=false;

  if (FileIndex < 0) or (FileIndex > fBundle.Count) then
  begin
    Log('Invalid file number! Save cancelled.');
    exit;
  end;


  TempStream:=TExplorerMemoryStream.Create;
  try
    fBundle.SaveFileToStream(FileIndex, TempStream);
    TempStream.Position:=0;

    SaveFile:=tfilestream.Create(IncludeTrailingPathDelimiter(DestDir)  + FileName, fmOpenWrite or fmCreate);
    try
      Result := WriteDDSToStream(Tempstream, SaveFile);
    finally
      SaveFile.Free;
    end;
  finally
    TempStream.Free;
  end;
end;

procedure TDFExplorerBase.SaveFile(FileNo: integer; DestDir, FileName: string);
begin
  fBundle.SaveFile(FileNo, DestDir, Filename);
end;

procedure TDFExplorerBase.SaveFiles(DestDir: string);
begin
  fBundle.SaveFiles(DestDir);
end;



procedure TDFExplorerBase.SaveFileToStream(FileNo: integer;
  DestStream: TStream);
begin
  fBundle.SaveFileToStream(FileNo, DestStream);
end;


end.
