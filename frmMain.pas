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
{
TODO
IRON BRIGADE PATH AND TEST
Costume quest support
Change busy animation - its the one from monkey island explorer.
Tiny mp3 files dont play - Need to check for mp3 alignment and realign?
Extra filetypes for iron brigade and costume quest - add
Iron Brigade apparently not all sounds working in FSB

When dumping check for files with same name? Are there files in bundles with duplicate names (and paths)?
}
unit frmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Menus, ImgList, Buttons, ExtCtrls, IniFiles,
  JvBaseDlg, JvBrowseFolder, JvExStdCtrls, JvRichEdit, JvEdit, JvExControls,
  JvTracker, JvExExtCtrls, JvExtComponent, JvSplit, JvAnimatedImage, JvGIFCtrl,

  GR32_Image, pngimage, gr32, VirtualTrees,

  AdvMenus, AdvMenuStylers, AdvGlowButton,

  JCLSysInfo, JCLStrings, JCLShell, JCLFileUtils, bass,

  uDFExplorer_Const, uDFExplorer_Base, uDFExplorer_Types, uDFExplorer_Funcs;

type
  TformMain = class(TForm)
    OpenDialog1: TOpenDialog;
    panelButtons: TPanel;
    btnAbout: TAdvGlowButton;
    btnFilterView: TAdvGlowButton;
    btnSaveAllFiles: TAdvGlowButton;
    btnSaveFile: TAdvGlowButton;
    btnOpen: TAdvGlowButton;
    editFind: TJvEdit;
    panelPreviewContainer: TPanel;
    PanelPreviewAudio: TPanel;
    lblTime: TLabel;
    TrackBarAudio: TJvTracker;
    panelPreviewImage: TPanel;
    imagePreview: TImage32;
    panelPreviewText: TPanel;
    memoPreview: TMemo;
    panelBlank: TPanel;
    Image1: TImage;
    Tree: TVirtualStringTree;
    panelBottom: TPanel;
    memoLog: TJvRichEdit;
    SaveDialog1: TSaveDialog;
    dlgBrowseForSaveFolder: TJvBrowseForFolderDialog;
    AdvMenuOfficeStyler1: TAdvMenuOfficeStyler;
    PopupFileTypes: TAdvPopupMenu;
    popupOpen: TAdvPopupMenu;
    MenuItemOpenFolder: TMenuItem;
    N2: TMenuItem;
    MenuItemOpenCave: TMenuItem;
    popupSave: TAdvPopupMenu;
    menuItemDumpFile: TMenuItem;
    menuItemDumpImage: TMenuItem;
    menuItemDumpDDSImage: TMenuItem;
    menuItemDumpText: TMenuItem;
    menuItemDumpAudio: TMenuItem;
    popupSaveAll: TAdvPopupMenu;
    menuItemSaveAllRaw: TMenuItem;
    menuItemSaveAllImages: TMenuItem;
    menuItemSaveAllDDSImages: TMenuItem;
    menuItemSaveAllText: TMenuItem;
    menuItemSaveAllAudio: TMenuItem;
    JvxSplitter1: TJvxSplitter;
    ImageList1: TImageList;
    panelProgress: TPanel;
    Image2: TImage;
    JvGIFAnimator1: TJvGIFAnimator;
    Timer1: TTimer;
    btnSendToHex: TAdvGlowButton;
    menuItemSaveAllVisibleRaw: TMenuItem;
    MenuItemOpenIronBrigade: TMenuItem;
    panelAudioButtons: TPanel;
    btnPlay: TSpeedButton;
    btnPause: TSpeedButton;
    btnStop: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure editFindChange(Sender: TObject);
    procedure memoLogURLClick(Sender: TObject; const URLText: string;
      Button: TMouseButton);
    procedure OpenPopupMenuHandler(Sender: TObject);
    procedure TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure TreeGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean;
      var ImageIndex: Integer);
    procedure TreeChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
    procedure menuItemDumpFileClick(Sender: TObject);
    procedure btnSaveFileClick(Sender: TObject);
    procedure menuItemDumpImageClick(Sender: TObject);
    procedure menuItemDumpDDSImageClick(Sender: TObject);
    procedure menuItemDumpTextClick(Sender: TObject);
    procedure menuItemSaveAllRawClick(Sender: TObject);
    procedure btnSaveAllFilesClick(Sender: TObject);
    procedure menuItemSaveAllImagesClick(Sender: TObject);
    procedure btnAboutClick(Sender: TObject);
    procedure menuItemSaveAllDDSImagesClick(Sender: TObject);
    procedure menuItemSaveAllTextClick(Sender: TObject);
    procedure btnPauseClick(Sender: TObject);
    procedure btnPlayClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure TrackBarAudioChangedValue(Sender: TObject; NewValue: Integer);
    procedure Timer1Timer(Sender: TObject);
    procedure TreeDblClick(Sender: TObject);
    procedure menuItemDumpAudioClick(Sender: TObject);
    procedure menuItemSaveAllAudioClick(Sender: TObject);
    procedure btnSendToHexClick(Sender: TObject);
    procedure menuItemSaveAllVisibleRawClick(Sender: TObject);
  private
    fExplorer: TDFExplorerBase;
    fAudioStream: TMemoryStream;
    fAudioHandle: HSTREAM;
    fTotalTime: string;
    fTrackBarChanging: boolean;
    fHexEditorPath: string;
    fFilesToCleanup: TStringList;
    function IsViewFilteredByCategory: boolean;
    procedure OnDoneLoading(Count: integer);
    procedure DoLog(Text: string);
    procedure FreeResources;
    procedure StopAndFreeAudio;
    procedure ShowProgress(Running: boolean);
    procedure EnableDisableButtonsGlobal(Value: boolean);
    procedure EnableDisableButtons_TreeDependant;
    procedure AddFiletypePopupItems;
    procedure FilterNodesByFileExt(FileExt: string);
    procedure FileTypePopupMenuHandler(Sender: TObject);
    procedure OpenFile;
    procedure UpdateSaveAllMenu;
    procedure OnDebug(DebugText: string);
    procedure CheckIniForHexEditor;
  public
    { Public declarations }
  end;

