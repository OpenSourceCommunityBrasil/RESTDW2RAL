{ DataModule de eventos.

  E o equivalente direto do DataModule onde voce solta um TRESTDWServerEvents no
  REST Dataware: os handlers tem a mesma assinatura e o corpo deles nao mudou.

  O modulo instancia uma copia deste DataModule por requisicao, entao nao guarde
  estado entre chamadas em campos daqui. }
unit udm_eventos;

interface

uses
  System.SysUtils, System.Classes, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  RALTypes, RALRESTDWServerEvents, RALRESTDWParams, RALRESTDWTypes;

type
  Tdm_eventos = class(TDataModule)
    srv: TRALRESTDWServerEvents;
    procedure srvEventspingReplyEvent(var AParams: TRALRESTDWParams;
      const AResult: TStringList);
    procedure srvEventssomaReplyEvent(var AParams: TRALRESTDWParams;
      const AResult: TStringList);
    procedure srvEventscadastroReplyEvent(var AParams: TRALRESTDWParams;
      const AResult: TStringList);
    procedure srvEventsclientesReplyEvent(var AParams: TRALRESTDWParams;
      const AResult: TStringList);
    procedure srvEventssigiloReplyEvent(var AParams: TRALRESTDWParams;
      const AResult: TStringList);
    procedure srvEventssigiloAuthRequest(const AParams: TRALRESTDWParams;
      var ARejected: Boolean; var AResultError: StringRAL;
      var AStatusCode: IntegerRAL; ARequestHeader: TStringList);
    procedure srvCreate(ASelf: TComponent);
  private
    { Criado no OnCreate, que roda uma vez por requisicao - o mesmo gancho que o
      RDW oferece para preparar conexao, cache e afins. }
    FMemoria: TFDMemTable;
  public
    destructor Destroy; override;
  end;

var
  dm_eventos: Tdm_eventos;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}

{$R *.dfm}

procedure Tdm_eventos.srvCreate(ASelf: TComponent);
begin
  FMemoria := TFDMemTable.Create(Self);
  FMemoria.FieldDefs.Add('id', ftInteger);
  FMemoria.FieldDefs.Add('nome', ftString, 60);
  FMemoria.FieldDefs.Add('saldo', ftFloat);
  FMemoria.FieldDefs.Add('cadastro', ftDateTime);
  FMemoria.CreateDataSet;
end;

destructor Tdm_eventos.Destroy;
begin
  // o Owner ja liberaria, mas deixar explicito ajuda quem le a demo
  FreeAndNil(FMemoria);
  inherited;
end;

{ 1. O evento mais simples possivel: sem parametro, devolve texto no Result.
     O cliente le em Params.ItemsString[cUndefined] (o RawBody do RDW). }
procedure Tdm_eventos.srvEventspingReplyEvent(var AParams: TRALRESTDWParams;
  const AResult: TStringList);
begin
  AResult.Text := 'pong';
end;

{ 2. Dois parametros de entrada e um de saida.

     a e b sao ovInteger e total e ovInteger/odOUT: os tres viajam com tipo,
     nao como texto. }
procedure Tdm_eventos.srvEventssomaReplyEvent(var AParams: TRALRESTDWParams;
  const AResult: TStringList);
var
  vTotal: Integer;
begin
  vTotal := AParams.ItemsString['a'].AsInteger +
            AParams.ItemsString['b'].AsInteger;

  AParams.ItemsString['total'].AsInteger := vTotal;
  AResult.Text := Format('%d + %d = %d', [AParams.ItemsString['a'].AsInteger,
                                          AParams.ItemsString['b'].AsInteger,
                                          vTotal]);
end;

{ 3. odINOUT: o mesmo parametro entra e volta.

     saldo e ovFloat e nascimento e ovDate. Os dois viajam em binario tipado,
     entao um servidor pt-BR e um cliente en-US trocam 1234.56 sem virar 123456
     - que e o que acontecia quando o valor virava texto pelo FloatToStr local. }
procedure Tdm_eventos.srvEventscadastroReplyEvent(var AParams: TRALRESTDWParams;
  const AResult: TStringList);
begin
  AParams.ItemsString['nome'].AsString :=
    UpperCase(AParams.ItemsString['nome'].AsString);
  AParams.ItemsString['saldo'].AsFloat :=
    AParams.ItemsString['saldo'].AsFloat * 2;
  AParams.ItemsString['nascimento'].AsDateTime :=
    AParams.ItemsString['nascimento'].AsDateTime + 1;

  AResult.Text := 'ok';
end;

{ 4. Devolvendo um dataset inteiro num parametro (TypeObject = toDataset).

     Serializado pelo storage do proprio PascalRAL, entao qualquer consumidor
     de dataset do RAL le do outro lado. }
procedure Tdm_eventos.srvEventsclientesReplyEvent(var AParams: TRALRESTDWParams;
  const AResult: TStringList);
var
  vInt1: Integer;
begin
  FMemoria.EmptyDataSet;
  for vInt1 := 1 to 5 do
  begin
    FMemoria.Append;
    FMemoria.FieldByName('id').AsInteger := vInt1;
    FMemoria.FieldByName('nome').AsString := Format('Cliente %d', [vInt1]);
    FMemoria.FieldByName('saldo').AsFloat := vInt1 * 1000.55;
    FMemoria.FieldByName('cadastro').AsDateTime := Date - vInt1;
    FMemoria.Post;
  end;

  AParams.ItemsString['dados'].LoadFromDataSet(FMemoria);
  AResult.Text := IntToStr(FMemoria.RecordCount);
end;

{ 5. Autorizacao por evento: OnAuthRequest roda antes do handler e pode recusar
     a chamada sozinho, sem tocar na autenticacao do TRALServer. }
procedure Tdm_eventos.srvEventssigiloAuthRequest(const AParams: TRALRESTDWParams;
  var ARejected: Boolean; var AResultError: StringRAL;
  var AStatusCode: IntegerRAL; ARequestHeader: TStringList);
begin
  ARejected := AParams.ItemsString['token'].AsString <> 'abracadabra';
  if ARejected then
  begin
    AResultError := 'token invalido';
    AStatusCode := 401;
  end;
end;

procedure Tdm_eventos.srvEventssigiloReplyEvent(var AParams: TRALRESTDWParams;
  const AResult: TStringList);
begin
  AResult.Text := 'conteudo liberado';
end;

initialization
  { OBRIGATORIO: o TRALRESTDWModule acha este DataModule pelo nome da classe,
    via GetClass. Sem o registro, toda chamada responde 403. }
  RegisterClass(Tdm_eventos);

end.
