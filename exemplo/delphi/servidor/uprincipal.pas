{ Servidor da demo.

  Repare no que NAO tem aqui: nenhuma rota escrita a mao e nenhum arquivo de
  exportacao. O TRALRESTDWModule le o ClassModule, acha os TRALRESTDWServerEvents
  do DataModule e publica as rotas sozinho (AutoRoutes). }
unit uprincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls,
  RALServer, RALIndyServer, RALRoutes, RALTypes, RALRESTDWModule,
  { o RALDBFireDAC precisa estar linkado para que o DatabaseLink 'FireDAC'
    encontre o driver pelo nome }
  RALDBModule, RALDBFireDAC;

type
  Tfprincipal = class(TForm)
    server: TRALIndyServer;
    rdw: TRALRESTDWModule;
    dbm: TRALDBModule;
    mLog: TMemo;
    btLigar: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btLigarClick(Sender: TObject);
  private
    procedure Log(const AMsg: string);
    procedure MostrarRotas;
  end;

var
  fprincipal: Tfprincipal;

implementation

{$R *.dfm}

uses
  udm_eventos, udm_banco;

procedure Tfprincipal.Log(const AMsg: string);
begin
  mLog.Lines.Add(AMsg);
end;

procedure Tfprincipal.MostrarRotas;
var
  vInt1: Integer;
  vRoute: TRALRoute;
begin
  Log(Format('%d rota(s) publicada(s) automaticamente a partir de "%s":',
             [rdw.Routes.Count, rdw.ClassModule]));

  for vInt1 := 0 to rdw.Routes.Count - 1 do
  begin
    vRoute := TRALRoute(rdw.Routes.Items[vInt1]);
    Log(Format('   %-12s %s   (%d param de entrada)',
               [vRoute.Name, vRoute.Route, vRoute.InputParams.Count]));
  end;
  Log('');
end;

procedure Tfprincipal.FormCreate(Sender: TObject);
begin
  MostrarRotas;

  { o banco e criado ao lado do executavel na primeira execucao; o caminho vai
    para o modulo em codigo porque depende de onde o exe esta }
  PrepararBanco;
  dbm.Database := ArquivoBanco;
  Log('banco DBWare: ' + dbm.Database);
  Log(Format('   rotas de banco publicadas em "%s" pelo TRALDBModule', [dbm.Domain]));
  Log('');

  server.Start;
  Log(Format('servidor no ar em http://localhost:%d', [server.Port]));
  btLigar.Caption := 'Parar';
end;

procedure Tfprincipal.btLigarClick(Sender: TObject);
begin
  if server.Active then
  begin
    server.Stop;
    btLigar.Caption := 'Ligar';
    Log('servidor parado');
  end
  else
  begin
    server.Start;
    btLigar.Caption := 'Parar';
    Log(Format('servidor no ar em http://localhost:%d', [server.Port]));
  end;
end;

end.