var
  formMain: TformMain;
  MyPopUpItems: array of TMenuItem;

implementation

uses frmAbout;

{$R *.dfm}


procedure TformMain.FormCreate(Sender: TObject);
begin
  formMain.Caption := strAppName + ' ' + strAppVersion;

  EditFind.Font.Size:=20;

  dlgBrowseforSavefolder.RootDirectory:=fdDesktopDirectory;
  dlgBrowseforSavefolder.RootDirectoryPath:=GetDesktopDirectoryFolder;

  SaveDialog1.InitialDir:=GetDesktopDirectoryFolder;
  JvxSplitter1.TopLeftLimit:=Tree.Constraints.MinWidth;

  lblTime.Font.Size := lblTime.Font.Size + 4;

  MemoLog.Clear;
  DoLog(strAppName + ' ' + strAppVersion);
  DoLog(strAppURL);

  {$IFDEF DebugMode}
    DoLog('Debug mode ON');
  {$ENDIF}

	// check the correct BASS dll was loaded
	if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
	begin
		MessageBox(0, 'An incorrect version of BASS.DLL was loaded', nil, MB_ICONERROR);
		Halt;
	end;

	// Initialize audio - default device, 44100hz, stereo, 16 bits
	if not BASS_Init(-1, 44100, 0, Handle, nil) then
		MessageBox(0, 'Error initializing audio!', nil, MB_ICONERROR);

  //Look for ini file and path to hex editor
  CheckIniForHexEditor;

  if fHexEditorPath = '' then
  begin
    btnSendToHex.Visible := false;
    editFind.Left := 412;
    editFind.Width := 450;
  end;
end;

procedure TformMain.FormDestroy(Sender: TObject);
begin
  FreeResources;
  if fFilesToCleanup <> nil then //might still be open if not all files could be deleted in FreeResources()
    fFilesToCleanup.Free;
  BASS_Free;
end;

procedure TformMain.OpenFile;
begin
  FreeResources;
  try
    fExplorer:=TDFExplorerBase.Create(OpenDialog1.FileName, OnDebug);
    try
      EnableDisableButtonsGlobal(false);
      memoLog.Clear;
      imagePreview.Bitmap.Clear;
      Tree.Clear;
      fExplorer.OnDoneLoading:=OnDoneLoading;
      fExplorer.OnDebug:=OnDebug;
      Tree.Header.AutoFitColumns(true);
      PanelBlank.BringToFront;

      fExplorer.Initialise;
      UpdateSaveAllMenu;
      DoLog('Opened file: ' + ExtractFileName( OpenDialog1.FileName ) );
    finally
      EnableDisableButtonsGlobal(true);
    end;
  except on E: EInvalidFile do
  begin
    DoLog(E.Message);
    FreeResources;
    EnableDisableButtonsGlobal(true);
  end;
  end;
end;

procedure TformMain.FreeResources;
var
  i: integer;
begin
  editFind.Text:='';
  tree.Clear;

  StopAndFreeAudio;

  //Try and delete any temp files sent to hex editor
  if fFilesToCleanup <> nil then
  begin
    for i := fFilesToCleanup.Count - 1 downto 0 do
      if DeleteFile(fFilesToCleanup[i]) then fFilesToCleanup.Delete(i);

     {if theres still files to be deleted - keep them on the list - FreeResources is called
      every time a ttarch is opened so could free it later}
     if fFilesToCleanup.Count = 0 then
        FreeAndNil(fFilesToCleanup);
  end;

  //In case invalid files are opened twice in succession
  if fExplorer <> nil then
    FreeAndNil(FExplorer);

  if MyPopUpItems <> nil then
  begin
    for i:=low(mypopupitems) to high(mypopupitems) do
      mypopupitems[i].Free;

    MyPopUpItems:=nil;
  end;
end;










{******************   Custom Events   ******************}

procedure TformMain.DoLog(Text: string);
begin
  memoLog.Lines.Add(Text);
end;

procedure TformMain.OnDoneLoading(Count: integer);
begin
  Tree.RootNodeCount := Count;
  AddFileTypePopupItems;
end;

procedure TformMain.OnDebug(DebugText: string);
begin
  memoLog.Lines.Add(DebugText);
end;

procedure TformMain.ShowProgress(Running: boolean);
begin
  case Running of
    True:
    begin
      jvgifanimator1.Animate := true;
      panelProgress.Visible:=true;
      panelProgress.BringToFront;
    end;

    False:
    begin
      jvgifanimator1.Animate := false;
      panelProgress.Visible:=false;
    end;
  end;
end;







{******************   Form update stuff Stuff   ******************}
procedure TformMain.editFindChange(Sender: TObject);
var
  i, FoundPos: integer;
  TempNode: pVirtualNode;
begin
  //sometimes it still has focus when view is filtered by category
  if (editFind.Focused = false) then exit;

  if EditFind.Text = '' then
  begin
    // If view is filtered and someone clicks in the search box and out again without typing
    // anything , we dont want the view to change to show all nodes
    if IsViewFilteredByCategory = false then
      FilterNodesByFileExt('');

    exit;
  end;

  //Remove tick from all items
  for I := 0 to PopupFileTypes.Items.Count -1 do
  begin
    PopupFileTypes.Items[i].Checked:=false;
  end;

  tree.BeginUpdate;
  //Make them all visible again
  FilterNodesByFileExt('');

  TempNode:=Tree.GetFirst;
  while (tempNode <> nil) do
  begin
    FoundPos:=pos(uppercase(EditFind.Text), uppercase(fExplorer.FileName[TempNode.index]));

    if FoundPos > 0 then
    begin
      tree.IsVisible[TempNode]:=true;
    end
    else
      tree.IsVisible[TempNode]:=false;

    TempNode:=Tree.GetNext(TempNode);
  end;

  tree.EndUpdate;
  //Show hide the save all visible menu
  menuItemSaveAllVisibleRaw.Visible := Tree.VisibleCount > 0;
