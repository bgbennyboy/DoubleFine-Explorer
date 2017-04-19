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

unit uDFExplorer_Funcs;

interface

uses
  Sysutils, Windows, JCLRegistry, uDFExplorer_Types, uMemReader, Classes, StrUtils,
  JCLStrings, ImagingTypes, ImagingUtility;

  function GetFileTypeFromFileExtension(FileExt: string; ActualFileExt: string = ''):
    TFileType;
  function GetCavePath: string;
  function GetStackingPath: string;
  function GetIronBrigadePath: string;
  function GetCostumeQuestPath: string;
  function GetCostumeQuest2Path: string;
  function GetBrutalLegendPath: string;
  function GetBrokenAgePath: string;
  function GetGrimRemasteredPath: string;
  function GetMassiveChalicePath: string;
  function GetPsychonautsSteamPath: string;
  function GetDOTTPath: string;
  function GetFullThrottlePath: string;
  function GetHeadlanderPath: string;
  function SanitiseFileName(FileName: string): string;
  function ExtractPartialPath(FileName: string): string;
  function SwapEndianDWord(Value: integer): integer; register;
  function SwapEndianWord(const Value: Word): Word; inline;
  function FindParamIndex(Param: string): integer;
  function FindFileHeader(SearchStream: TStream; StartSearchAt,
    EndSearchAt: Integer; Header: string): integer;
  procedure RemoveReadOnlyFileAttribute(FileName: string);
  procedure GetSteamLibraryPaths(LibraryPaths: TStringList);
  procedure ConvertYCoCgToRGB(Pixels: PByte; NumPixels, BytesPerPixel: Integer);


implementation

procedure GetSteamLibraryPaths(LibraryPaths: TStringList);
var
  SteamPath, VDFfile, CurrLine, NewPath: string;
  Reader: TStreamReader;
  i: integer;
