unit udm_restdw;

interface

uses
  System.SysUtils, System.Classes, RALCustomObjects, ralrestdwserverevents,
  ralrestdwparams, uRESTDWAbout, uRESTDWServerEvents, uRESTDWParams;

type
  Tdm_restdw = class(TDataModule)
    server_events: TRALRESTDWServerEvents;
    RESTDWServerEvents1: TRESTDWServerEvents;
    procedure server_eventsEvents0ReplyEvent(AParams: TRALRESTDWParams;
      const AResult: TStringList);
    procedure RESTDWServerEvents1Eventsdwevent1ReplyEvent(
      var Params: TRESTDWParams; var Result: string);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  dm_restdw: Tdm_restdw;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure Tdm_restdw.RESTDWServerEvents1Eventsdwevent1ReplyEvent(
  var Params: TRESTDWParams; var Result: string);
begin
//
end;

procedure Tdm_restdw.server_eventsEvents0ReplyEvent(AParams: TRALRESTDWParams;
  const AResult: TStringList);
begin
  AResult.Text := 'pong';
end;

initialization
  RegisterClass(Tdm_restdw);

end.
