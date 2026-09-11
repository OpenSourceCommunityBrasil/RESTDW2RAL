/// The RDW option objects that both transports carry.
///
/// In RDW the pooler and the client pooler share the same option classes, and
/// code written against either one names them. They live here so both shells -
/// TRALRESTDWClient and TRALRESTDWServicePooler - publish the very same types,
/// and a cast written for one still compiles against the other.
///
/// Each one tells its owner when something changed: RDW code sets these at
/// runtime, right before a call, so reading them once at Loaded would not be
/// enough.
unit RALRESTDWOptions;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  RALTypes, RALServer, RALClient, RALAuthentication, RALCripto, RALToken,
  RALRESTDWTypes;

type
  /// Same members and order as RDW's TRESTDWAuthOption
  TRALRESTDWAuthOption = (rdwAONone, rdwAOBasic, rdwAOBearer, rdwAOToken,
                          rdwOAuth);

  { TRALRESTDWPersistent }

  /// A TPersistent that tells its owner when something changed
  TRALRESTDWPersistent = class(TPersistent)
  private
    FOnChange: TNotifyEvent;
  protected
    procedure Changed;
  public
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  { TRALRESTDWAuthOptionParam }

  TRALRESTDWAuthOptionParam = class(TRALRESTDWPersistent)
  private
    FAuthDialog: Boolean;
    FCustom404BodyMessage: StringRAL;
    FCustom404FooterMessage: StringRAL;
    FCustom404TitleMessage: StringRAL;
    FCustomAuthErrorPage: TStringList;
    FCustomDialogAuthMessage: StringRAL;

    procedure SetCustomAuthErrorPage(AValue: TStringList);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property AuthDialog: Boolean read FAuthDialog write FAuthDialog;
    { As paginas de erro do RDW. Quem responde por elas no RAL e o
      ResponsePages do servidor, que tem formato proprio, entao aqui elas so
      guardam o texto. }
    property CustomDialogAuthMessage: StringRAL read FCustomDialogAuthMessage
      write FCustomDialogAuthMessage;
    property Custom404TitleMessage: StringRAL read FCustom404TitleMessage
      write FCustom404TitleMessage;
    property Custom404BodyMessage: StringRAL read FCustom404BodyMessage
      write FCustom404BodyMessage;
    property Custom404FooterMessage: StringRAL read FCustom404FooterMessage
      write FCustom404FooterMessage;
    property CustomAuthErrorPage: TStringList read FCustomAuthErrorPage
      write SetCustomAuthErrorPage;
  end;

  { TRALRESTDWAuthOptionBasic }

  TRALRESTDWAuthOptionBasic = class(TRALRESTDWAuthOptionParam)
  private
    FPassword: StringRAL;
    FUserName: StringRAL;

    procedure SetPassword(const AValue: StringRAL);
    procedure SetUserName(const AValue: StringRAL);
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Username: StringRAL read FUserName write SetUserName;
    property Password: StringRAL read FPassword write SetPassword;
  end;

  { TRALRESTDWAuthOptions }

  /// AuthenticationOptions, o jeito RDW de dizer quem pode entrar
  TRALRESTDWAuthOptions = class(TRALRESTDWPersistent)
  private
    FAuthorizationOption: TRALRESTDWAuthOption;
    FOptionParams: TRALRESTDWAuthOptionBasic;

    procedure OptionChanged(ASender: TObject);
    procedure SetAuthorizationOption(AValue: TRALRESTDWAuthOption);
    procedure SetOptionParams(AValue: TRALRESTDWAuthOptionBasic);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
  published
    property AuthorizationOption: TRALRESTDWAuthOption read FAuthorizationOption
      write SetAuthorizationOption default rdwAONone;
    property OptionParams: TRALRESTDWAuthOptionBasic read FOptionParams
      write SetOptionParams;
  end;

  { TRALRESTDWCriptOptions }

  /// CriptOptions do RDW; por dentro alimenta o CriptoOptions do RAL
  TRALRESTDWCriptOptions = class(TRALRESTDWPersistent)
  private
    FKey: StringRAL;
    FUse: Boolean;

    procedure SetKey(const AValue: StringRAL);
    procedure SetUse(AValue: Boolean);
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Use: Boolean read FUse write SetUse default False;
    property Key: StringRAL read FKey write SetKey;
  end;

  { TRALRESTDWAuthTokenParam }

  { As opcoes de token do RDW. O RAL tem JWT proprio (TRALServerJWTAuth e
    TRALClientJWTAuth), com configuracao que nao casa membro a membro com
    esta - entao aqui os valores sao guardados e o token continua sendo
    configurado no componente do RAL. }
  TRALRESTDWTokenType = (rdwTS, rdwJWT, rdwPersonal);
  TRALRESTDWCryptType = (rdwMD5, rdwSHA1, rdwSHA256, rdwSHA512);

  TRALRESTDWAuthTokenParam = class(TRALRESTDWAuthOptionParam)
  private
    FBeginTime: TDateTime;
    FCryptType: TRALRESTDWCryptType;
    FEndTime: TDateTime;
    FGetTokenEvent: StringRAL;
    FKey: StringRAL;
    FLifeCycle: IntegerRAL;
    FSecrets: StringRAL;
    FServerSignature: StringRAL;
    FTokenHash: StringRAL;
    FTokenType: TRALRESTDWTokenType;
  public
    procedure Assign(ASource: TPersistent); override;

    { Emite um token a partir do payload, assinado com a Key - e o mesmo
      GetToken do RDW e nao e inerte: sai um JWT HS256 de verdade, que o
      TRALServerJWTAuth do RAL valida se a chave for a mesma. }
    function GetToken(const APayload: StringRAL): StringRAL;
  published
    property BeginTime: TDateTime read FBeginTime write FBeginTime;
    property EndTime: TDateTime read FEndTime write FEndTime;
    property Secrets: StringRAL read FSecrets write FSecrets;
    property TokenType: TRALRESTDWTokenType read FTokenType write FTokenType
      default rdwTS;
    property CryptType: TRALRESTDWCryptType read FCryptType write FCryptType
      default rdwMD5;
    property Key: StringRAL read FKey write FKey;
    property GetTokenEvent: StringRAL read FGetTokenEvent write FGetTokenEvent;
    property TokenHash: StringRAL read FTokenHash write FTokenHash;
    property ServerSignature: StringRAL read FServerSignature
      write FServerSignature;
    property LifeCycle: IntegerRAL read FLifeCycle write FLifeCycle default 0;
  end;

  { TRALRESTDWAuthOptionBearer }

  { As opcoes de bearer do cliente no RDW. O token e so carregado: quem o
    coloca no cabecalho e o TRALClientJWTAuth do RAL. }
  { Onde o token viaja. O RAL manda sempre no cabecalho Authorization, que e o
    rdwtHeader; rdwtRequest, que punha o token no corpo, nao tem equivalente. }
  TRALRESTDWTokenRequest = (rdwtHeader, rdwtRequest);

  { Bearer e token sao duas classes no RDW e uma so aqui: guardam a mesma
    coisa - o valor que vai no cabecalho Authorization, mais os dados de
    emissao. Quem o poe na requisicao e o TRALClientJWTAuth do RAL. }
  TRALRESTDWAuthOptionBearer = class(TRALRESTDWAuthTokenParam)
  private
    FToken: StringRAL;
    FTokenRequestType: TRALRESTDWTokenRequest;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Token: StringRAL read FToken write FToken;
    property TokenRequestType: TRALRESTDWTokenRequest read FTokenRequestType
      write FTokenRequestType default rdwtHeader;
      // inerte: o RAL manda o token sempre no cabecalho Authorization
  end;

  { TRALRESTDWConnectionDefs }

  { O que o PrepareConnection do driver do RDW recebia para montar a conexao.
    Aqui ele chega preenchido a partir do TRALDBModule, e o que o handler
    escrever de volta e aplicado nele. }
  TRALRESTDWConnectionDefs = class(TRALRESTDWPersistent)
  private
    FCharset: StringRAL;
    FDBPort: IntegerRAL;
    FDataSource: StringRAL;
    FDatabaseName: StringRAL;
    FDriverID: StringRAL;
    FHostName: StringRAL;
    FOtherDetails: StringRAL;
    FPassword: StringRAL;
    FProtocol: StringRAL;
    FUsername: StringRAL;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property Charset: StringRAL read FCharset write FCharset;
    property DriverID: StringRAL read FDriverID write FDriverID;
    property DatabaseName: StringRAL read FDatabaseName write FDatabaseName;
    property HostName: StringRAL read FHostName write FHostName;
    property Username: StringRAL read FUsername write FUsername;
    property Password: StringRAL read FPassword write FPassword;
    property Protocol: StringRAL read FProtocol write FProtocol;
    property DBPort: IntegerRAL read FDBPort write FDBPort default 0;
    property DataSource: StringRAL read FDataSource write FDataSource;
    property OtherDetails: StringRAL read FOtherDetails write FOtherDetails;
  end;

  { O TTyperequest do RDW. Dos quatro, so o https muda alguma coisa aqui: o RAL
    escolhe o esquema pela BaseURL, e nao ha transporte proprio por tipo. }
  TRALRESTDWTypeRequest = (trHttp, trHttps, trSocket, trWebSocket);

  { TRALRESTDWConnectionServer }

  { Um servidor da lista de reserva do RDW. O RAL nao tem failover, entao a
    colecao existe, guarda o que o .dfm trouxer, e nada troca de servidor
    sozinho. }
  TRALRESTDWConnectionServer = class(TCollectionItem)
  private
    FActive: Boolean;
    FName: StringRAL;
    FConnectTimeOut: IntegerRAL;
    FPoolerName: StringRAL;
    FPoolerPort: IntegerRAL;
    FPoolerService: StringRAL;
    FRequestTimeOut: IntegerRAL;
    FAccessTag: StringRAL;
    FAuthentication: Boolean;
    FCompression: Boolean;
    FDataRoute: StringRAL;
    FEncodeStrings: Boolean;
    FEncoding: TRALRESTDWEncodeSelect;
    FServerEventName: StringRAL;
    FTypeRequest: TRALRESTDWTypeRequest;
    FWelcomeMessage: StringRAL;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(ASource: TPersistent); override;
  published
    property Name: StringRAL read FName write FName;
    property Active: Boolean read FActive write FActive default False;
    property PoolerService: StringRAL read FPoolerService write FPoolerService;
    property PoolerPort: IntegerRAL read FPoolerPort write FPoolerPort
      default 8082;
    property PoolerName: StringRAL read FPoolerName write FPoolerName;
    property RequestTimeOut: IntegerRAL read FRequestTimeOut
      write FRequestTimeOut default 0;
    property ConnectTimeOut: IntegerRAL read FConnectTimeOut
      write FConnectTimeOut default 0;

    { O mesmo item serve de entrada de failover, e la o RDW batiza as coisas de
      outro jeito (Host/Port em vez de PoolerService/PoolerPort). Todas inertes:
      o RAL nao tem failover de cliente. }
    property Host: StringRAL read FPoolerService write FPoolerService stored False;
    property Port: IntegerRAL read FPoolerPort write FPoolerPort stored False;
    property Compression: Boolean read FCompression write FCompression default False;
    property hEncodeStrings: Boolean read FEncodeStrings write FEncodeStrings default True;
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding default esUtf8;
    property WelcomeMessage: StringRAL read FWelcomeMessage write FWelcomeMessage;
    property AccessTag: StringRAL read FAccessTag write FAccessTag;
    property TypeRequest: TRALRESTDWTypeRequest read FTypeRequest write FTypeRequest
      default trHttp;
    property ServerEventName: StringRAL read FServerEventName write FServerEventName;
    property DataRoute: StringRAL read FDataRoute write FDataRoute;
    property Authentication: Boolean read FAuthentication write FAuthentication
      default True;
  end;

  { TRALRESTDWConnectionServers }

  TRALRESTDWConnectionServers = class(TCollection)
  private
    FOwner: TPersistent;

    function GetItem(AIndex: Integer): TRALRESTDWConnectionServer;
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TPersistent);
    property Items[AIndex: Integer]: TRALRESTDWConnectionServer read GetItem;
      default;
  end;

  /// Mesmos membros e ordem do TConnStatus do RDW
  TRALRESTDWConnStatus = (hsResolving, hsConnecting, hsConnected,
                          hsDisconnecting, hsDisconnected, hsStatusText);

  { TRALRESTDWProxyOptions }

  /// ProxyOptions do RDW. O RAL nao atravessa proxy, entao aqui so guarda.
  { O SSL do RDW. O SSLVersions e do proprio RDW (uRESTDWBasic) e o SSLMode e o
    TIdSSLMode do Indy, repetido aqui com os mesmos nomes de valor para o DFM
    carregar sem arrastar o Indy para o pacote base - quem escolhe o motor e o
    usuario, e um cliente de netHTTP nao tem por que linkar Indy.
    Inertes: no RAL o TLS e do motor, configurado por SSL.SSLOptions. }
  TRALRESTDWSSLVersion = (SSLv2, SSLv23, SSLv3, TLSv1, TLSv1_1, TLSv1_2,
                          TLSv1_3);
  TRALRESTDWSSLVersions = set of TRALRESTDWSSLVersion;
  TRALRESTDWSSLMode = (sslmUnassigned, sslmClient, sslmServer, sslmBoth);

  { Os ganchos de progresso do RDW (TOnWork/TOnWorkEnd, de
    uRESTDWComponentEvents), que la vem do Indy. Ficam declarados para o DFM
    carregar e o handler continuar ligado; o TRALClient nao publica progresso,
    entao nada os dispara. }
  TRALRESTDWOnWork = procedure(ASender: TObject; AWorkCount: Int64) of object;
  TRALRESTDWOnWorkEnd = procedure(ASender: TObject) of object;

  TRALRESTDWProxyOptions = class(TRALRESTDWPersistent)
  private
    FProxyPassword: StringRAL;
    FProxyPort: IntegerRAL;
    FProxyServer: StringRAL;
    FProxyUsername: StringRAL;
  public
    procedure Assign(ASource: TPersistent); override;
  published
    property ProxyServer: StringRAL read FProxyServer write FProxyServer;
    property ProxyPort: IntegerRAL read FProxyPort write FProxyPort default 0;
    property ProxyUsername: StringRAL read FProxyUsername write FProxyUsername;
    property ProxyPassword: StringRAL read FProxyPassword write FProxyPassword;

    { O RDW tem dois proxies de nomes diferentes: o do cliente e o
      TProxyConnectionInfo do Indy (ProxyServer/ProxyPort/...) e o do database e
      o TProxyOptions dele (Server/Port/Login/Password). Uma casca so atende os
      dois publicando os dois jogos de nomes sobre o mesmo campo; este jogo vai
      com stored False para ser lido do DFM antigo e nunca gravado em dobro. }
    property Server: StringRAL read FProxyServer write FProxyServer stored False;
    property Port: IntegerRAL read FProxyPort write FProxyPort stored False;
    property Login: StringRAL read FProxyUsername write FProxyUsername stored False;
    property Password: StringRAL read FProxyPassword write FProxyPassword stored False;
  end;

  { TRALRESTDWIPVersionConfig }

  /// ServerIPVersionConfig do RDW; por dentro e o IPConfig do RAL
  TRALRESTDWIPVersionConfig = class(TRALRESTDWPersistent)
  private
    FIPv4Address: StringRAL;
    FIPv6Address: StringRAL;

    procedure SetIPv4Address(const AValue: StringRAL);
    procedure SetIPv6Address(const AValue: StringRAL);
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    property IPv4Address: StringRAL read FIPv4Address write SetIPv4Address;
    property IPv6Address: StringRAL read FIPv6Address write SetIPv6Address;
  end;

