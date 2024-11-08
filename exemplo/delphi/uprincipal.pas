unit uprincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  RALServer, ralrestdwmodule, RALCustomObjects, RALSynopseServer;

type
  Tfprincipal = class(TForm)
    server: TRALSynopseServer;
    rdw: TRALRESTDWModule;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  fprincipal: Tfprincipal;

implementation

{$R *.dfm}

procedure Tfprincipal.FormCreate(Sender: TObject);
begin
  server.Start;
end;

end.
