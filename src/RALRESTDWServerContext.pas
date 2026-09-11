/// RDW's ServerContext, the other way it publishes an endpoint.
///
/// `TRESTDWServerEvents` answers under the module's route by event name;
/// `TRESTDWServerContext` answers a *path* and hands the handler the raw
/// content type and body - which is how the RDW demos serve static pages and
/// small custom endpoints from inside the DataModule.
///
/// RAL has the same idea in `TRALRoute`, so each context item becomes one route
/// on the module: the path is the route, `OnReplyRequest` fills the text and
/// the content type, and `OnReplyRequestStream` fills a stream.
unit RALRESTDWServerContext;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  RALTypes, RALConsts, RALServer, RALRoutes, RALRequest, RALResponse,
  RALMIMETypes, RALTools,
  RALRESTDWTypes, RALRESTDWParams;

type
  { Mesmas assinaturas do RDW: o handler recebe os params e devolve o conteudo
    e o tipo. TRequestType aqui e o TRALMethod, como em todo o resto. }
  TRALRESTDWReplyRequest = procedure(const AParams: TRALRESTDWParams;
                                     var AContentType, AResult: string;
                                     const ARequestType: TRALMethod) of object;
  TRALRESTDWReplyRequestStream = procedure(const AParams: TRALRESTDWParams;
                                           var AContentType: string;
                                           const AResult: TStream;
                                           const ARequestType: TRALMethod) of object;

  { TRALRESTDWContext }

  TRALRESTDWContext = class(TCollectionItem)
  private
    FActive: Boolean;
    FContextName: StringRAL;
    FDefaultContentType: StringRAL;
    FNeedAuthorization: Boolean;
    FOnReplyRequest: TRALRESTDWReplyRequest;
    FOnReplyRequestStream: TRALRESTDWReplyRequestStream;
  protected
    function GetDisplayName: string; override;
    procedure SetDisplayName(const AValue: string); override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(ASource: TPersistent); override;

    /// Responde uma requisicao, no formato que o handler pedir
    procedure Responder(ARequest: TRALRequest; AResponse: TRALResponse);
  published
    property Name: string read GetDisplayName write SetDisplayName;
    property ContextName: StringRAL read FContextName write FContextName;
    property Active: Boolean read FActive write FActive default True;
    property DefaultContentType: StringRAL read FDefaultContentType
      write FDefaultContentType;
    property NeedAuthorization: Boolean read FNeedAuthorization
      write FNeedAuthorization default False;
    property OnReplyRequest: TRALRESTDWReplyRequest read FOnReplyRequest
      write FOnReplyRequest;
    property OnReplyRequestStream: TRALRESTDWReplyRequestStream
      read FOnReplyRequestStream write FOnReplyRequestStream;
  end;

  { TRALRESTDWContextList }

  TRALRESTDWContextList = class(TCollection)
  private
    FOwner: TPersistent;

    function GetItem(AIndex: Integer): TRALRESTDWContext;
    procedure SetItem(AIndex: Integer; AValue: TRALRESTDWContext);
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TPersistent);

    function Add: TRALRESTDWContext; reintroduce;
    /// nil quando nao houver contexto com esse nome
    function FindContext(const AName: StringRAL): TRALRESTDWContext;

    property Items[AIndex: Integer]: TRALRESTDWContext read GetItem
      write SetItem; default;
  end;

  { TRALRESTDWServerContext }

  TRALRESTDWServerContext = class(TComponent)
  private
    FContextList: TRALRESTDWContextList;
    FIgnoreInvalidParams: Boolean;

    procedure SetContextList(AValue: TRALRESTDWContextList);
    /// Uma rota so para todos os contextos; acha o certo pelo caminho pedido
    procedure ReplyContexto(ARequest: TRALRequest; AResponse: TRALResponse);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Publica um contexto por rota no servidor. Chamado pelo pooler quando ele
      descobre o DataModule, do mesmo jeito que faz com os ServerEvents. }
    procedure PublicarRotas(AServer: TRALServer; const ADomain: StringRAL);
  published
    property ContextList: TRALRESTDWContextList read FContextList
      write SetContextList;
    property IgnoreInvalidParams: Boolean read FIgnoreInvalidParams
      write FIgnoreInvalidParams default False;
  end;

implementation

{ TRALRESTDWContext }

constructor TRALRESTDWContext.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FActive := True;
  FNeedAuthorization := False;
  FDefaultContentType := rctTEXTHTML;
end;

function TRALRESTDWContext.GetDisplayName: string;
begin
  Result := string(FContextName);
  if Result = '' then
    Result := inherited GetDisplayName;
end;

procedure TRALRESTDWContext.SetDisplayName(const AValue: string);
begin
  FContextName := StringRAL(AValue);
  inherited SetDisplayName(AValue);
end;

