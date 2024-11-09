unit RALRESTDWServerEvents;

interface

uses
  Classes, SysUtils,
  RALCustomObjects, RALTypes, RALRequest, RALRESTDWParamsMethods,
  RALStream, RALRESTDWEvents;

type

  { TRALRESTDWServerEvents }

  TRALRESTDWServerEvents = Class(TRALComponent)
  private
    FEvents: TRALRESTDWEventList;
    FAccessTag: StringRAL;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    function GetEvents : TStream;

    function CanAnswerEvent(ARequest: TRALRequest): TRALRESTDWEvent;
  published
    property Events : TRALRESTDWEventList read FEvents write FEvents;
    property AccessTag : StringRAL read FAccessTag write FAccessTag;
  end;

implementation

{ TRALRESTDWServerEvents }

constructor TRALRESTDWServerEvents.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEvents := TRALRESTDWEventList.Create(Self);
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
  vEvent: TRALRESTDWEvent;
  vParam: TRALRESTDWParamMethod;
begin
  Result := TMemoryStream.Create;

  vWriter := TRALBinaryWriter.Create(Result);
  try
    vWriter.WriteInteger(FEvents.Count);
    for vInt1 := 0 to Pred(FEvents.Count) do
    begin
      vEvent := TRALRESTDWEvent(FEvents.Items[vInt1]);

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

function TRALRESTDWServerEvents.CanAnswerEvent(ARequest: TRALRequest): TRALRESTDWEvent;
var
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEvent;
begin
  Result := nil;
  for vInt1 := 0 to Pred(FEvents.Count) do
  begin
    vEvent := TRALRESTDWEvent(FEvents.Items[vInt1]);
    if vEvent.GetRoute = ARequest.Query then
    begin
      Result := vEvent;
      Break;
    end;
  end;
end;

end.
