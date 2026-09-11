/// The service pooler a migrated RDW server keeps configuring, over RAL's Indy
/// engine.
///
/// Which engine ends up underneath is the migrating developer's choice, not
/// RDW's: TRESTDWIdServicePooler and TRESTDWIcsServicePooler both land here if
/// Indy is what they picked, and on the Synopse or Sagui shell if it is not.
/// That is why the engine is in the class name and not the RDW transport.
///
/// What the shell buys is that this keeps compiling and working, untouched:
///
///     RESTDWIdServicePooler1.ServerMethodClass := TDMPrincipal;
///     RESTDWIdServicePooler1.RootPath := '/api/';
///     RESTDWIdServicePooler1.AuthenticationOptions.AuthorizationOption := rdwAOBasic;
///     TRESTDWAuthOptionBasic(RESTDWIdServicePooler1.AuthenticationOptions
///       .OptionParams).Username := 'admin';
///     RESTDWIdServicePooler1.Active := True;
///
/// Across the real RDW demos those five shapes are most of what the pooler is
/// asked to do - AuthenticationOptions.OptionParams alone appears forty times.
/// A converter rewriting that by text would be guessing; here it only has to
/// swap the class name.
///
/// The rules themselves live in RALRESTDWOptions, so the next engine's shell is
/// a thin file and never a second copy of them.
unit RALRESTDWIndyPooler;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  IdSSLOpenSSL,
  RALTypes, RALServer, RALIndyServer, RALAuthentication,
  RALRESTDWTypes, RALRESTDWOptions, RALRESTDWModule;

