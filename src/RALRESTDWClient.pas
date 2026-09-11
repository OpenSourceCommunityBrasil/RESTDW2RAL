/// The client transport a migrated RDW project keeps talking to.
///
/// A converter can rewrite a .dfm, but it cannot rewrite code with any
/// confidence, and the RDW client pooler is used from code all the time:
///
///     RESTClientPooler1.Host := eHost.Text;
///     RESTClientPooler1.Port := StrToInt(ePort.Text);
///     RESTClientPooler1.AuthenticationOptions.AuthorizationOption := rdwAOBasic;
///     TRESTDWAuthOptionBasic(RESTClientPooler1.AuthenticationOptions.OptionParams)
///       .Username := edUser.Text;
///
/// So this class keeps RDW's face and does RAL's work behind it: Host, Port and
/// UseSSL become the one BaseURL that TRALClient wants, DataCompression becomes
/// CompressType, and AuthenticationOptions becomes the TRALClientBasicAuth that
/// RAL expects in Authentication. The four lines above then compile and behave,
/// with no edit at all.
///
/// Members RAL has no answer for are published too - otherwise the form stops
/// streaming at the first one and takes the whole thing with it - but every one
/// of them is marked `deprecated`, so the compiler names the line that counts on
/// something this layer does not do.
unit RALRESTDWClient;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  RALTypes, RALClient, RALCompress, RALAuthentication, RALResponse,
  RALRESTDWTypes, RALRESTDWOptions;

