program srv_rdw2ral;

uses
  Vcl.Forms,
  uprincipal in 'uprincipal.pas' {fprincipal},
  udm_eventos in 'udm_eventos.pas' {dm_eventos: TDataModule};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(Tfprincipal, fprincipal);
  Application.Run;
end.