{ O de/para em si.

  Cada motor do RAL - Indy, Synopse, Sagui - precisa da sua propria casca,
  porque o TRALServer e abstrato e quem implementa o transporte e a classe
  filha. O que essas cascas NAO precisam e repetir a regra: ela e a mesma para
  todas, entao mora aqui, recebendo o servidor como parametro. }

/// AuthenticationOptions -> o componente de autenticacao que o RAL espera
procedure RALRESTDWApplyServerAuth(AServer: TRALServer;
                                   AOptions: TRALRESTDWAuthOptions;
                                   var ABasic: TRALServerBasicAuth);
/// O mesmo do lado do cliente
procedure RALRESTDWApplyClientAuth(AClient: TRALClient;
                                   AOptions: TRALRESTDWAuthOptions;
                                   var ABasic: TRALClientBasicAuth);
/// CriptOptions.Use/Key -> CriptoOptions.CriptType/Key
procedure RALRESTDWApplyCripto(AOptions: TRALRESTDWCriptOptions;
                               ADest: TRALCriptoOptions);
{ CORS_CustomHeaders do RDW e uma lista 'Header=Valor'; o RAL guarda a origem
  numa propriedade e os nomes de cabecalho noutra. }
procedure RALRESTDWApplyCORS(AServer: TRALServer; AEnabled: Boolean;
                             AHeaders: TStrings);
