/// The client-side database connection a migrated RDW project keeps using.
///
/// In RDW, `TRESTDWIdDatabase` is two things at once: the HTTP transport
/// (`PoolerService`, `PoolerPort`, `UseSSL`, `AuthenticationOptions`,
/// `Compression`) and the database link the `TRESTDWClientSQL` points at
/// (`DataRoute`, `PoolerName`). RAL splits those in two - a `TRALClient` and a
/// `TRALDBConnection` - which is cleaner but is not what an existing `.dfm`
/// says.
///
/// So this shell *is* a `TRALDBConnection` and owns the `TRALClient` it needs,
/// keeping RDW's face on top:
///
///     RESTDWIdDatabase1.PoolerService := 'servidor';
///     RESTDWIdDatabase1.PoolerPort    := 8082;
///     RESTDWIdDatabase1.Active        := True;
///
/// `PoolerService` + `PoolerPort` + `UseSSL` become the client's `BaseURL`, and
/// `DataRoute` becomes `ModuleRoute` - the path the `TRALDBModule` answers on.
/// The `TRALClient` is reachable as `Client`, for anyone who wants to configure
/// it with RAL's own names.
unit RALRESTDWDatabase;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  RALTypes, RALClient, RALAuthentication, RALCompress, RALDBConnection,
  RALDBTypes,
  RALRESTDWTypes, RALRESTDWOptions, RALRESTDWMassive;

