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