/// ServerIPVersionConfig -> IPConfig
procedure RALRESTDWApplyIPConfig(AServer: TRALServer;
                                 AConfig: TRALRESTDWIPVersionConfig);
/// PathTraversalRaiseError -> Security.Options
procedure RALRESTDWApplyPathTraversal(AServer: TRALServer; AValue: Boolean);

implementation

{ TRALRESTDWAuthTokenParam }

procedure TRALRESTDWAuthTokenParam.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWAuthTokenParam;
begin
  inherited Assign(ASource);

  if not (ASource is TRALRESTDWAuthTokenParam) then
    Exit;

  vSource := TRALRESTDWAuthTokenParam(ASource);
  FBeginTime := vSource.BeginTime;
  FEndTime := vSource.EndTime;
  FSecrets := vSource.Secrets;
  FTokenType := vSource.TokenType;
  FCryptType := vSource.CryptType;
  FKey := vSource.Key;
  FGetTokenEvent := vSource.GetTokenEvent;
  FTokenHash := vSource.TokenHash;
  FServerSignature := vSource.ServerSignature;
  FLifeCycle := vSource.LifeCycle;
  Changed;
end;

function TRALRESTDWAuthTokenParam.GetToken(const APayload: StringRAL): StringRAL;
var
  vJWT: TRALJWT;
