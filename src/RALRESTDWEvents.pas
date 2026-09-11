/// The event collection: one item per RDW event, with its params and handlers.
unit RALRESTDWEvents;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  RALTypes, RALRESTDWParams, RALRESTDWParamsMethods, RALRequest, RALResponse,
  RALConsts, RALTools, RALParams, RALRESTDWTypes, RALMimeTypes;

type
  { Handler signatures.

    They carry `var` on the params exactly like REST Dataware, so an existing
    handler only has to have its parameter type renamed - see RALRESTDWCompat,
    which aliases even that away. }
  { AResult e String, e nao StringRAL, de proposito: StringRAL e UTF8String, o
    handler do RDW 1.4.3 declara String, e o DFM liga os dois pelo nome sem
    conferir a assinatura. Um byte por caractere de um lado e dois do outro
    nao daria erro de compilacao - daria texto corrompido na primeira
    chamada. }
  {$IFDEF RDW143}
  TRALRESTDWReplyEvent = procedure(var AParams: TRALRESTDWParams;
                                   var AResult: string) of object;
  TRALRESTDWReplyEventByType = procedure(var AParams: TRALRESTDWParams;
                                         var AResult: string;
                                         const ARequestType: TRALMethod;
                                         var AStatusCode: IntegerRAL;
                                         ARequestHeader: TStringList) of object;
  {$ELSE}
  TRALRESTDWReplyEvent = procedure(var AParams: TRALRESTDWParams;
                                   const AResult: TStringList) of object;
  TRALRESTDWReplyEventByType = procedure(var AParams: TRALRESTDWParams;
                                         const AResult: TStringList;
                                         const ARequestType: TRALMethod;
                                         var AStatusCode: IntegerRAL;
                                         ARequestHeader: TStringList) of object;
  {$ENDIF}

  /// Per-event authorization, fired before the handler
  TRALRESTDWAuthRequest = procedure(const AParams: TRALRESTDWParams;
                                    var ARejected: Boolean;
                                    var AResultError: string;
                                    var AStatusCode: IntegerRAL;
                                    ARequestHeader: TStringList) of object;
  /// Same shape as RDW's TObjectExecute
  TRALRESTDWObjectExecute = procedure(const ASelf: TCollectionItem) of object;

  { TRALRESTDWRoute }

  /// One HTTP verb of an event
  TRALRESTDWRoute = class(TPersistent)
  private
    FActive: Boolean;
    FNeedAuthorization: Boolean;
  public
    constructor Create(AActive: Boolean = False);
    procedure Assign(ASource: TPersistent); override;
  published
    property Active: Boolean read FActive write FActive;
    property NeedAuthorization: Boolean read FNeedAuthorization write FNeedAuthorization;
  end;

  { TRALRESTDWRoutes }

  /// Which verbs the event answers, in the shape RDW exposes. It is translated
  /// into the RAL route's AllowedMethods/SkipAuthMethods when the route is built.
  TRALRESTDWRoutes = class(TPersistent)
  private
    FAll: TRALRESTDWRoute;
    FGet: TRALRESTDWRoute;
    FPost: TRALRESTDWRoute;
    FPut: TRALRESTDWRoute;
    FPatch: TRALRESTDWRoute;
    FDelete: TRALRESTDWRoute;
    FOption: TRALRESTDWRoute;

    function RouteOf(AMethod: TRALMethod): TRALRESTDWRoute;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Assign(ASource: TPersistent); override;

    function RouteIsActive(AMethod: TRALMethod): Boolean;
    function RouteNeedAuthorization(AMethod: TRALMethod): Boolean;
    /// The RAL method set this event answers
    function AllowedMethods: TRALMethods;
    /// The RAL method set that bypasses authentication
    function SkipAuthMethods: TRALMethods;
  published
    property All: TRALRESTDWRoute read FAll write FAll;
    property Get: TRALRESTDWRoute read FGet write FGet;
    property Post: TRALRESTDWRoute read FPost write FPost;
    property Put: TRALRESTDWRoute read FPut write FPut;
    property Patch: TRALRESTDWRoute read FPatch write FPatch;
    property Delete: TRALRESTDWRoute read FDelete write FDelete;
    property Option: TRALRESTDWRoute read FOption write FOption;
  end;

  { TRALRESTDWEventBase }

  TRALRESTDWEventBase = class(TCollectionItem)
  private
    FBaseURL: StringRAL;
    FDefaultContentType: StringRAL;
    FDescription: TStrings;
    FEventName: StringRAL;
    FParams: TRALRESTDWParamsMethods;
    FRoutes: TRALRESTDWRoutes;
    FDataMode: TRALRESTDWDataMode;
    FOnlyPreDefinedParams: boolean;
    FCallbackEvent: boolean;
  protected
    function GetDisplayName: string; override;
    procedure SetDisplayName(const AValue: string); override;
    procedure SetParams(const Value: TRALRESTDWParamsMethods);
    procedure SetRoutes(const Value: TRALRESTDWRoutes);

    procedure AssignTo(ADest: TPersistent); override;

    procedure SetDescription(AValue: TStrings);
    procedure SetBaseURL(const AValue: StringRAL);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;

    function GetNamePath: string; override;
    /// BaseURL + '/' + EventName, relative to the module's Domain
    function GetRoute: StringRAL;
  published
    property BaseURL: StringRAL read FBaseURL write SetBaseURL;
    property DefaultContentType: StringRAL read FDefaultContentType write FDefaultContentType;
    property Description: TStrings read FDescription write SetDescription;
    property EventName: StringRAL read FEventName write FEventName;
    /// RDW alias of EventName
    property Name: string read GetDisplayName write SetDisplayName;
    property Params: TRALRESTDWParamsMethods read FParams write SetParams;
    property Routes: TRALRESTDWRoutes read FRoutes write SetRoutes;
    property DataMode: TRALRESTDWDataMode read FDataMode write FDataMode;
    property CallbackEvent: boolean read FCallbackEvent write FCallbackEvent;
    property OnlyPreDefinedParams: Boolean read FOnlyPreDefinedParams write FOnlyPreDefinedParams;
  end;

  { TRALRESTDWEventServer }

  TRALRESTDWEventServer = class(TRALRESTDWEventBase)
  private
    FOnReplyEvent: TRALRESTDWReplyEvent;
    FOnReplyEventByType: TRALRESTDWReplyEventByType;
    FOnAuthRequest: TRALRESTDWAuthRequest;
    FOnBeforeExecute: TRALRESTDWObjectExecute;
  protected
    procedure AssignTo(ADest: TPersistent); override;

    /// Names a request body param that was not declared in Params, or '' when
    /// they all were. The two routing params are never counted.
    function UndeclaredParam(ARequest: TRALRequest): StringRAL;
  public
    procedure ReplyEvent(ARequest : TRALRequest; AResponse: TRALResponse;
                         AModule: TComponent = nil;
                         AIgnoreInvalidParams: boolean = True);
  published
    property OnReplyEvent: TRALRESTDWReplyEvent read FOnReplyEvent write FOnReplyEvent;
    property OnReplyEventByType: TRALRESTDWReplyEventByType read FOnReplyEventByType write FOnReplyEventByType;
    property OnAuthRequest: TRALRESTDWAuthRequest read FOnAuthRequest write FOnAuthRequest;
    property OnBeforeExecute: TRALRESTDWObjectExecute read FOnBeforeExecute write FOnBeforeExecute;
  end;

  { TRALRESTDWEventList }

  TRALRESTDWEventList = Class(TOwnedCollection)
  protected
    function GetEventName(AName : StringRAL): TRALRESTDWEventBase;
    function GetEvent(AIndex : IntegerRAL): TRALRESTDWEventBase;
  public
    { The item class is a parameter now. It used to be picked by comparing the
      owner's class *name* with a literal, so a descendant of the ServerEvents
      component silently got items with no handlers. }
    constructor Create(AOwner: TPersistent;
                       AItemClass: TCollectionItemClass = nil);

    /// Declares an event in code, the RDW AddEvent shape
    function AddEvent(const AEventName: StringRAL;
                      const ABaseURL: StringRAL = '/';
                      const AContentType: StringRAL = '';
                      ADataMode: TRALRESTDWDataMode = dmRAW): TRALRESTDWEventBase;

    property Items[AIndex : IntegerRAL] : TRALRESTDWEventBase read GetEvent; default;
    property EventByName[AName : StringRAL] : TRALRESTDWEventBase read GetEventName;
  end;

