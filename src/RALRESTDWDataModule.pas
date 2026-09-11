/// The DataModule a migrated RDW server keeps descending from.
///
/// In RDW the server DataModule descends from TServerMethodDataModule, and its
/// .dfm stores properties that plain TDataModule does not have - Encoding,
/// QueuedRequest, ClientInfo. Streaming stops at the first unknown property and
/// takes the whole form with it, so without an ancestor that publishes them the
/// converted project raises on the first create.
///
/// That is the whole reason this class exists: it publishes the surface so the
/// .dfm streams untouched and the developer's own code still compiles. What it
/// does *not* do is pretend to implement RDW - only the members with a real
/// counterpart in RAL do anything, and the ones that do not say so here and in
/// the converter's report.
unit RALRESTDWDataModule;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  RALTypes, RALRequest,
  RALRESTDWTypes, RALRESTDWParams, RALRESTDWEvents, RALRESTDWMassive;

type
  { TRALRESTDWClientInfo }

  /// Who is on the other end of the current request.
  TRALRESTDWClientInfo = class(TPersistent)
  private
    FBaseRequest: StringRAL;
    FIP: StringRAL;
    FPort: IntegerRAL;
    FToken: StringRAL;
    FUserAgent: StringRAL;
  public
    procedure Assign(ASource: TPersistent); override;
    /// Same name and order as RDW, for code that filled it by hand
    procedure SetClientInfo(const AIP, AUserAgent, ABaseRequest: StringRAL;
                            APort: IntegerRAL);
    /// Fills from the request RAL is answering
    procedure LoadFrom(ARequest: TRALRequest);
  published
    property BaseRequest: StringRAL read FBaseRequest;
    property ip: StringRAL read FIP;
    property UserAgent: StringRAL read FUserAgent;
    property port: IntegerRAL read FPort;
    property Token: StringRAL read FToken;
  end;

  /// Same signature as RDW's TUserBasicAuth, so an existing handler still binds
  TRALRESTDWUserBasicAuth = procedure(Welcomemsg, AccessTag, Username,
                                      Password: StringRAL;
                                      var Params: TRALRESTDWParams;
                                      var ErrorCode: IntegerRAL;
                                      var ErrorMessage: StringRAL;
                                      var Accept: Boolean) of object;

  { TRALRESTDWDataModule }

  TRALRESTDWDataModule = class(TDataModule)
  private
    FClientInfo: TRALRESTDWClientInfo;
    FClientWelcomeMessage: StringRAL;
    FEncoding: TRALRESTDWEncodeSelect;
    FQueuedRequest: Boolean;
    FOnReplyEvent: TRALRESTDWReplyEvent;
    FOnUserBasicAuth: TRALRESTDWUserBasicAuth;
    FOnMassiveProcess: TRALRESTDWMassiveProcess;
    FOnAfterMassiveLineProcess: TRALRESTDWMassiveLineProcess;
    FOnMassiveBegin: TRALRESTDWMassiveEvent;
    FOnMassiveAfterStartTransaction: TRALRESTDWMassiveEvent;
    FOnMassiveAfterBeforeCommit: TRALRESTDWMassiveEvent;
    FOnMassiveAfterAfterCommit: TRALRESTDWMassiveEvent;
    FOnMassiveEnd: TRALRESTDWMassiveEvent;

    procedure SetClientInfoProp(AValue: TRALRESTDWClientInfo);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetClientWelcomeMessage(const AValue: StringRAL);
    procedure SetClientInfo(const AIP, AUserAgent, ABaseRequest: StringRAL;
                            APort: IntegerRAL);
  published
    property ClientWelcomeMessage: StringRAL read FClientWelcomeMessage;
    property ClientInfo: TRALRESTDWClientInfo read FClientInfo write SetClientInfoProp;

    { Kept so the .dfm streams. RAL speaks UTF-8 on every engine, which is what
      esUtf8 asked for; the other two are read back and ignored. }
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
    { Kept so the .dfm streams. RDW serialized requests through one queue; RAL
      answers each on its own thread, so there is nothing to switch off. }
    property QueuedRequest: Boolean read FQueuedRequest write FQueuedRequest
      default False;

    { Fallback handler for an event with none of its own. Declared so the .dfm
      streams and the handler keeps compiling - it is not called yet. }
    property OnReplyEvent: TRALRESTDWReplyEvent read FOnReplyEvent write FOnReplyEvent;
    { Os ganchos do massive. Declarados para o .dfm abrir e para o metodo
      continuar compilando; nenhum deles e disparado, porque quem aplica o
      lote e o TRALDBModule, dentro do PascalRAL, e este projeto nao mexe no
      RAL. Ver o cabecalho de RALRESTDWMassive. }
    property OnMassiveProcess: TRALRESTDWMassiveProcess read FOnMassiveProcess
      write FOnMassiveProcess;
    property OnAfterMassiveLineProcess: TRALRESTDWMassiveLineProcess
      read FOnAfterMassiveLineProcess write FOnAfterMassiveLineProcess;
    property OnMassiveBegin: TRALRESTDWMassiveEvent read FOnMassiveBegin
      write FOnMassiveBegin;
    property OnMassiveAfterStartTransaction: TRALRESTDWMassiveEvent
      read FOnMassiveAfterStartTransaction write FOnMassiveAfterStartTransaction;
    property OnMassiveAfterBeforeCommit: TRALRESTDWMassiveEvent
      read FOnMassiveAfterBeforeCommit write FOnMassiveAfterBeforeCommit;
    property OnMassiveAfterAfterCommit: TRALRESTDWMassiveEvent
      read FOnMassiveAfterAfterCommit write FOnMassiveAfterAfterCommit;
    property OnMassiveEnd: TRALRESTDWMassiveEvent read FOnMassiveEnd
      write FOnMassiveEnd;

    { Declared with RDW's exact signature so the .dfm streams and the handler
      keeps compiling - it is not called yet. RAL authenticates before routing,
      where no DataModule instance exists; use TRALServerBasicAuth.OnValidate. }
    property OnUserBasicAuth: TRALRESTDWUserBasicAuth read FOnUserBasicAuth
      write FOnUserBasicAuth;
  end;