type
  { TRALRESTDWIndyServicePooler }

  TRALRESTDWIndyServicePooler = class(TRALIndyServer)
  private
    FAtivarNoLoaded: Boolean;
    FAuthenticationOptions: TRALRESTDWAuthOptions;
    FBasicAuth: TRALServerBasicAuth;
    FCORS: Boolean;
    FCORSCustomHeaders: TStringList;
    FCriptOptions: TRALRESTDWCriptOptions;
    FEncodeErrors: Boolean;
    FEncoding: TRALRESTDWEncodeSelect;
    FForceWelcomeAccess: Boolean;
    FModule: TRALRESTDWModule;
    FPathTraversalRaiseError: Boolean;
    FProxyOptions: TRALRESTDWProxyOptions;
    FRequestTimeout: IntegerRAL;
    FServerIPVersionConfig: TRALRESTDWIPVersionConfig;

    function GetAtivo: Boolean;
    function GetRootPath: StringRAL;
    function GetSSLCertFile: StringRAL;
    function GetSSLMethod: TIdSSLVersion;
    function GetSSLMode: TIdSSLMode;
    function GetSSLPrivateKeyFile: StringRAL;
    function GetSSLPrivateKeyPassword: StringRAL;
    function GetSSLRootCertFile: StringRAL;
    function GetSSLVerifyDepth: IntegerRAL;
    function GetSSLVerifyMode: TIdSSLVerifyModeSet;
    function GetSSLVersions: TIdSSLVersions;
    function GetServerMethodClass: TComponentClass;
    function GetServicePort: IntegerRAL;

    procedure OptionChanged(ASender: TObject);
    procedure SetAtivo(AValue: Boolean);
    procedure SetAuthenticationOptions(AValue: TRALRESTDWAuthOptions);
    procedure SetAuthenticator(AValue: TRALAuthServer);
    function GetAuthenticator: TRALAuthServer;
    procedure SetCORS(AValue: Boolean);
    procedure SetCORSCustomHeaders(AValue: TStringList);
    procedure SetCriptOptions(AValue: TRALRESTDWCriptOptions);
    procedure SetPathTraversalRaiseError(AValue: Boolean);
    procedure SetProxyOptions(AValue: TRALRESTDWProxyOptions);
    procedure SetRootPath(const AValue: StringRAL);
    procedure SetSSLCertFile(const AValue: StringRAL);
    procedure SetSSLMethod(AValue: TIdSSLVersion);
    procedure SetSSLMode(AValue: TIdSSLMode);
    procedure SetSSLPrivateKeyFile(const AValue: StringRAL);
    procedure SetSSLPrivateKeyPassword(const AValue: StringRAL);
    procedure SetSSLRootCertFile(const AValue: StringRAL);
    procedure SetSSLVerifyDepth(AValue: IntegerRAL);
    procedure SetSSLVerifyMode(AValue: TIdSSLVerifyModeSet);
    procedure SetSSLVersions(AValue: TIdSSLVersions);
    procedure SetServerIPVersionConfig(AValue: TRALRESTDWIPVersionConfig);
    procedure SetServerMethodClass(AValue: TComponentClass);
    procedure SetServicePort(AValue: IntegerRAL);

    procedure AplicarOpcoes;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { A classe do DataModule que responde aos eventos. No RDW o transporte
      guardava a classe; no RAL quem acha e o modulo, pelo nome - por isso a
      atribuicao tambem registra a classe. }
    property ServerMethodClass: TComponentClass read GetServerMethodClass
      write SetServerMethodClass;
    /// O modulo que publica os eventos; criado junto com o componente
    property Module: TRALRESTDWModule read FModule;

    { Publicava uma rota do pooler de banco do RDW. Nao faz nada: no RAL o banco
      e publicado por um TRALDBModule, que tem configuracao propria. }
    procedure AddDataRoute(const ARoute: StringRAL;
                           APooler: TObject = nil); overload;
      // inerte: sem equivalente: publique o banco com um TRALDBModule
  published
    { --- o que vira mesmo alguma coisa no RAL --- }
    { Redeclarado so para interceptar o que o streamer escreve. O DFM do RDW
      grava Active antes de ServicePort, e o TRALServer abre o socket no
      instante em que Active vira True, com a porta que houver ali - o
      servidor subiria na porta errada. Guardar a intencao ate o Loaded
      resolve, e redeclarar em vez de sobrescrever SetActive e o que
      distingue o streamer do proprio RAL: SetPort desliga e religa o
      servidor por dentro, e aquele SetActive(False) apagaria a intencao. }
    property Active: Boolean read GetAtivo write SetAtivo;
    property ServicePort: IntegerRAL read GetServicePort write SetServicePort
      default 8082;
    property RootPath: StringRAL read GetRootPath write SetRootPath;
    property Authenticator: TRALAuthServer read GetAuthenticator
      write SetAuthenticator;
    property AuthenticationOptions: TRALRESTDWAuthOptions
      read FAuthenticationOptions write SetAuthenticationOptions;
    property CriptOptions: TRALRESTDWCriptOptions read FCriptOptions
      write SetCriptOptions;
    property CORS: Boolean read FCORS write SetCORS default False;
    property CORS_CustomHeaders: TStringList read FCORSCustomHeaders
      write SetCORSCustomHeaders;
    property PathTraversalRaiseError: Boolean read FPathTraversalRaiseError
      write SetPathTraversalRaiseError default False;
    property ServerIPVersionConfig: TRALRESTDWIPVersionConfig
      read FServerIPVersionConfig write SetServerIPVersionConfig;

    { SSL: o RAL guarda tudo dentro de SSL.SSLOptions, e os tipos sao os mesmos
      do Indy que o RDW ja usava, entao o valor do formulario atravessa igual. }
    property SSLCertFile: StringRAL read GetSSLCertFile write SetSSLCertFile;
    property SSLPrivateKeyFile: StringRAL read GetSSLPrivateKeyFile
      write SetSSLPrivateKeyFile;
    property SSLPrivateKeyPassword: StringRAL read GetSSLPrivateKeyPassword
      write SetSSLPrivateKeyPassword;
    property SSLRootCertFile: StringRAL read GetSSLRootCertFile
      write SetSSLRootCertFile;
    property SSLMode: TIdSSLMode read GetSSLMode write SetSSLMode;
    property SSLMethod: TIdSSLVersion read GetSSLMethod write SetSSLMethod;
    property SSLVersions: TIdSSLVersions read GetSSLVersions write SetSSLVersions;
    property SSLVerifyMode: TIdSSLVerifyModeSet read GetSSLVerifyMode
      write SetSSLVerifyMode;
    property SSLVerifyDepth: IntegerRAL read GetSSLVerifyDepth
      write SetSSLVerifyDepth;

    { --- aceitos e inertes ---
      Existem para o formulario abrir e para o codigo que os le continuar
      compilando, e cada um diz ao lado por que nao faz nada. O Delphi nao
      aceita diretiva de hint em propriedade, entao quem avisa em cima do
      projeto e o conversor: ele relata todo inerte que veio com valor
      diferente do padrao. }
    property RequestTimeout: IntegerRAL read FRequestTimeout write FRequestTimeout
      default -1;
      // inerte: o RAL nao derruba a conexao por tempo de requisicao
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
      // inerte: o RAL fala UTF-8 em todas as engines
    property ForceWelcomeAccess: Boolean read FForceWelcomeAccess
      write FForceWelcomeAccess default False;
      // inerte: a pagina de entrada do RAL e o ShowServerStatus
    property EncodeErrors: Boolean read FEncodeErrors write FEncodeErrors
      default False;
      // inerte: o RAL responde erro em texto puro, sem codificar
    property ProxyOptions: TRALRESTDWProxyOptions read FProxyOptions
      write SetProxyOptions;
      // inerte: o RAL nao atravessa proxy
  end;