end;

procedure TformMain.EnableDisableButtonsGlobal(Value: boolean);
begin
  btnOpen.Enabled:=Value;
  btnSaveFile.Enabled:=Value;
  btnSaveAllFiles.Enabled:=Value;
  tree.Enabled:=Value;
  btnFilterView.Enabled:=Value;
  btnAbout.Enabled:=Value;
  editFind.Enabled:=Value;
  btnSendToHex.Enabled:=Value;

  btnPlay.Enabled:=Value;
  btnPause.Enabled:=Value;
  btnStop.Enabled:=Value;
  TrackBarAudio.Enabled:=Value;

  if Value then EnableDisableButtons_TreeDependant;
end;

procedure TformMain.EnableDisableButtons_TreeDependant;
var
  NodeIsSelected: boolean;
  Ext: string;
begin
  if Tree.RootNodeCount > 0 then
    btnSaveAllFiles.Enabled:=true
  else
    btnSaveAllFiles.Enabled:=false;

  NodeIsSelected := Tree.SelectedCount > 0;
  btnSaveFile.Enabled:=NodeIsSelected;
  btnSendToHex.Enabled:=NodeIsSelected;
  menuItemSaveAllVisibleRaw.Visible := Tree.VisibleCount > 0;

  if NodeIsSelected then
  begin
    ext:=Uppercase(extractfileext(fExplorer.FileName[Tree.focusednode.Index]));
    menuItemDumpImage.Visible:= fExplorer.FileType[Tree.focusednode.Index] = ft_GenericImage;
    menuItemDumpDDSImage.Visible:=fExplorer.FileType[Tree.focusednode.Index] = ft_DDSImage;
    menuItemDumpText.Visible:= (fExplorer.FileType[Tree.focusednode.Index] = ft_Text) or (fExplorer.FileType[Tree.focusednode.Index] = ft_DelimitedText);
    menuItemDumpAudio.Visible:= fExplorer.FileType[Tree.focusednode.Index] = ft_Audio;
  end;
end;

procedure TformMain.memoLogURLClick(Sender: TObject; const URLText: string;
  Button: TMouseButton);
begin
  shellexec(0, 'open', URLText,'', '', SW_SHOWNORMAL);
end;


procedure TformMain.UpdateSaveAllMenu;
var
  i: integer;
  Ext: string;
begin
  {Parse through all files and enable the appropriate menu if it finds
  corresponding file type}

  if Tree.RootNodeCount = 0 then exit;


  menuItemSaveAllImages.Visible:=false;
  menuItemSaveAllText.Visible:=false;
  menuItemSaveAllDDSImages.Visible:=false;
  menuItemSaveAllAudio.Visible:=false;


  for i:=0 to tree.RootNodeCount -1 do
  begin
    ext:=Uppercase(extractfileext(extractfileext(fExplorer.FileName[i])));
    if fExplorer.FileType[i]  = ft_GenericImage then
      menuItemSaveAllImages.Visible:=true;
    if fExplorer.FileType[i]  = ft_DDSImage then
    begin
      menuItemSaveAllImages.Visible:=true;
      menuItemSaveAllDDSImages.Visible:=true;
    end;
    if (fExplorer.FileType[i]  = ft_Text) or (fExplorer.FileType[i]  = ft_DelimitedText) then
      menuItemSaveAllText.Visible:=true;
    if fExplorer.FileType[i]  = ft_Audio then
      menuItemSaveAllAudio.Visible:=true;
  end;
end;








{******************   Tree Stuff   ******************}

procedure TformMain.TreeChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  ext: string;
begin
  EnableDisableButtons_TreeDependant;

  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;

  panelBlank.BringToFront;
  //Clear resources here just to save memory ie not leaving a big image hanging around
  imagePreview.Bitmap.Clear;
  memoPreview.Clear;

  ext:=Uppercase(extractfileext(fExplorer.FileName[Tree.focusednode.Index]));

  //Other images
  if fExplorer.FileType[Tree.FocusedNode.Index] = ft_GenericImage then
  begin
    panelPreviewImage.BringToFront;
    fExplorer.DrawImageGeneric(Tree.focusednode.Index, imagePreview.Bitmap);
  end;

  //Text types
  if fExplorer.FileType[Tree.FocusedNode.Index] = ft_Text then
  begin
    panelPreviewText.BringToFront;
    memoPreview.Clear;
    fExplorer.ReadText(Tree.focusednode.Index, memoPreview.Lines);
  end;

  if (fExplorer.FileType[Tree.FocusedNode.Index] = ft_DelimitedText) then
  begin
    panelPreviewText.BringToFront;
    memoPreview.Clear;
    fExplorer.ReadDelimitedText(Tree.focusednode.Index, memoPreview.Lines);
  end;

  //DDS Images
  if fExplorer.FileType[Tree.FocusedNode.Index] = ft_DDSImage then
  begin
    panelPreviewImage.BringToFront;
    fExplorer.DrawImageDDS(Tree.focusednode.Index, imagePreview.Bitmap);
  end;


  //Audio types
  if fExplorer.FileType[Tree.FocusedNode.Index] = ft_Audio then
  begin
    panelPreviewAudio.BringToFront;
  end;
end;

procedure TformMain.TreeDblClick(Sender: TObject);
begin
  //Audio types
  if fExplorer.FileType[Tree.focusednode.Index] = ft_Audio then
  begin
    panelPreviewAudio.BringToFront;
    StopAndFreeAudio;
    btnPlay.Click;
  end;