implementation

{ TRALRESTDWRoute }

constructor TRALRESTDWRoute.Create(AActive: Boolean);
begin
  inherited Create;
  FActive := AActive;
  FNeedAuthorization := False;
end;

procedure TRALRESTDWRoute.Assign(ASource: TPersistent);
begin
  if ASource.InheritsFrom(TRALRESTDWRoute) then
  begin
    FActive := TRALRESTDWRoute(ASource).Active;
    FNeedAuthorization := TRALRESTDWRoute(ASource).NeedAuthorization;
  end
  else
  begin
    inherited Assign(ASource);
  end;
end;

{ TRALRESTDWRoutes }

constructor TRALRESTDWRoutes.Create;
begin
  inherited Create;
  // como no RDW: por padrao o evento responde a qualquer verbo
  FAll := TRALRESTDWRoute.Create(True);
  FGet := TRALRESTDWRoute.Create;
  FPost := TRALRESTDWRoute.Create;
  FPut := TRALRESTDWRoute.Create;
  FPatch := TRALRESTDWRoute.Create;
  FDelete := TRALRESTDWRoute.Create;
  FOption := TRALRESTDWRoute.Create;
end;

destructor TRALRESTDWRoutes.Destroy;
begin
  FreeAndNil(FAll);
  FreeAndNil(FGet);
  FreeAndNil(FPost);
  FreeAndNil(FPut);
  FreeAndNil(FPatch);
  FreeAndNil(FDelete);
  FreeAndNil(FOption);
  inherited Destroy;