procedure TRALRESTDWContext.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWContext;
begin
  if not (ASource is TRALRESTDWContext) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  vSource := TRALRESTDWContext(ASource);
  FActive := vSource.Active;
  FContextName := vSource.ContextName;
  FDefaultContentType := vSource.DefaultContentType;
  FNeedAuthorization := vSource.NeedAuthorization;
  FOnReplyRequest := vSource.OnReplyRequest;
  FOnReplyRequestStream := vSource.OnReplyRequestStream;
end;

procedure TRALRESTDWContext.Responder(ARequest: TRALRequest;
  AResponse: TRALResponse);
var
  vParams: TRALRESTDWParams;
  vTipo, vTexto: string;
  vStream: TMemoryStream;
begin
  vParams := TRALRESTDWParams.Create;
  try
    vParams.AssignRequest(ARequest);
    vTipo := string(FDefaultContentType);

    if Assigned(FOnReplyRequestStream) then
    begin
      vStream := TMemoryStream.Create;
      try
        FOnReplyRequestStream(vParams, vTipo, vStream, ARequest.Method);
        vStream.Position := 0;
        AResponse.AddFile(vStream);
        AResponse.ContentType := StringRAL(vTipo);
        AResponse.StatusCode := HTTP_OK;
      finally
        FreeAndNil(vStream);
      end;
      Exit;
    end;

    if not Assigned(FOnReplyRequest) then
    begin
      AResponse.Answer(HTTP_NotFound);
      Exit;
    end;

    vTexto := '';
    FOnReplyRequest(vParams, vTipo, vTexto, ARequest.Method);
    AResponse.Answer(HTTP_OK, StringRAL(vTexto), StringRAL(vTipo));
  finally
    FreeAndNil(vParams);
  end;
end;

{ TRALRESTDWContextList }

constructor TRALRESTDWContextList.Create(AOwner: TPersistent);
begin
  inherited Create(TRALRESTDWContext);
  FOwner := AOwner;
end;

function TRALRESTDWContextList.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TRALRESTDWContextList.GetItem(AIndex: Integer): TRALRESTDWContext;
begin
  Result := TRALRESTDWContext(inherited Items[AIndex]);
end;

procedure TRALRESTDWContextList.SetItem(AIndex: Integer; AValue: TRALRESTDWContext);
begin
  inherited Items[AIndex] := AValue;
end;

function TRALRESTDWContextList.Add: TRALRESTDWContext;
begin
  Result := TRALRESTDWContext(inherited Add);
end;

function TRALRESTDWContextList.FindContext(
  const AName: StringRAL): TRALRESTDWContext;
var
  vInt1: Integer;
begin
  Result := nil;
  for vInt1 := 0 to Count - 1 do
    if SameText(string(Items[vInt1].ContextName), string(AName)) then
      Exit(Items[vInt1]);
end;

{ TRALRESTDWServerContext }

procedure TRALRESTDWServerContext.ReplyContexto(ARequest: TRALRequest;
  AResponse: TRALResponse);
var
  vCaminho: StringRAL;
  vPos: IntegerRAL;
  vCtx: TRALRESTDWContext;
begin
  { o ultimo trecho do caminho e o nome do contexto - e assim que o RDW
    resolvia, e e o que mantem as URLs do projeto migrado iguais }
  vCaminho := FixRoute(ARequest.Query);
  vPos := LastDelimiter('/', string(vCaminho));
  if vPos > 0 then
    vCaminho := Copy(vCaminho, vPos + 1, MaxInt);

  vCtx := FContextList.FindContext(vCaminho);
  if (vCtx = nil) or (not vCtx.Active) then
  begin
    AResponse.Answer(HTTP_NotFound);
    Exit;
  end;

  vCtx.Responder(ARequest, AResponse);
end;

constructor TRALRESTDWServerContext.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FContextList := TRALRESTDWContextList.Create(Self);
  FIgnoreInvalidParams := False;
end;

destructor TRALRESTDWServerContext.Destroy;
begin
  FreeAndNil(FContextList);
  inherited Destroy;
end;

procedure TRALRESTDWServerContext.SetContextList(AValue: TRALRESTDWContextList);
begin
  FContextList.Assign(AValue);
end;

procedure TRALRESTDWServerContext.PublicarRotas(AServer: TRALServer;
  const ADomain: StringRAL);
var
  vInt1: Integer;
  vCtx: TRALRESTDWContext;
begin
  if AServer = nil then
    Exit;

  for vInt1 := 0 to FContextList.Count - 1 do
  begin
    vCtx := FContextList[vInt1];
    if (not vCtx.Active) or (Trim(string(vCtx.ContextName)) = '') then
      Continue;

    { Uma rota por contexto, todas caindo no mesmo metodo: quem escolhe o item
      e o caminho da requisicao, entao mexer na colecao depois nao deixa
      nenhuma rota apontando para um item que sumiu. }
    AServer.CreateRoute(ADomain + '/' + vCtx.ContextName,
                        {$IFDEF FPC}@{$ENDIF}ReplyContexto);
  end;
end;

end.
