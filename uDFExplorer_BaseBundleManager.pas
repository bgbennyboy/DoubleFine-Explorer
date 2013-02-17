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
    function GetFileOffset(Index: integer): integer; Virtual; Abstract;
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
    property FileOffset[Index: integer]: integer read GetFileOffset;
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