type
  /// Mesma forma do OnBeforeGet do TRESTDWIdClientREST
  TRALRESTDWBeforeGet = procedure(var AUrl: string;
                                  var AHeaders: TStringList) of object;

  { TRALRESTDWClient }

  TRALRESTDWClient = class(TRALClient)
  private
    FAccept: StringRAL;
    FAcceptEncoding: StringRAL;
    FAllowCookies: Boolean;
    FAuthenticationOptions: TRALRESTDWAuthOptions;
    FBasicAuth: TRALClientBasicAuth;
    FBinaryRequest: Boolean;
    FCharset: StringRAL;
    FContentEncoding: StringRAL;
    FContentType: StringRAL;
    FCriptOptions: TRALRESTDWCriptOptions;
    FDataCompression: Boolean;
    FDataRoute: StringRAL;
    FEncodedStrings: Boolean;
    FEncoding: TRALRESTDWEncodeSelect;
    FFailOver: Boolean;
    FFailOverConnections: TRALRESTDWConnectionServers;
    FFailOverReplaceDefaults: Boolean;
    FSSLMode: TRALRESTDWSSLMode;
    FSSLVersions: TRALRESTDWSSLVersions;
    FAccessControlAllowOrigin: StringRAL;
    FCertMode: TRALRESTDWSSLMode;
    FMaxAuthRetries: IntegerRAL;
    FPortCert: IntegerRAL;
    FRequestCharset: TRALRESTDWEncodeSelect;
    FVerifyCert: Boolean;
    FOnWork: TRALRESTDWOnWork;
    FOnWorkBegin: TRALRESTDWOnWork;
    FOnWorkEnd: TRALRESTDWOnWorkEnd;
    FHandleRedirects: Boolean;
    FHost: StringRAL;
    FPoolerNotFoundMessage: StringRAL;
    FPort: IntegerRAL;
    FRedirectMaximum: IntegerRAL;
    FProxyOptions: TRALRESTDWProxyOptions;
    FThreadRequest: Boolean;
    FUseSSL: Boolean;
    FAccessTag: StringRAL;
    FWelcomeMessage: StringRAL;
    FOnBeforeGet: TRALRESTDWBeforeGet;

    function GetTypeRequest: TRALRESTDWTypeRequest;
    procedure SetTypeRequest(AValue: TRALRESTDWTypeRequest);
    procedure OptionChanged(ASender: TObject);
    procedure SetAuthenticationOptions(AValue: TRALRESTDWAuthOptions);
    procedure SetCriptOptions(AValue: TRALRESTDWCriptOptions);
    procedure SetDataCompression(AValue: Boolean);
    procedure SetHost(const AValue: StringRAL);
    procedure SetPort(AValue: IntegerRAL);
    procedure SetProxyOptions(AValue: TRALRESTDWProxyOptions);
    procedure SetFailOverConnections(AValue: TRALRESTDWConnectionServers);
    procedure SetFailOver(AValue: Boolean);
    procedure SetUseSSL(AValue: Boolean);

    /// Host + Port + UseSSL sao um endereco so para o RAL
    procedure EscolherEngine;
    function ChamarVerbo(AMetodo: TRALMethod; const AUrl: StringRAL;
                         AHeaders: TStringList; ABody, AResposta: TStream): IntegerRAL;
    /// Separa uma URL absoluta em BaseURL + rota, que e a forma do TRALClient
    function PrepararUrl(const AUrl: StringRAL): StringRAL;
    procedure RebuildBaseURL;
    /// AuthenticationOptions vira o componente que o RAL quer em Authentication
    procedure RebuildAuth;
    procedure RebuildCripto;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Os verbos crus do TRESTDWIdClientREST, com a mesma assinatura: devolvem o
      codigo HTTP e escrevem o corpo em AResposta. Nao sao inertes - vao pelo
      TRALClient -, entao um projeto que usava o RDW so como cliente REST
      continua funcionando sem mudar uma linha.

      AUrl pode ser absoluta (e o que o RDW sempre passava) ou relativa a
      BaseURL; a absoluta e desmontada e a BaseURL volta ao que era no fim. }
    function Get(const AUrl: StringRAL; AHeaders: TStringList;
                 AResposta: TStream): IntegerRAL; reintroduce; overload;
    function Post(const AUrl: StringRAL; AHeaders: TStringList; ABody: TStream;
                  AResposta: TStream): IntegerRAL; reintroduce; overload;
    function Put(const AUrl: StringRAL; AHeaders: TStringList; ABody: TStream;
                 AResposta: TStream): IntegerRAL; reintroduce; overload;
    function Delete(const AUrl: StringRAL; AHeaders: TStringList;
                    AResposta: TStream): IntegerRAL; reintroduce; overload;
  published
    { Chamado antes de cada verbo cru, com a URL e os cabecalhos que vao sair -
      o mesmo gancho do RDW, no mesmo momento. }
    property OnBeforeGet: TRALRESTDWBeforeGet read FOnBeforeGet write FOnBeforeGet;

    { --- o que vira mesmo alguma coisa no RAL --- }
    property Host: StringRAL read FHost write SetHost;
    property Port: IntegerRAL read FPort write SetPort default 8082;
    property UseSSL: Boolean read FUseSSL write SetUseSSL default False;
    property DataCompression: Boolean read FDataCompression
      write SetDataCompression default False;
    property CriptOptions: TRALRESTDWCriptOptions read FCriptOptions
      write SetCriptOptions;
    property AuthenticationOptions: TRALRESTDWAuthOptions
      read FAuthenticationOptions write SetAuthenticationOptions;
    { Inerte de proposito. O TRALClient so ganhou MaxRedirects depois, e este
      pacote tem de instalar num PascalRAL de algumas semanas atras - usar o
      membro novo impediria a instalacao em vez de ajudar. }
    property RedirectMaximum: IntegerRAL read FRedirectMaximum
      write FRedirectMaximum default 0;
    { Os dois viajam como cabecalho, que e onde o servidor deste projeto os
      procura - os mesmos nomes que o RDW usava. }
    property AccessTag: StringRAL read FAccessTag write FAccessTag;
    property WelcomeMessage: StringRAL read FWelcomeMessage
      write FWelcomeMessage;
    { trHttps liga o SSL, que e o mesmo que UseSSL := True }
    property TypeRequest: TRALRESTDWTypeRequest read GetTypeRequest
      write SetTypeRequest default trHttp;
    { RequestTimeOut e ConnectTimeOut nao aparecem aqui de proposito: o RAL ja
      os tem com a mesma grafia a menos de caixa, e o Pascal nao distingue
      caixa - o DFM e o codigo do RDW caem nos do RAL sozinhos. }

    { --- aceitos e inertes ---
      Existem para o formulario abrir e para o codigo que os le continuar
      compilando, e cada um diz ao lado por que nao faz nada. O Delphi nao
      aceita diretiva de hint em propriedade, entao quem avisa em cima do
      projeto e o conversor: ele relata todo inerte que veio com valor
      diferente do padrao. }
    property Accept: StringRAL read FAccept write FAccept;
      // inerte: o RAL negocia o Accept a partir do conteudo
    property AcceptEncoding: StringRAL read FAcceptEncoding write FAcceptEncoding;
      // inerte: o RAL negocia a compressao pelo CompressType
    property ContentEncoding: StringRAL read FContentEncoding write FContentEncoding;
      // inerte: o RAL negocia a compressao pelo CompressType
    property ContentType: StringRAL read FContentType write FContentType;
      // inerte: o RAL define o Content-Type pelo corpo enviado
    property Charset: StringRAL read FCharset write FCharset;
      // inerte: o RAL fala UTF-8 em todas as engines
    property DataRoute: StringRAL read FDataRoute write FDataRoute;
      // inerte: era do pooler de banco do RDW; no RAL use TRALDBModule
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
      // inerte: o RAL fala UTF-8 em todas as engines
    property EncodedStrings: Boolean read FEncodedStrings write FEncodedStrings
      default True;
      // inerte: o RAL escolhe a codificacao do corpo sozinho
    property ThreadRequest: Boolean read FThreadRequest write FThreadRequest
      default False;
      // inerte: no RAL a chamada assincrona e escolhida por metodo
    property AllowCookies: Boolean read FAllowCookies write FAllowCookies
      default False;
      // inerte: o RAL guarda cookie por sessao, sem chave para desligar
    property HandleRedirects: Boolean read FHandleRedirects write FHandleRedirects
      default False;
      // inerte: o RAL segue redirecionamento ate MaxRedirects
    property BinaryRequest: Boolean read FBinaryRequest write FBinaryRequest
      default False;
      // inerte: o corpo do RAL ja vai binario quando precisa
    { O BaseURL do TRALClient e uma lista, e o RAL passa para a proxima linha
      quando o transporte falha: e failover, e e nele que a lista do RDW entra. }
    property FailOver: Boolean read FFailOver write SetFailOver default False;
    property FailOverConnections: TRALRESTDWConnectionServers
      read FFailOverConnections write SetFailOverConnections;
    property FailOverReplaceDefaults: Boolean read FFailOverReplaceDefaults
      write FFailOverReplaceDefaults default False;
      // inerte
    property SSLVersions: TRALRESTDWSSLVersions read FSSLVersions
      write FSSLVersions default [];
      // inerte: no RAL a versao de TLS e do motor, em SSL.SSLOptions
    property SSLMode: TRALRESTDWSSLMode read FSSLMode write FSSLMode
      default sslmUnassigned;
      // inerte: idem
    property CertMode: TRALRESTDWSSLMode read FCertMode write FCertMode
      default sslmUnassigned;
      // inerte: idem
    property VerifyCert: Boolean read FVerifyCert write FVerifyCert default False;
      // inerte: quem confere o certificado no RAL e o OnValidateServerCert
    property PortCert: IntegerRAL read FPortCert write FPortCert default 0;
      // inerte: o RAL usa a porta da BaseURL para tudo
    property MaxAuthRetries: IntegerRAL read FMaxAuthRetries
      write FMaxAuthRetries default 0;
      // inerte: o RAL nao repete a autenticacao sozinho
    property RequestCharset: TRALRESTDWEncodeSelect read FRequestCharset
      write FRequestCharset default esUtf8;
      // inerte: o Charset do TRALClient vale para pedido e resposta
    property AccessControlAllowOrigin: StringRAL read FAccessControlAllowOrigin
      write FAccessControlAllowOrigin;
      // inerte: CORS e coisa de servidor
    property OnWork: TRALRESTDWOnWork read FOnWork write FOnWork;
      // inerte: o TRALClient nao publica progresso de transferencia
    property OnWorkBegin: TRALRESTDWOnWork read FOnWorkBegin write FOnWorkBegin;
      // inerte: idem
    property OnWorkEnd: TRALRESTDWOnWorkEnd read FOnWorkEnd write FOnWorkEnd;
      // inerte: idem
    property PoolerNotFoundMessage: StringRAL read FPoolerNotFoundMessage
      write FPoolerNotFoundMessage;
      // inerte: a mensagem de rota inexistente vem do servidor
    property ProxyOptions: TRALRESTDWProxyOptions read FProxyOptions
      write SetProxyOptions;
      // inerte: o RAL nao atravessa proxy
  end;

