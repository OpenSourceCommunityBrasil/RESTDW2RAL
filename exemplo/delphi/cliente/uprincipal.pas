{ Cliente da demo.

  Repare no que NAO tem aqui: a colecao Events do TRALRESTDWClientEvents esta
  vazia no formulario. Com AutoFetch ligado, a primeira chamada busca as
  definicoes no servidor sozinha - nao ha passo de design-time nenhum.

  O ServerEventName tambem esta vazio: quando o DataModule do servidor tem um
  unico TRALRESTDWServerEvents, o servidor resolve sem ambiguidade. }
unit uprincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Param, FireDAC.Stan.Error,
  FireDAC.DatS, FireDAC.Phys.Intf, FireDAC.DApt.Intf, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  RALTypes, RALClient, RALnetHTTPClient,
  RALRESTDWClientEvents, RALRESTDWParams, RALRESTDWTypes;

type
  Tfprincipal = class(TForm)
    cliente: TRALClient;
    ce: TRALRESTDWClientEvents;
    memoria: TFDMemTable;
    ds: TDataSource;
    mLog: TMemo;
    grade: TDBGrid;
    btPing: TButton;
    btSoma: TButton;
    btCadastro: TButton;
    btClientes: TButton;
    btSigilo: TButton;
    btLista: TButton;
    procedure btPingClick(Sender: TObject);
    procedure btSomaClick(Sender: TObject);
    procedure btCadastroClick(Sender: TObject);
    procedure btClientesClick(Sender: TObject);
    procedure btSigiloClick(Sender: TObject);
    procedure btListaClick(Sender: TObject);
  private
    procedure Log(const AMsg: string);
  end;

var
  fprincipal: Tfprincipal;

implementation

{$R *.dfm}

procedure Tfprincipal.Log(const AMsg: string);
begin
  mLog.Lines.Add(AMsg);
end;

{ 1. Evento sem parametro: o retorno do handler chega no param cUndefined,
     que e o RawBody do RDW. }
procedure Tfprincipal.btPingClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: StringRAL;
begin
  ce.CreateDWParams('ping', vParams);
  if vParams = nil then
  begin
    Log('ping: evento nao encontrado no servidor');
    Exit;
  end;

  try
    if ce.SendEvent('ping', vParams, vErro) then
      Log('ping -> ' + vParams.ItemsString[cUndefined].AsString)
    else
      Log('ping FALHOU: ' + vErro);
  finally
    // CreateDWParams entrega o objeto para quem chamou: quem chamou libera
    FreeAndNil(vParams);
  end;
end;

{ 2. Entrada e saida: a e b vao, total volta. }
procedure Tfprincipal.btSomaClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: StringRAL;
begin
  ce.CreateDWParams('soma', vParams);
  if vParams = nil then
    Exit;

  try
    vParams.ItemsString['a'].AsInteger := 17;
    vParams.ItemsString['b'].AsInteger := 25;

    if ce.SendEvent('soma', vParams, vErro) then
      Log(Format('soma -> total=%d   result="%s"',
                 [vParams.ItemsString['total'].AsInteger,
                  Trim(vParams.ItemsString[cUndefined].AsString)]))
    else
      Log('soma FALHOU: ' + vErro);
  finally
    FreeAndNil(vParams);
  end;
end;

{ 3. odINOUT com float e data.

     O valor sai daqui e volta transformado pelo servidor. Como os dois viajam
     tipados, o numero nao passa por FloatToStr em lugar nenhum e o separador
     decimal da maquina nao entra na conta. }
procedure Tfprincipal.btCadastroClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: StringRAL;
begin
  ce.CreateDWParams('cadastro', vParams);
  if vParams = nil then
    Exit;

  try
    vParams.ItemsString['nome'].AsString := 'fernando';
    vParams.ItemsString['saldo'].AsFloat := 1234.56;
    vParams.ItemsString['nascimento'].AsDateTime := EncodeDate(1980, 5, 17);

    if ce.SendEvent('cadastro', vParams, vErro) then
      Log(Format('cadastro -> nome=%s  saldo=%.2f  nascimento=%s',
                 [vParams.ItemsString['nome'].AsString,
                  vParams.ItemsString['saldo'].AsFloat,
                  DateToStr(vParams.ItemsString['nascimento'].AsDateTime)]))
    else
      Log('cadastro FALHOU: ' + vErro);
  finally
    FreeAndNil(vParams);
  end;
end;

{ 4. Um dataset inteiro dentro de um parametro. }
procedure Tfprincipal.btClientesClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: StringRAL;
begin
  ce.CreateDWParams('clientes', vParams);
  if vParams = nil then
    Exit;

  try
    if ce.SendEvent('clientes', vParams, vErro) then
    begin
      memoria.Close;
      vParams.ItemsString['dados'].SaveToDataSet(memoria);
      Log(Format('clientes -> %d registro(s) na grade', [memoria.RecordCount]));
    end
    else
    begin
      Log('clientes FALHOU: ' + vErro);
    end;
  finally
    FreeAndNil(vParams);
  end;
end;

{ 5. Autorizacao por evento: com o token errado o servidor recusa antes do
     handler rodar. }
procedure Tfprincipal.btSigiloClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro, vNativo: StringRAL;
begin
  ce.CreateDWParams('sigilo', vParams);
  if vParams = nil then
    Exit;

  try
    vParams.ItemsString['token'].AsString := 'errado';
    if ce.SendEvent('sigilo', vParams, vErro, vNativo) then
      Log(Format('sigilo (token errado) -> HTTP %s  "%s"',
                 [vNativo, Trim(vParams.ItemsString[cUndefined].AsString)]))
    else
      Log('sigilo FALHOU: ' + vErro);

    vParams.ItemsString['token'].AsString := 'abracadabra';
    if ce.SendEvent('sigilo', vParams, vErro, vNativo) then
      Log(Format('sigilo (token certo)  -> HTTP %s  "%s"',
                 [vNativo, Trim(vParams.ItemsString[cUndefined].AsString)]))
    else
      Log('sigilo FALHOU: ' + vErro);
  finally
    FreeAndNil(vParams);
  end;
end;

{ Bonus: o que o servidor expoe, e o que o cliente aprendeu sozinho. }
procedure Tfprincipal.btListaClick(Sender: TObject);
var
  vInt1: Integer;
begin
  Log('ServerEvents no servidor: ' + ce.GetServerEvents);

  if ce.Events.Count = 0 then
    ce.FetchEvents;

  Log(Format('%d evento(s) espelhado(s) aqui:', [ce.Events.Count]));
  for vInt1 := 0 to ce.Events.Count - 1 do
    Log(Format('   %-10s %-10s %d param(s)',
               [ce.Events.Items[vInt1].EventName,
                ce.Events.Items[vInt1].GetRoute,
                ce.Events.Items[vInt1].Params.Count]));
end;

end.
