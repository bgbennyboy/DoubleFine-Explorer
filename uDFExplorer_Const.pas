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

unit uDFExplorer_Const;

interface

const
  strAppName:              string = 'DoubleFine Explorer';
  strAppVersion:           string = '1.3.3';
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
  strChooseAFolder:               string = 'Choose a folder';
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