type
  { TRALRESTDWStateConnection }

  /// StateConnection do RDW: verificava a conexao de tempos em tempos
  TRALRESTDWStateConnection = class(TRALRESTDWPersistent)
  private
    FAutoCheck: Boolean;
    FInTime: IntegerRAL;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    property AutoCheck: Boolean read FAutoCheck write FAutoCheck default False;
    property InTime: IntegerRAL read FInTime write FInTime default 1000;
  end;

  { A assinatura do OnBeforeConnect do RDW (TOnEventBeforeConnection). Um
    TNotifyEvent seria quase igual, mas o parametro la e TComponent, e o
    designer confere a assinatura ao ligar o handler. }
  TRALRESTDWBeforeConnect = procedure(Sender: TComponent) of object;

  { TRALRESTDWConnectionDefs }

  /// ClientConnectionDefs do RDW
  TRALRESTDWConnectionDefs = class(TRALRESTDWPersistent)
  private
    FActive: Boolean;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Active: Boolean read FActive write FActive default False;
  end;

  { TRALRESTDWDatabase }

  TRALRESTDWDatabase = class(TRALDBConnection)
  private
    FAccept: StringRAL;
    FActive: Boolean;
    FAuthenticationOptions: TRALRESTDWAuthOptions;
    FBasicAuth: TRALClientBasicAuth;
    FCharset: StringRAL;
    FClientConnectionDefs: TRALRESTDWConnectionDefs;
    FCompression: Boolean;
    FContentEncoding: StringRAL;
    FContentType: StringRAL;
    FCriptOptions: TRALRESTDWCriptOptions;
    FEncodedStrings: Boolean;
    FEncoding: TRALRESTDWEncodeSelect;
    FFailOver: Boolean;
    FFailOverConnections: TRALRESTDWConnectionServers;
    FFailOverReplaceDefaults: Boolean;
    FSSLMode: TRALRESTDWSSLMode;
    FSSLVersions: TRALRESTDWSSLVersions;
    FHandleRedirects: Boolean;
    FIgnoreEchoPooler: Boolean;
    FInterno: TRALClient;
    FParamCreate: Boolean;
    FPoolerName: StringRAL;
    FPoolerNotFoundMessage: StringRAL;
    FPoolerPort: IntegerRAL;
    FPoolerService: StringRAL;
    FProxy: Boolean;
    FProxyOptions: TRALRESTDWProxyOptions;
    FRedirectMaximum: IntegerRAL;
    FStateConnection: TRALRESTDWStateConnection;
    FStrsEmpty2Null: Boolean;
    FStrsTrim: Boolean;
    FStrsTrim2Len: Boolean;
    FUseSSL: Boolean;
    FOnBeforeConnect: TRALRESTDWBeforeConnect;
    FAccessTag: StringRAL;
    FWelcomeMessage: StringRAL;
    FPoolerList: TStringList;

    function GetConnectTimeOut: IntegerRAL;
    function GetTypeRequest: TRALRESTDWTypeRequest;
    procedure SetTypeRequest(AValue: TRALRESTDWTypeRequest);
    function GetDataRoute: StringRAL;
    function GetRequestTimeOut: IntegerRAL;
    function GetUserAgent: StringRAL;
    procedure OptionChanged(ASender: TObject);
    procedure SetActive(AValue: Boolean);
    procedure SetAuthenticationOptions(AValue: TRALRESTDWAuthOptions);
    procedure SetClientConnectionDefs(AValue: TRALRESTDWConnectionDefs);
    procedure SetCompression(AValue: Boolean);
    procedure SetConnectTimeOut(AValue: IntegerRAL);
    procedure SetCriptOptions(AValue: TRALRESTDWCriptOptions);
    procedure SetDataRoute(const AValue: StringRAL);
    procedure SetPoolerPort(AValue: IntegerRAL);
    procedure SetPoolerService(const AValue: StringRAL);
    procedure SetProxyOptions(AValue: TRALRESTDWProxyOptions);
    procedure SetFailOverConnections(AValue: TRALRESTDWConnectionServers);
    procedure SetFailOver(AValue: Boolean);
    procedure SetRequestTimeOut(AValue: IntegerRAL);
    procedure SetStateConnection(AValue: TRALRESTDWStateConnection);
    procedure SetUserAgent(const AValue: StringRAL);
    procedure SetUseSSL(AValue: Boolean);

    /// PoolerService + PoolerPort + UseSSL viram o BaseURL do cliente interno
    procedure RebuildBaseURL;
    procedure EscolherEngine;
  protected
    procedure Loaded; override;
  public
    { A inicializacao vai aqui, e nao num construtor, porque
      TRALDBConnection.Create e declarado `overload` e nao `override`: ele
      esconde o construtor virtual do TComponent, entao um construtor daqui
      nem seria chamado quando o formulario cria o componente. AfterConstruction
      e virtual de verdade e roda antes de o streaming ler a primeira
      propriedade, que e exatamente o que estes objetos precisam. }
    procedure AfterConstruction; override;
    destructor Destroy; override;

    { Os campos que formam a chave da tabela, perguntando ao servidor - o mesmo
      GetKeyFieldNames do RDW, e igualmente de verdade: a estrutura vem do
      TRALDBModule, que marca a chave nos flags de cada campo. }
    procedure GetKeyFieldNames(const ATableName: StringRAL; AList: TStrings);
    { Open e Close do RDW. No RAL a conexao e por requisicao, entao aqui eles
      ligam e desligam o Active - que e o que o codigo portado testa logo
      depois - e disparam o OnBeforeConnect no momento certo. }
    procedure Open;
    procedure Close;
    { A forma do RDW: manda o lote acumulado no cache e devolve o erro por
      parametro. Quem aplica e o dataset ligado ao cache. }
    procedure ApplyUpdates(ACache: TRALRESTDWMassiveCache; var AError: Boolean;
                           var AMessage: string);
    { A lista de poolers publicados. O RAL nao expoe varios bancos por rota -
      um TRALDBModule, uma rota -, entao vem sempre com a rota atual. }
    function PoolerList: TStrings;
  published
    { --- o que vira mesmo alguma coisa no RAL --- }
    property PoolerService: StringRAL read FPoolerService write SetPoolerService;
    property PoolerPort: IntegerRAL read FPoolerPort write SetPoolerPort default 8082;
    property UseSSL: Boolean read FUseSSL write SetUseSSL default False;
    { A rota em que o TRALDBModule do servidor responde. No RDW o mesmo valor
      ficava em DataRoute; aqui ele e o ModuleRoute da conexao. }
    property DataRoute: StringRAL read GetDataRoute write SetDataRoute;
    property Compression: Boolean read FCompression write SetCompression default True;
    property CriptOptions: TRALRESTDWCriptOptions read FCriptOptions
      write SetCriptOptions;
    property AuthenticationOptions: TRALRESTDWAuthOptions read FAuthenticationOptions
      write SetAuthenticationOptions;
    property RequestTimeOut: IntegerRAL read GetRequestTimeOut write SetRequestTimeOut;
    property ConnectTimeOut: IntegerRAL read GetConnectTimeOut write SetConnectTimeOut;
    property UserAgent: StringRAL read GetUserAgent write SetUserAgent;
    { Guardado e aplicado no Loaded, para nao tentar conectar no meio da
      leitura do formulario, quando o endereco ainda esta pela metade. }
    property Active: Boolean read FActive write SetActive default False;
    { trHttps liga o SSL, que e o mesmo que UseSSL := True; o resto do enum do
      RDW nao muda nada aqui. }
    property TypeRequest: TRALRESTDWTypeRequest read GetTypeRequest
      write SetTypeRequest default trHttp;

    { Levados na requisicao como cabecalho, que e onde o servidor deste projeto
      os procura - os mesmos nomes que o RDW usava. }
    property AccessTag: StringRAL read FAccessTag write FAccessTag;
    property WelcomeMessage: StringRAL read FWelcomeMessage write FWelcomeMessage;

    { --- aceitos e inertes ---
      Existem para o formulario abrir e para o codigo que os le continuar
      compilando. Cada um diz ao lado por que nao faz nada. }
    property Accept: StringRAL read FAccept write FAccept;
      // inerte: o RAL negocia o Accept a partir do conteudo
    property ContentType: StringRAL read FContentType write FContentType;
      // inerte: o RAL define o Content-Type pelo corpo enviado
    property ContentEncoding: StringRAL read FContentEncoding write FContentEncoding;
      // inerte: quem decide a compressao e Compression, acima
    property Charset: StringRAL read FCharset write FCharset;
      // inerte: o RAL fala UTF-8 em todas as engines
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
      // inerte: idem
    property EncodedStrings: Boolean read FEncodedStrings write FEncodedStrings
      default True;
      // inerte: o RAL escolhe a codificacao do corpo sozinho
    property PoolerName: StringRAL read FPoolerName write FPoolerName;
      { inerte: no RDW nomeava o TRESTDWPoolerDB dentro do DataModule; no RAL
        quem identifica o banco e a rota do modulo, que esta em DataRoute }
    property PoolerNotFoundMessage: StringRAL read FPoolerNotFoundMessage
      write FPoolerNotFoundMessage;
      // inerte: a mensagem de rota inexistente vem do servidor
    property IgnoreEchoPooler: Boolean read FIgnoreEchoPooler write FIgnoreEchoPooler
      default False;
      // inerte: o RAL nao tem o handshake de echo do RDW
    property ParamCreate: Boolean read FParamCreate write FParamCreate default True;
      // inerte: os params sao criados a partir do SQL, sempre
    property StrsTrim: Boolean read FStrsTrim write FStrsTrim default False;
      // inerte: o RAL devolve o texto do banco como esta
    property StrsEmpty2Null: Boolean read FStrsEmpty2Null write FStrsEmpty2Null
      default False;
      // inerte: idem
    property StrsTrim2Len: Boolean read FStrsTrim2Len write FStrsTrim2Len
      default True;
      // inerte: idem
    property Proxy: Boolean read FProxy write FProxy default False;
      // inerte: o RAL nao atravessa proxy
    property ProxyOptions: TRALRESTDWProxyOptions read FProxyOptions
      write SetProxyOptions;
      // inerte: idem
    { vira linha a mais no BaseURL do cliente interno, que e a lista de failover
      do RAL - ver RALRESTDWApplyBaseURL }
    property FailOver: Boolean read FFailOver write SetFailOver default False;
    property FailOverConnections: TRALRESTDWConnectionServers
      read FFailOverConnections write SetFailOverConnections;
    property FailOverReplaceDefaults: Boolean read FFailOverReplaceDefaults
      write FFailOverReplaceDefaults default False;
      // inerte: idem
    property SSLVersions: TRALRESTDWSSLVersions read FSSLVersions
      write FSSLVersions default [];
      // inerte: no RAL a versao de TLS e do motor
    property SSLMode: TRALRESTDWSSLMode read FSSLMode write FSSLMode
      default sslmUnassigned;
      // inerte: idem
    property HandleRedirects: Boolean read FHandleRedirects write FHandleRedirects
      default False;
      // inerte: o RAL segue redirecionamento sozinho
    property RedirectMaximum: IntegerRAL read FRedirectMaximum write FRedirectMaximum
      default 0;
      // inerte: o TRALClient instalado pode nao ter MaxRedirects ainda
    property StateConnection: TRALRESTDWStateConnection read FStateConnection
      write SetStateConnection;
      // inerte: nao ha verificacao periodica de conexao
    property ClientConnectionDefs: TRALRESTDWConnectionDefs read FClientConnectionDefs
      write SetClientConnectionDefs;
      // inerte: as definicoes de conexao vivem no TRALDBModule do servidor
    property OnBeforeConnect: TRALRESTDWBeforeConnect read FOnBeforeConnect
      write FOnBeforeConnect;
      { chamado no Loaded, antes de Active virar True - e o gancho onde codigo
        do RDW costuma montar o endereco a partir de um .ini }
  end;