begin
  vJWT := TRALJWT.Create;
  try
    { Secrets primeiro, que e onde o RDW guardava o segredo; Key e o nome do
      token e serve de reserva quando Secrets vem vazio. }
    if FSecrets <> '' then
      vJWT.SignSecretKey := FSecrets
    else
      vJWT.SignSecretKey := FKey;

    { o payload do RDW ja vem como JSON; o AsJSON o absorve inteiro e o Token
      monta cabecalho, corpo e assinatura }
    vJWT.Payload.AsJSON := APayload;
    Result := vJWT.Token;
  finally
    FreeAndNil(vJWT);
  end;
end;

procedure TRALRESTDWAuthOptionBearer.Assign(ASource: TPersistent);
begin
  inherited Assign(ASource);

  if ASource is TRALRESTDWAuthOptionBearer then
  begin
    FToken := TRALRESTDWAuthOptionBearer(ASource).Token;
    FTokenRequestType := TRALRESTDWAuthOptionBearer(ASource).TokenRequestType;
    Changed;
  end;
end;

{ TRALRESTDWConnectionDefs }

procedure TRALRESTDWConnectionDefs.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWConnectionDefs;
begin
  if not (ASource is TRALRESTDWConnectionDefs) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  vSource := TRALRESTDWConnectionDefs(ASource);
  FCharset := vSource.Charset;
  FDriverID := vSource.DriverID;
  FDatabaseName := vSource.DatabaseName;
  FHostName := vSource.HostName;
  FUsername := vSource.Username;
  FPassword := vSource.Password;
  FProtocol := vSource.Protocol;
  FDBPort := vSource.DBPort;
  FDataSource := vSource.DataSource;
  FOtherDetails := vSource.OtherDetails;
  Changed;
