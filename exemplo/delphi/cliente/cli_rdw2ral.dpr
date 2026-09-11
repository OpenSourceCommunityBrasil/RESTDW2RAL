program cli_rdw2ral;

uses
  Vcl.Forms,
  uprincipal in 'uprincipal.pas' {fprincipal};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(Tfprincipal, fprincipal);
  Application.Run;
end.