implementation

{ TRALRESTDWStateConnection }

constructor TRALRESTDWStateConnection.Create;
begin
  inherited Create;
  FAutoCheck := False;
  FInTime := 1000;
end;

procedure TRALRESTDWStateConnection.Assign(ASource: TPersistent);
begin
  if not (ASource is TRALRESTDWStateConnection) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  FAutoCheck := TRALRESTDWStateConnection(ASource).AutoCheck;
  FInTime := TRALRESTDWStateConnection(ASource).InTime;
  Changed;
end;

{ TRALRESTDWConnectionDefs }

procedure TRALRESTDWConnectionDefs.Assign(ASource: TPersistent);
begin
  if not (ASource is TRALRESTDWConnectionDefs) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  FActive := TRALRESTDWConnectionDefs(ASource).Active;
  Changed;
end;

{ TRALRESTDWDatabase }

procedure TRALRESTDWDatabase.AfterConstruction;
begin
  inherited AfterConstruction;

  FPoolerService := 'localhost';
  FPoolerPort := 8082;
  FUseSSL := False;
  FCompression := True;
  FEncoding := esUtf8;
  FEncodedStrings := True;
  FCharset := 'utf8';
  FParamCreate := True;
  FStrsTrim2Len := True;

  FAuthenticationOptions := TRALRESTDWAuthOptions.Create;
  FAuthenticationOptions.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;

  FCriptOptions := TRALRESTDWCriptOptions.Create;
  FCriptOptions.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;

  FProxyOptions := TRALRESTDWProxyOptions.Create;
  FFailOverConnections := TRALRESTDWConnectionServers.Create(Self);
  FStateConnection := TRALRESTDWStateConnection.Create;
  FClientConnectionDefs := TRALRESTDWConnectionDefs.Create;
  FPoolerList := TStringList.Create;

  { o cliente nasce junto e pertence a este componente: no RDW o transporte e a
    conexao eram a mesma peca, e e essa forma que o .dfm portado espera }
  FInterno := TRALClient.Create(Self);
  FInterno.Name := 'RDWClient';
  EscolherEngine;
  Client := FInterno;

  RebuildBaseURL;
  ModuleRoute := '/datadm';