end;

procedure TformMain.TreeGetImageIndex(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex;
  var Ghosted: Boolean; var ImageIndex: Integer);
var
  FileType: TFileType;
begin
  if column <> 0 then exit;
  if Kind = ikOverlay then exit;

  FileType := fExplorer.FileType[node.Index];

  case FileType of
    ft_GenericImage: ImageIndex:= 8;
    ft_DDSImage: ImageIndex:= 8;
    ft_Text:  ImageIndex:= 9;
    ft_DelimitedText:  ImageIndex:= 14;
    ft_Audio: ImageIndex:= 12;
    ft_Other: ImageIndex:= 5;
    ft_Unknown: ImageIndex:=5
  else
    ImageIndex:=5;
  end;
end;

procedure TformMain.TreeGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
begin
  case Column of
    0: Celltext := fExplorer.FileName[node.index];
    1: Celltext := fExplorer.FileExtension[node.Index];
    2: Celltext := inttostr(fExplorer.FileSize[node.index] );
    3: Celltext := inttostr (fExplorer.FileOffset[node.index] );
  end;
end;










{******************   Category Filtering Stuff   ******************}

function TformMain.IsViewFilteredByCategory: boolean;
var
  i: integer;
begin
  result:=false;
  for I := 0 to PopupFileTypes.Items.Count -1 do
  begin
    if PopupFileTypes.Items[i].Checked then
      result:=true;
  end;
end;

procedure TformMain.AddFiletypePopupItems;
var
  FileTypes: TStringList;
  tempStr: string;
  tempFileType: TFileType;
  i: integer;
begin
  Filetypes:=tstringlist.Create;
  try
    for i:=0 to tree.RootNodeCount -1 do
    begin
      tempStr:= fExplorer.FileExtension[i];

      if (FileTypes.IndexOf(tempStr)=-1) and (tempStr > '' ) then
          FileTypes.Add(tempStr);
    end;
    FileTypes.Sort;

    SetLength(MyPopupItems, Filetypes.Count + 2); //+2 for 'all files' and line break
    for i:=low(mypopupitems) to high(mypopupitems) -2 do
    begin
      MyPopUpItems[i]:=TMenuItem.Create(Self);
      MyPopUpItems[i].Caption:=FileTypes[i];
      MyPopUpItems[i].tag:=i + 2;
      PopupFileTypes.Items.add(MyPopupItems[i]);
      MyPopUpItems[i].OnClick:=FileTypePopupMenuHandler;

      //icons
      tempFileType := GetFileTypeFromFileExtension( FileTypes[i] );

      case tempFileType of
        ft_GenericImage:   MyPopupItems[i].ImageIndex:=8;
        ft_DDSImage:   MyPopupItems[i].ImageIndex:=8;
        ft_Text:    MyPopupItems[i].ImageIndex:=9;
        ft_DelimitedText:    MyPopupItems[i].ImageIndex:=14;
        ft_Audio:  MyPopupItems[i].ImageIndex:=12;
        ft_Other:   MyPopupItems[i].ImageIndex:=5;
        ft_Unknown: MyPopupItems[i].ImageIndex:=5;
        else
          MyPopupItems[i].ImageIndex:=5;
      end;
    end;

    //Add 'all files' menu item
    i:=high(mypopupitems);
    MyPopUpItems[i]:=TMenuItem.Create(Self);
    MyPopUpItems[i].Caption:=strViewAllFiles;
    MyPopUpItems[i].tag:=0;
    MyPopUpItems[i].Checked:=true;
    //MyPopUpItems[i].ImageIndex:=5;
    popupFileTypes.Items.Insert(0, MyPopUpItems[i]);
    MyPopUpItems[i].OnClick:=FileTypePopupMenuHandler;

    //Add line break menu item
    i:=high(mypopupitems)-1;
    MyPopUpItems[i]:=TMenuItem.Create(Self);
    MyPopUpItems[i].Caption:='-';
    MyPopUpItems[i].tag:=1;
    MyPopUpItems[i].Checked:=true;
    //MyPopUpItems[i].ImageIndex:=5;
    popupFileTypes.Items.Insert(1, MyPopUpItems[i]);
  finally
    Filetypes.Free;
  end;
end;

procedure TformMain.FilterNodesByFileExt(FileExt: string);
var
  TempNode: PVirtualNode;
begin
  if Tree.RootNodeCount=0 then exit;

  Tree.BeginUpdate;
  try
    TempNode:=Tree.GetFirst;
    while (tempNode <> nil) do
    begin
      if FileExt = '' then //Show all nodes
        Tree.IsVisible[TempNode]:=true
      else
      if fExplorer.FileExtension[TempNode.Index] = FileExt then
        Tree.IsVisible[TempNode]:=true
      else
        Tree.IsVisible[TempNode]:=false;

      TempNode:=Tree.GetNext(TempNode);
    end;
  finally
    Tree.EndUpdate;
  end;
end;




{******************     Popup Handlers     ******************}

procedure TformMain.OpenPopupMenuHandler(Sender: TObject);
var
  SenderName: string;
begin
  SenderName := tmenuitem(sender).Name;

  if SenderName = 'MenuItemOpenFolder' then
    OpenDialog1.InitialDir:=''
  else
  if SenderName = 'MenuItemOpenCave' then
    OpenDialog1.InitialDir:=GetCavePath
  else
  if SenderName = 'MenuItemOpenStacking' then
    OpenDialog1.InitialDir:=GetStackingPath
  else
  if SenderName = 'MenuItemOpenCostumeQuest' then
    OpenDialog1.InitialDir:=GetCostumeQuestPath
  else
  if SenderName = 'MenuItemOpenIronBrigade' then
    OpenDialog1.InitialDir:=GetIronBrigadePath;


  if OpenDialog1.Execute then
    OpenFile;
end;