implementation

{ TRALRESTDWClient }

constructor TRALRESTDWClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FHost := 'localhost';
  FPort := 8082;
  FUseSSL := False;
  FEncoding := esUtf8;
  FRequestCharset := esUtf8;
  FEncodedStrings := True;
  FCharset := 'utf8';

  FAuthenticationOptions := TRALRESTDWAuthOptions.Create;
  FAuthenticationOptions.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;

  FCriptOptions := TRALRESTDWCriptOptions.Create;
  FCriptOptions.OnChange := {$IFDEF FPC}@{$ENDIF}OptionChanged;

  FProxyOptions := TRALRESTDWProxyOptions.Create;
  FFailOverConnections := TRALRESTDWConnectionServers.Create(Self);

  EscolherEngine;
  RebuildBaseURL;
end;

{ O DFM do RDW nao tem EngineType para o conversor aproveitar, e o TRALClient
  nasce sem nenhuma - sem escolher aqui, a primeira chamada falharia sem dizer
  por que. Indy na frente porque e de onde quem migra esta vindo. }
procedure TRALRESTDWClient.EscolherEngine;
var
  vLista: TStringList;
begin
  if EngineType <> '' then
    Exit;

  vLista := TStringList.Create;
  try
    GetEngineList(vLista);
    if vLista.IndexOf('Indy') >= 0 then
      EngineType := 'Indy'
    else if vLista.Count > 0 then
      EngineType := vLista[0];
  finally
    FreeAndNil(vLista);
  end;
