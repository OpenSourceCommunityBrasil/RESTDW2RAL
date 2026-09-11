{ Banco da demo.

  SQLite pelo FireDAC, que ja vem com o Delphi e nao precisa de servidor nem de
  DLL - o arquivo e criado do lado do executavel na primeira execucao.

  Nada aqui e do RESTDW2RAL: e so o banco que o TRALDBModule vai servir. }
unit udm_banco;

interface

uses
  System.SysUtils, System.Classes, Data.DB,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs, FireDAC.VCLUI.Wait, FireDAC.Comp.Client,
  FireDAC.Comp.UI;

/// Caminho do arquivo, ao lado do executavel
function ArquivoBanco: string;
/// Cria o arquivo e as tabelas se ainda nao existirem, com alguns registros
procedure PrepararBanco;

implementation

function ArquivoBanco: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'demo_rdw2ral.sqlite3';
end;

procedure PrepararBanco;
var
  vCon: TFDConnection;
  vDrv: TFDPhysSQLiteDriverLink;
  vWait: TFDGUIxWaitCursor;
begin
  vDrv := TFDPhysSQLiteDriverLink.Create(nil);
  vWait := TFDGUIxWaitCursor.Create(nil);
  vCon := TFDConnection.Create(nil);
  try
    vCon.DriverName := 'SQLite';
    vCon.Params.Values['Database'] := ArquivoBanco;
    vCon.Params.Values['LockingMode'] := 'Normal';
    vCon.LoginPrompt := False;
    vCon.Connected := True;

    vCon.ExecSQL(
      'CREATE TABLE IF NOT EXISTS clientes (' +
      '  id     INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  nome   VARCHAR(60) NOT NULL,' +
      '  cidade VARCHAR(60),' +
      '  saldo  NUMERIC(15,2),' +
      '  desde  DATE)');

    vCon.ExecSQL(
      'CREATE TABLE IF NOT EXISTS pedidos (' +
      '  id         INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  id_cliente INTEGER NOT NULL,' +
      '  descricao  VARCHAR(80),' +
      '  valor      NUMERIC(15,2))');

    if vCon.ExecSQLScalar('SELECT COUNT(*) FROM clientes') = 0 then
    begin
      vCon.ExecSQL('INSERT INTO clientes (nome, cidade, saldo, desde) VALUES ' +
        '(''Fernando'', ''Curitiba'', 1500.75, ''2020-03-11''),' +
        '(''Mariana'', ''Recife'', 320.00, ''2021-07-02''),' +
        '(''Joaquim'', ''Belem'', 9840.20, ''2019-11-23'')');

      vCon.ExecSQL('INSERT INTO pedidos (id_cliente, descricao, valor) VALUES ' +
        '(1, ''Licenca anual'', 1200.00),' +
        '(1, ''Suporte'', 300.75),' +
        '(2, ''Licenca mensal'', 120.00),' +
        '(3, ''Consultoria'', 9840.20)');
    end;

    vCon.Connected := False;
  finally
    FreeAndNil(vCon);
    FreeAndNil(vWait);
    FreeAndNil(vDrv);
  end;
end;

end.
