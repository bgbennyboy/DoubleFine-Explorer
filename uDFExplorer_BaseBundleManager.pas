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

unit uDFExplorer_BaseBundleManager;

interface

uses
  classes, Contnrs,
  uFileReader, uDFExplorer_Types;

type
  TBundleManager = class
  protected
    fBigEndian: boolean;
    fBundle: TExplorerFileStream;
    fBundleFileName: string;
    fonDoneLoading: TOnDoneLoading;
    fonProgress: TProgressEvent;
    fonDebug: TDebugEvent;
    function DetectBundle: boolean; Virtual; Abstract;
    function GetFilesCount: integer; Virtual; Abstract;
    function GetFileName(Index: integer): string; Virtual; Abstract;
    function GetFileSize(Index: integer): integer; Virtual; Abstract;
    function GetFileOffset(Index: integer): LongWord; Virtual; Abstract;
    function GetFileExtension(Index: integer): string; Virtual; Abstract;
    function GetFileType(Index: integer): TFiletype; Virtual; Abstract;
    procedure Log(Text: string); Virtual; Abstract;
  public
    BundleFiles: TObjectList;
    constructor Create(ResourceFile: string); Virtual; Abstract;
    destructor Destroy; override;
    procedure ParseFiles; Virtual; Abstract;
    procedure SaveFile(FileNo: integer; DestDir, FileName: string); Virtual; Abstract;
    procedure SaveFileToStream(FileNo: integer; DestStream: TStream); Virtual; Abstract;
    procedure SaveFiles(DestDir: string); Virtual; Abstract;
    property Count: integer read GetFilesCount;
    property OnDoneLoading: TOnDoneLoading read FOnDoneLoading write FOnDoneLoading;
    property OnProgress: TProgressEvent read FOnProgress write FOnProgress;
    property OnDebug: TDebugEvent read FOnDebug write FOnDebug;
    property FileName[Index: integer]: string read GetFileName;
    property FileSize[Index: integer]: integer read GetFileSize;
    property FileOffset[Index: integer]: LongWord read GetFileOffset;
    property FileExtension[Index: integer]: string read GetFileExtension;
    property FileType[Index: integer]: TFileType read GetFileType;
    property BigEndian: boolean read fBigEndian;
  end;

const
    strErrFileSize:   string  = 'File size  <=0! Save cancelled.';
    strErrFileNo:     string  = 'Invalid file number! Save cancelled.';
    strSavingFile:    string  = 'Saving file ';

implementation

destructor TBundleManager.Destroy;
begin

  inherited;
end;

end.
