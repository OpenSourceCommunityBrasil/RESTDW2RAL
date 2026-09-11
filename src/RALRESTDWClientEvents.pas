unit RALRESTDWClientEvents;

interface

uses
  Classes, SysUtils,
  RALCustomObjects, RALTypes, RALRESTDWEvents, RALStream, RALParams,
  RALRESTDWParamsMethods, RALRESTDWTypes, RALClient, RALRESTDWParams,
  RALTools, RALResponse;

type
  TRALRESTDWSendEvent = (seGET, sePOST, sePUT, seDELETE, sePATCH);

  { TRALRESTDWClientEvents }

  TRALRESTDWClientEvents = class(TRALComponent)
  private
    FAccessTag: StringRAL;
    FEvents: TRALRESTDWEventList;
    FModuleRoute: StringRAL;
    FServerEventName: StringRAL;
    FRALClient : TRALClient;
    procedure SetModuleRoute(AValue: StringRAL);
  protected
    procedure SetRALClient(const AValue: TRALClient);
    procedure SetEventList(const AValue: TRALRESTDWEventList);
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    /// rota do evento ja com o dominio do modulo no servidor
    function EventUrl(AEvent: TRALRESTDWEventBase): StringRAL;
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

    procedure ClearEvents;
    procedure SetEvents(AStream: TStream);
    function GetServerEvents: StringRAL;
    function GetEvents: TStream;
  published
    property AccessTag : StringRAL read FAccessTag write FAccessTag;
    property Events : TRALRESTDWEventList read FEvents write SetEventList;
    property ModuleRoute: StringRAL read FModuleRoute write SetModuleRoute;
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
  FModuleRoute := '/';
end;

destructor TRALRESTDWClientEvents.Destroy;
begin
  FreeAndNil(FEvents);
  inherited;
end;

procedure TRALRESTDWClientEvents.SetEventList(const AValue: TRALRESTDWEventList);
begin
  FEvents.Assign(AValue);
end;

function TRALRESTDWClientEvents.EventUrl(AEvent: TRALRESTDWEventBase): StringRAL;
begin
  // GetRoute e relativo ao modulo; o dominio do modulo vem do ModuleRoute
  Result := FixRoute(FModuleRoute + '/' + AEvent.GetRoute);
end;

procedure TRALRESTDWClientEvents.CreateDWParams(AEventName: StringRAL; var AParams: TRALRESTDWParams);
var
  vEvent: TRALRESTDWEventBase;
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
  vParamMethod: TRALRESTDWParamMethod;
begin
  // sempre definido: evento inexistente deixava a variavel do chamador intacta
  AParams := nil;

  vEvent := FEvents.EventByName[AEventName];
  if vEvent = nil then
    Exit;

  AParams := TRALRESTDWParams.Create;
  for vInt1 := 0 To Pred(vEvent.Params.Count) do
  begin
    vParamMethod := TRALRESTDWParamMethod(vEvent.Params.Items[vInt1]);
    vParam := AParams.ItemsString[vParamMethod.ParamName];
    if vParam = nil then
      vParam := AParams.NewParam;

    // AsString carimba ObjectValue := ovString, entao o valor vai antes do tipo
    vParam.AsString := vParamMethod.DefaultValue;
    vParam.ParamName := vParamMethod.ParamName;
    vParam.Alias := vParamMethod.Alias;
    vParam.TypeObject := vParamMethod.TypeObject;
    vParam.ObjectDirection := vParamMethod.ObjectDirection;
    vParam.ObjectValue := vParamMethod.ObjectValue;
    vParam.Encoded := vParamMethod.Encoded;
  end;
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
  AParams: TRALRESTDWParams; var AError: StringRAL;
  var ANativeResult: StringRAL; AEventType: TRALRESTDWSendEvent;
  AsSyncExec: Boolean): Boolean;
var
  vEvent: TRALRESTDWEventBase;
  vParam: TRALParam;
  vJsonParam: TRALRESTDWJSONParam;
  vStream: TStream;
  vResponse : TRALResponse;
  vUrl : StringRAL;
