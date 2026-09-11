/// The client half: a local mirror of a server's events, and the call itself.
///
/// Shaped after REST Dataware's TRESTDWClientEvents - same property names, same
/// method signatures - with the RESTClientPooler replaced by a TRALClient.
unit RALRESTDWClientEvents;

interface

uses
  Classes, SysUtils,
  RALCustomObjects, RALTypes, RALRESTDWEvents, RALStream, RALParams,
  RALRESTDWParamsMethods, RALRESTDWTypes, RALClient, RALRESTDWParams,
  RALTools, RALResponse;

type
  TRALRESTDWSendEvent = (seGET, sePOST, sePUT, seDELETE, sePATCH);
  /// Same shape as RDW's TOnBeforeSend
  TRALRESTDWBeforeSend = procedure(ASelf: TComponent) of object;

  { TRALRESTDWClientEvents }

  TRALRESTDWClientEvents = class(TRALComponent)
  private
    FAccessTag: StringRAL;
    FEvents: TRALRESTDWEventList;
    FModuleRoute: StringRAL;
    FServerEventName: StringRAL;
    FRALClient : TRALClient;
    FAutoFetch: boolean;
    FFetched: boolean;
    FOnBeforeSend: TRALRESTDWBeforeSend;

    procedure SetModuleRoute(AValue: StringRAL);
    function GetGetEvents: boolean;
    procedure SetGetEvents(AValue: boolean);
  protected
    procedure SetRALClient(const AValue: TRALClient);
    procedure SetEventList(const AValue: TRALRESTDWEventList);
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    /// The event's route already carrying the module's domain
    function EventUrl(AEvent: TRALRESTDWEventBase): StringRAL;
    /// Finds an event, fetching the definitions once when AutoFetch allows it
    function FindEvent(const AEventName: StringRAL): TRALRESTDWEventBase;
    procedure CheckClient;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    /// Builds the declared params of an event. The caller owns the object;
    /// an unknown event name leaves it nil.
    procedure CreateDWParams(AEventName: StringRAL; var AParams: TRALRESTDWParams);

    function SendEvent(AEventName: StringRAL; var AParams: TRALRESTDWParams;
                       var AError: string; AEventType: TRALRESTDWSendEvent = sePOST;
                       AsSyncExec: Boolean = False): Boolean; overload;
    function SendEvent(AEventName: StringRAL; var AParams: TRALRESTDWParams;
                       var AError: string; var ANativeResult: string;
                       AEventType: TRALRESTDWSendEvent = sePOST;
                       AsSyncExec: Boolean = False): Boolean; overload;

    procedure ClearEvents;
    /// Replaces the local mirror with the definitions in AStream
    procedure SetEvents(AStream: TStream);
    /// Downloads the definitions and applies them - what GetEvents := True does
    procedure FetchEvents;
    /// The raw definition stream, for storing or inspecting
    function FetchEventsStream: TStream;
    /// The '|'-separated list of ServerEvents the server exposes
    function GetServerEvents: StringRAL;
  published
    property AccessTag : StringRAL read FAccessTag write FAccessTag;
    property Events : TRALRESTDWEventList read FEvents write SetEventList;
    { Set it to True to pull the event definitions from the server, in the
      designer or in code. Reads back True once the mirror is filled - the same
      property REST Dataware exposes. }
    property GetEvents: boolean read GetGetEvents write SetGetEvents stored False;
    { Pulls the definitions by itself the first time an unknown event is asked
      for, so a working client needs no design-time step at all. }
    property AutoFetch: boolean read FAutoFetch write FAutoFetch default True;
    property ModuleRoute: StringRAL read FModuleRoute write SetModuleRoute;
    property RALClient: TRALClient read FRALClient write SetRALClient;
    property ServerEventName: StringRAL read FServerEventName write FServerEventName;
    property OnBeforeSend: TRALRESTDWBeforeSend read FOnBeforeSend write FOnBeforeSend;
  end;

implementation

{ TRALRESTDWClientEvents }

