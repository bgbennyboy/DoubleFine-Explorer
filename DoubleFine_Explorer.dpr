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

program DoubleFine_Explorer;

uses
  Forms,
  frmMain in 'frmMain.pas' {formMain},
  uDFExplorer_Const in 'uDFExplorer_Const.pas',
  uDFExplorer_PAKManager in 'uDFExplorer_PAKManager.pas',
  uDFExplorer_Types in 'uDFExplorer_Types.pas',
  uDFExplorer_Base in 'uDFExplorer_Base.pas',
  uDFExplorer_Funcs in 'uDFExplorer_Funcs.pas',
  uDFExplorer_FSBManager in 'uDFExplorer_FSBManager.pas',
  frmAbout in 'frmAbout.pas' {Aboutfrm},
  uDFExplorer_BaseBundleManager in 'uDFExplorer_BaseBundleManager.pas',
  uDFExplorer_PCKManager in 'uDFExplorer_PCKManager.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DoubleFine Explorer';
  Application.CreateForm(TformMain, formMain);
  Application.CreateForm(TAboutfrm, Aboutfrm);
  Application.Run;
end.