end;

{ TRALRESTDWConnectionServer }

constructor TRALRESTDWConnectionServer.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FPoolerPort := 8082;
  FEncodeStrings := True;
  FEncoding := esUtf8;
  FTypeRequest := trHttp;
  FAuthentication := True;
end;

procedure TRALRESTDWConnectionServer.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWConnectionServer;
begin
  if not (ASource is TRALRESTDWConnectionServer) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  vSource := TRALRESTDWConnectionServer(ASource);
  FName := vSource.Name;
  FActive := vSource.Active;
  FPoolerService := vSource.PoolerService;
  FPoolerPort := vSource.PoolerPort;
  FPoolerName := vSource.PoolerName;
  FRequestTimeOut := vSource.RequestTimeOut;
  FConnectTimeOut := vSource.ConnectTimeOut;
  FAccessTag := vSource.AccessTag;
  FAuthentication := vSource.Authentication;
  FCompression := vSource.Compression;
  FDataRoute := vSource.DataRoute;
  FEncodeStrings := vSource.hEncodeStrings;
  FEncoding := vSource.Encoding;
  FServerEventName := vSource.ServerEventName;
  FTypeRequest := vSource.TypeRequest;
  FWelcomeMessage := vSource.WelcomeMessage;
end;

{ TRALRESTDWConnectionServers }