end;

procedure TRALRESTDWRoutes.Assign(ASource: TPersistent);
var
  vSrc: TRALRESTDWRoutes;
begin
  if ASource.InheritsFrom(TRALRESTDWRoutes) then
  begin
    vSrc := TRALRESTDWRoutes(ASource);
    FAll.Assign(vSrc.All);
    FGet.Assign(vSrc.Get);
    FPost.Assign(vSrc.Post);
    FPut.Assign(vSrc.Put);
    FPatch.Assign(vSrc.Patch);
    FDelete.Assign(vSrc.Delete);
    FOption.Assign(vSrc.Option);
  end
  else
  begin
    inherited Assign(ASource);
  end;
end;

function TRALRESTDWRoutes.RouteOf(AMethod: TRALMethod): TRALRESTDWRoute;
begin
  case AMethod of
    amGET     : Result := FGet;
    amPOST    : Result := FPost;
    amPUT     : Result := FPut;
    amPATCH   : Result := FPatch;
    amDELETE  : Result := FDelete;
    amOPTIONS : Result := FOption;
    else
      Result := FAll;
  end;
end;

function TRALRESTDWRoutes.RouteIsActive(AMethod: TRALMethod): Boolean;
begin
  Result := FAll.Active or RouteOf(AMethod).Active;
end;

function TRALRESTDWRoutes.RouteNeedAuthorization(AMethod: TRALMethod): Boolean;
begin
  if FAll.Active then
    Result := FAll.NeedAuthorization or RouteOf(AMethod).NeedAuthorization
  else
    Result := RouteOf(AMethod).NeedAuthorization;
end;

function TRALRESTDWRoutes.AllowedMethods: TRALMethods;
begin
  if FAll.Active then
  begin
    Result := [amALL];
    Exit;
  end;

  Result := [];
  if FGet.Active then    Result := Result + [amGET];
  if FPost.Active then   Result := Result + [amPOST];
  if FPut.Active then    Result := Result + [amPUT];
  if FPatch.Active then  Result := Result + [amPATCH];
  if FDelete.Active then Result := Result + [amDELETE];
  // OPTIONS tem que passar sempre, senao o preflight de CORS morre na rota
  Result := Result + [amOPTIONS];
end;

function TRALRESTDWRoutes.SkipAuthMethods: TRALMethods;
var
  vMethod: TRALMethod;
begin
  { RDW diz o que PRECISA de autorizacao; o RAL diz o que DISPENSA. A traducao
    e o complemento, dentro do que o evento atende. }
  Result := [];
  for vMethod := amGET to amDELETE do
    if RouteIsActive(vMethod) and (not RouteNeedAuthorization(vMethod)) then
      Result := Result + [vMethod];

  if (Result <> []) and (not RouteNeedAuthorization(amOPTIONS)) then
    Result := Result + [amOPTIONS];
end;

{ TRALRESTDWEventBase }

constructor TRALRESTDWEventBase.Create(ACollection: TCollection);
begin
  inherited;
  FBaseURL := '/';
  FDefaultContentType := rctAPPLICATIONJSON;
  FDescription := TStringList.Create;
  FEventName := 'event' + IntToStr(Index);
  FParams := TRALRESTDWParamsMethods.Create(Self);
  FRoutes := TRALRESTDWRoutes.Create;
  FDataMode := dmRAW;
  FOnlyPreDefinedParams := False;
  FCallbackEvent := False;