begin
  try
    SteamPath := IncludeTrailingPathDelimiter(
      RegReadString(HKEY_CURRENT_USER, 'SOFTWARE\Valve\Steam', 'SteamPath'));
    SteamPath := StringReplace(SteamPath, '/', '\', [rfReplaceAll, rfIgnoreCase]);
  except on EJCLRegistryError do
    exit;
  end;

  LibraryPaths.Add(SteamPath);

  VDFfile := SteamPath + 'config\config.vdf';
  if FileExists(VDFfile) = false then exit;


  Reader := TStreamReader.Create(TFileStream.Create(VDFfile, fmOpenRead), TEncoding.UTF8);
  try
    while not Reader.EndOfStream do
    begin
      CurrLine := Reader.ReadLine;
      if AnsiContainsStr(CurrLine, '"BaseInstallFolder_') then //BaseInstallFolder is the extra library
      begin
        for i := 1 to 5 do //Normally just BaseInstallFolder1 but perhaps more if > 2 steam libraries
        begin
          if AnsiContainsStr(CurrLine, '"BaseInstallFolder_' + inttostr(i) + '"') then
            break;
        end;
        //ShowMessage(CurrLine);
        NewPath := StrAfter('"BaseInstallFolder_' + inttostr(i) + '"', CurrLine);
        NewPath := StrRemoveChars(NewPath, [#34]); //Remove the surrounding double quotes
        NewPath := StrRemoveChars(NewPath, [#9]); //Remove any tab characters before the string
        NewPath := IncludeTrailingPathDelimiter(NewPath); //Add the backslash to the path
        StrReplace(NewPath, '\\', '\', [rfReplaceAll]); //Remove the \\ and replace with \
        LibraryPaths.Add(NewPath);
        //ShowMessage(NewPath);
      end;
    end;
  finally
    Reader.Close();
    Reader.BaseStream.Free;
    Reader.Free();
  end;

end;

function GetFileTypeFromFileExtension(FileExt: string; ActualFileExt: string = ''):
  TFileType;
begin
  {The Cave types}
  if FileExt = 'AchievementIdMap' then result:= ft_DelimitedText //
  else
  if FileExt = 'AnimEventList' then result:= ft_DelimitedText //
  else
  if FileExt = 'AnimResource' then result:= ft_Other //
  else
  if FileExt = 'AudioEnvironment' then result:= ft_DelimitedText //
  else
  if FileExt = 'AudioProgrammerReport' then result:= ft_DelimitedText //
  else
  if FileExt = 'AudioWavbankMarkers' then result:= ft_DelimitedText //
  else
  if FileExt = 'AudioWavebankData' then result:= ft_DelimitedText //
  else
  if FileExt = 'Blob' then
    if ActualFileExt = '.LUA' then
      result:= ft_Text
    else
    if ActualFileExt = '.PNG' then
      result:= ft_GenericImage //in stacking
    else
    if ActualFileExt = '.CSV' then
      result:= ft_CSVText //in Costume Quest
    else
    if ActualFileExt = '.ATLAS' then
      result:= ft_Text //in Headlander
    else
    if ActualFileExt = '.SCREEN' then
      result:= ft_Text //in Headlander
    {else
    if ActualFileExt = '.IRRAD' then //in stacking - like delimited but differences
      result:= ft_DelimitedText}
    else
      result := ft_Other
  else
  if FileExt = 'CameraPath' then result:= ft_Other //
  else
  if FileExt = 'CaveCharacterSet' then result:= ft_DelimitedText //
  else
  if FileExt = 'CavePaintingTextureMap' then result:= ft_DelimitedText //
  else
  if FileExt = 'Climate' then result:= ft_DelimitedText //
  else
  if FileExt = 'CollisionShape' then result:= ft_Other //
  else
  if FileExt = 'ControllerConfig' then result:= ft_DelimitedText //
  else
  if FileExt = 'CreditsData' then result:= ft_DelimitedText //
  else
  if FileExt = 'Cutscene' then result:= ft_DelimitedText //
  else
  if FileExt = 'DialogSets' then result:= ft_Other //TODO text-like
  else
  if FileExt = 'DUIMovie' then result:= ft_DelimitedText //
  else
  if FileExt = 'Effect' then result:= ft_DelimitedText //
  else
  if FileExt = 'EffectTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'FlashConfig' then result:= ft_DelimitedText //
  else
  if FileExt = 'Heightfield' then result:= ft_Other //
  else
  if FileExt = 'InputAliases' then result:= ft_DelimitedText //
  else
  if FileExt = 'InteractionAnims' then result:= ft_DelimitedText //
  else
  if FileExt = 'LevelData' then result:= ft_DelimitedText //
  else
  if FileExt = 'Material' then result:= ft_DelimitedText //
  else
  if FileExt = 'Mesh' then result:= ft_Other //
  else
  if FileExt = 'MeshSet' then result:= ft_DelimitedText //
  else
  if FileExt = 'MusicSet' then result:= ft_DelimitedText //
  else
  if FileExt = 'ObjectData' then result:= ft_Other //
  else
  if FileExt = 'ParticleSystemData' then result:= ft_Other //
  else
  if FileExt = 'PathTileData' then result:= ft_Other //
  else
  if FileExt = 'PhysicalSurfaceMap' then result:= ft_Other //
  else
  if FileExt = 'PhysicsRigidBody' then result:= ft_Other //
  else
  if FileExt = 'ProgressionValues' then result:= ft_DelimitedText //
  else
  if FileExt = 'PrototypeResource' then result:= ft_DelimitedText //
  else
  if FileExt = 'ResourceBuildStamp' then result:= ft_DelimitedText //
  else
  if FileExt = 'Rig' then result:= ft_Other //
  else
  if FileExt = 'SimulationData' then result:= ft_DelimitedText //
  else
  if FileExt = 'SoundCueTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'Stance' then result:= ft_DelimitedText //
  else
  if FileExt = 'Story' then result:= ft_DelimitedText //
  else
  if FileExt = 'StringTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'SystemLineCodes' then result:= ft_DelimitedText //
  else
  if FileExt = 'TerrainMaterial' then result:= ft_DelimitedText //
  else
  if FileExt = 'Texture' then result:= ft_DDSImage
  else
  if FileExt = 'VisualTypeDefinitions' then result:= ft_DelimitedText //
  else
  if FileExt = 'WangTileset' then result:= ft_Other //
  else
  if FileExt = 'WaterEffectTable'then  result:= ft_DelimitedText //
  else
  if FileExt = 'Weather' then result:= ft_DelimitedText //
  else

  {Stacking types}
  if FileExt = 'AbilityResponseTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'BuffEffectsData' then result:= ft_DelimitedText //
  else
  if FileExt = 'CameraSettings' then result:= ft_DelimitedText //
  else
  if FileExt = 'DollTaskList' then result:= ft_DelimitedText //
  else
  if FileExt = 'Outfit' then result:= ft_DelimitedText //
  else
  if FileExt = 'RigidBodyEventData' then result:= ft_DelimitedText //
  else
  if FileExt = 'StackGameGlobals' then result:= ft_DelimitedText //
  else
  if FileExt = 'LoadingScreenRules' then result:= ft_DelimitedText //
  else
  if FileExt = 'BuffEffectTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'Buff' then result:= ft_DelimitedText //
  else
  if FileExt = 'DollReactionAnims' then result:= ft_DelimitedText //
  else
  if FileExt = 'PercentCompleteValues' then result:= ft_DelimitedText //
  else
  if FileExt = 'TutorialCardSet' then result:= ft_DelimitedText //
  else
  if FileExt = 'GameUnlocks' then result:= ft_DelimitedText //
  else
  if FileExt = 'InstanceVertexData' then result:= ft_Other //
  else
  if FileExt = 'DollSoundTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'GibData' then result:= ft_DelimitedText //
  else

  {Costume Quest types}
  if FileExt = 'DialogReactionSets' then result:= ft_Other //
  else
  if FileExt = 'InventoryItemResource' then result:= ft_DelimitedText //
  else
  if FileExt = 'QuestObjective' then result:= ft_DelimitedText //
  else
  if FileExt = 'CharacterNames' then result:= ft_DelimitedText //
  else
  if FileExt = 'CameraOperatorData' then result:= ft_DelimitedText //
  else

  {Iron Brigade types}
  if FileExt = 'ComboAnim' then result:= ft_DelimitedText //
  else
  if FileExt = 'ComboPose' then result:= ft_DelimitedText //
  else
  if FileExt = 'AmbMeshDefinition' then result:= ft_DelimitedText //
  else
  if FileExt = 'OceanData' then result:= ft_DelimitedText //
  else
  if FileExt = 'MechItem' then result:= ft_DelimitedText //
  else
  if FileExt = 'LobbyRulesAttributes' then result:= ft_DelimitedText //
  else
  if FileExt = 'DLCLobbyAttributes' then result:= ft_DelimitedText //
  else
  if FileExt = 'LootTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'SpawnManagerAttributes' then result:= ft_DelimitedText //
  else
  if FileExt = 'ShiftStory' then result:= ft_DelimitedText //
  else
  if FileExt = 'SpawnEvent' then result:= ft_DelimitedText //
  else
  if FileExt = 'LootLookup' then result:= ft_DelimitedText //
  else
  if FileExt = 'VidSubtitles' then result:= ft_DelimitedText //
  else
  if FileExt = 'RndTileData' then result:= ft_Other //
  else
  if FileExt = 'QuadTileData' then result:= ft_Other //
  else
  if FileExt = 'AmbTileData' then result:= ft_Other //
  else
  if FileExt = 'Chatter' then result:= ft_DelimitedText //
  else
  if FileExt = 'AchievementRequirementData' then result:= ft_DelimitedText //
  else
  if FileExt = 'DamageResponseTable' then result:= ft_DelimitedText //
  else
  if FileExt = 'WarChest' then result:= ft_DelimitedText //
  else
  if FileExt = 'Experience' then result:= ft_DelimitedText //
  else
  if FileExt = 'GameSettings' then result:= ft_DelimitedText //
  else
  if FileExt = 'AmbientVignettes' then result:= ft_DelimitedText //
  else
  if FileExt = 'LevelList' then result:= ft_DelimitedText //
  else
  if FileExt = 'LootTableInfo' then result:= ft_DelimitedText //
  else
  if FileExt = 'LoadingBackgroundSets' then result:= ft_DelimitedText //
  else
  if FileExt = 'Loadout' then result:= ft_DelimitedText //
  else
  if FileExt = 'DriverOutfit' then result:= ft_DelimitedText //
  else
  if FileExt = 'RegimentChallengeTab' then result:= ft_DelimitedText //
  else
  if FileExt = 'PilotList' then result:= ft_DelimitedText //
  else
  if FileExt = 'RichPresenceInfo' then result:= ft_DelimitedText //
  else
  if FileExt = 'MissionData' then result:= ft_DelimitedText //
  else
  if FileExt = 'CommonLineCodes' then result:= ft_DelimitedText //
  else
  if FileExt = 'NavigationSystemGraph' then result:= ft_Other//


  {Brutal Legend types}
  else
  if FileExt = 'DLCAchievementData' then result:= ft_DelimitedText//
  else
  if FileExt = 'DLCRockmoreHeadMap' then result:= ft_DelimitedText//
  else
  if FileExt = 'UpgradeCategory' then result:= ft_DelimitedText//
  else
  if FileExt = 'UpgradeSet' then result:= ft_DelimitedText//
  else
  if FileExt = 'SoloSetup' then result:= ft_DelimitedText//
  else
  if FileExt = 'TechTree' then result:= ft_DelimitedText//
  else
  if FileExt = 'PlaylistResource' then result:= ft_DelimitedText//
  else
  if FileExt = 'MusicNameTable' then result:= ft_DelimitedText//
  else
  if FileExt = 'VoiceSettings' then result:= ft_DelimitedText//
  else
  if FileExt = 'AttachmentPointTable' then result:= ft_DelimitedText//
  else
  if FileExt = 'EncounterTable' then result:= ft_DelimitedText//
  else
  if FileExt = 'ArtBrowserAssets' then result:= ft_DelimitedText//
  else
  if FileExt = 'DifficultySet' then result:= ft_DelimitedText//
  else
  if FileExt = 'StrategicResponses' then result:= ft_DelimitedText//
  else
  if FileExt = 'AIDifficulties' then result:= ft_DelimitedText//
  else
  if FileExt = 'UnitInfos' then result:= ft_DelimitedText//
  else
  if FileExt = 'GameMapRegions' then result:= ft_DelimitedText//
  else
  if FileExt = 'JournalEntries' then result:= ft_DelimitedText//
  else
  if FileExt = 'RockSolo' then result:= ft_DelimitedText//
  else
  if FileExt = 'StatLimits' then result:= ft_DelimitedText//
  else
  if FileExt = 'AnimMap' then result:= ft_DelimitedText//
  else
  if FileExt = 'CutsceneClump' then result:= ft_DelimitedText//
  else
  if FileExt = 'AlbumCover' then result:= ft_DelimitedText//
  else
  if FileExt = 'HUDSkin' then result:= ft_DelimitedText//
  else
  if FileExt = 'VehicleKeyframeData' then result:= ft_Other//
  else
  if FileExt = 'FurData' then result:= ft_Other//


  {Broken Age types}
  else
  if FileExt = 'lua' then result:= ft_Lua//
  else
  if FileExt = 'list' then result:= ft_Text//
  else
  if FileExt = 'settings' then result:= ft_Text//
  else
  if FileExt = 'clump' then result:= ft_Text//
  else
  if FileExt = 'effect' then result:= ft_Text//
  else
  if FileExt = 'fnt' then result:= ft_Text//
  else
  if FileExt = 'id' then result:= ft_Text//
  else
  if FileExt = 'sdoc' then result:= ft_Text//
  else
  if FileExt = 'texparams' then result:= ft_Text//
  else
  if FileExt = 'fsb' then result:= ft_FSBFile//
  else
  if FileExt = 'fev' then result:= ft_Other//
  else
  if FileExt = 'dtree' then result:= ft_Lua//
  else
  if FileExt = 'envstate' then result:= ft_Lua//
  else
  if FileExt = 'inv' then result:= ft_Lua//
  else
  if FileExt = 'loco' then result:= ft_Lua//
  else
  if FileExt = 'material' then result:= ft_Lua//
  else
  if FileExt = 'matmod' then result:= ft_Lua//
  else
  if FileExt = 'proto' then result:= ft_Lua//
  else
  if FileExt = 'scene' then result:= ft_Lua//
  else
  if FileExt = 'stance' then result:= ft_Lua//
  else
  if FileExt = 'brig' then result:= ft_Other//
  else
  if FileExt = 'rig' then result:= ft_Lua//
  else
  if FileExt = 'tex' then result:= ft_HeaderlessDDSImage//
  else
  if FileExt = 'anim' then result:= ft_Lua//
  else
  if FileExt = 'banim' then result:= ft_Other//
  else
  if FileExt = 'particles' then result:= ft_Lua//
  else
  if FileExt = 'font' then result:= ft_Lua//
  else
  if FileExt = 'bsdoc' then result:= ft_Other//
  else
  if FileExt = 'bshd' then result:= ft_Other//
  else
  if FileExt = 'ctsn' then result:= ft_Lua//
  else
  if FileExt = 'canim' then result:= ft_Text//
  else
  if FileExt = 'caff' then result:= ft_Lua//


  {Audio}
  else
  if FileExt = '.MP3' then result:= ft_Audio //
  else
  if (FileExt = '.WAV') or (FileExt = 'WAV') then
    if ActualFileExt = 'GRIMWAV' then
      result := ft_IMCAudio
    else
      result:= ft_Audio //

  {Psychonauts types}
  else
  if FileExt = '.vsh' then result:= ft_Text
  else
  if FileExt = '.h' then result:= ft_Text
  else
  if FileExt = '.psh' then result:= ft_Text
  else
  if FileExt = '.plb' then result:= ft_Other
  else
  if FileExt = '.pba' then result:= ft_Other
  else
  if FileExt = '.lua' then result:= ft_Other
  else
  if FileExt = '.lpf' then result:= ft_Other
  else
  if FileExt = '.jan' then result:= ft_Other
  else
  if FileExt = '.ini' then result:= ft_Text
  else
  if FileExt = '.hlps' then result:= ft_Text
  else
  if FileExt = '.eve' then result:= ft_Other
  else
  if FileExt = '.dfs' then result:= ft_Text
  else
  if FileExt = '.dds' then result:= ft_DDSImage
  else
  if FileExt = '.cam' then result:= ft_Other
  else
  if FileExt = '.atx' then result:= ft_Text
  else
  if FileExt = '.asd' then result:= ft_Text

  {Costume Quest 2 types}
  else
  if FileExt = 'MeshEventData' then result:= ft_DelimitedText
  else
  if FileExt = 'MonsterEncounterTable' then result:= ft_DelimitedText
  else
  if FileExt = 'MonsterRewardTable' then result:= ft_DelimitedText
  else
  if FileExt = 'EncounterGroupAliasTable' then result:= ft_DelimitedText
  else
  if FileExt = 'RichPresenceData' then result:= ft_DelimitedText

  {Grim Fandango Remastered types}
  else
  if FileExt = '.txt' then result:= ft_Text
  else
  if FileExt = '.LUA' then result:= ft_Lua
  else
  if FileExt = '.png' then result:= ft_GenericImage
  else
  if FileExt = '.mcb' then result:= ft_DDSImage
  else
  if FileExt = '.imc' then result:= ft_IMCAudio
  else
  if FileExt = '.lip' then result:= ft_Other

  {Massive Chalice types}
  else
  if FileExt = 'Wardrobe' then result:= ft_DelimitedText
  else
  if FileExt = 'ScrollingCameraSettings' then result:= ft_DelimitedText
  else
  if FileExt = 'StrategySettings' then result:= ft_DelimitedText

  {DOTT types}
  else
  if FileExt = 'png' then result:= ft_GenericImage
  else
  if FileExt = '000' then result:= ft_Other
  else
  if FileExt = '001' then result:= ft_Other
  else
  if FileExt = 'dxt' then result:= ft_HeaderlessDOTTDDSImage
  else
  if FileExt = 'ftx' then result:= ft_DOTTFontImage
  else
  if FileExt = 'xml' then result:= ft_DOTTXMLCostumeWithImage
  else
  if FileExt = 'sou' then result:= ft_Other
  else
  if FileExt = 'dir' then result:= ft_Other
  else
  if FileExt = 'bin' then result:= ft_Other
  else
  if FileExt = 'csv' then result:= ft_CSVText
  else
  if FileExt = 'gl' then result:= ft_Other
  else
  if FileExt = 'info' then result:= ft_Other
  else
  if FileExt = 'lfl' then result:= ft_Other
  else
  if FileExt = 'txt' then result:= ft_Text

  {Headlander types}
  else
  if FileExt = 'SurfaceGrowthData' then result:= ft_DelimitedText

  {Full Throttle fypes}
  else
  if FileExt = 'wav' then result:= ft_Audio //Cant remember why this function is case sensitive instead of everything being uppercased. Perhaps it helps distinguish between some games?

  else
  begin
     result:= ft_Unknown;
    //Log('Unknown file type ' + FileExt);
  end;
end;

function GetBrokenAgePath: string;
const
  ExtraPath: string = 'steamapps\Common\Broken Age\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetBrutalLegendPath: string;
const
  ExtraPath: string = 'steamapps\Common\BrutalLegend\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetCavePath: string;
const
  ExtraPath: string = 'steamapps\Common\TheCave\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;


function GetStackingPath: string;
const
  ExtraPath: string = 'steamapps\Common\Stacking\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetCostumeQuestPath: string;
const
  ExtraPath: string = 'steamapps\Common\costume quest\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetCostumeQuest2Path: string;
const
  ExtraPath: string = 'steamapps\Common\CostumeQuest2\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetGrimRemasteredPath: string;
const
  ExtraPath: string = 'steamapps\Common\GrimFandangoRemastered\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetMassiveChalicePath: string;
const
  ExtraPath: string = 'steamapps\Common\Massive Chalice\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;


function GetIronBrigadePath: string;
const
  ExtraPath: string = 'steamapps\Common\iron brigade\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;


  if DirectoryExists(result) = false then
    if DirectoryExists(
      'C:\Program Files (x86)\Microsoft Games Studios\Iron Brigade\Win\') then //Retail path? untested by me
      result := 'C:\Program Files (x86)\Microsoft Games Studios\Iron Brigade\Win';
end;

function GetPsychonautsSteamPath: string;
const
  ExtraPath: string = 'steamapps\Common\Psychonauts\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetDOTTPath: string;
const
  ExtraPath: string = 'steamapps\Common\Day of the Tentacle Remastered\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetFullThrottlePath: string;
const
  ExtraPath: string = 'steamapps\Common\Full Throttle Remastered\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;
end;

function GetHeadlanderPath: string;
const
  ExtraPath: string = 'steamapps\Common\Headlander\Win\';
var
  Paths: TStringList;
  i: integer;
begin
  Result := '';
  Paths := TStringList.Create;
  try
    GetSteamLibraryPaths(Paths);
    if Paths.Count > 0 then
      for I := 0 to Paths.Count -1 do
      begin
        if DirectoryExists(Paths[i] + ExtraPath) then
        begin
          result:=Paths[i] + ExtraPath;
          break;
        end;
      end;
  finally
    Paths.free;
  end;


  if DirectoryExists(result) = false then
      if DirectoryExists(
        'D:\Games\Headlander\Win\') then //Install location on my laptop - TODO remove
        result := 'D:\Games\Headlander\Win';
end;

function SanitiseFileName(FileName: string): string;
var
  DelimiterPos: integer;
begin
  DelimiterPos := LastDelimiter('/', FileName );
  if DelimiterPos = 0 then
  begin
    DelimiterPos := LastDelimiter('\', FileName ); //Iron Brigade uses backslash
    if DelimiterPos = 0 then
      result := FileName
    else
      Result := Copy( FileName, DelimiterPos + 1, Length(FileName) - DelimiterPos + 1);
  end
  else
    Result := Copy( FileName, DelimiterPos + 1, Length(FileName) - DelimiterPos + 1);
end;

function ExtractPartialPath(FileName: string): string;
var
  DelimiterPos: integer;
begin
  DelimiterPos := LastDelimiter('/', FileName );
  if DelimiterPos = 0 then
  begin
    DelimiterPos := LastDelimiter('\', FileName ); //Iron Brigade uses backslash
    if DelimiterPos = 0 then
      result := ''
    else
    begin
      Result := Copy( FileName, 1,  DelimiterPos);
      Result := StringReplace(Result, '/', '\', [rfReplaceAll, rfIgnoreCase ]);
    end;
  end
  else
  begin
    Result := Copy( FileName, 1,  DelimiterPos);
    Result := StringReplace(Result, '/', '\', [rfReplaceAll, rfIgnoreCase ]);
  end;
end;

function SwapEndianDWord(Value: integer): integer; register;
asm
  bswap eax
end;

function SwapEndianWord(const Value: Word): Word; inline;
begin
  Result:= Value xor $8000;
end;

function FindParamIndex(Param: string): integer;
var  //Remember to include / in param when calling this, since ParamStr returns the /
  i: integer;
begin
  result:=-1;

  for i := 1 to ParamCount do
  begin
    if Uppercase(Param) = Uppercase(ParamStr(i)) then
    begin
      result:=i;
      break;
    end;
  end;
end;

procedure RemoveReadOnlyFileAttribute(FileName: string);
var
  Attributes: cardinal;
begin
  if FileName = '' then exit;

  Attributes:=FileGetAttr(FileName);
  if Attributes = INVALID_FILE_ATTRIBUTES then exit;

  if Attributes and faReadOnly = faReadOnly then
    FileSetAttr(FileName, Attributes xor faReadOnly);
end;

procedure YCoCgToRGBWithAlpha(Y, Co, Cg, InAlpha: Byte; var R, G, B, OutAlpha: Byte);
var
  CoInt, CgInt: Integer;
begin
  CoInt := Co - 128;
  CgInt := Cg - 128;
  R := ClampToByte(Y + CoInt - CgInt);
  G := ClampToByte(Y + CgInt);
  B := ClampToByte(Y - CoInt - CgInt);
  OutAlpha := InAlpha;
end;


procedure ConvertYCoCgToRGB(Pixels: PByte; NumPixels, BytesPerPixel: Integer);
var
  I: Integer;
  PixPtr: PByte;
  Y, CO, CG, Al: Byte;
begin
  //https://www.nvidia.com/object/real-time-ycocg-dxt-compression.html
  //When converted rgba gets laid out as co,cg,a,y
  PixPtr := Pixels;
  for I := 0 to NumPixels - 1 do
  begin
    with PColor32Rec(PixPtr)^ do
    begin
      CO := R;
      CG := G;
      Al := B;
      Y  := A;
      YCoCgToRGBWithAlpha(Y, CO, CG, Al, R, G, B, A);
    end;
    Inc(PixPtr, BytesPerPixel);
  end;
end;


function FindFileHeader(SearchStream: TStream;
  StartSearchAt, EndSearchAt: Integer; Header: string): integer;
var
  HeaderLength, Index: integer;
  Tempbyte: byte;
begin
  Result:=-1;
  Index:=1;
  if EndSearchAt > SearchStream.Size then
    EndSearchAt:=SearchStream.Size;

  HeaderLength:=Length(Header);
  if HeaderLength <= 0 then exit;


  SearchStream.Position:=StartSearchAt;
  while SearchStream.Position < EndSearchAt do
  begin
    SearchStream.Read(TempByte, 1);
    if Chr(TempByte) <> Header[Index] then
    begin
      if Index > 1 then
        SearchStream.Position := SearchStream.Position  -1;

      Index:=1;
      continue;
    end;

    inc(Index);
    if index > HeaderLength then
    begin
      Result:=SearchStream.Position - HeaderLength;
      exit;
    end;
  end;

end;
end.