procedure TformMain.FileTypePopupMenuHandler(Sender: TObject);
var
  tempStr: string;
  i: integer;
begin
  if Tree.RootNodeCount=0 then exit;

  editFind.Text:=''; //doing editFind.clear doesnt show the 'search' default text
  tree.SetFocus; //take the focus away from the search editbox if it has it

  with Sender as TMenuItem do
  begin
    tempStr:=caption;
    StrReplace(tempStr, '&', '',[rfIgnoreCase, rfReplaceAll]);
    if tempStr = strViewAllFiles then
      FilterNodesByFileExt('')
    else
      FilterNodesByFileExt(tempStr);

    //DoLog('Filtered view by category: ' + temp);
  end;

  //Remove tick from all items
  for I := 0 to PopupFileTypes.Items.Count -1 do
  begin
    PopupFileTypes.Items[i].Checked:=false;
  end;

  //Add tick to the item
  with Sender as TMenuItem do
  begin
    PopupFileTypes.Items[tag].Checked:=true;
  end;
end;






{******************   Save Stuff   ******************}

procedure TformMain.menuItemDumpFileClick(Sender: TObject);
begin
  btnSaveFile.OnClick(formMain);
end;

procedure TformMain.menuItemDumpImageClick(Sender: TObject);
var
  TempPng: TPngImage;
  TempBmp: TBitmap;
  TempBmp32: TBitmap32;
  DecodeResult: boolean;
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;

  SaveDialog1.Filter:='Png files|*.png';
  SaveDialog1.DefaultExt:='.png';
  SaveDialog1.FileName:= SanitiseFileName( ChangeFileExt(fExplorer.FileName[Tree.focusednode.Index], '' ) );
  if SaveDialog1.Execute = false then exit;

  DecodeResult:=false;

  TempPng:=TPngImage.Create;
  try
    EnableDisableButtonsGlobal(false);
    DoLog(strSavingFile + SaveDialog1.FileName);

    TempBmp32:=TBitmap32.Create;
    try
      if fExplorer.FileType[Tree.focusednode.Index] = ft_DDSImage then
      begin
        DecodeResult:=fExplorer.DrawImageDDS(Tree.focusednode.Index, TempBmp32)
      end
      else
      if fExplorer.FileType[Tree.focusednode.Index] = ft_GenericImage then
        DecodeResult:=fExplorer.DrawImageGeneric(Tree.focusednode.Index, TempBmp32) ;

      if DecodeResult = false then
      begin
        DoLog('Image decode failed! Save cancelled.');
        exit;
      end;

      TempBmp:=TBitmap.Create;
      try
        TempBmp.Assign(TempBmp32);
        TempPng.Assign(TempBmp);
      finally
        TempBmp.Free;
      end;
      TempPng.SaveToFile(SaveDialog1.FileName);
    finally
      TempBmp32.Free;
    end;
  finally
    TempPng.Free;
    if DecodeResult = true then DoLog(strDone);
    EnableDisableButtonsGlobal(true);
  end;

end;

procedure TformMain.menuItemDumpTextClick(Sender: TObject);
var
  TempStrings: TStringList;
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;

  SaveDialog1.Filter:='Text files|*.txt';
  SaveDialog1.DefaultExt:='.txt';
  SaveDialog1.FileName:= SanitiseFileName( ChangeFileExt(fExplorer.FileName[Tree.focusednode.Index], '' ) );
  if SaveDialog1.Execute = false then exit;

  TempStrings:=TStringList.Create;
  try
    EnableDisableButtonsGlobal(false);
    DoLog(strSavingFile + SaveDialog1.FileName);

    if fExplorer.FileType[Tree.FocusedNode.Index] = ft_Text then
      fExplorer.ReadText(Tree.focusednode.Index, TempStrings)
    else
    if fExplorer.FileType[Tree.FocusedNode.Index] = ft_DelimitedText then
      fExplorer.ReadDelimitedText(Tree.FocusedNode.Index, TempStrings);

    TempStrings.SaveToFile( SaveDialog1.FileName );
  finally
    TempStrings.Free;
    DoLog(strDone);
    EnableDisableButtonsGlobal(true);
  end;

end;

procedure TformMain.menuItemDumpAudioClick(Sender: TObject);
var
  DecodeResult: boolean;
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;

  SaveDialog1.Filter:='MP3 files|*.MP3';
  SaveDialog1.DefaultExt:='.mp3';
  SaveDialog1.FileName:=ChangeFileExt(fExplorer.FileName[Tree.focusednode.Index], '' );
  if SaveDialog1.Execute = false then exit;

  DecodeResult:=false;
  EnableDisableButtonsGlobal(false);
  try
    DoLog(strSavingFile + SaveDialog1.FileName);

    if fExplorer.FileType[Tree.focusednode.Index] = ft_Audio then
    //if Ext = strWavExt then
      //DecodeResult:=fExplorer.SaveWavToFile(Tree.focusednode.Index, ExtractFilePath(SaveDialog1.FileName), ExtractFileName(SaveDialog1.FileName))
      fExplorer.SaveFile(Tree.focusednode.Index, ExtractFilePath(SaveDialog1.FileName), ExtractFileName(SaveDialog1.FileName))
    else
    begin
      DoLog('Not a recognised audio type file extension! Save cancelled.');
      DecodeResult:=false;
    end;
  finally
    if DecodeResult = true then DoLog(strDone);
    EnableDisableButtonsGlobal(true);
  end;


end;

procedure TformMain.menuItemSaveAllAudioClick(Sender: TObject);
var
  TempNode: pVirtualNode;
