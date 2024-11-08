unit RALRESTDWServerEvents;

interface

uses
  Classes, SysUtils,
  RALCustomObjects, RALTypes, RALRequest, RALResponse, RALConsts,
  RALRESTDWParams, RALRESTDWParamsMethods, RALTools, RALMIMETypes;

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
  protected
    function GetDisplayName: string; override;
    procedure SetDisplayName(const AValue: string); override;

    procedure SetDescription(AValue: TStrings);
    procedure SetParams(AValue: TRALRESTDWParamsMethods);
    procedure SetBaseURL(const AValue: StringRAL);
  public
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;

    procedure ReplyEvent(ARequest : TRALRequest; AResponse: TRALResponse);
  published
    property BaseURL: StringRAL read FBaseURL write SetBaseURL;
    property DefaultContentType: StringRAL read FDefaultContentType write FDefaultContentType;
    property Description: TStrings read FDescription write SetDescription;
    property EventName: StringRAL read FEventName write FEventName;
    property Params: TRALRESTDWParamsMethods read FParams write SetParams;

    property OnReplyEvent: TRALRESTDWReplyEvent read FOnReplyEvent write FOnReplyEvent;
    property OnReplyEventByType: TRALRESTDWReplyEventByType read FOnReplyEventByType write FOnReplyEventByType;
  end;

  { TRALRESTDWEventList }

  TRALRESTDWEventList = Class(TOwnedCollection)
  protected
    function GetEventName(AName : StringRAL): TRALRESTDWEvent;
  public
    constructor Create(AOwner: TPersistent);

    property EventByName[AName : StringRAL] : TRALRESTDWEvent read GetEventName;
  end;

  { TRALRESTDWServerEvents }

  TRALRESTDWServerEvents = Class(TRALComponent)
  private
    FEventList: TRALRESTDWEventList;
    FAccessTag: StringRAL;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    function CanAnswerEvent(ARequest: TRALRequest): TRALRESTDWEvent;
  published
    property Events : TRALRESTDWEventList read FEventList write FEventList;
    property AccessTag : StringRAL read FAccessTag write FAccessTag;
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

procedure TRALRESTDWEvent.SetParams(AValue: TRALRESTDWParamsMethods);
begin

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

    AResponse.ContentType := FDefaultContentType;
    FParams.CreateParams(vParams);
    
    try
      if Assigned(FOnReplyEvent) then
        FOnReplyEvent(vParams, vResult)
      else if Assigned(FOnReplyEventByType) then
        FOnReplyEventByType(vParams, vResult, ARequest.Method, vStatusCode, vHeader);
        
      AResponse.StatusCode := vStatusCode;
      AResponse.ResponseText := vResult.Text;
      AResponse.Params.AppendParams(vHeader, rpkHEADER);
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

procedure TRALRESTDWEvent.CreateParams(AParams: TRALRESTDWParams);
begin

end;

destructor TRALRESTDWEvent.Destroy;
begin
  FreeAndNil(FDescription);
  FreeAndNil(FParams);
  inherited;
end;

function TRALRESTDWEvent.GetDisplayName: string;
begin
  Result := FEventName;
  inherited;
end;

procedure TRALRESTDWEvent.SetDisplayName(const AValue: string);
begin
  if Trim(AValue) <> '' then
    FEventName := AValue;
  inherited;
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

{ TRALRESTDWServerEvents }

constructor TRALRESTDWServerEvents.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEventList := TRALRESTDWEventList.Create(Self);
end;

destructor TRALRESTDWServerEvents.Destroy;
begin
  FreeAndNil(FEventList);
  inherited Destroy;
end;

function TRALRESTDWServerEvents.CanAnswerEvent(ARequest: TRALRequest): TRALRESTDWEvent;
var
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEvent;
begin
  Result := nil;
  for vInt1 := 0 to Pred(FEventList.Count) do
  begin
    vEvent := TRALRESTDWEvent(FEventList.Items[vInt1]);
    if vEvent.BaseURL = ARequest.Query then
    begin
      Result := vEvent;
      Break;
    end;
  end;
end;

end.