constructor TRALRESTDWConnectionServers.Create(AOwner: TPersistent);
begin
  inherited Create(TRALRESTDWConnectionServer);
  FOwner := AOwner;
end;

function TRALRESTDWConnectionServers.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TRALRESTDWConnectionServers.GetItem(
  AIndex: Integer): TRALRESTDWConnectionServer;
begin
  Result := TRALRESTDWConnectionServer(inherited Items[AIndex]);
end;

{ TRALRESTDWPersistent }

procedure TRALRESTDWPersistent.Changed;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

{ TRALRESTDWAuthOptionParam }

constructor TRALRESTDWAuthOptionParam.Create;
begin
  inherited Create;
  FCustomAuthErrorPage := TStringList.Create;
end;

destructor TRALRESTDWAuthOptionParam.Destroy;
begin
  FreeAndNil(FCustomAuthErrorPage);
  inherited Destroy;
end;

procedure TRALRESTDWAuthOptionParam.SetCustomAuthErrorPage(AValue: TStringList);
begin
  FCustomAuthErrorPage.Assign(AValue);
end;

procedure TRALRESTDWAuthOptionParam.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWAuthOptionParam;
begin
  if not (ASource is TRALRESTDWAuthOptionParam) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  vSource := TRALRESTDWAuthOptionParam(ASource);
  FAuthDialog := vSource.AuthDialog;
  FCustomDialogAuthMessage := vSource.CustomDialogAuthMessage;
  FCustom404TitleMessage := vSource.Custom404TitleMessage;
  FCustom404BodyMessage := vSource.Custom404BodyMessage;
  FCustom404FooterMessage := vSource.Custom404FooterMessage;
  FCustomAuthErrorPage.Assign(vSource.CustomAuthErrorPage);
  Changed;
end;

{ TRALRESTDWAuthOptionBasic }

procedure TRALRESTDWAuthOptionBasic.SetUserName(const AValue: StringRAL);
begin
  if FUserName = AValue then
    Exit;

  FUserName := AValue;
  Changed;
end;

procedure TRALRESTDWAuthOptionBasic.SetPassword(const AValue: StringRAL);
begin
  if FPassword = AValue then
    Exit;

  FPassword := AValue;
  Changed;
end;