constructor TRALRESTDWClientEvents.Create(AOwner: TComponent);
begin
  inherited;
  FEvents := TRALRESTDWEventList.Create(Self, TRALRESTDWEventBase);
  FModuleRoute := '/';
  FAutoFetch := True;
  FFetched := False;
end;

destructor TRALRESTDWClientEvents.Destroy;
begin
  FreeAndNil(FEvents);
  inherited;
end;

procedure TRALRESTDWClientEvents.ClearEvents;
begin
  FEvents.Clear;
  FFetched := False;
end;

procedure TRALRESTDWClientEvents.SetEventList(const AValue: TRALRESTDWEventList);
begin
  FEvents.Assign(AValue);
end;

function TRALRESTDWClientEvents.GetGetEvents: boolean;
begin
  Result := FEvents.Count > 0;
end;

procedure TRALRESTDWClientEvents.SetGetEvents(AValue: boolean);
begin
  if AValue then
    FetchEvents
  else
    ClearEvents;
end;

procedure TRALRESTDWClientEvents.CheckClient;
begin
  if FRALClient = nil then
    raise Exception.Create('Property RALClient not assigned');
end;

function TRALRESTDWClientEvents.EventUrl(AEvent: TRALRESTDWEventBase): StringRAL;
begin
  // GetRoute e relativo ao modulo; o dominio do modulo vem do ModuleRoute
  Result := FixRoute(FModuleRoute + '/' + AEvent.GetRoute);
end;

function TRALRESTDWClientEvents.FindEvent(const AEventName: StringRAL): TRALRESTDWEventBase;
begin
  Result := FEvents.EventByName[AEventName];
  if (Result <> nil) or (not FAutoFetch) or FFetched or (FRALClient = nil) then
    Exit;

  { primeira vez que se pede um evento desconhecido: busca as definicoes no
    servidor e tenta de novo. E o que dispensa o passo de design-time }
  FetchEvents;
  Result := FEvents.EventByName[AEventName];
end;

procedure TRALRESTDWClientEvents.CreateDWParams(AEventName: StringRAL;
  var AParams: TRALRESTDWParams);
var
  vEvent: TRALRESTDWEventBase;
begin
  // sempre definido: evento inexistente deixava a variavel do chamador intacta
  AParams := nil;

  vEvent := FindEvent(AEventName);
  if vEvent = nil then
    Exit;

  AParams := TRALRESTDWParams.Create;
  vEvent.Params.CreateParams(AParams);
end;

procedure TRALRESTDWClientEvents.Notification(AComponent: TComponent; Operation: TOperation);
begin
  if (Operation = opRemove) and (AComponent = FRALClient) then
    FRALClient := nil;
  inherited Notification(AComponent, Operation);
end;

function TRALRESTDWClientEvents.SendEvent(AEventName: StringRAL;
  var AParams: TRALRESTDWParams; var AError: string;
  AEventType: TRALRESTDWSendEvent; AsSyncExec: Boolean): Boolean;
var
  vNativeResult: string;
begin
  Result := SendEvent(AEventName, AParams, AError, vNativeResult,
                      AEventType, AsSyncExec);
end;