implementation

{ TRALRESTDWIndyServicePooler }

constructor TRALRESTDWIndyServicePooler.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Port := 8082;
  FRequestTimeout := -1;
  FEncoding := esUtf8;
  FCORS := False;

  FCORSCustomHeaders := TStringList.Create;

  FAuthenticationOptions := TRALRESTDWAuthOptions.Create;
  FAuthenticationOptions.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;

  FCriptOptions := TRALRESTDWCriptOptions.Create;
  FCriptOptions.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;

  FServerIPVersionConfig := TRALRESTDWIPVersionConfig.Create;
  FServerIPVersionConfig.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;

  FProxyOptions := TRALRESTDWProxyOptions.Create;

  { o modulo nasce junto: no RDW o transporte publicava os eventos sozinho, e e
    esse comportamento que quem migra espera encontrar }
  FModule := TRALRESTDWModule.Create(Self);
  FModule.Name := 'RDWModule';
  FModule.Server := Self;
  FModule.Domain := '/';
end;

destructor TRALRESTDWIndyServicePooler.Destroy;
begin
  FreeAndNil(FProxyOptions);
  FreeAndNil(FServerIPVersionConfig);
  FreeAndNil(FCriptOptions);
  FreeAndNil(FAuthenticationOptions);
  FreeAndNil(FCORSCustomHeaders);
  // FModule e FBasicAuth pertencem a este componente: o inherited os destroi
  inherited Destroy;
end;

function TRALRESTDWIndyServicePooler.GetAtivo: Boolean;
begin
  Result := inherited Active;
end;

procedure TRALRESTDWIndyServicePooler.SetAtivo(AValue: Boolean);
begin
  if csLoading in ComponentState then
  begin
    FAtivarNoLoaded := AValue;
    Exit;
  end;

  inherited Active := AValue;
end;

procedure TRALRESTDWIndyServicePooler.Loaded;
begin
  inherited Loaded;

  AplicarOpcoes;

  if FAtivarNoLoaded then
  begin
    FAtivarNoLoaded := False;
    inherited Active := True;
  end;
end;

procedure TRALRESTDWIndyServicePooler.OptionChanged(ASender: TObject);
begin
  if csLoading in ComponentState then
    Exit;

  AplicarOpcoes;
end;

procedure TRALRESTDWIndyServicePooler.AplicarOpcoes;
begin
  RALRESTDWApplyServerAuth(Self, FAuthenticationOptions, FBasicAuth);
  RALRESTDWApplyCripto(FCriptOptions, CriptoOptions);
  RALRESTDWApplyCORS(Self, FCORS, FCORSCustomHeaders);
  RALRESTDWApplyIPConfig(Self, FServerIPVersionConfig);
  RALRESTDWApplyPathTraversal(Self, FPathTraversalRaiseError);
end;

{ --- porta e rota --- }

function TRALRESTDWIndyServicePooler.GetServicePort: IntegerRAL;
begin
  Result := Port;
end;

procedure TRALRESTDWIndyServicePooler.SetServicePort(AValue: IntegerRAL);
begin
  Port := AValue;
end;

function TRALRESTDWIndyServicePooler.GetRootPath: StringRAL;
begin
  Result := FModule.Domain;
end;

procedure TRALRESTDWIndyServicePooler.SetRootPath(const AValue: StringRAL);
begin
  if Trim(AValue) = '' then
    FModule.Domain := '/'
  else
    FModule.Domain := AValue;
end;

{ --- a classe dos eventos --- }

function TRALRESTDWIndyServicePooler.GetServerMethodClass: TComponentClass;
begin
  Result := TComponentClass(GetClass(FModule.ClassModule));
end;

procedure TRALRESTDWIndyServicePooler.SetServerMethodClass(AValue: TComponentClass);
begin
  if AValue = nil then
  begin
    FModule.ClassModule := '';
    Exit;
  end;

  { o modulo acha a classe pelo nome, e GetClass so enxerga classe registrada -
    registrar aqui poupa quem migra de descobrir isso do jeito dificil }
  RegisterClass(TPersistentClass(AValue));
  FModule.ClassModule := AValue.ClassName;
  FModule.RefreshRoutes;
end;

procedure TRALRESTDWIndyServicePooler.AddDataRoute(const ARoute: StringRAL;
  APooler: TObject);
begin
  // nada a fazer: ver o deprecated na declaracao