begin
  if Tree.RootNodeCount=0 then exit;
  if dlgBrowseforSaveFolder.Execute = false then exit;

  EnableDisableButtonsGlobal(false);
  try
    DoLog(strDumpingAllAudio);
    ShowProgress(True);

    TempNode:=Tree.GetFirst;
    while (tempNode <> nil) do
    begin
      if fExplorer.FileType[TempNode.Index] <> ft_Audio then //not an audio file
      begin
        TempNode:=Tree.GetNext(TempNode);
        continue;
      end;

      if fExplorer.FileType[TempNode.Index] = ft_Audio then
        fExplorer.SaveFile(TempNode.Index, IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory), fExplorer.FileName[TempNode.Index]);

      Application.ProcessMessages;
      TempNode:=Tree.GetNext(TempNode);
    end;

  finally
    EnableDisableButtonsGlobal(true);
    ShowProgress(False);
    DoLog(strDone);
  end;

end;

procedure TformMain.menuItemSaveAllDDSImagesClick(Sender: TObject);
var
  TempNode: pVirtualNode;
  DecodeResult: boolean;
begin
  if Tree.RootNodeCount=0 then exit;
  if dlgBrowseforSaveFolder.Execute = false then exit;

  EnableDisableButtonsGlobal(false);
  try
    DoLog(strDumpingAllDDSImages);
    ShowProgress(True);

    TempNode:=Tree.GetFirst;
    while (tempNode <> nil) do
    begin
      if   fExplorer.FileType[TempNode.Index] <> ft_DDSImage then //not DDS image
      begin
        TempNode:=Tree.GetNext(TempNode);
        continue;
      end;

      DecodeResult:=false;
      if fExplorer.FileType[TempNode.Index] = ft_DDSImage then
      begin
        ForceDirectories(extractfilepath(IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory) + ExtractPartialPath( fExplorer.FileName[TempNode.Index])));
        DecodeResult:=fExplorer.SaveDDSToFile(TempNode.Index, IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory), ChangeFileExt(fExplorer.FileName[TempNode.Index], '.dds'))
      end;

      if DecodeResult = false then
      begin
        TempNode:=Tree.GetNext(TempNode);
        Application.ProcessMessages;
        continue;
      end;

      Application.ProcessMessages;
      TempNode:=Tree.GetNext(TempNode);
    end;

  finally
    EnableDisableButtonsGlobal(true);
    ShowProgress(False);
    DoLog(strDone);
  end;

end;

procedure TformMain.menuItemSaveAllImagesClick(Sender: TObject);
var
  TempPng: TPngImage;
  TempBmp: TBitmap;
  TempBmp32: TBitmap32;
  TempNode: pVirtualNode;
  DecodeResult: boolean;
begin
  if Tree.RootNodeCount=0 then exit;
  if dlgBrowseforSaveFolder.Execute = false then exit;

  TempPng:=TPngImage.Create;
  TempBmp32:=TBitmap32.Create;
  TempBmp:=TBitmap.Create;
  try
    EnableDisableButtonsGlobal(false);
    ShowProgress(True);
    DoLog(strDumpingAllImages);

    TempNode:=Tree.GetFirst;
    while (tempNode <> nil) do
    begin
      if (fExplorer.FileType[TempNode.Index] <> ft_DDSImage) then
        if (fExplorer.FileType[TempNode.Index] <> ft_GenericImage) then  //not an image
        begin
          TempNode:=Tree.GetNext(TempNode);
          continue;
        end;

      TempBmp32.Clear;
      TempBmp.Assign(nil);

      DecodeResult := false;
      if fExplorer.FileType[TempNode.Index] = ft_DDSImage then
      begin
        DecodeResult:=fExplorer.DrawImageDDS(TempNode.Index, TempBmp32)
      end
      else
      if fExplorer.FileType[TempNode.Index] = ft_GenericImage then
        DecodeResult:=fExplorer.DrawImageGeneric(TempNode.Index, TempBmp32);

      if DecodeResult = false then
      begin
        TempNode:=Tree.GetNext(TempNode);
        continue;
      end;

      TempBmp.Assign(TempBmp32);
      TempPng.Assign(TempBmp);
      ForceDirectories(extractfilepath(IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory) + ExtractPartialPath( fExplorer.FileName[TempNode.Index])));
      TempPng.SaveToFile(IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory) +  ChangeFileExt(fExplorer.FileName[TempNode.Index], '.png'));

      Application.ProcessMessages;
      TempNode:=Tree.GetNext(TempNode);
    end;

  finally
    TempPng.Free;
    TempBmp32.Free;
    TempBmp.Free;
    EnableDisableButtonsGlobal(true);
    ShowProgress(False);
    DoLog(strDone);
  end;

end;

procedure TformMain.menuItemSaveAllRawClick(Sender: TObject);
begin
  btnSaveAllFiles.OnClick(formMain);
end;

procedure TformMain.menuItemSaveAllTextClick(Sender: TObject);
var
  TempStrings: TStringList;
  TempNode: pVirtualNode;
begin
  if Tree.RootNodeCount=0 then exit;
  if dlgBrowseforSaveFolder.Execute = false then exit;

  TempStrings:=TStringList.Create;
  try
    EnableDisableButtonsGlobal(false);
    ShowProgress(True);
    DoLog(strDumpingAllText);

    TempNode:=Tree.GetFirst;
    while (tempNode <> nil) do
    begin
      if fExplorer.FileType[TempNode.Index] <> ft_Text then
        if fExplorer.FileType[TempNode.Index] <> ft_DelimitedText then
        begin
          TempNode:=Tree.GetNext(TempNode);
          continue;
        end;

      TempStrings.Clear;

      if fExplorer.FileType[TempNode.Index] = ft_Text then
        fExplorer.ReadText(TempNode.Index, TempStrings)
      else
      if fExplorer.FileType[TempNode.Index] = ft_DelimitedText then
        fExplorer.ReadDelimitedText(TempNode.Index, TempStrings);

      ForceDirectories(extractfilepath(IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory) + ExtractPartialPath( fExplorer.FileName[TempNode.Index])));
      TempStrings.SaveToFile( IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory) + ChangeFileExt(fExplorer.FileName[TempNode.Index], '.txt') );
      TempNode:=Tree.GetNext(TempNode);
      Application.ProcessMessages;
    end;

  finally
    TempStrings.Free;
    EnableDisableButtonsGlobal(true);
    ShowProgress(False);
    DoLog(strDone);
  end;

