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
  {$IFDEF FPC}
    RALDBSQLDB,
  {$ELSE}
    RALDBFireDAC,
  {$ENDIF}
  RALRESTDWTypes, RALRESTDWModule, RALRequest;

type
  { Liga a conexao do projeto ao TRALDBModule do RAL.

    No RDW o DataModule do servidor nasce a cada requisicao e quem monta os
    parametros da conexao e o BeforeConnect dela, escrito pelo projeto - lendo
    .ini, campos de tela, o que for. Nada fica fixo no .dfm.

    No RAL o TRALDBModule guarda a conexao como texto e monta o proprio driver,
    entao aquele codigo do projeto nunca rodaria e a migracao chegaria no banco
    sem usuario e sem caminho. O RAL oferece a costura certa: o OnBeforeConnect
    do modulo dispara com a conexao dele em maos e antes de abrir. Ali esta
    ponte cria o DataModule do projeto, dispara o BeforeConnect da conexao de
    la e copia os parametros que sairam. }
  TRALRESTDWPonteConexao = class(TComponent)
  private
    FClasseModulo: TComponentClass;
  public
    procedure AntesDeConectar(ASender: TObject; ARequest: TRALRequest);
    property ClasseModulo: TComponentClass read FClasseModulo write FClasseModulo;
  end;

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
    FDataRoute: StringRAL;
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
    { A rota em que o TRALDBModule responde. O RDW nao tem equivalente no lado
      do servidor - la a rota e fixa no transporte -, entao este e o unico
      membro daqui que nao veio do RDW. O default casa com o DataRoute que o
      TRESTDataBase do cliente ja traz. }
    property DataRoute: StringRAL read FDataRoute write FDataRoute;
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
  { casa com o DataRoute que o TRESTDataBase do cliente ja traz de fabrica }
  FDataRoute := '/datadm';
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

  { O nome tem que ser o DatabaseName da classe de link, e quem a registra e a
    initialization da unit dela - por isso ela entra no uses acima. Sem isso o
    GetDatabaseClass devolve nil e o servidor responde "DBLink Property
    missing" na primeira consulta, com tudo o mais certo. }
  {$IFDEF FPC}
    AModule.DatabaseLink := 'SQLDB';
  {$ELSE}
    AModule.DatabaseLink := 'FireDAC';
  {$ENDIF}
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

{ O objeto do tipo pedido dentro de um DataModule, ou nil. }
function AcharComponente(AInstancia: TComponent;
  AClasse: TClass): TComponent;
var
  vInt1: IntegerRAL;
begin
  Result := nil;
  if AInstancia = nil then
    Exit;
  for vInt1 := 0 to Pred(AInstancia.ComponentCount) do
    if AInstancia.Components[vInt1].InheritsFrom(AClasse) then
    begin
      Result := AInstancia.Components[vInt1];
      Exit;
    end;
end;

{ Uma propriedade de objeto por nome, sem conhecer o tipo do componente - a
  conexao pode ser TFDConnection, TZConnection, TSQLConnection... }
function ObjetoDaProp(AObj: TObject; const ANome: string): TObject;
var
  vProp: PPropInfo;
begin
  Result := nil;
  if AObj = nil then
    Exit;
  vProp := GetPropInfo(AObj, ANome);
  if (vProp = nil) or (vProp^.PropType^.Kind <> tkClass) then
    Exit;
  Result := GetObjectProp(AObj, vProp);
end;

{ TRALRESTDWPonteConexao }

procedure TRALRESTDWPonteConexao.AntesDeConectar(ASender: TObject;
  ARequest: TRALRequest);
var
  vObj: TComponent;
  vPooler: TRALRESTDWPoolerDB;
  vConn: TComponent;
  vMetodo: TMethod;
  vNotify: TNotifyEvent;
  vOrigem, vDestino: TObject;
begin
  if FClasseModulo = nil then
    Exit;

  { por requisicao, como no RDW: o BeforeConnect costuma ler estado que muda }
  vObj := FClasseModulo.Create(nil);
  try
    vPooler := TRALRESTDWPoolerDB(AcharComponente(vObj, TRALRESTDWPoolerDB));
    if (vPooler = nil) or (vPooler.RESTDriver = nil) then
      Exit;

    vConn := vPooler.RESTDriver.Connection;
    if vConn = nil then
      Exit;

    { dispara o BeforeConnect do projeto sem abrir conexao nenhuma: o handler
      so preenche Params, e e disso que se precisa }
    vMetodo := GetMethodProp(vConn, 'BeforeConnect');
    if vMetodo.Code <> nil then
    begin
      TMethod(vNotify) := vMetodo;
      try
        vNotify(vConn);
      except
        { handler do projeto que depende de tela fechada nao pode derrubar a
          requisicao - fica o que o .dfm trouxe }
      end;
    end;

    vOrigem := ObjetoDaProp(vConn, 'Params');
    vDestino := ObjetoDaProp(ASender, 'Params');
    if (vOrigem is TStrings) and (vDestino is TStrings) and
       (TStrings(vOrigem).Count > 0) then
      TStrings(vDestino).Assign(TStrings(vOrigem));
  finally
    vObj.Free;
  end;
end;

{ Acha o TRESTDWPoolerDB que o projeto declarou dentro do DataModule do servidor
  e materializa o TRALDBModule correspondente, pendurado no servidor. Roda uma
  vez, quando o modulo de eventos instancia a classe para descobrir rotas. }
procedure MontarBanco(AServer: TRALServer; AInstancia: TComponent);
var
  vInt1: IntegerRAL;
  vComp: TComponent;
  vPooler: TRALRESTDWPoolerDB;
  vModule: TRALDBModule;
  vPonte: TRALRESTDWPonteConexao;
  vRota: StringRAL;
begin
  if (AServer = nil) or (AInstancia = nil) then
    Exit;

  vPooler := nil;
  for vInt1 := 0 to Pred(AInstancia.ComponentCount) do
  begin
    vComp := AInstancia.Components[vInt1];
    if vComp.InheritsFrom(TRALRESTDWPoolerDB) then
    begin
      vPooler := TRALRESTDWPoolerDB(vComp);
      Break;
    end;
  end;

  if (vPooler = nil) or (not vPooler.Active) then
    Exit;

  vRota := vPooler.DataRoute;
  if Trim(vRota) = '' then
    vRota := '/datadm';

  { um por rota: RefreshRoutes roda mais de uma vez (Loaded, SetServer, o verbo
    do editor) e nao se empilha modulo de banco a cada passada }
  for vInt1 := 0 to Pred(AServer.ComponentCount) do
  begin
    vComp := AServer.Components[vInt1];
    if vComp.InheritsFrom(TRALDBModule) and
       SameText(string(TRALDBModule(vComp).Domain), string(vRota)) then
    begin
      vPooler.ConfigurarModulo(TRALDBModule(vComp));
      Exit;
    end;
  end;

  vModule := TRALDBModule.Create(AServer);
  vModule.Name := 'RDWDBModule';
  vModule.Domain := vRota;
  vModule.Server := AServer;
  vPooler.ConfigurarModulo(vModule);

  { o que o .dfm trouxe ja esta no modulo; a ponte cobre o resto, que e o
    normal: projeto que monta a conexao em codigo }
  vPonte := TRALRESTDWPonteConexao.Create(vModule);
  vPonte.ClasseModulo := TComponentClass(AInstancia.ClassType);
  vModule.OnBeforeConnect := {$IFDEF FPC}@{$ENDIF}vPonte.AntesDeConectar;
end;

initialization
  RALRESTDWMontarBanco := {$IFDEF FPC}@{$ENDIF}MontarBanco;

finalization
  RALRESTDWMontarBanco := nil;

end.
