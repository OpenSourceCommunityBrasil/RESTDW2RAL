unit RALRESTDWServerEvents;

interface

uses
  Classes, SysUtils,
  RALCustomObjects, RALTypes, RALRequest, RALRESTDWParamsMethods,
  RALStream, RALTools, RALRESTDWEvents;

type

  { TRALRESTDWServerEvents }

  TRALRESTDWServerEvents = Class(TRALComponent)
  private
    FEvents: TRALRESTDWEventList;
    FAccessTag: StringRAL;
  protected
    procedure SetEventList(const AValue: TRALRESTDWEventList);
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    /// return events to clientevents
    function GetEvents : TStream;
    /// return events to binary
    procedure ExportEvents(AWriter: TRALBinaryWriter);

    function CanAnswerEvent(ARequest: TRALRequest;
                            const ADomain: StringRAL = '/'): TRALRESTDWEventServer;
  published
    property Events : TRALRESTDWEventList read FEvents write SetEventList;
    property AccessTag : StringRAL read FAccessTag write FAccessTag;
  end;

implementation

{ TRALRESTDWServerEvents }

constructor TRALRESTDWServerEvents.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEvents := TRALRESTDWEventList.Create(Self);
end;

procedure TRALRESTDWServerEvents.SetEventList(const AValue: TRALRESTDWEventList);
begin
  FEvents.Assign(AValue);
end;

destructor TRALRESTDWServerEvents.Destroy;
begin
  FreeAndNil(FEvents);
  inherited Destroy;
end;

function TRALRESTDWServerEvents.GetEvents: TStream;
var
  vWriter: TRALBinaryWriter;
  vInt1, vInt2: IntegerRAL;
  vEvent: TRALRESTDWEventServer;
  vParam: TRALRESTDWParamMethod;
begin
  Result := TMemoryStream.Create;

  vWriter := TRALBinaryWriter.Create(Result);
  try
    vWriter.WriteInteger(FEvents.Count);
    for vInt1 := 0 to Pred(FEvents.Count) do
    begin
      vEvent := TRALRESTDWEventServer(FEvents.Items[vInt1]);

      vWriter.WriteString(vEvent.BaseURL);
      vWriter.WriteString(vEvent.DefaultContentType);
      vWriter.WriteString(vEvent.EventName);

      vWriter.WriteInteger(vEvent.Params.Count);
      for vInt2 := 0 to Pred(vEvent.Params.Count) do
      begin
        vParam := TRALRESTDWParamMethod(vEvent.Params.Items[vInt2]);

        vWriter.WriteString(vParam.Alias);
        vWriter.WriteString(vParam.DefaultValue);
        vWriter.WriteBoolean(vParam.Encoded);
        vWriter.WriteString(vParam.ParamName);
        vWriter.WriteByte(Ord(vParam.ObjectDirection));
        vWriter.WriteByte(Ord(vParam.ObjectValue));
        vWriter.WriteByte(Ord(vParam.TypeObject));
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

    AWriter.WriteInteger(vEvent.Params.Count);
    for vInt2 := 0 to Pred(vEvent.Params.Count) do
    begin
      vParam := TRALRESTDWParamMethod(vEvent.Params.Items[vInt2]);

      AWriter.WriteString(vParam.ParamName);
      AWriter.WriteByte(Ord(vParam.ObjectValue));
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

  { a rota do evento nao carrega o Domain do modulo, mas a query da requisicao
    carrega. RALSameName porque o casamento de rota do proprio RAL ignora a caixa }
  vQuery := FixRoute(ARequest.Query);

  for vInt1 := 0 to Pred(FEvents.Count) do
  begin
    vEvent := TRALRESTDWEventServer(FEvents.Items[vInt1]);
    if RALSameName(FixRoute(ADomain + '/' + vEvent.GetRoute), vQuery) then
    begin
      Result := vEvent;
      Break;
    end;
  end;
end;

end.
