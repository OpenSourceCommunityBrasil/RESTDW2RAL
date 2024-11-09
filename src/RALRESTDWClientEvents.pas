unit RALRESTDWClientEvents;

interface

uses
  Classes, SysUtils,
  RALCustomObjects, RALTypes, RALRESTDWEvents, RALStream, RALParams,
  RALRESTDWParamsMethods, RALRESTDWTypes, RALClient, RALRESTDWParams;

type
  TRALRESTDWSendEvent = (seGET, sePOST, sePUT, seDELETE, sePATCH);

  TRALRESTDWClientEvents = class(TRALComponent)
  private
    FAccessTag: StringRAL;
    FEvents: TRALRESTDWEventList;
    FServerEventName: StringRAL;
    FRALClient : TRALClient;
  protected
    procedure SetRALClient(const AValue: TRALClient);
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    procedure CreateDWParams(AEventName: StringRAL; var AParams: TRALRESTDWParams);
    function SendEvent(AEventName: StringRAL; AParams: TRALRESTDWParams;
                       var AError: StringRAL; AEventType: TRALRESTDWSendEvent = sePOST;
                       AsSyncExec: Boolean = False): Boolean; overload;
    function SendEvent(AEventName: StringRAL; AParams: TRALRESTDWParams;
                       var AError: StringRAL; var ANativeResult : StringRAL;
                       AEventType: TRALRESTDWSendEvent = sePOST;
                       AsSyncExec: Boolean = False): Boolean; overload;

    procedure SetEvents(AStream: TStream);
    procedure ClearEvents;
  published
    property AccessTag : StringRAL read FAccessTag write FAccessTag;
    property Events : TRALRESTDWEventList read FEvents write FEvents;
    property RALClient: TRALClient read FRALClient write SetRALClient;
    property ServerEventName: StringRAL read FServerEventName write FServerEventName;
  end;

implementation

{ TRALRESTDWClientEvents }

procedure TRALRESTDWClientEvents.ClearEvents;
begin
  FEvents.Clear;
end;

constructor TRALRESTDWClientEvents.Create(AOwner: TComponent);
begin
  inherited;
  FEvents := TRALRESTDWEventList.Create(Self);
end;

procedure TRALRESTDWClientEvents.CreateDWParams(AEventName: StringRAL; var AParams: TRALRESTDWParams);
var
  vEvent: TRALRESTDWEvent;
  vInt1: IntegerRAL;
  vFound: boolean;
  vParam: TRALRESTDWJSONParam;
  vParamMethod: TRALRESTDWParamMethod;
begin
  vEvent := FEvents.EventByName[AEventName];
  if vEvent <> nil then
  begin
    AParams := TRALRESTDWParams.Create;
    for vInt1 := 0 To Pred(vEvent.Params.Count) do
    begin
      vParamMethod := TRALRESTDWParamMethod(vEvent.Params.Items[vInt1]);
      vParam := AParams.ItemsString[vParamMethod.ParamName];
      if vParam = nil then
        vParam := AParams.NewParam;

      vParam.ParamName := vParamMethod.ParamName;
      vParam.Alias := vParamMethod.Alias;
      vParam.ObjectDirection := vParamMethod.ObjectDirection;
      vParam.ObjectValue := vParamMethod.ObjectValue;
      vParam.Encoded := vParamMethod.Encoded;
      vParam.AsString := vParamMethod.DefaultValue;
    end;
  end;
end;

destructor TRALRESTDWClientEvents.Destroy;
begin
  FreeAndNil(FEvents);
  inherited;
end;

procedure TRALRESTDWClientEvents.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FRALClient) then
    FRALClient := nil;
  inherited Notification(AComponent, Operation);
end;

function TRALRESTDWClientEvents.SendEvent(AEventName: StringRAL;
  AParams: TRALRESTDWParams; var AError: StringRAL;
  AEventType: TRALRESTDWSendEvent; AsSyncExec: Boolean): Boolean;