function TRALRESTDWClientEvents.SendEvent(AEventName: StringRAL;
  var AParams: TRALRESTDWParams; var AError: string;
  var ANativeResult: string; AEventType: TRALRESTDWSendEvent;
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

  CheckClient;

  vEvent := FindEvent(AEventName);
  if vEvent = nil then
  begin
    AError := StringRAL(Format('Event "%s" not found', [AEventName]));
    Exit;
  end;

  if AParams = nil then
    AParams := TRALRESTDWParams.Create;

  FRALClient.Request.Clear;
  if FAccessTag <> '' then
    FRALClient.Request.Params.AddParam('accesstag', FAccessTag, rpkBODY);
  if FServerEventName <> '' then
    FRALClient.Request.Params.AddParam('servereventname', FServerEventName, rpkBODY);

  AParams.AppendRequest(FRALClient.Request);

  if Assigned(FOnBeforeSend) then
    FOnBeforeSend(Self);

  vUrl := EventUrl(vEvent);

  { assincrono: dispara e volta na hora, sem resposta para ler - que e o que
    Assyncexec significa no RDW. Os params de saida nao sao preenchidos. }
  if AsSyncExec then
  begin
    try
      case AEventType of
        seGET    : FRALClient.Get(vUrl, nil, ebMultiThread);
        sePOST   : FRALClient.Post(vUrl, nil, ebMultiThread);
        sePUT    : FRALClient.Put(vUrl, nil, ebMultiThread);
        seDELETE : FRALClient.Delete(vUrl, nil, ebMultiThread);
        sePATCH  : FRALClient.Patch(vUrl, nil, ebMultiThread);
      end;
      Result := True;
    except
      on e : Exception do
        AError := e.Message;
    end;
    Exit;
  end;

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

      ANativeResult := StringRAL(IntToStr(vResponse.StatusCode));
      AParams.AssignResponse(vResponse);

      { mesma armadilha do lado da resposta: handler que devolve so o texto, sem
        param odOUT, manda um unico param de body e o nome cUndefined nao chega }
      vParam := vResponse.ParamByName(cUndefined);
      if vParam = nil then
        vParam := vResponse.Body;
      if vParam <> nil then
      begin
        vJsonParam := AParams.ItemsString[cUndefined];
        if vJsonParam = nil then
        begin
          vJsonParam := AParams.NewParam;
          vJsonParam.ParamName := cUndefined;
        end;

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
          ANativeResult := StringRAL(IntToStr(vResponse.StatusCode));
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

  procedure ReadRoute(ARoute: TRALRESTDWRoute);
  begin
    ARoute.Active := vWriter.ReadBoolean;
    ARoute.NeedAuthorization := vWriter.ReadBoolean;
  end;

begin
  ClearEvents;
  if AStream = nil then
    Exit;

  vWriter := TRALBinaryWriter.Create(AStream);
  try
    if vWriter.ReadString <> cEventsSignature then
      raise Exception.Create('Not a RESTDW2RAL event stream');
    if vWriter.ReadInteger <> cEventsVersion then
      raise Exception.Create('Event stream written by another version of RESTDW2RAL');

    vTotEvents := vWriter.ReadInteger;
    for vInt1 := 1 to vTotEvents do
    begin
      vEvent := TRALRESTDWEventBase(FEvents.Add);

      vEvent.BaseURL := vWriter.ReadString;
      vEvent.DefaultContentType := vWriter.ReadString;
      vEvent.EventName := vWriter.ReadString;
      vEvent.Description.Text := vWriter.ReadString;
      vEvent.DataMode := TRALRESTDWDataMode(vWriter.ReadByte);
      vEvent.CallbackEvent := vWriter.ReadBoolean;
      vEvent.OnlyPreDefinedParams := vWriter.ReadBoolean;

      ReadRoute(vEvent.Routes.All);
      ReadRoute(vEvent.Routes.Get);
      ReadRoute(vEvent.Routes.Post);
      ReadRoute(vEvent.Routes.Put);
      ReadRoute(vEvent.Routes.Patch);
      ReadRoute(vEvent.Routes.Delete);
      ReadRoute(vEvent.Routes.Option);

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
        vParam.DataMode := TRALRESTDWDataMode(vWriter.ReadByte);
      end;
    end;
    FFetched := True;
  finally
    FreeAndNil(vWriter);
  end;
end;

procedure TRALRESTDWClientEvents.FetchEvents;
var
  vStream: TStream;
begin
  // marcado antes: uma falha de rede nao pode virar uma tentativa por chamada
  FFetched := True;

  vStream := FetchEventsStream;
  try
    SetEvents(vStream);
  finally
    FreeAndNil(vStream);
  end;
end;

function TRALRESTDWClientEvents.GetServerEvents : StringRAL;
var
  vParam: TRALParam;
  vUrl : StringRAL;
  vResponse : TRALResponse;
begin
  Result := '';
  CheckClient;

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

function TRALRESTDWClientEvents.FetchEventsStream: TStream;
var
  vParam: TRALParam;
  vUrl : StringRAL;
  vResponse : TRALResponse;
begin
  Result := nil;
  CheckClient;

  FRALClient.Request.Clear;
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