end;

destructor TRALRESTDWDatabase.Destroy;
begin
  FreeAndNil(FPoolerList);
  FreeAndNil(FClientConnectionDefs);
  FreeAndNil(FStateConnection);
  FreeAndNil(FFailOverConnections);
  FreeAndNil(FProxyOptions);
  FreeAndNil(FCriptOptions);
  FreeAndNil(FAuthenticationOptions);
  // FInterno e FBasicAuth pertencem a este componente: o inherited os destroi
  inherited Destroy;
end;

{ O TRALClient nasce sem engine nenhuma; sem escolher aqui, a primeira chamada
  falharia sem dizer por que. Indy na frente porque e de onde quem migra vem. }
procedure TRALRESTDWDatabase.EscolherEngine;
var
  vLista: TStringList;
begin
  if FInterno.EngineType <> '' then
    Exit;

  vLista := TStringList.Create;
  try
    GetEngineList(vLista);
    if vLista.IndexOf('Indy') >= 0 then
      FInterno.EngineType := 'Indy'
    else if vLista.Count > 0 then
      FInterno.EngineType := vLista[0];
  finally
    FreeAndNil(vLista);
  end;
end;

procedure TRALRESTDWDatabase.Loaded;
begin
  inherited Loaded;

  RebuildBaseURL;
  RALRESTDWApplyClientAuth(FInterno, FAuthenticationOptions, FBasicAuth);
  RALRESTDWApplyCripto(FCriptOptions, FInterno.CriptoOptions);

  if FActive then
  begin
    if Assigned(FOnBeforeConnect) then
      FOnBeforeConnect(Self);
    { nada a abrir: a conexao do RAL e por requisicao. Active fica True para o
      codigo que o le, e o endereco ja esta montado. }
  end;
