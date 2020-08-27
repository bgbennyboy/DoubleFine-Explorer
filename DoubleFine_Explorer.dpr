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

program DoubleFine_Explorer;



{$R *.dres}

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
  uDFExplorer_PPAKManager in 'uDFExplorer_PPAKManager.pas',
  uDFExplorer_LPAKManager in 'uDFExplorer_LPAKManager.pas',
  uDFExplorer_PKGManager in 'uDFExplorer_PKGManager.pas',
  uDFExplorer_LABManager in 'uDFExplorer_LABManager.pas',
  uVimaDecode in 'uVimaDecode.pas',
  uDFExplorer_PCKManager in 'uDFExplorer_PCKManager.pas',
  uDFExplorer_ISBManager in 'uDFExplorer_ISBManager.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DoubleFine Explorer';
  Application.CreateForm(TformMain, formMain);
  Application.CreateForm(TAboutfrm, Aboutfrm);
  Application.Run;
end.