end;

{ --- autenticacao --- }

function TRALRESTDWIndyServicePooler.GetAuthenticator: TRALAuthServer;
begin
  Result := Authentication;
end;

procedure TRALRESTDWIndyServicePooler.SetAuthenticator(AValue: TRALAuthServer);
begin
  Authentication := AValue;
end;

procedure TRALRESTDWIndyServicePooler.SetAuthenticationOptions(
  AValue: TRALRESTDWAuthOptions);
begin
  FAuthenticationOptions.Assign(AValue);
end;

{ --- opcoes --- }

procedure TRALRESTDWIndyServicePooler.SetCriptOptions(AValue: TRALRESTDWCriptOptions);
begin
  FCriptOptions.Assign(AValue);
end;

procedure TRALRESTDWIndyServicePooler.SetProxyOptions(AValue: TRALRESTDWProxyOptions);
begin
  FProxyOptions.Assign(AValue);
end;

procedure TRALRESTDWIndyServicePooler.SetServerIPVersionConfig(
  AValue: TRALRESTDWIPVersionConfig);
begin
  FServerIPVersionConfig.Assign(AValue);
end;

procedure TRALRESTDWIndyServicePooler.SetCORS(AValue: Boolean);
begin
  if FCORS = AValue then
    Exit;

  FCORS := AValue;
  OptionChanged(Self);
end;

procedure TRALRESTDWIndyServicePooler.SetCORSCustomHeaders(AValue: TStringList);
begin
  FCORSCustomHeaders.Assign(AValue);
  OptionChanged(Self);
end;

procedure TRALRESTDWIndyServicePooler.SetPathTraversalRaiseError(AValue: Boolean);
begin
  if FPathTraversalRaiseError = AValue then
    Exit;

  FPathTraversalRaiseError := AValue;
  OptionChanged(Self);
end;

{ --- SSL: tudo vive em SSL.SSLOptions --- }

function TRALRESTDWIndyServicePooler.GetSSLCertFile: StringRAL;
begin
  Result := SSL.SSLOptions.CertFile;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLCertFile(const AValue: StringRAL);
begin
  SSL.SSLOptions.CertFile := AValue;
  SSL.Enabled := AValue <> '';
end;

function TRALRESTDWIndyServicePooler.GetSSLPrivateKeyFile: StringRAL;
begin
  Result := SSL.SSLOptions.KeyFile;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLPrivateKeyFile(const AValue: StringRAL);
begin
  SSL.SSLOptions.KeyFile := AValue;
end;

function TRALRESTDWIndyServicePooler.GetSSLPrivateKeyPassword: StringRAL;
begin
  Result := SSL.SSLOptions.Key;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLPrivateKeyPassword(const AValue: StringRAL);
begin
  SSL.SSLOptions.Key := AValue;
end;

function TRALRESTDWIndyServicePooler.GetSSLRootCertFile: StringRAL;
begin
  Result := SSL.SSLOptions.RootCertFile;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLRootCertFile(const AValue: StringRAL);
begin
  SSL.SSLOptions.RootCertFile := AValue;
end;

function TRALRESTDWIndyServicePooler.GetSSLMode: TIdSSLMode;
begin
  Result := SSL.SSLOptions.Mode;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLMode(AValue: TIdSSLMode);
begin
  SSL.SSLOptions.Mode := AValue;
end;

function TRALRESTDWIndyServicePooler.GetSSLMethod: TIdSSLVersion;
begin
  Result := SSL.SSLOptions.Method;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLMethod(AValue: TIdSSLVersion);
begin
  SSL.SSLOptions.Method := AValue;
end;

function TRALRESTDWIndyServicePooler.GetSSLVersions: TIdSSLVersions;
begin
  Result := SSL.SSLOptions.SSLVersions;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLVersions(AValue: TIdSSLVersions);
begin
  SSL.SSLOptions.SSLVersions := AValue;
end;

function TRALRESTDWIndyServicePooler.GetSSLVerifyMode: TIdSSLVerifyModeSet;
begin
  Result := SSL.SSLOptions.VerifyMode;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLVerifyMode(AValue: TIdSSLVerifyModeSet);
begin
  SSL.SSLOptions.VerifyMode := AValue;
end;

function TRALRESTDWIndyServicePooler.GetSSLVerifyDepth: IntegerRAL;
begin
  Result := SSL.SSLOptions.VerifyDepth;
end;

procedure TRALRESTDWIndyServicePooler.SetSSLVerifyDepth(AValue: IntegerRAL);
begin
  SSL.SSLOptions.VerifyDepth := AValue;
end;

end.
