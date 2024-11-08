program ral_rdw1;

uses
  madExcept,
  madLinkDisAsm,
  madListHardware,
  madListProcesses,
  madListModules,
  Vcl.Forms,
  uprincipal in 'uprincipal.pas' {fprincipal},
  udm_restdw in 'udm_restdw.pas' {dm_restdw: TDataModule};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(Tfprincipal, fprincipal);
  Application.CreateForm(Tdm_restdw, dm_restdw);
  Application.Run;
end.
