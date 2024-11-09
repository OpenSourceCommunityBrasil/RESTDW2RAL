unit RALRESTDWEvents;

interface

uses
  Classes, SysUtils,
  RALTypes, RALRESTDWParams, RALRESTDWParamsMethods, RALRequest, RALResponse,
  RALConsts, RALTools, RALRESTDWTypes, RALMimeTypes;

type
  TRALRESTDWReplyEvent = procedure(AParams: TRALRESTDWParams; const AResult: TStringList) of object;
  TRALRESTDWReplyEventByType = procedure(var AParams: TRALRESTDWParams;
                                         const AResult: TStringList;
                                         const ARequestType: TRALMethod;
                                         var AStatusCode: IntegerRAL;
                                         ARequestHeader: TStringList) of object;

  { TRALRESTDWEvent }

  TRALRESTDWEvent = class(TCollectionItem)
  private
    FBaseURL: StringRAL;
    FDefaultContentType: StringRAL;
    FDescription: TStrings;
    FEventName: StringRAL;
    FParams: TRALRESTDWParamsMethods;

    FOnReplyEvent: TRALRESTDWReplyEvent;
    FOnReplyEventByType: TRALRESTDWReplyEventByType;
    FOnBeforeExecute: TNotifyEvent;
  protected
    function GetDisplayName: string; override;
    procedure SetDisplayName(const AValue: string); override;
    procedure SetParams(const Value: TRALRESTDWParamsMethods);

    procedure SetDescription(AValue: TStrings);
    procedure SetBaseURL(const AValue: StringRAL);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;

    function GetNamePath: string; override;
    function GetRoute: StringRAL;

    procedure ReplyEvent(ARequest : TRALRequest; AResponse: TRALResponse);
  published
    property BaseURL: StringRAL read FBaseURL write SetBaseURL;
    property DefaultContentType: StringRAL read FDefaultContentType write FDefaultContentType;
    property Description: TStrings read FDescription write SetDescription;
    property EventName: StringRAL read FEventName write FEventName;
    property Params: TRALRESTDWParamsMethods read FParams write SetParams;

    property OnReplyEvent: TRALRESTDWReplyEvent read FOnReplyEvent write FOnReplyEvent;
    property OnReplyEventByType: TRALRESTDWReplyEventByType read FOnReplyEventByType write FOnReplyEventByType;
    property OnBeforeExecute: TNotifyEvent read FOnBeforeExecute write FOnBeforeExecute;
  end;

  { TRALRESTDWEventList }

  TRALRESTDWEventList = Class(TOwnedCollection)
  protected
    function GetEventName(AName : StringRAL): TRALRESTDWEvent;
  public
    constructor Create(AOwner: TPersistent);

    property EventByName[AName : StringRAL] : TRALRESTDWEvent read GetEventName;
  end;

implementation

{ TRALRESTDWEvent }

procedure TRALRESTDWEvent.SetBaseURL(const AValue: StringRAL);
begin
  FBaseURL := FixRoute(AValue);
end;

procedure TRALRESTDWEvent.SetDescription(AValue: TStrings);
begin
  FDescription.Assign(AValue);
end;

procedure TRALRESTDWEvent.ReplyEvent(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vParams: TRALRESTDWParams;
  vResult: TStringList;
  vHeader: TStringList;
  vStatusCode: IntegerRAL;
begin
  vResult := TStringList.Create;
  vHeader := TStringList.Create;
  vParams := TRALRESTDWParams.Create;
  try
    vStatusCode := HTTP_OK;
    AResponse.Clear;
    AResponse.ContentType := FDefaultContentType;
    FParams.CreateParams(vParams);
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
      if Trim(vResult.Text) <> '' then
        AResponse.Params.AddParam(cUndefined, vResult.Text, rpkBODY);
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
    FreeAndNil(vResult);
    FreeAndNil(vHeader);
    FreeAndNil(vParams);
  end;
end;

constructor TRALRESTDWEvent.Create(ACollection: TCollection);
begin
  inherited;
  FBaseURL := '/';
  FDefaultContentType := rctAPPLICATIONJSON;
  FDescription := TStringList.Create;
  FEventName := 'event' + IntToStr(Index);
  FParams := TRALRESTDWParamsMethods.Create(Self);
end;

destructor TRALRESTDWEvent.Destroy;
begin
  FreeAndNil(FDescription);
  FreeAndNil(FParams);
  inherited;
end;

function TRALRESTDWEvent.GetRoute: StringRAL;
begin
  Result := FixRoute(FBaseURL + '/' + FEventName);
end;

function TRALRESTDWEvent.GetDisplayName: string;
begin
  Result := FEventName;
  inherited;
end;

function TRALRESTDWEvent.GetNamePath: string;
var
  vName: StringRAL;
begin
  Result := '';
  if Self = nil then
    Exit;

  vName := Collection.GetNamePath;
  Result := vName + '_' + FEventName;
end;

procedure TRALRESTDWEvent.SetDisplayName(const AValue: string);
begin
  if Trim(AValue) <> '' then
    FEventName := AValue;
  inherited;
end;

procedure TRALRESTDWEvent.SetParams(const Value: TRALRESTDWParamsMethods);
begin
  FParams := Value;
end;

{ TRALRESTDWEventList }

function TRALRESTDWEventList.GetEventName(AName : StringRAL): TRALRESTDWEvent;
var
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEvent;
begin
  Result := nil;
  for vInt1 := 0 to Pred(Count) do
  begin
    vEvent := TRALRESTDWEvent(Items[vInt1]);
    if SameText(vEvent.EventName, AName) then
    begin
      Result := vEvent;
      Break;
    end;
  end;
end;

constructor TRALRESTDWEventList.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TRALRESTDWEvent);
end;

end.
