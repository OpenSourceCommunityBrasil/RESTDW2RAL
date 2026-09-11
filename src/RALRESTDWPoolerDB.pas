/// The server-side database publisher a migrated RDW project keeps declaring.
///
/// RDW puts `TRESTDWPoolerDB` inside the server DataModule, points it at a
/// driver component (`RESTDriver`), and the transport finds it by name
/// (`PoolerName = 'TDMPrincipal.RESTDWPoolerFD'`). RAL does it the other way
/// round: a `TRALDBModule` hangs off the `TRALServer` and answers on a route.
///
/// The two cannot be the same object - RDW's lives in a DataModule created per
/// request, RAL's has to exist while the server is up - so the shell splits the
/// job the way the shapes demand:
///
/// - `TRALRESTDWPoolerDB` **describes** the database. It streams where RDW put
///   it, keeps RDW's property names, and carries the connection it was given.
/// - `TRALRESTDWIndyServicePooler` finds it inside `ServerMethodClass` and
///   materialises the real `TRALDBModule`, attached to itself, on the route the
///   client asks for (`DataRoute` there, `Domain` here).
///
/// So `PoolerName` and `DataRoute` keep lining up, and nothing in the migrated
/// project has to learn about `TRALDBModule`.
unit RALRESTDWPoolerDB;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils, TypInfo,
  RALTypes, RALDBBase, RALDBModule, RALServer,
  RALRESTDWTypes;

type
  /// Mesmos membros e ordem do TRESTDWDatabaseType do RDW
  TRALRESTDWDatabaseType = (dbtUndefined, dbtAccess, dbtDbase, dbtFirebird,
                            dbtInterbase, dbtMySQL, dbtSQLLite, dbtOracle,
                            dbtMsSQL, dbtODBC, dbtParadox, dbtPostgreSQL,
                            dbtAdo);

  { TRALRESTDWDriverBase }

  { O driver do RDW (TRESTDWFireDACDriver, TRESTDWZeosDriver...) so aponta para
    um componente de conexao e diz de que banco ele e. Aqui ele guarda os dois e
    le os parametros da conexao por RTTI, sem amarrar a unit a um driver: todo
    componente de conexao do Delphi publica Params como TStrings. }
  TRALRESTDWDriverBase = class(TComponent)
  private
    FCommitRecords: IntegerRAL;
    FCompression: Boolean;
    FConnection: TComponent;
    FConectionType: TRALRESTDWDatabaseType;
    FEncodeStringsJSON: Boolean;
    FEncoding: TRALRESTDWEncodeSelect;
    FParamCreate: Boolean;
    FStrsEmpty2Null: Boolean;
    FStrsTrim: Boolean;
    FStrsTrim2Len: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;

    /// O tipo do RAL correspondente ao ConectionType
    function TipoRAL: TRALDatabaseType;
    { Um parametro da conexao apontada, lido por RTTI. Vazio quando nao houver
      conexao ou quando ela nao publicar Params. }
    function ParamConexao(const ANome: StringRAL): StringRAL;
  published
    property Connection: TComponent read FConnection write FConnection;
    property ConectionType: TRALRESTDWDatabaseType read FConectionType
      write FConectionType default dbtUndefined;

    { --- aceitos e inertes --- }
    property Compression: Boolean read FCompression write FCompression default False;
      // inerte: a compressao do RAL e do servidor inteiro, no CompressType
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
      // inerte: o RAL fala UTF-8 em todas as engines
    property EncodeStringsJSON: Boolean read FEncodeStringsJSON
      write FEncodeStringsJSON default False;
      // inerte: o dataset do RAL viaja binario, nao em JSON
    property ParamCreate: Boolean read FParamCreate write FParamCreate default False;
      // inerte: os params saem do SQL, sempre
    property StrsTrim: Boolean read FStrsTrim write FStrsTrim default False;
      // inerte: o RAL devolve o texto do banco como esta
    property StrsEmpty2Null: Boolean read FStrsEmpty2Null write FStrsEmpty2Null
      default False;
      // inerte: idem
    property StrsTrim2Len: Boolean read FStrsTrim2Len write FStrsTrim2Len
      default False;
      // inerte: idem
    property CommitRecords: IntegerRAL read FCommitRecords write FCommitRecords
      default 0;
      // inerte: o RAL aplica o lote inteiro numa transacao so
  end;

  { TRALRESTDWFireDACDriver }

  /// O nome que o .dfm do RDW guarda; a base faz todo o trabalho
  TRALRESTDWFireDACDriver = class(TRALRESTDWDriverBase)
  end;

  { TRALRESTDWPoolerDB }

  TRALRESTDWPoolerDB = class(TComponent)
  private
    FActive: Boolean;
    FCompression: Boolean;
    FEncoding: TRALRESTDWEncodeSelect;
    FParamCreate: Boolean;
    FPoolerOffMessage: StringRAL;
    FRESTDriver: TRALRESTDWDriverBase;
    FStrsEmpty2Null: Boolean;
    FStrsTrim: Boolean;
    FStrsTrim2Len: Boolean;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;

    { Configura um TRALDBModule a partir do que o driver aponta. E o servidor
      que chama isto, uma vez, ao descobrir o DataModule. }
    procedure ConfigurarModulo(AModule: TRALDBModule);
  published
    property RESTDriver: TRALRESTDWDriverBase read FRESTDriver write FRESTDriver;
    { Com False o servidor nao publica a rota de banco, que e o mesmo efeito do
      pooler desligado no RDW. }
    property Active: Boolean read FActive write FActive default False;

    { --- aceitos e inertes --- }
    property Compression: Boolean read FCompression write FCompression default False;
      // inerte: a compressao do RAL e do servidor inteiro
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
      // inerte: o RAL fala UTF-8 em todas as engines
    property ParamCreate: Boolean read FParamCreate write FParamCreate default False;
      // inerte: os params saem do SQL
    property PoolerOffMessage: StringRAL read FPoolerOffMessage
      write FPoolerOffMessage;
      // inerte: com Active False a rota nem existe, e o servidor responde 404
    property StrsTrim: Boolean read FStrsTrim write FStrsTrim default False;
      // inerte: o RAL devolve o texto do banco como esta
    property StrsEmpty2Null: Boolean read FStrsEmpty2Null write FStrsEmpty2Null
      default False;
      // inerte: idem
    property StrsTrim2Len: Boolean read FStrsTrim2Len write FStrsTrim2Len
      default False;
      // inerte: idem
  end;