end;

destructor TRALRESTDWClient.Destroy;
begin
  FreeAndNil(FFailOverConnections);
  FreeAndNil(FProxyOptions);
  FreeAndNil(FCriptOptions);
  FreeAndNil(FAuthenticationOptions);
  // FBasicAuth pertence a este componente: o Owner o destroi
  inherited Destroy;
end;

procedure TRALRESTDWClient.Loaded;
begin
  inherited Loaded;
  { o DFM grava Host, Port e UseSSL em qualquer ordem, e a autenticacao chega em
    duas propriedades separadas - so depois de tudo lido e que da para montar }
  RebuildBaseURL;
  RebuildAuth;
  RebuildCripto;
end;

procedure TRALRESTDWClient.OptionChanged(ASender: TObject);
begin
  if csLoading in ComponentState then
    Exit;

  if ASender = FCriptOptions then
    RebuildCripto
  else
    RebuildAuth;
end;

procedure TRALRESTDWClient.RebuildBaseURL;
begin
  RALRESTDWApplyBaseURL(BaseURL, FUseSSL, FHost, FPort, FFailOver,
                        FFailOverConnections);
end;

procedure TRALRESTDWClient.RebuildAuth;
begin
  RALRESTDWApplyClientAuth(Self, FAuthenticationOptions, FBasicAuth);
end;

procedure TRALRESTDWClient.RebuildCripto;
begin
  RALRESTDWApplyCripto(FCriptOptions, CriptoOptions);
end;

procedure TRALRESTDWClient.SetHost(const AValue: StringRAL);
begin
  if FHost = AValue then
    Exit;

  FHost := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWClient.SetPort(AValue: IntegerRAL);
begin
  if FPort = AValue then
    Exit;

  FPort := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWClient.SetUseSSL(AValue: Boolean);
begin
  if FUseSSL = AValue then
    Exit;

  FUseSSL := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWClient.SetDataCompression(AValue: Boolean);
begin
  FDataCompression := AValue;
  if AValue then
    CompressType := ctGZip
  else
    CompressType := ctNone;
end;

procedure TRALRESTDWClient.SetAuthenticationOptions(AValue: TRALRESTDWAuthOptions);
begin
  FAuthenticationOptions.Assign(AValue);
end;

procedure TRALRESTDWClient.SetCriptOptions(AValue: TRALRESTDWCriptOptions);
begin
  FCriptOptions.Assign(AValue);
end;

{ ---------------------------------------------------- os verbos crus do RDW }

function TRALRESTDWClient.PrepararUrl(const AUrl: StringRAL): StringRAL;
var
  vTexto, vEsquema: string;
  vPos: Integer;
begin
  vTexto := string(AUrl);
  vPos := Pos('://', vTexto);

  // relativa: a BaseURL do componente ja responde por ela
  if vPos = 0 then
    Exit(AUrl);

  vEsquema := Copy(vTexto, 1, vPos + 2);
  vTexto := Copy(vTexto, vPos + 3, MaxInt);

  vPos := Pos('/', vTexto);
  if vPos = 0 then
  begin
    BaseURL.Text := vEsquema + vTexto;
    Exit('/');
  end;

  BaseURL.Text := vEsquema + Copy(vTexto, 1, vPos - 1);
  Result := StringRAL(Copy(vTexto, vPos, MaxInt));
