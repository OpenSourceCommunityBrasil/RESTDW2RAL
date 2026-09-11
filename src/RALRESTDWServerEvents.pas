/// The component you drop on a DataModule: a collection of events and their
/// handlers, exactly as REST Dataware's TRESTDWServerEvents.
unit RALRESTDWServerEvents;

interface

uses
  Classes, SysUtils,
  RALCustomObjects, RALTypes, RALRequest, RALResponse, RALRESTDWParamsMethods,
  RALStream, RALTools, RALRESTDWTypes, RALRESTDWParams, RALRESTDWEvents;

type
  /// Same shape as RDW's TObjectEvent
  TRALRESTDWObjectEvent = procedure(ASelf: TComponent) of object;

  { TRALRESTDWServerEvents }

  TRALRESTDWServerEvents = Class(TRALComponent)
  private
    FEvents: TRALRESTDWEventList;
    FAccessTag: StringRAL;
    FDefaultEvent: StringRAL;
    FIgnoreInvalidParams: boolean;
    FOnCreate: TRALRESTDWObjectEvent;
    FCreateFired: boolean;
  protected
    procedure SetEventList(const AValue: TRALRESTDWEventList);
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    /// Fires OnCreate once per instance. The module calls it after streaming
    /// the DataModule, which is where the handler is already assigned.
    procedure DoCreate;

    /// Builds the declared params of an event, like the RDW method of the same name
    procedure CreateDWParams(AEventName: StringRAL; var AParams: TRALRESTDWParams);

    /// Serialized event definitions for TRALRESTDWClientEvents
    function GetEvents : TStream;
    /// Compact definitions for the module's route export file
    procedure ExportEvents(AWriter: TRALBinaryWriter);

    function CanAnswerEvent(ARequest: TRALRequest;
                            const ADomain: StringRAL = '/'): TRALRESTDWEventServer;
    /// Resolves the event for this request and runs it. False when no event matched.
    function ExecuteEvent(ARequest: TRALRequest; AResponse: TRALResponse;
                          AModule: TComponent = nil;
                          const ADomain: StringRAL = '/'): boolean;
  published
    property Events : TRALRESTDWEventList read FEvents write SetEventList;
    property AccessTag : StringRAL read FAccessTag write FAccessTag;
    /// Answers when the request matches no event by route
    property DefaultEvent : StringRAL read FDefaultEvent write FDefaultEvent;
    { With OnlyPreDefinedParams on the event, decides whether an undeclared
      param is silently dropped (True, the default) or refused with 400. }
    property IgnoreInvalidParams : boolean read FIgnoreInvalidParams write FIgnoreInvalidParams default True;
    property OnCreate : TRALRESTDWObjectEvent read FOnCreate write FOnCreate;
  end;

implementation

{ TRALRESTDWServerEvents }

constructor TRALRESTDWServerEvents.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEvents := TRALRESTDWEventList.Create(Self, TRALRESTDWEventServer);
  FIgnoreInvalidParams := True;
  FCreateFired := False;
end;

destructor TRALRESTDWServerEvents.Destroy;
begin
  FreeAndNil(FEvents);
  inherited Destroy;
end;

procedure TRALRESTDWServerEvents.SetEventList(const AValue: TRALRESTDWEventList);
begin
  FEvents.Assign(AValue);
end;

procedure TRALRESTDWServerEvents.DoCreate;
begin
  if FCreateFired then
    Exit;

  FCreateFired := True;
  if Assigned(FOnCreate) then
    FOnCreate(Self);
end;

procedure TRALRESTDWServerEvents.CreateDWParams(AEventName: StringRAL;
  var AParams: TRALRESTDWParams);
var
  vEvent: TRALRESTDWEventBase;
begin
  AParams := nil;

  vEvent := FEvents.EventByName[AEventName];
  if vEvent = nil then
    Exit;

  AParams := TRALRESTDWParams.Create;
  vEvent.Params.CreateParams(AParams);
end;

function TRALRESTDWServerEvents.GetEvents: TStream;
var
  vWriter: TRALBinaryWriter;
  vInt1, vInt2: IntegerRAL;
  vEvent: TRALRESTDWEventServer;
  vParam: TRALRESTDWParamMethod;

  procedure WriteRoute(ARoute: TRALRESTDWRoute);
  begin
    vWriter.WriteBoolean(ARoute.Active);
    vWriter.WriteBoolean(ARoute.NeedAuthorization);
  end;