implementation

{ TRALRESTDWClientInfo }

procedure TRALRESTDWClientInfo.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWClientInfo;
begin
  if not (ASource is TRALRESTDWClientInfo) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  vSource := TRALRESTDWClientInfo(ASource);
  FBaseRequest := vSource.BaseRequest;
  FIP := vSource.ip;
  FPort := vSource.port;
  FToken := vSource.Token;
  FUserAgent := vSource.UserAgent;
end;

procedure TRALRESTDWClientInfo.SetClientInfo(const AIP, AUserAgent,
  ABaseRequest: StringRAL; APort: IntegerRAL);
begin
  FIP := AIP;
  FUserAgent := AUserAgent;
  FBaseRequest := ABaseRequest;
  FPort := APort;
end;

procedure TRALRESTDWClientInfo.LoadFrom(ARequest: TRALRequest);
begin
  if ARequest = nil then
    Exit;

  FIP := ARequest.ClientInfo.IP;
  FPort := ARequest.ClientInfo.Port;
  FUserAgent := ARequest.ClientInfo.UserAgent;
  FBaseRequest := ARequest.Query;
  FToken := ARequest.Authorization.AuthString;
end;

{ TRALRESTDWDataModule }

constructor TRALRESTDWDataModule.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FClientInfo := TRALRESTDWClientInfo.Create;
  FEncoding := esUtf8;
  FQueuedRequest := False;
end;

destructor TRALRESTDWDataModule.Destroy;
begin
  FreeAndNil(FClientInfo);
  inherited Destroy;
end;

procedure TRALRESTDWDataModule.SetClientInfoProp(AValue: TRALRESTDWClientInfo);
begin
  FClientInfo.Assign(AValue);
end;

procedure TRALRESTDWDataModule.SetClientWelcomeMessage(const AValue: StringRAL);
begin
  FClientWelcomeMessage := AValue;
end;

procedure TRALRESTDWDataModule.SetClientInfo(const AIP, AUserAgent,
  ABaseRequest: StringRAL; APort: IntegerRAL);
begin
  FClientInfo.SetClientInfo(AIP, AUserAgent, ABaseRequest, APort);
end;

end.
