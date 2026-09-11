{ Cliente da demo, versao Lazarus/FPC.

  O mesmo codigo do cliente Delphi: o que muda e o engine (fpHTTP, que e o
  proprio fphttpclient do FPC e nao precisa de nada instalado) e as units da LCL.

  A colecao Events esta vazia no formulario de proposito: AutoFetch busca as
  definicoes na primeira chamada. }
unit uprincipal;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls,
  RALTypes, RALClient, RALfpHTTPClient,
  RALRESTDWClientEvents, RALRESTDWParams, RALRESTDWTypes;

type

  { TForm1 }

  TForm1 = class(TForm)
    cliente: TRALClient;
    ce: TRALRESTDWClientEvents;
    mLog: TMemo;
    btPing: TButton;
    btSoma: TButton;
    btCadastro: TButton;
    btLista: TButton;
    procedure btPingClick(Sender: TObject);
    procedure btSomaClick(Sender: TObject);
    procedure btCadastroClick(Sender: TObject);
    procedure btListaClick(Sender: TObject);
  private
    procedure Log(const AMsg: string);
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.Log(const AMsg: string);
begin
  mLog.Lines.Add(AMsg);
end;

procedure TForm1.btPingClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: string;
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
    FreeAndNil(vParams);
  end;
end;

procedure TForm1.btSomaClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: string;
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

procedure TForm1.btCadastroClick(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: string;
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

procedure TForm1.btListaClick(Sender: TObject);
var
  vInt1: Integer;
begin
  Log('ServerEvents no servidor: ' + ce.GetServerEvents);

  if ce.Events.Count = 0 then
    ce.FetchEvents;

  Log(Format('%d evento(s) espelhado(s) aqui:', [ce.Events.Count]));
  for vInt1 := 0 to ce.Events.Count - 1 do
    Log(Format('   %-10s %-12s %d param(s)',
               [ce.Events.Items[vInt1].EventName,
                ce.Events.Items[vInt1].GetRoute,
                ce.Events.Items[vInt1].Params.Count]));
end;

end.