end;

procedure TformMain.menuItemSaveAllVisibleRawClick(Sender: TObject);
var
  TempNode: pVirtualNode;
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.VisibleCount=0 then exit;
  if dlgBrowseforSaveFolder.Execute = false then exit;

  try
    EnableDisableButtonsGlobal(false);
    ShowProgress(True);
    DoLog(strDumpingAllVisibleFiles);

    TempNode:=Tree.GetFirst;
    while (tempNode <> nil) do
    begin
      if Tree.IsVisible[TempNode] = false then //not visible
      begin
        TempNode:=Tree.GetNext(TempNode);
        continue;
      end
      else
      begin
        ForceDirectories(extractfilepath(IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory) + ExtractPartialPath( fExplorer.FileName[TempNode.Index])));
        fExplorer.SaveFile(TempNode.Index, IncludeTrailingPathDelimiter(dlgBrowseForSaveFolder.Directory), fExplorer.FileName[TempNode.Index]);

      end;

      TempNode:=Tree.GetNext(TempNode);
      Application.ProcessMessages;
    end;

  finally
    EnableDisableButtonsGlobal(true);
    ShowProgress(False);
    DoLog(strDone);
  end;

end;

procedure TformMain.menuItemDumpDDSImageClick(Sender: TObject);
var
  DecodeResult: boolean;
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;

  SaveDialog1.Filter:='DDS files|*.dds';
  SaveDialog1.DefaultExt:='.dds';
  SaveDialog1.FileName:= SanitiseFileName (ChangeFileExt(fExplorer.FileName[Tree.focusednode.Index], '' ) );
  if SaveDialog1.Execute = false then exit;

  DecodeResult:=false;
  EnableDisableButtonsGlobal(false);
  try
    DoLog(strSavingFile + SaveDialog1.FileName);

    if fExplorer.FileType[Tree.focusednode.Index] =ft_DDSImage then
    begin
      DecodeResult:=fExplorer.SaveDDSToFile(Tree.focusednode.Index,ExtractFilePath(SaveDialog1.FileName), ExtractFileName(SaveDialog1.FileName))
    end
    else
    begin
      DoLog('Not a recognised dds type file extension! Save cancelled.');
      DecodeResult:=false;
    end;
  finally
    if DecodeResult = true then DoLog(strDone);
    EnableDisableButtonsGlobal(true);
  end;

end;

procedure TformMain.btnSaveAllFilesClick(Sender: TObject);
begin
  if Tree.RootNodeCount=0 then exit;
  if dlgBrowseforSaveFolder.Execute = false then exit;

  ShowProgress(true);
  EnableDisableButtonsGlobal(false);
  try
    DoLog(strDumpingAllFiles);
    fExplorer.SaveFiles(dlgBrowseForSaveFolder.Directory);
  finally
    EnableDisableButtonsGlobal(true);
    ShowProgress(False);
    DoLog(strDone);
  end;
end;

procedure TformMain.btnSaveFileClick(Sender: TObject);
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;

  SaveDialog1.Filter:='All Files|*.*';
  SaveDialog1.DefaultExt:='';

  SaveDialog1.FileName := SanitiseFileName( fExplorer.FileName[Tree.focusednode.Index] );

  if SaveDialog1.Execute = false then exit;

  DoLog(strSavingFile + SaveDialog1.FileName);
  EnableDisableButtonsGlobal(false);
  try
    fExplorer.SaveFile(Tree.focusednode.Index, ExtractFilePath(SaveDialog1.FileName), ExtractFileName(SaveDialog1.FileName));
  finally
    DoLog(strDone);
    EnableDisableButtonsGlobal(true);
    //Progressbar1.Position:=0;
  end;
end;



procedure TformMain.btnSendToHexClick(Sender: TObject);
var
  NewName: string;
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;
  if fHexEditorPath = '' then DoLog(strErrorHexEditorPath);


  EnableDisableButtonsGlobal(false);
  try
    try
      fExplorer.SaveFile(Tree.focusednode.Index, IncludeTrailingPathDelimiter(Getwindowstempfolder), SanitiseFileName(fExplorer.FileName[Tree.focusednode.Index]));
      ShellExec(0, 'open', fHexEditorPath, '"' + IncludeTrailingPathDelimiter( GetWindowsTempFolder) + SanitiseFileName(fExplorer.FileName[Tree.focusednode.Index]) +'"', ExtractFilePath(fHexEditorPath), SW_SHOWNORMAL);
    except on E: EFCreateError do
    begin //get new name if its already there and open
      NewName := FindUnusedFileName( IncludeTrailingPathDelimiter( GetWindowsTempFolder) + SanitiseFileName(fExplorer.FileName[Tree.focusednode.Index]), ExtractFileExt(fExplorer.FileName[Tree.focusednode.Index]), '-copy');
      DoLog(strErrHexFileExists + NewName);
      fExplorer.SaveFile(Tree.focusednode.Index, IncludeTrailingPathDelimiter(Getwindowstempfolder), ExtractFileName(NewName));
      ShellExec(0, 'open', fHexEditorPath, '"' + IncludeTrailingPathDelimiter( GetWindowsTempFolder) + ExtractFileName(NewName) +'"', ExtractFilePath(fHexEditorPath), SW_SHOWNORMAL);
    end;
    end;

    //Add files to list so they can be cleaned up later if possible
    if fFilesToCleanup = nil then
      fFilesToCleanUp := TStringList.Create;

    if NewName <> '' then
      fFilesToCleanUp.Add( IncludeTrailingPathDelimiter(Getwindowstempfolder) + ExtractFileName(NewName))
    else
      fFilesToCleanUp.Add( IncludeTrailingPathDelimiter(Getwindowstempfolder) + ExtractFileName(fExplorer.FileName[Tree.focusednode.Index]));
  finally
    EnableDisableButtonsGlobal(true);
  end;

