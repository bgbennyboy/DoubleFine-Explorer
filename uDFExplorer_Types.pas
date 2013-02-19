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

unit uDFExplorer_Types;

interface

uses
  SysUtils;

type
  TProgressEvent = procedure(ProgressMax: integer; ProgressPos: integer) of object;
  TDebugEvent = procedure(DebugText: string) of object;
  TOnDoneLoading = procedure(FileNamesCount: integer) of object;
  EInvalidFile = class (exception);

  TFileType = (
    ft_GenericImage,
    ft_DDSImage,
    ft_Text,
    ft_DelimitedText,
    ft_Other,
    ft_Audio,
    ft_Unknown
  );

  TDFFile = class
    FileName: string;
    UncompressedSize: integer;
    NameOffset: integer;
    Offset:   integer;
    Size:     integer;
    FileTypeIndex: integer;
    CompressionType: integer;
    Compressed: boolean;
    FileExtension: string;
    FileType: TFileType;
  end;

  TFSBFile = class
    FileName: string;
    Size:     integer;
    Offset:   integer;
    FileType: TFileType;
    FileExtension: string;
  end;

implementation

end.