implementation

{ TRALRESTDWDriverBase }

constructor TRALRESTDWDriverBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConectionType := dbtUndefined;
  FEncoding := esUtf8;
end;

procedure TRALRESTDWDriverBase.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FConnection) then
    FConnection := nil;
end;

function TRALRESTDWDriverBase.TipoRAL: TRALDatabaseType;
begin
  { O RAL cobre quatro bancos; os outros do enum do RDW nao tem link no RAL, e
    cair em Firebird calado seria pior do que o desenvolvedor escolher. }
  case FConectionType of
    dbtMySQL:                    Result := dtMySQL;
    dbtPostgreSQL:               Result := dtPostgreSQL;
    dbtSQLLite:                  Result := dtSQLite;
    dbtFirebird, dbtInterbase:   Result := dtFirebird;
  else
    Result := dtFirebird;
  end;
end;

function TRALRESTDWDriverBase.ParamConexao(const ANome: StringRAL): StringRAL;
var
  vProp: PPropInfo;
  vParams: TObject;
begin
  Result := '';
  if FConnection = nil then
    Exit;

  vProp := GetPropInfo(FConnection, 'Params');
  if (vProp = nil) or (vProp^.PropType^.Kind <> tkClass) then
    Exit;

  vParams := GetObjectProp(FConnection, vProp);
  if not (vParams is TStrings) then
    Exit;

  Result := StringRAL(TStrings(vParams).Values[string(ANome)]);
end;

{ TRALRESTDWPoolerDB }

constructor TRALRESTDWPoolerDB.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEncoding := esUtf8;
end;

procedure TRALRESTDWPoolerDB.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FRESTDriver) then
    FRESTDriver := nil;
end;

procedure TRALRESTDWPoolerDB.ConfigurarModulo(AModule: TRALDBModule);
var
  vPorta: StringRAL;
begin
  if (AModule = nil) or (FRESTDriver = nil) then
    Exit;

  { O link e sempre FireDAC no Delphi: e o unico que o RAL traz para o servidor
    ali, e e tambem o que o driver do RDW usava por baixo. }
  AModule.DatabaseLink := 'FireDAC';
  AModule.DatabaseType := FRESTDriver.TipoRAL;

  { Os parametros saem da conexao que o driver aponta, com os nomes que todo
    componente de conexao usa. }
  AModule.Database := FRESTDriver.ParamConexao('Database');
  AModule.Username := FRESTDriver.ParamConexao('User_Name');
  AModule.Password := FRESTDriver.ParamConexao('Password');
  AModule.Hostname := FRESTDriver.ParamConexao('Server');
  { CharacterSet fica de fora de proposito: o TRALDBModule so o ganhou
    recentemente, e este pacote precisa instalar num PascalRAL de algumas
    semanas atras. O charset da conexao vem do proprio banco. }

  vPorta := FRESTDriver.ParamConexao('Port');
  if vPorta <> '' then
    AModule.Port := StrToIntDef(string(vPorta), 0);
end;

end.