var
  vNativeResult: StringRAL;
begin
  Result := SendEvent(AEventName, AParams, AError, vNativeResult,
                      AEventType, AsSyncExec);
end;

function TRALRESTDWClientEvents.SendEvent(AEventName: StringRAL;
  AParams: TRALRESTDWParams; var AError, ANativeResult: StringRAL;
  AEventType: TRALRESTDWSendEvent; AsSyncExec: Boolean): Boolean;
var
  vEvent: TRALRESTDWEvent;
  vParam: TRALParam;
  vJsonParam: TRALRESTDWJSONParam;
  vStream: TStream;
begin
  Result := False;
  vEvent := FEvents.EventByName[AEventName];
  if vEvent <> nil then
  begin
    FRALClient.Request.Clear;
    if FAccessTag <> '' then
      FRALClient.Request.Params.AddParam('accesstag', FAccessTag, rpkBODY);
    FRALClient.Request.Params.AddParam('servereventname', FServerEventName);

    AParams.AppendRequest(FRALClient.Request);

    FRALClient.Route := vEvent.GetRoute;
    try
      case AEventType of
        seGET    : FRALClient.Get;
        sePOST   : FRALClient.Post;
        sePUT    : FRALClient.Put;
        seDELETE : FRALClient.Delete;
        sePATCH  : FRALClient.Patch;
      end;
      Result := True;
      AParams.AssignResponse(FRALClient.Response);

      vParam := FRALClient.Response.ParamByName(cUndefined);
      if vParam <> nil then
      begin
        vJsonParam := AParams.NewParam;
        vJsonParam.ParamName := cUndefined;

        vStream := vParam.SaveToStream;
        try
          vJsonParam.LoadFromStream(vStream);
        finally
          FreeAndNil(vStream);
        end;
      end;
    except
      on e : Exception do
      begin
        AError := e.Message;
        ANativeResult := IntToStr(FRALClient.Response.StatusCode);
      end;
    end;
  end;
end;

procedure TRALRESTDWClientEvents.SetEvents(AStream: TStream);
var
  vWriter: TRALBinaryWriter;
  vTotEvents, vTotParams, vInt1, vInt2: IntegerRAL;
  vEvent: TRALRESTDWEvent;
  vParam: TRALRESTDWParamMethod;
begin
  ClearEvents;

  vWriter := TRALBinaryWriter.Create(AStream);
  try
    vTotEvents := vWriter.ReadInteger;
    for vInt1 := 1 to vTotEvents do
    begin
      vEvent := TRALRESTDWEvent(FEvents.Add);

      vEvent.BaseURL := vWriter.ReadString;
      vEvent.DefaultContentType := vWriter.ReadString;
      vEvent.EventName := vWriter.ReadString;

      vTotParams := vWriter.ReadInteger;
      for vInt2 := 1 to vTotParams do
      begin
        vParam := TRALRESTDWParamMethod(vEvent.Params.Add);

        vParam.Alias := vWriter.ReadString;
        vParam.DefaultValue := vWriter.ReadString;
        vParam.Encoded := vWriter.ReadBoolean;
        vParam.ParamName := vWriter.ReadString;
        vParam.ObjectDirection := TRALRESTDWObjectDirection(vWriter.ReadByte);
        vParam.ObjectValue := TRALRESTDWObjectValue(vWriter.ReadByte);
        vParam.TypeObject := TRALRESTDWTypeObject(vWriter.ReadByte);
      end;
    end;
  finally
    FreeAndNil(vWriter);
  end;
end;

procedure TRALRESTDWClientEvents.SetRALClient(const AValue: TRALClient);
begin
  if FRALClient <> nil then
    FRALClient.RemoveFreeNotification(Self);

  FRALClient := AValue;

  if FRALClient <> nil then
    FRALClient.FreeNotification(Self);
end;

end.
