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
    ft_CSVText,
    ft_DelimitedText,
    ft_Other,
    ft_Audio,
    ft_FSBFile,
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

  TFSBCodec = (
    FMOD_SOUND_FORMAT_NONE,             //* Unitialized / unknown. */
    FMOD_SOUND_FORMAT_PCM8,             //* 8bit integer PCM data. */
    FMOD_SOUND_FORMAT_PCM16,            //* 16bit integer PCM data. */
    FMOD_SOUND_FORMAT_PCM24,            //* 24bit integer PCM data. */
    FMOD_SOUND_FORMAT_PCM32,            //* 32bit integer PCM data. */
    FMOD_SOUND_FORMAT_PCMFLOAT,         //* 32bit floating point PCM data. */
    FMOD_SOUND_FORMAT_GCADPCM,          //* Compressed Nintendo 3DS/Wii DSP data. */
    FMOD_SOUND_FORMAT_IMAADPCM,         //* Compressed IMA ADPCM data. */
    FMOD_SOUND_FORMAT_VAG,              //* Compressed PlayStation Portable ADPCM data. */
    FMOD_SOUND_FORMAT_HEVAG,            //* Compressed PSVita ADPCM data. */
    FMOD_SOUND_FORMAT_XMA,              //* Compressed Xbox360 XMA data. */
    FMOD_SOUND_FORMAT_MPEG,             //* Compressed MPEG layer 2 or 3 data. */
    FMOD_SOUND_FORMAT_CELT,             //* Compressed CELT data. */
    FMOD_SOUND_FORMAT_AT9,              //* Compressed PSVita ATRAC9 data. */
    FMOD_SOUND_FORMAT_XWMA,             //* Compressed Xbox360 xWMA data. */
    FMOD_SOUND_FORMAT_VORBIS           //* Compressed Vorbis data. */
    );

  TFSBFile = class
    FileName: string;
    Size:     integer;
    Offset:   integer;
    FileType: TFileType;
    FileExtension: string;
    Codec: TFSBCodec;
    Channels: integer;
    Bits: integer;
    Freq: integer;
  end;


implementation

end.