end;

function TRALRESTDWClient.ChamarVerbo(AMetodo: TRALMethod; const AUrl: StringRAL;
  AHeaders: TStringList; ABody, AResposta: TStream): IntegerRAL;
var
  vResp: TRALResponse;
  vUrl, vLinha: string;
  vRota: StringRAL;
  vBaseAntes: string;
  vInt1, vPos: Integer;
  vCorpo: TStringStream;
begin
  Result := 0;
  vUrl := string(AUrl);

  if Assigned(FOnBeforeGet) then
    FOnBeforeGet(vUrl, AHeaders);

  { a URL absoluta sobrescreve a BaseURL enquanto a chamada dura; devolver o
    valor no fim e o que deixa o componente utilizavel para as duas formas }
  vBaseAntes := BaseURL.Text;
  vResp := nil;
  try
    vRota := PrepararUrl(StringRAL(vUrl));

    Request.Clear;
    if AHeaders <> nil then
    begin
      for vInt1 := 0 to AHeaders.Count - 1 do
      begin
        vLinha := AHeaders[vInt1];
        vPos := Pos(':', vLinha);
        if vPos = 0 then
          Continue;
        Request.AddHeader(StringRAL(Trim(Copy(vLinha, 1, vPos - 1))),
                          StringRAL(Trim(Copy(vLinha, vPos + 1, MaxInt))));
      end;
    end;

    if (ABody <> nil) and (ABody.Size > 0) then
    begin
      ABody.Position := 0;
      vCorpo := TStringStream.Create('');
      try
        vCorpo.CopyFrom(ABody, ABody.Size);
        Request.AddBody(StringRAL(vCorpo.DataString));
      finally
        FreeAndNil(vCorpo);
      end;
    end;

    vResp := ExecuteSingle(vRota, AMetodo);
    if vResp = nil then
      Exit;

    Result := vResp.StatusCode;
    if (AResposta <> nil) and (vResp.ResponseStream <> nil) then
    begin
      vResp.ResponseStream.Position := 0;
      AResposta.CopyFrom(vResp.ResponseStream, vResp.ResponseStream.Size);
      AResposta.Position := 0;
    end;
  finally
    BaseURL.Text := vBaseAntes;
  end;
end;

function TRALRESTDWClient.Get(const AUrl: StringRAL; AHeaders: TStringList;
  AResposta: TStream): IntegerRAL;
begin
  Result := ChamarVerbo(amGET, AUrl, AHeaders, nil, AResposta);
end;

function TRALRESTDWClient.Post(const AUrl: StringRAL; AHeaders: TStringList;
  ABody: TStream; AResposta: TStream): IntegerRAL;
begin
  Result := ChamarVerbo(amPOST, AUrl, AHeaders, ABody, AResposta);
end;

function TRALRESTDWClient.Put(const AUrl: StringRAL; AHeaders: TStringList;
  ABody: TStream; AResposta: TStream): IntegerRAL;
begin
  Result := ChamarVerbo(amPUT, AUrl, AHeaders, ABody, AResposta);
end;

function TRALRESTDWClient.Delete(const AUrl: StringRAL; AHeaders: TStringList;
  AResposta: TStream): IntegerRAL;
begin
  Result := ChamarVerbo(amDELETE, AUrl, AHeaders, nil, AResposta);
end;

procedure TRALRESTDWClient.SetFailOverConnections(
  AValue: TRALRESTDWConnectionServers);
begin
  FFailOverConnections.Assign(AValue);
  RebuildBaseURL;
end;

procedure TRALRESTDWClient.SetFailOver(AValue: Boolean);
begin
  if FFailOver = AValue then
    Exit;
  FFailOver := AValue;
  RebuildBaseURL;
end;

procedure TRALRESTDWClient.SetProxyOptions(AValue: TRALRESTDWProxyOptions);
begin
  FProxyOptions.Assign(AValue);
end;

function TRALRESTDWClient.GetTypeRequest: TRALRESTDWTypeRequest;
begin
  if FUseSSL then
    Result := trHttps
  else
    Result := trHttp;
end;

procedure TRALRESTDWClient.SetTypeRequest(AValue: TRALRESTDWTypeRequest);
begin
  UseSSL := AValue = trHttps;
end;

end.