end;






{***********************   Audio Playback Stuff   ***********************}
procedure TformMain.StopAndFreeAudio;
begin
  BASS_ChannelSlideAttribute(fAudioHandle, BASS_ATTRIB_VOL, 0, 500);
  Sleep(500);
  BASS_ChannelStop(fAudioHandle);
  BASS_StreamFree(fAudioHandle);
  TrackBarAudio.Value := 0;
  lblTime.Caption := '';
  fTotalTime := '';

  if fAudioStream <> nil then
    FreeAndNil(fAudioStream);
end;


procedure TformMain.btnPauseClick(Sender: TObject);
begin
  if BASS_ChannelPause(fAudioHandle) = false then
    if BASS_ErrorGetCode = BASS_ERROR_ALREADY then //Already paused
      BASS_ChannelPlay(fAudioHandle, False)
end;

procedure TformMain.btnPlayClick(Sender: TObject);
var
  DecodeResult: boolean;
  strSecs: string;
  ByteLength: QWord;
  SecsLength: Double;
  Seconds: Integer;
begin
  if Tree.RootNodeCount=0 then exit;
  if Tree.SelectedCount=0 then exit;

  if fExplorer.FileType[Tree.focusednode.Index] <> ft_Audio then
  begin
    DoLog('File not recognised audio type');
    exit;
  end;

  BASS_StreamFree(fAudioHandle);
  if fAudioStream <> nil then
    FreeAndNil(fAudioStream);

  fAudioStream := TMemoryStream.Create;
  try
    DecodeResult:=false;

    if fExplorer.FileType[Tree.focusednode.Index] = ft_Audio then //ext = strWAVExt then
      fExplorer.SaveFileToStream(Tree.focusednode.Index, fAudioStream); //.SaveWavToStream(Tree.focusednode.Index, fAudioStream);


    //fAudioStream.SaveToFile('c:\users\ben\desktop\musictest.wav');

    fAudioStream.Position:=0;
    fAudioHandle := BASS_StreamCreateFile(True, fAudioStream.Memory, 0, fAudioStream.Size, BASS_UNICODE);

    //if fAudioHandle = 0 then exit;


	if not BASS_ChannelPlay(fAudioHandle, True) then
    begin
		DoLog('Error playing stream! Error code:' + inttostr(BASS_ErrorGetCode));
		Exit;
    end;


    ByteLength := BASS_ChannelGetLength(fAudioHandle, BASS_POS_BYTE);
    SecsLength := BASS_ChannelBytes2Seconds(fAudioHandle, ByteLength);
    Seconds := Trunc(SecsLength);

    strSecs := IntToStr(Seconds mod 60);
    if Seconds mod 60 < 10 then
      strSecs := '0' + strSecs;
    fTotalTime:= ' / ' + Format('%d:%s', [Seconds div 60, strSecs]);
    //lblCurrentlyPlaying.Caption :=fExplorer.FileName[Tree.focusednode.Index];

    TrackBarAudio.Value := 0;
    TrackBarAudio.Maximum:= round(BASS_ChannelBytes2Seconds(fAudioHandle, BASS_ChannelGetLength(fAudioHandle, BASS_POS_BYTE)));
    fTrackBarChanging := false;

    Timer1.Enabled := true;
  finally
    //fAudioStream.Free;
  end;

end;

function SecToTime(Sec: Integer): string;
var
  H, M, S: string;
  ZH, ZM, ZS: Integer;
begin
  ZH := Sec div 3600;
  ZM := Sec div 60 - ZH * 60;
  ZS := Sec - (ZH * 3600 + ZM * 60) ;
  H := IntToStr(ZH) ;

  if ZM mod 60 < 10 then
    M := '0' + IntToStr(ZM)
  else
    M := IntToStr(ZM) ;
  if ZS mod 60 < 10 then
    S := '0' + IntToStr(ZS)
  else
    S := IntToStr(ZS) ;

  Result := {H + ':' +} M + ':' + S;
end;

procedure TformMain.Timer1Timer(Sender: TObject);
var
  Seconds: integer;
begin
  Seconds :=  round(BASS_ChannelBytes2Seconds(fAudioHandle, BASS_ChannelGetPosition(fAudioHandle, BASS_POS_BYTE)));
  if Seconds < 0 then
    lblTime.caption := '00:00' + fTotalTime
  else
    lblTime.caption := SecToTime(Seconds) + fTotalTime;

  if fTrackBarChanging = false then
    TrackBarAudio.Value:= Seconds;

end;

procedure TformMain.TrackBarAudioChangedValue(Sender: TObject;
  NewValue: Integer);
begin
  fTrackBarChanging:=true;
  BASS_ChannelSetPosition(fAudioHandle, BASS_ChannelSeconds2Bytes(fAudioHandle, TrackBarAudio.Value)  , BASS_POS_BYTE);
  fTrackBarChanging:=false;
end;

procedure TformMain.btnStopClick(Sender: TObject);
begin
  StopAndFreeAudio;
end;



procedure TformMain.btnAboutClick(Sender: TObject);
begin
  AboutFrm.ShowModal;
end;

procedure TformMain.CheckIniForHexEditor;
var
  IniFile: TIniFile;
begin
  fHexEditorPath := '';
  if FileExists(ExtractFilePath(Application.ExeName) + 'DoublefineExplorer.ini') = false then exit;

  IniFile := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'DoublefineExplorer.ini');
  try
    fHexEditorPath := IniFile.ReadString('Settings', 'Hexeditor', '');
  finally
    IniFile.Free
  end;
end;

end.