end;

procedure TRALRESTDWDatabase.OptionChanged(ASender: TObject);
begin
  if csLoading in ComponentState then
    Exit;

  if ASender = FCriptOptions then
    RALRESTDWApplyCripto(FCriptOptions, FInterno.CriptoOptions)
  else
    RALRESTDWApplyClientAuth(FInterno, FAuthenticationOptions, FBasicAuth);
end;

procedure TRALRESTDWDatabase.RebuildBaseURL;
begin
  if FInterno = nil then
    Exit;

  RALRESTDWApplyBaseURL(FInterno.BaseURL, FUseSSL, FPoolerService, FPoolerPort,
                        FFailOver, FFailOverConnections);
end;

procedure TRALRESTDWDatabase.SetActive(AValue: Boolean);
begin
  if FActive = AValue then
    Exit;

  FActive := AValue;

  if (csLoading in ComponentState) or (not AValue) then
    Exit;

  RebuildBaseURL;
  if Assigned(FOnBeforeConnect) then
    FOnBeforeConnect(Self);
end;

function TRALRESTDWDatabase.GetTypeRequest: TRALRESTDWTypeRequest;
begin
  if FUseSSL then
    Result := trHttps
  else
    Result := trHttp;
end;

procedure TRALRESTDWDatabase.SetTypeRequest(AValue: TRALRESTDWTypeRequest);
begin
  UseSSL := AValue = trHttps;
end;

procedure TRALRESTDWDatabase.GetKeyFieldNames(const ATableName: StringRAL;
  AList: TStrings);
var
  vCampos: TRALDBInfoFields;
  vInt1: IntegerRAL;
begin
  if AList = nil then
    Exit;

  AList.Clear;
  if Trim(ATableName) = '' then
    Exit;

  vCampos := InfoFieldsFromSQL('select * from ' + ATableName);
  if vCampos = nil then
    Exit;

  try
    { bit 8 e o pfInKey, do jeito que TRALDB.GetFieldProviderFlags empacota }
    for vInt1 := 0 to vCampos.Count - 1 do
      if (vCampos.Field[vInt1].Flags and 8) > 0 then
        AList.Add(string(vCampos.Field[vInt1].FieldName));
  finally
    FreeAndNil(vCampos);
  end;