procedure TRALRESTDWAuthOptionBasic.Assign(ASource: TPersistent);
begin
  inherited Assign(ASource);

  if ASource is TRALRESTDWAuthOptionBasic then
  begin
    FUserName := TRALRESTDWAuthOptionBasic(ASource).Username;
    FPassword := TRALRESTDWAuthOptionBasic(ASource).Password;
    Changed;
  end;
end;

{ TRALRESTDWAuthOptions }

constructor TRALRESTDWAuthOptions.Create;
begin
  inherited Create;
  FAuthorizationOption := rdwAONone;
  FOptionParams := TRALRESTDWAuthOptionBasic.Create;
  FOptionParams.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;
end;

destructor TRALRESTDWAuthOptions.Destroy;
begin
  FreeAndNil(FOptionParams);
  inherited Destroy;
end;

procedure TRALRESTDWAuthOptions.OptionChanged(ASender: TObject);
begin
  Changed;
end;

procedure TRALRESTDWAuthOptions.SetAuthorizationOption(AValue: TRALRESTDWAuthOption);
begin
  if FAuthorizationOption = AValue then
    Exit;

  FAuthorizationOption := AValue;
  Changed;
end;

procedure TRALRESTDWAuthOptions.SetOptionParams(AValue: TRALRESTDWAuthOptionBasic);
begin
  FOptionParams.Assign(AValue);
end;

procedure TRALRESTDWAuthOptions.Assign(ASource: TPersistent);
begin
  if not (ASource is TRALRESTDWAuthOptions) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  FAuthorizationOption := TRALRESTDWAuthOptions(ASource).AuthorizationOption;
  FOptionParams.Assign(TRALRESTDWAuthOptions(ASource).OptionParams);
  Changed;
end;

{ TRALRESTDWCriptOptions }

procedure TRALRESTDWCriptOptions.SetKey(const AValue: StringRAL);
begin
  if FKey = AValue then
    Exit;

  FKey := AValue;
  Changed;
end;

procedure TRALRESTDWCriptOptions.SetUse(AValue: Boolean);
begin
  if FUse = AValue then
    Exit;

  FUse := AValue;
  Changed;
end;

procedure TRALRESTDWCriptOptions.Assign(ASource: TPersistent);
begin
  if not (ASource is TRALRESTDWCriptOptions) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  FKey := TRALRESTDWCriptOptions(ASource).Key;
  FUse := TRALRESTDWCriptOptions(ASource).Use;
  Changed;
end;

{ TRALRESTDWProxyOptions }

procedure TRALRESTDWProxyOptions.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWProxyOptions;
begin
  if not (ASource is TRALRESTDWProxyOptions) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  vSource := TRALRESTDWProxyOptions(ASource);
  FProxyServer := vSource.ProxyServer;
  FProxyPort := vSource.ProxyPort;
  FProxyUsername := vSource.ProxyUsername;
  FProxyPassword := vSource.ProxyPassword;
  Changed;
end;

{ TRALRESTDWIPVersionConfig }

constructor TRALRESTDWIPVersionConfig.Create;
begin
  inherited Create;
  FIPv4Address := '0.0.0.0';
  FIPv6Address := '::';
end;

procedure TRALRESTDWIPVersionConfig.SetIPv4Address(const AValue: StringRAL);
begin
  if FIPv4Address = AValue then
    Exit;

  FIPv4Address := AValue;
  Changed;
end;

procedure TRALRESTDWIPVersionConfig.SetIPv6Address(const AValue: StringRAL);
begin
  if FIPv6Address = AValue then
    Exit;

  FIPv6Address := AValue;
  Changed;
end;

procedure TRALRESTDWIPVersionConfig.Assign(ASource: TPersistent);
begin
  if not (ASource is TRALRESTDWIPVersionConfig) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  FIPv4Address := TRALRESTDWIPVersionConfig(ASource).IPv4Address;
  FIPv6Address := TRALRESTDWIPVersionConfig(ASource).IPv6Address;
  Changed;
end;

{ ------------------------------------------------------------------ de/para }

