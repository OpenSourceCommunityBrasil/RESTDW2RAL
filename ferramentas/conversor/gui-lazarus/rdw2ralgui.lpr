program rdw2ralgui;

{ A janela do conversor no Lazarus. O motor - uConversor, uma pasta acima - e o
  mesmo da linha de comando e da janela do Delphi. }

{$mode delphi}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // a widgetset da LCL
  Forms,
  uprincipal;

// Sem a diretiva de recurso de proposito: o lazbuild nao gera o .res do
// projeto - so o IDE -, e com ela aqui um checkout limpo nao compila pela
// linha de comando. O que ela traria e bloco de versao; o manifesto que da o
// visual do Windows vem da propria LCL.

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'RESTDW2RAL';
  Application.Initialize;
  Application.CreateForm(Tfprincipal, fprincipal);
  Application.Run;
end.
