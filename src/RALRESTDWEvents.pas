unit RALRESTDWEvents;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils,
  RALTypes, RALRESTDWParams, RALRESTDWParamsMethods, RALRequest, RALResponse,
  RALConsts, RALTools, RALRESTDWTypes, RALMimeTypes;

type
  {$IFDEF RDW143}
  TRALRESTDWReplyEvent = procedure(AParams: TRALRESTDWParams;
                                   var AResult: StringRAL) of object;
  TRALRESTDWReplyEventByType = procedure(var AParams: TRALRESTDWParams;
                                         var AResult: StringRAL;
                                         const ARequestType: TRALMethod;
                                         var AStatusCode: IntegerRAL;
                                         ARequestHeader: TStringList) of object;
  {$ELSE}
  TRALRESTDWReplyEvent = procedure(AParams: TRALRESTDWParams;
                                   const AResult: TStringList) of object;
  TRALRESTDWReplyEventByType = procedure(var AParams: TRALRESTDWParams;
                                         const AResult: TStringList;
                                         const ARequestType: TRALMethod;
                                         var AStatusCode: IntegerRAL;
                                         ARequestHeader: TStringList) of object;
  {$ENDIF}

  { TRALRESTDWEventBase }

  TRALRESTDWEventBase = class(TCollectionItem)
  private
    FBaseURL: StringRAL;
    FDefaultContentType: StringRAL;
    FDescription: TStrings;
    FEventName: StringRAL;
    FParams: TRALRESTDWParamsMethods;
    FOnlyPreDefinedParams: boolean;
  protected
    function GetDisplayName: string; override;
    procedure SetDisplayName(const AValue: string); override;
    procedure SetParams(const Value: TRALRESTDWParamsMethods);

    procedure AssignTo(ADest: TPersistent); override;

    procedure SetDescription(AValue: TStrings);
    procedure SetBaseURL(const AValue: StringRAL);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;

    function GetNamePath: string; override;
    function GetRoute: StringRAL;
  published
    property BaseURL: StringRAL read FBaseURL write SetBaseURL;
    property DefaultContentType: StringRAL read FDefaultContentType write FDefaultContentType;
    property Description: TStrings read FDescription write SetDescription;
    property EventName: StringRAL read FEventName write FEventName;
    property Params: TRALRESTDWParamsMethods read FParams write SetParams;
    property OnlyPreDefinedParams: Boolean read FOnlyPreDefinedParams write FOnlyPreDefinedParams;
  end;

  TRALRESTDWEventServer = class(TRALRESTDWEventBase)
  private
    FOnReplyEvent: TRALRESTDWReplyEvent;
    FOnReplyEventByType: TRALRESTDWReplyEventByType;
    FOnBeforeExecute: TNotifyEvent;
  protected
    procedure AssignTo(ADest: TPersistent); override;
  public
    procedure ReplyEvent(ARequest : TRALRequest; AResponse: TRALResponse;
                         AModule: TComponent = nil);
  published
    property OnReplyEvent: TRALRESTDWReplyEvent read FOnReplyEvent write FOnReplyEvent;
    property OnReplyEventByType: TRALRESTDWReplyEventByType read FOnReplyEventByType write FOnReplyEventByType;
    property OnBeforeExecute: TNotifyEvent read FOnBeforeExecute write FOnBeforeExecute;
  end;

  { TRALRESTDWEventList }

  TRALRESTDWEventList = Class(TOwnedCollection)
  protected
    function GetEventName(AName : StringRAL): TRALRESTDWEventBase;
  public
    constructor Create(AOwner: TPersistent);

    property EventByName[AName : StringRAL] : TRALRESTDWEventBase read GetEventName;
  end;

implementation

{ TRALRESTDWEvent }

procedure TRALRESTDWEventBase.SetBaseURL(const AValue: StringRAL);
begin
  FBaseURL := FixRoute(AValue);
end;

procedure TRALRESTDWEventBase.SetDescription(AValue: TStrings);
begin
  FDescription.Assign(AValue);
end;

constructor TRALRESTDWEventBase.Create(ACollection: TCollection);
begin
  inherited;
  FBaseURL := '/';
  FDefaultContentType := rctAPPLICATIONJSON;
  FDescription := TStringList.Create;
  FEventName := 'event' + IntToStr(Index);
  FParams := TRALRESTDWParamsMethods.Create(Self);
end;

destructor TRALRESTDWEventBase.Destroy;
begin
  FreeAndNil(FDescription);
  FreeAndNil(FParams);
  inherited;
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

procedure TRALRESTDWEventBase.SetParams(const Value: TRALRESTDWParamsMethods);
begin
  // trocar o ponteiro vazava a colecao antiga e deixava duas donas da nova
  FParams.Assign(Value);
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
      OnlyPreDefinedParams := Self.OnlyPreDefinedParams;
      Params := Self.Params;
    end;
  end
  else
  begin
    inherited AssignTo(ADest);
  end;
end;

{ TRALRESTDWEventList }

function TRALRESTDWEventList.GetEventName(AName : StringRAL): TRALRESTDWEventBase;
var
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEventBase;
begin
  Result := nil;
  for vInt1 := 0 to Pred(Count) do
  begin
    vEvent := TRALRESTDWEventBase(Items[vInt1]);
    if SameText(vEvent.EventName, AName) then
    begin
      Result := vEvent;
      Break;
    end;
  end;
end;

constructor TRALRESTDWEventList.Create(AOwner: TPersistent);
begin
  if SameText(AOwner.ClassName, 'TRALRESTDWServerEvents') then
    inherited Create(AOwner, TRALRESTDWEventServer)
  else
    inherited Create(AOwner, TRALRESTDWEventBase)
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
      OnBeforeExecute := Self.OnBeforeExecute;
    end;
  end;
end;

procedure TRALRESTDWEventServer.ReplyEvent(ARequest: TRALRequest;
  AResponse: TRALResponse; AModule: TComponent);
var
  vParams: TRALRESTDWParams;
  {$IFDEF RDW143}
    vResult: StringRAL;
  {$ELSE}
    vResult: TStringList;
  {$ENDIF}
  vHeader: TStringList;
  vStatusCode: IntegerRAL;
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

    FParams.CreateParams(vParams);
    vParams.Module := AModule;
    vParams.AssignRequest(ARequest);

    AResponse.ContentDispositionInline := True;

    if Assigned(FOnBeforeExecute) then
      FOnBeforeExecute(Self);

    try
      if Assigned(FOnReplyEvent) then
        FOnReplyEvent(vParams, vResult)
      else if Assigned(FOnReplyEventByType) then
        FOnReplyEventByType(vParams, vResult, ARequest.Method, vStatusCode, vHeader);

      AResponse.StatusCode := vStatusCode;

      {$IFDEF RDW143}
        if Trim(vResult) <> '' then
          AResponse.Params.AddParam(cUndefined, vResult, rpkBODY);
      {$ELSE}
        if Trim(vResult.Text) <> '' then
          AResponse.Params.AddParam(cUndefined, vResult.Text, rpkBODY);
      {$ENDIF}

      AResponse.Params.AppendParams(vHeader, rpkHEADER);
      vParams.AppendResponse(AResponse);
    except
      on e: Exception do
      begin
        AResponse.StatusCode := HTTP_InternalError;
        AResponse.ResponseText := e.message;
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