procedure RALRESTDWApplyServerAuth(AServer: TRALServer;
  AOptions: TRALRESTDWAuthOptions; var ABasic: TRALServerBasicAuth);
begin
  if AServer = nil then
    Exit;

  if AOptions.AuthorizationOption <> rdwAOBasic then
  begin
    { so desliga o que esta camada ligou: quem apontou o Authentication para um
      autenticador proprio nao perde o dele }
    if (ABasic <> nil) and (AServer.Authentication = ABasic) then
      AServer.Authentication := nil;
    Exit;
  end;

  if ABasic = nil then
    ABasic := TRALServerBasicAuth.Create(AServer);

  ABasic.UserName := AOptions.OptionParams.Username;
  ABasic.Password := AOptions.OptionParams.Password;
  ABasic.AuthDialog := AOptions.OptionParams.AuthDialog;

  if AServer.Authentication <> ABasic then
    AServer.Authentication := ABasic;
end;

procedure RALRESTDWApplyClientAuth(AClient: TRALClient;
  AOptions: TRALRESTDWAuthOptions; var ABasic: TRALClientBasicAuth);
begin
  if AClient = nil then
    Exit;

  if AOptions.AuthorizationOption <> rdwAOBasic then
  begin
    if (ABasic <> nil) and (AClient.Authentication = ABasic) then
      AClient.Authentication := nil;
    Exit;
  end;

  if ABasic = nil then
    ABasic := TRALClientBasicAuth.Create(AClient);

  ABasic.UserName := AOptions.OptionParams.Username;
  ABasic.Password := AOptions.OptionParams.Password;

  if AClient.Authentication <> ABasic then
    AClient.Authentication := ABasic;
end;

procedure RALRESTDWApplyCripto(AOptions: TRALRESTDWCriptOptions;
  ADest: TRALCriptoOptions);
begin
  if ADest = nil then
    Exit;

  if AOptions.Use then
    ADest.CriptType := crAES256
  else
    ADest.CriptType := crNone;

  if AOptions.Key <> '' then
    ADest.Key := AOptions.Key;
end;

procedure RALRESTDWApplyCORS(AServer: TRALServer; AEnabled: Boolean;
  AHeaders: TStrings);
var
  vInt1, vPos: Integer;
  vNome, vValor: StringRAL;
  vLista: TStringList;
begin
  if (AServer = nil) or (not AEnabled) or (AHeaders = nil) then
    Exit;

  vLista := TStringList.Create;
  try
    for vInt1 := 0 to AHeaders.Count - 1 do
    begin
      vPos := Pos('=', AHeaders[vInt1]);
      if vPos = 0 then
        Continue;

      vNome := Trim(Copy(AHeaders[vInt1], 1, vPos - 1));
      vValor := Trim(Copy(AHeaders[vInt1], vPos + 1, MaxInt));

      if SameText(vNome, 'Access-Control-Allow-Origin') then
        AServer.CORSOptions.AllowOrigin := vValor
      else if SameText(vNome, 'Access-Control-Allow-Headers') then
      begin
        { Allow-Methods nao entra: o RAL responde com os verbos que a rota
          realmente aceita, que e mais certo do que uma lista fixa. }
        vLista.CommaText := vValor;
        AServer.CORSOptions.AllowHeaders.Assign(vLista);
      end;
    end;
  finally
    FreeAndNil(vLista);
  end;
end;

procedure RALRESTDWApplyIPConfig(AServer: TRALServer;
  AConfig: TRALRESTDWIPVersionConfig);
begin
  if AServer = nil then
    Exit;

  AServer.IPConfig.IPv4Bind := AConfig.IPv4Address;
  AServer.IPConfig.IPv6Bind := AConfig.IPv6Address;
end;

procedure RALRESTDWApplyPathTraversal(AServer: TRALServer; AValue: Boolean);
begin
  if AServer = nil then
    Exit;

  if AValue then
    AServer.Security.Options := AServer.Security.Options + [rsoPathTransvBlackList]
  else
    AServer.Security.Options := AServer.Security.Options - [rsoPathTransvBlackList];
end;

end.
