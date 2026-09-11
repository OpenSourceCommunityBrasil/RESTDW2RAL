program rdw2ralgui;

uses
  Vcl.Forms,
  uprincipal in 'uprincipal.pas' {fprincipal},
  uConversor in '..\uConversor.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'rdw2ral';
  Application.CreateForm(Tfprincipal, fprincipal);
  Application.Run;
end.
