{
******************************************************
  DoubleFine Explorer
  Copyright (c) 2014 Bennyboy
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

unit uDFExplorer_Const;

interface

const
  strAppName:              string = 'DoubleFine Explorer';
  strAppVersion:           string = '1.1';
  strAppURL:               string = 'http://quickandeasysoftware.net';
  strCmdLineOpenAndDelete: string = '/OPENFILEANDDELETELATER';


{**********************************Main Form***********************************}
  strDumpingAllFiles:             string = 'Dumping all files...';
  strDumpingAllVisibleFiles:      string = 'Dumping all visible files...';
  strDumpingAllImages:            string = 'Dumping all images...';
  strDumpingAllDDSImages:         string = 'Dumping all dds images...';
  strDumpingAllText:              string = 'Dumping all text...';
  strDumpingAllAudio:             string = 'Dumping all audio...';
  strDumpingAllLua:               string = 'Decompiling all lua...WARNING this may take a while (at least 5 minutes to decompile all lua files in pdata.pck';
  strDone:                        string = '...done!';
  strViewAllFiles:                string = 'View all files';
  strViewSavedGameFiles:          string = 'Saved games';
  strSavingFile:                  string  = 'Saving file ';
  strSendingToHex:                string = 'Sending file to hex editor: ';
  strErrorHexEditorPath:          string = 'Error - hex editor path not found in ini!';
  strErrHexFileExists:            string = 'File already exists and in use! Saving as ';
  strIncorrectBASSVersion:        string = 'An incorrect version of BASS.DLL was loaded';
  strErrorInitializingAudio:      string = 'Error initializing audio!';
  strErrorUnrecognisedAudioType:  string = 'File not a recognised audio type';
  strErrorPlayingStreamCode:      string = 'Error playing stream! Error code:';
  strErrorInvalidFileNoLuaDec:    string = 'Invalid file number! Lua decompile failed.';

implementation

end.