end;

destructor TRALRESTDWEventBase.Destroy;
begin
  FreeAndNil(FDescription);
  FreeAndNil(FParams);
  FreeAndNil(FRoutes);
  inherited;
end;

procedure TRALRESTDWEventBase.SetBaseURL(const AValue: StringRAL);
begin
  FBaseURL := FixRoute(AValue);
end;

procedure TRALRESTDWEventBase.SetDescription(AValue: TStrings);
begin
  FDescription.Assign(AValue);
end;

procedure TRALRESTDWEventBase.SetParams(const Value: TRALRESTDWParamsMethods);
begin
  // trocar o ponteiro vazava a colecao antiga e deixava duas donas da nova
  FParams.Assign(Value);
end;

procedure TRALRESTDWEventBase.SetRoutes(const Value: TRALRESTDWRoutes);
begin
  FRoutes.Assign(Value);
end;

function TRALRESTDWEventBase.GetRoute: StringRAL;
begin
  Result := FixRoute(FBaseURL + '/' + FEventName);
end;

function TRALRESTDWEventBase.GetDisplayName: string;
begin
  Result := FEventName;
  inherited;
end;

function TRALRESTDWEventBase.GetNamePath: string;
var
  vName: StringRAL;
begin
  Result := '';
  if Self = nil then
    Exit;

  vName := Collection.GetNamePath;
  Result := vName + '_' + FEventName;
end;

procedure TRALRESTDWEventBase.SetDisplayName(const AValue: string);
begin
  if Trim(AValue) <> '' then
    FEventName := AValue;
  inherited;
end;

procedure TRALRESTDWEventBase.AssignTo(ADest: TPersistent);
begin
  if ADest.InheritsFrom(TRALRESTDWEventBase) then
  begin
    with ADest as TRALRESTDWEventBase do
    begin
      BaseURL := Self.BaseURL;
      DefaultContentType := Self.DefaultContentType;
      Description := Self.Description;
      EventName := Self.EventName;
      DataMode := Self.DataMode;
      CallbackEvent := Self.CallbackEvent;
      OnlyPreDefinedParams := Self.OnlyPreDefinedParams;
      Routes := Self.Routes;
      Params := Self.Params;
    end;
  end
  else
  begin
    inherited AssignTo(ADest);
  end;
end;

{ TRALRESTDWEventList }

constructor TRALRESTDWEventList.Create(AOwner: TPersistent;
  AItemClass: TCollectionItemClass);
begin
  if AItemClass = nil then
    AItemClass := TRALRESTDWEventBase;
  inherited Create(AOwner, AItemClass);
end;

function TRALRESTDWEventList.AddEvent(const AEventName, ABaseURL,
  AContentType: StringRAL; ADataMode: TRALRESTDWDataMode): TRALRESTDWEventBase;
begin
  Result := TRALRESTDWEventBase(Add);
  Result.EventName := AEventName;
  Result.BaseURL := ABaseURL;
  Result.DataMode := ADataMode;
  if AContentType <> '' then
    Result.DefaultContentType := AContentType;
end;

function TRALRESTDWEventList.GetEvent(AIndex: IntegerRAL): TRALRESTDWEventBase;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < Count) then
    Result := TRALRESTDWEventBase(inherited Items[AIndex]);
end;

function TRALRESTDWEventList.GetEventName(AName : StringRAL): TRALRESTDWEventBase;
var
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEventBase;
begin
  Result := nil;
  for vInt1 := 0 to Pred(Count) do
  begin
    vEvent := TRALRESTDWEventBase(inherited Items[vInt1]);
    if SameText(vEvent.EventName, AName) then
    begin
      Result := vEvent;
      Break;
    end;
  end;
end;

{ TRALRESTDWEventServer }

procedure TRALRESTDWEventServer.AssignTo(ADest: TPersistent);
begin
  inherited AssignTo(ADest);

  if ADest.InheritsFrom(TRALRESTDWEventServer) then
  begin
    with ADest as TRALRESTDWEventServer do
    begin
      OnReplyEvent := Self.OnReplyEvent;
      OnReplyEventByType := Self.OnReplyEventByType;
      OnAuthRequest := Self.OnAuthRequest;
      OnBeforeExecute := Self.OnBeforeExecute;
    end;
  end;
end;