end;

procedure TRALRESTDWDatabase.ApplyUpdates(ACache: TRALRESTDWMassiveCache;
  var AError: Boolean; var AMessage: string);
begin
  if ACache = nil then
  begin
    AError := True;
    AMessage := 'ApplyUpdates sem MassiveCache';
    Exit;
  end;

  ACache.Aplicar(AError, AMessage);
end;

procedure TRALRESTDWDatabase.Open;
begin
  Active := True;
end;

procedure TRALRESTDWDatabase.Close;
begin
  Active := False;
end;

function TRALRESTDWDatabase.PoolerList: TStrings;
begin
  FPoolerList.Clear;
  FPoolerList.Add(string(ModuleRoute));
  Result := FPoolerList;
end;

procedure TRALRESTDWDatabase.SetPoolerService(const AValue: StringRAL);
begin
  if FPoolerService = AValue then
    Exit;

  FPoolerService := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWDatabase.SetPoolerPort(AValue: IntegerRAL);
begin
  if FPoolerPort = AValue then
    Exit;

  FPoolerPort := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWDatabase.SetUseSSL(AValue: Boolean);
begin
  if FUseSSL = AValue then
    Exit;

  FUseSSL := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWDatabase.SetCompression(AValue: Boolean);
begin
  FCompression := AValue;
  if FInterno = nil then
    Exit;

  if AValue then
    FInterno.CompressType := ctGZip
  else
    FInterno.CompressType := ctNone;
end;

function TRALRESTDWDatabase.GetDataRoute: StringRAL;
begin
  Result := ModuleRoute;
end;

procedure TRALRESTDWDatabase.SetDataRoute(const AValue: StringRAL);
begin
  ModuleRoute := AValue;
end;

function TRALRESTDWDatabase.GetRequestTimeOut: IntegerRAL;
begin
  Result := FInterno.RequestTimeout;
end;

procedure TRALRESTDWDatabase.SetRequestTimeOut(AValue: IntegerRAL);
begin
  FInterno.RequestTimeout := AValue;
end;

function TRALRESTDWDatabase.GetConnectTimeOut: IntegerRAL;
begin
  Result := FInterno.ConnectTimeout;
end;

procedure TRALRESTDWDatabase.SetConnectTimeOut(AValue: IntegerRAL);
begin
  FInterno.ConnectTimeout := AValue;
end;

function TRALRESTDWDatabase.GetUserAgent: StringRAL;
begin
  Result := FInterno.UserAgent;
end;

procedure TRALRESTDWDatabase.SetUserAgent(const AValue: StringRAL);
begin
  FInterno.UserAgent := AValue;
end;

procedure TRALRESTDWDatabase.SetAuthenticationOptions(AValue: TRALRESTDWAuthOptions);
begin
  FAuthenticationOptions.Assign(AValue);
end;

procedure TRALRESTDWDatabase.SetCriptOptions(AValue: TRALRESTDWCriptOptions);
begin
  FCriptOptions.Assign(AValue);
end;

procedure TRALRESTDWDatabase.SetFailOverConnections(
  AValue: TRALRESTDWConnectionServers);
begin
  FFailOverConnections.Assign(AValue);
  RebuildBaseURL;
end;

procedure TRALRESTDWDatabase.SetFailOver(AValue: Boolean);
begin
  if FFailOver = AValue then
    Exit;
  FFailOver := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWDatabase.SetProxyOptions(AValue: TRALRESTDWProxyOptions);
begin
  FProxyOptions.Assign(AValue);
end;

procedure TRALRESTDWDatabase.SetStateConnection(AValue: TRALRESTDWStateConnection);
begin
  FStateConnection.Assign(AValue);
end;

procedure TRALRESTDWDatabase.SetClientConnectionDefs(AValue: TRALRESTDWConnectionDefs);
begin
  FClientConnectionDefs.Assign(AValue);
end;

end.