begin
  Result := False;

  if FRALClient = nil then
    raise Exception.Create('Property RALClient not assigned');

  vEvent := FEvents.EventByName[AEventName];
  if vEvent = nil then
  begin
    AError := Format('Event "%s" not found', [AEventName]);
    Exit;
  end;

  FRALClient.Request.Clear;
  if FAccessTag <> '' then
    FRALClient.Request.Params.AddParam('accesstag', FAccessTag, rpkBODY);
  FRALClient.Request.Params.AddParam('servereventname', FServerEventName, rpkBODY);

  AParams.AppendRequest(FRALClient.Request);

  vUrl := EventUrl(vEvent);
  vResponse := nil;
  try
    try
      case AEventType of
        seGET    : FRALClient.Get(vUrl, vResponse);
        sePOST   : FRALClient.Post(vUrl, vResponse);
        sePUT    : FRALClient.Put(vUrl, vResponse);
        seDELETE : FRALClient.Delete(vUrl, vResponse);
        sePATCH  : FRALClient.Patch(vUrl, vResponse);
      end;

      AParams.AssignResponse(vResponse);

      vParam := vResponse.ParamByName(cUndefined);
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

      // so no fim: antes o True era marcado logo apos a chamada e sobrevivia a
      // uma excecao na leitura da resposta
      Result := True;
    except
      on e : Exception do
      begin
        AError := e.Message;
        // ExecuteSingle libera a resposta e re-lanca em erro de transporte,
        // entao aqui vResponse e justamente nil
        if vResponse <> nil then
          ANativeResult := IntToStr(vResponse.StatusCode);
      end;
    end;
  finally
    FreeAndNil(vResponse);
  end;
end;

procedure TRALRESTDWClientEvents.SetEvents(AStream: TStream);
var
  vWriter: TRALBinaryWriter;
  vTotEvents, vTotParams, vInt1, vInt2: IntegerRAL;
  vEvent: TRALRESTDWEventBase;
  vParam: TRALRESTDWParamMethod;
begin
  ClearEvents;
  if AStream = nil then
    Exit;

  vWriter := TRALBinaryWriter.Create(AStream);
  try
    vTotEvents := vWriter.ReadInteger;
    for vInt1 := 1 to vTotEvents do
    begin
      vEvent := TRALRESTDWEventBase(FEvents.Add);

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

function TRALRESTDWClientEvents.GetServerEvents : StringRAL;
var
  vParam: TRALParam;
  vUrl : StringRAL;
  vResponse : TRALResponse;
begin
  Result := '';

  if FRALClient = nil then
    raise Exception.Create('Property RALClient not assigned');

  FRALClient.Request.Clear;
  if FAccessTag <> '' then
    FRALClient.Request.Params.AddParam('accesstag', FAccessTag, rpkBODY);

  vUrl := FixRoute(FModuleRoute + '/getservereventslist');
  vResponse := nil;
  try
    try
      FRALClient.Post(vUrl, vResponse);
      vParam := vResponse.Body;
      if vParam <> nil then
        Result := vParam.AsString;
    except
      on e : Exception do
        raise Exception.CreateFmt('Erro ao recuperar os ServerEvents: %s', [e.Message]);
    end;
  finally
    FreeAndNil(vResponse);
  end;
end;

function TRALRESTDWClientEvents.GetEvents: TStream;
var
  vParam: TRALParam;
  vUrl : StringRAL;
  vResponse : TRALResponse;
begin
  Result := nil;

  if FRALClient = nil then
    raise Exception.Create('Property RALClient not assigned');

  FRALClient.Request.Clear;
  FRALClient.Request.ContentType := 'text/plain';
  if FAccessTag <> '' then
    FRALClient.Request.Params.AddParam('accesstag', FAccessTag, rpkBODY);
  FRALClient.Request.Params.AddParam('servereventname', FServerEventName, rpkBODY);

  vUrl := FixRoute(FModuleRoute + '/getevents');
  vResponse := nil;
  try
    try
      FRALClient.Post(vUrl, vResponse);
      vParam := vResponse.Body;
      if vParam <> nil then
        Result := vParam.SaveToStream;
    except
      on e : Exception do
        raise Exception.CreateFmt('Erro ao recuperar os Events: %s', [e.Message]);
    end;
  finally
    FreeAndNil(vResponse);
  end;
end;

procedure TRALRESTDWClientEvents.SetModuleRoute(AValue: StringRAL);
begin
  if FModuleRoute = AValue then
    Exit;

  FModuleRoute := FixRoute(AValue);
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