begin
  Result := TMemoryStream.Create;

  vWriter := TRALBinaryWriter.Create(Result);
  try
    { assinatura e versao na frente: sem elas, um cliente e um servidor de
      versoes diferentes liam o campo seguinte como tamanho de string e
      estouravam com "stream announces more bytes than it holds" }
    vWriter.WriteString(cEventsSignature);
    vWriter.WriteInteger(cEventsVersion);

    vWriter.WriteInteger(FEvents.Count);
    for vInt1 := 0 to Pred(FEvents.Count) do
    begin
      vEvent := TRALRESTDWEventServer(FEvents.Items[vInt1]);

      vWriter.WriteString(vEvent.BaseURL);
      vWriter.WriteString(vEvent.DefaultContentType);
      vWriter.WriteString(vEvent.EventName);
      vWriter.WriteString(vEvent.Description.Text);
      vWriter.WriteByte(Ord(vEvent.DataMode));
      vWriter.WriteBoolean(vEvent.CallbackEvent);
      vWriter.WriteBoolean(vEvent.OnlyPreDefinedParams);

      WriteRoute(vEvent.Routes.All);
      WriteRoute(vEvent.Routes.Get);
      WriteRoute(vEvent.Routes.Post);
      WriteRoute(vEvent.Routes.Put);
      WriteRoute(vEvent.Routes.Patch);
      WriteRoute(vEvent.Routes.Delete);
      WriteRoute(vEvent.Routes.Option);

      vWriter.WriteInteger(vEvent.Params.Count);
      for vInt2 := 0 to Pred(vEvent.Params.Count) do
      begin
        vParam := vEvent.Params.Items[vInt2];

        vWriter.WriteString(vParam.Alias);
        vWriter.WriteString(vParam.DefaultValue);
        vWriter.WriteBoolean(vParam.Encoded);
        vWriter.WriteString(vParam.ParamName);
        vWriter.WriteByte(Ord(vParam.ObjectDirection));
        vWriter.WriteByte(Ord(vParam.ObjectValue));
        vWriter.WriteByte(Ord(vParam.TypeObject));
        vWriter.WriteByte(Ord(vParam.DataMode));
      end;
    end;
    Result.Position := 0;
  finally
    FreeAndNil(vWriter);
  end;
end;

procedure TRALRESTDWServerEvents.ExportEvents(AWriter: TRALBinaryWriter);
var
  vInt1, vInt2: IntegerRAL;
  vEvent: TRALRESTDWEventServer;
  vParam: TRALRESTDWParamMethod;
begin
  AWriter.WriteInteger(FEvents.Count);
  for vInt1 := 0 to Pred(FEvents.Count) do
  begin
    vEvent := TRALRESTDWEventServer(FEvents.Items[vInt1]);

    AWriter.WriteString(vEvent.EventName);
    AWriter.WriteString(vEvent.GetRoute);
    AWriter.WriteString(vEvent.Description.Text);
    AWriter.WriteBoolean(vEvent.CallbackEvent);
    // os verbos, para a rota importada nascer com o AllowedMethods certo
    AWriter.WriteBoolean(vEvent.Routes.All.Active);
    AWriter.WriteBoolean(vEvent.Routes.Get.Active);
    AWriter.WriteBoolean(vEvent.Routes.Post.Active);
    AWriter.WriteBoolean(vEvent.Routes.Put.Active);
    AWriter.WriteBoolean(vEvent.Routes.Patch.Active);
    AWriter.WriteBoolean(vEvent.Routes.Delete.Active);
    AWriter.WriteBoolean(vEvent.Routes.Option.Active);

    AWriter.WriteInteger(vEvent.Params.Count);
    for vInt2 := 0 to Pred(vEvent.Params.Count) do
    begin
      vParam := vEvent.Params.Items[vInt2];

      AWriter.WriteString(vParam.ParamName);
      AWriter.WriteByte(Ord(vParam.ObjectValue));
      AWriter.WriteByte(Ord(vParam.ObjectDirection));
    end;
  end;
end;

function TRALRESTDWServerEvents.CanAnswerEvent(ARequest: TRALRequest;
  const ADomain: StringRAL): TRALRESTDWEventServer;
var
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEventServer;
  vQuery: StringRAL;
begin
  Result := nil;

  { A rota do evento nao carrega o Domain do modulo, mas a query da requisicao
    carrega. A comparacao ignora a caixa porque o casamento de rota do proprio
    RAL ignora - SameText e nao o RALSameName do RALTools de proposito: aquele e
    de 2026-09-10 e amarraria este pacote a um PascalRAL das ultimas horas. Aqui
    roda uma vez por requisicao, sobre um punhado de eventos, entao a conversao
    que o SameText faz no Delphi nao pesa. }
  vQuery := FixRoute(ARequest.Query);

  for vInt1 := 0 to Pred(FEvents.Count) do
  begin
    vEvent := TRALRESTDWEventServer(FEvents.Items[vInt1]);
    if SameText(FixRoute(ADomain + '/' + vEvent.GetRoute), vQuery) and
       vEvent.Routes.RouteIsActive(ARequest.Method) then
    begin
      Result := vEvent;
      Break;
    end;
  end;
end;

function TRALRESTDWServerEvents.ExecuteEvent(ARequest: TRALRequest;
  AResponse: TRALResponse; AModule: TComponent; const ADomain: StringRAL): boolean;
var
  vEvent: TRALRESTDWEventServer;
begin
  vEvent := CanAnswerEvent(ARequest, ADomain);

  // nada casou pela rota: o DefaultEvent e a ultima chance, como no RDW
  if (vEvent = nil) and (FDefaultEvent <> '') then
    vEvent := TRALRESTDWEventServer(FEvents.EventByName[FDefaultEvent]);

  Result := vEvent <> nil;
  if Result then
    vEvent.ReplyEvent(ARequest, AResponse, AModule, FIgnoreInvalidParams);
end;

end.
