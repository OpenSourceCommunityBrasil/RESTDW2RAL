{ Cliente DBWare da demo.

  O TRALRESTDWClientSQL e o TRESTDWClientSQL do RDW vestido sobre o dataset
  remoto do PascalRAL: SQL, Params, DataBase, UpdateTableName, MasterDataSet,
  MasterFields, ApplyUpdates, ExecSQL e RowsAffected tem o mesmo nome e o mesmo
  comportamento, entao o codigo de um formulario portado nao muda.

  Nada aqui e escrito a mao no servidor: o TRALDBModule do outro lado publica as
  rotas de banco sozinho, e o SQL viaja para ser executado la. }
unit uprincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.Grids, Vcl.DBGrids, Vcl.ExtCtrls, Data.DB,
  RALTypes, RALDBTypes, RALClient, RALnetHTTPClient, RALDBConnection,
  RALRESTDWClientSQL;

type
  Tfprincipal = class(TForm)
    cliente: TRALClient;
    conexao: TRALDBConnection;
    qryClientes: TRALRESTDWClientSQL;
    qryPedidos: TRALRESTDWClientSQL;
    dsClientes: TDataSource;
    dsPedidos: TDataSource;
    gradeClientes: TDBGrid;
    gradePedidos: TDBGrid;
    mLog: TMemo;
    btAbrir: TButton;
    btExecSQL: TButton;
    btGravar: TButton;
    btApagar: TButton;
    btTabelas: TButton;
    chkAutoCommit: TCheckBox;
    lbClientes: TLabel;
    lbPedidos: TLabel;
    procedure btAbrirClick(Sender: TObject);
    procedure btExecSQLClick(Sender: TObject);
    procedure btGravarClick(Sender: TObject);
    procedure btApagarClick(Sender: TObject);
    procedure btTabelasClick(Sender: TObject);
    procedure chkAutoCommitClick(Sender: TObject);
    procedure qryClientesGetDataError(ASuccess: Boolean; const AError: StringRAL);
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

{ Erro do servidor chega aqui. Sem um handler destes - e sem OnError - o
  RaiseErrors levanta excecao, em vez de deixar a falha passar em silencio. }
procedure Tfprincipal.qryClientesGetDataError(ASuccess: Boolean;
  const AError: StringRAL);
begin
  Log('ERRO do servidor: ' + AError);
end;

{ 1. Abrir: o SELECT viaja, o servidor executa e devolve o dataset.

     O detalhe abre junto e se refaz sozinho a cada troca de registro no master,
     por causa de MasterDataSet + MasterFields. }
procedure Tfprincipal.btAbrirClick(Sender: TObject);
begin
  qryClientes.Close;
  qryClientes.SQL.Text := 'SELECT id, nome, cidade, saldo, desde FROM clientes ORDER BY id';
  qryClientes.UpdateTableName := 'clientes';
  qryClientes.Open;

  qryPedidos.Close;
  qryPedidos.SQL.Text := 'SELECT id, id_cliente, descricao, valor FROM pedidos ' +
                         'WHERE id_cliente = :id ORDER BY id';
  qryPedidos.UpdateTableName := 'pedidos';
  qryPedidos.MasterDataSet := qryClientes;
  qryPedidos.MasterFields := 'id';
  qryPedidos.Open;

  Log(Format('abriu: %d cliente(s), %d pedido(s) do cliente atual',
             [qryClientes.RecordCount, qryPedidos.RecordCount]));
end;

{ 2. ExecSQL: comando sem retorno de dados, com parametros.

     RowsAffected diz quantas linhas o servidor mexeu - mesmo nome do RDW. }
procedure Tfprincipal.btExecSQLClick(Sender: TObject);
var
  vQry: TRALRESTDWClientSQL;
begin
  vQry := TRALRESTDWClientSQL.Create(nil);
  try
    vQry.DataBase := conexao;
    vQry.SQL.Text := 'INSERT INTO clientes (nome, cidade, saldo, desde) ' +
                     'VALUES (:nome, :cidade, :saldo, :desde)';
    vQry.ParamByName('nome').AsString := 'Novo ' + FormatDateTime('hhnnss', Now);
    vQry.ParamByName('cidade').AsString := 'Sao Paulo';
    vQry.ParamByName('saldo').AsFloat := 100.5;
    vQry.ParamByName('desde').AsDate := Date;
    vQry.ExecSQL;

    Log(Format('ExecSQL: %d linha(s) inserida(s), LastId=%d',
               [vQry.RowsAffected, vQry.LastId]));
  finally
    FreeAndNil(vQry);
  end;

  if qryClientes.Active then
    qryClientes.RefreshData;
end;

{ 3. Gravar: edite direto na grade e mande as alteracoes de uma vez.

     Com CacheUpdateRecords ligado (o padrao), Post e Delete ficam no cache ate
     ApplyUpdates - que e o comportamento do RDW com cache de updates. }
procedure Tfprincipal.btGravarClick(Sender: TObject);
begin
  if qryClientes.State in dsEditModes then
    qryClientes.Post;

  qryClientes.ApplyUpdates;
  Log('ApplyUpdates enviado (alteracoes da grade de clientes)');
end;

{ 4. Apagar o registro atual. Com AutoCommitData marcado, vai ao servidor na
     hora; sem, entra no cache e espera o Gravar. }
procedure Tfprincipal.btApagarClick(Sender: TObject);
begin
  if qryClientes.IsEmpty then
    Exit;

  Log(Format('apagando o cliente %s', [qryClientes.FieldByName('nome').AsString]));
  qryClientes.Delete;

  if not qryClientes.AutoCommitData then
    Log('   ficou no cache - clique em Gravar para enviar');
end;

{ 5. Metadados: o que o servidor tem, sem escrever SQL. }
procedure Tfprincipal.btTabelasClick(Sender: TObject);
var
  vTabelas: TRALDBInfoTables;
  vInt1: Integer;
begin
  vTabelas := conexao.GetTables;
  try
    Log(Format('%d tabela(s) no banco do servidor:', [vTabelas.Count]));
    for vInt1 := 0 to vTabelas.Count - 1 do
      Log('   ' + vTabelas.Table[vInt1].Name);
  finally
    FreeAndNil(vTabelas);
  end;
end;

procedure Tfprincipal.chkAutoCommitClick(Sender: TObject);
begin
  qryClientes.AutoCommitData := chkAutoCommit.Checked;
  qryPedidos.AutoCommitData := chkAutoCommit.Checked;
  if chkAutoCommit.Checked then
    Log('AutoCommitData ligado: cada Post/Delete vai ao servidor na hora')
  else
    Log('AutoCommitData desligado: as alteracoes esperam o Gravar');
end;

end.