function TRALRESTDWEventServer.UndeclaredParam(ARequest: TRALRequest): StringRAL;
var
  vInt1: IntegerRAL;
  vParam: TRALParam;
  vName: StringRAL;
begin
  Result := '';
  for vInt1 := 0 to Pred(ARequest.Params.Count) do
  begin
    vParam := ARequest.Params.Index[vInt1];
    if vParam.Kind <> rpkBODY then
      Continue;

    vName := vParam.ParamName;
    { servereventname e accesstag sao do transporte, nao do evento; e um unico
      param de body chega renomeado para ral_body pelo proprio RAL }
    if SameText(vName, 'servereventname') or SameText(vName, 'accesstag') or
       SameText(vName, 'ral_body') or SameText(vName, cUndefined) then
      Continue;

    if not FParams.Declared(vName) then
    begin
      Result := vName;
      Break;
    end;
  end;
end;

procedure TRALRESTDWEventServer.ReplyEvent(ARequest: TRALRequest;
  AResponse: TRALResponse; AModule: TComponent; AIgnoreInvalidParams: boolean);
var
  vParams: TRALRESTDWParams;
  {$IFDEF RDW143}
    { String, e nao StringRAL: a assinatura do handler tem que bater com a do
      RDW 1.4.3, que o DFM liga por nome sem conferir }
    vResult: string;
  {$ELSE}
    vResult: TStringList;
  {$ENDIF}
  vHeader: TStringList;
  vStatusCode: IntegerRAL;
  vRejected: boolean;
  vInvalid: StringRAL;
  vError: string;
begin
  {$IFDEF RDW143}
    vResult := '';
  {$ELSE}
    vResult := TStringList.Create;
  {$ENDIF}
  vHeader := TStringList.Create;
  vParams := TRALRESTDWParams.Create;
  try
    vStatusCode := HTTP_OK;

    AResponse.Clear;
    AResponse.ContentType := FDefaultContentType;
    AResponse.ContentDispositionInline := True;

    FParams.CreateParams(vParams);
    vParams.Module := AModule;
    vParams.DataMode := FDataMode;
    vParams.AssignRequest(ARequest);

    try
      if FOnlyPreDefinedParams and (not AIgnoreInvalidParams) then
      begin
        vInvalid := UndeclaredParam(ARequest);
        if vInvalid <> '' then
        begin
          AResponse.Answer(HTTP_BadRequest,
                           Format('Param "%s" is not declared in event "%s"',
                                  [vInvalid, FEventName]), rctTEXTPLAIN);
          Exit;
        end;
      end;

      if Assigned(FOnAuthRequest) then
      begin
        vRejected := False;
        vError := '';
        vStatusCode := HTTP_Unauthorized;
        FOnAuthRequest(vParams, vRejected, vError, vStatusCode, vHeader);
        if vRejected then
        begin
          AResponse.Params.AppendParams(vHeader, rpkHEADER);
          AResponse.Answer(vStatusCode, StringRAL(vError), rctTEXTPLAIN);
          Exit;
        end;
        vStatusCode := HTTP_OK;
      end;

      if Assigned(FOnBeforeExecute) then
        FOnBeforeExecute(Self);

      if Assigned(FOnReplyEvent) then
        FOnReplyEvent(vParams, vResult)
      else if Assigned(FOnReplyEventByType) then
        FOnReplyEventByType(vParams, vResult, ARequest.Method, vStatusCode, vHeader);

      AResponse.StatusCode := vStatusCode;

      {$IFDEF RDW143}
        if Trim(vResult) <> '' then
          AResponse.Params.AddParam(cUndefined, StringRAL(vResult), rpkBODY);
      {$ELSE}
        if Trim(vResult.Text) <> '' then
          AResponse.Params.AddParam(cUndefined, vResult.Text, rpkBODY);
      {$ENDIF}

      AResponse.Params.AppendParams(vHeader, rpkHEADER);
      vParams.AppendResponse(AResponse);
    except
      on e: Exception do
      begin
        { texto puro de proposito: o ContentType do evento costuma ser
          application/json e uma mensagem de erro crua nao e JSON }
        AResponse.Clear;
        AResponse.Answer(HTTP_InternalError, e.Message, rctTEXTPLAIN);
      end;
    end;
  finally
    {$IFNDEF RDW143}
      FreeAndNil(vResult);
    {$ENDIF}
    FreeAndNil(vHeader);
    FreeAndNil(vParams);
  end;
end;

end.
