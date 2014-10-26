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

unit frmAbout;

interface

uses
  Windows, Forms, Controls, Classes, Graphics,
  ExtCtrls, JvExControls, JvScrollText,
  JCLShell,
  uDFExplorer_Const, pngimage;


type
  TAboutfrm = class(TForm)
    Image1: TImage;
    Image2: TImage;
    JvScrollText1: TJvScrollText;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure Image1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Aboutfrm: TAboutfrm;

implementation

{$R *.dfm}

procedure TAboutfrm.FormCreate(Sender: TObject);
begin
  //Add the version to the scrolling text
  JVScrollText1.Items.Strings[2]:='Version ' + strAppVersion;
  //Add a huge empty string to force scrolltext to align properly
  JVScrollText1.Items.Add('                                                                                                                               ');
  JVScrollText1.Font.Color:=clWhite;
  JVScrollText1.Font.Size:=14;

  Aboutfrm.Caption:='About ' + strAppName;
end;

procedure TAboutfrm.FormHide(Sender: TObject);
begin
  //JVScrollText1.Active:=false;
end;

procedure TAboutfrm.FormShow(Sender: TObject);
begin
  JVScrollText1.Active:=true;
end;

procedure TAboutfrm.Image1Click(Sender: TObject);
begin
  shellexec(0, 'open', 'Http://quickandeasysoftware.net','', '', SW_SHOWNORMAL);
end;

end.
