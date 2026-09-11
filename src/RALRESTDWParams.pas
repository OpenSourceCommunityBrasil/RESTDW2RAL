unit RALRESTDWParams;

interface

uses
  Classes, SysUtils, Variants, TypInfo,
  RALTypes, RALRESTDWTypes, RALRequest, RALResponse, RALParams, RALJson,
  RALBase64, RALStream;

type

  { TRALRESTDWJSONParam }

  TRALRESTDWJSONParam = class(TPersistent)
  private
    FTypeObject: TRALRESTDWTypeObject;
    FObjectDirection: TRALRESTDWObjectDirection;
    FObjectValue: TRALRESTDWObjectValue;
    FParamName: StringRAL;
    FAlias: StringRAL;
    FValue: TStream;
    FEncoded: boolean;
  protected
    procedure AssignTo(ADest: TPersistent); override;

    function GetAsStream: TStream;
    function GetAsBase64 : StringRAL;
    function GetAsAnsiString: AnsiString;
    function GetAsBCD: currency;
    function GetAsBoolean: boolean;
    function GetAsCurrency: currency;
    function GetAsDateTime: TDateTime;
    function GetAsFloat: double;
    function GetAsFMTBCD: currency;
    function GetAsInteger: integer;
    function GetAsLargeInt: Int64;
    function GetAsLongWord: longword;
    function GetAsSingle: single;
    function GetAsString: string;
    function GetAsWideString: WideString;
    function GetAsWord: word;
    function GetByteString: string;
    procedure SetAsStream(const AValue: TStream);
    procedure SetAsAnsiString(AValue: AnsiString);
    procedure SetAsBCD(AValue: currency);
    procedure SetAsBoolean(AValue: boolean);
    procedure SetAsCurrency(AValue: currency);
    procedure SetAsDate(AValue: TDateTime);
    procedure SetAsDateTime(AValue: TDateTime);
    procedure SetAsFloat(AValue: double);
    procedure SetAsFMTBCD(AValue: currency);
    procedure SetAsInteger(AValue: integer);
    procedure SetAsLargeInt(AValue: Int64);
    procedure SetAsLongWord(AValue: longword);
    procedure SetAsObject(AValue: string);
    procedure SetAsShortInt(AValue: integer);
    procedure SetAsSingle(AValue: single);
    procedure SetAsSmallInt(AValue: integer);
    procedure SetAsString(AValue: string);
    procedure SetAsTime(AValue: TDateTime);
    procedure SetAsWideString(AValue: wideString);
    procedure SetAsWord(AValue: word);
    procedure SetAsBase64(AValue: StringRAL);
  public
    constructor Create;
    destructor Destroy; override;

    function ToJSONObject: TRALJSONObject;
    function ToJSON: StringRAL;

    procedure SaveToStream(AStream: TStream); overload;
    function SaveToStream : TStream; overload;
    procedure LoadFromStream(AStream: TStream);

    function IsNull : Boolean;
    function IsEmpty : Boolean;
  published
    property TypeObject: TRALRESTDWTypeObject read FTypeObject write FTypeObject;
    property ObjectDirection: TRALRESTDWObjectDirection read FObjectDirection write FObjectDirection;
    property ObjectValue: TRALRESTDWObjectValue read FObjectValue write FObjectValue;
    property ParamName: StringRAL read FParamName write FParamName;
    property Alias: StringRAL read FAlias write FAlias;
    property Encoded: boolean read FEncoded write FEncoded;
    property Value: TStream read FValue;

    property AsBCD: currency read GetAsBCD write SetAsBCD;
    property AsFMTBCD: currency read GetAsFMTBCD write SetAsFMTBCD;
    property AsBoolean: boolean read GetAsBoolean write SetAsBoolean;
    property AsCurrency: currency read GetAsCurrency write SetAsCurrency;
    property AsExtended: currency read GetAsCurrency write SetAsCurrency;
    property AsDate: TDateTime read GetAsDateTime write SetAsDate;
    property AsTime: TDateTime read GetAsDateTime write SetAsTime;
    property AsDateTime: TDateTime read GetAsDateTime write SetAsDateTime;
    property AsSingle: single read GetAsSingle write SetAsSingle;
    property AsFloat: double read GetAsFloat write SetAsFloat;
    property AsInteger: integer read GetAsInteger write SetAsInteger;
    property AsSmallInt: integer read GetAsInteger write SetAsSmallInt;
    property AsShortInt: integer read GetAsInteger write SetAsShortInt;
    property AsWord: word read GetAsWord write SetAsWord;
    property AsLongWord: longword read GetAsLongWord write SetAsLongWord;
    property AsLargeInt: int64 read GetAsLargeInt write SetAsLargeInt;
    property AsString: string read GetAsString write SetAsString;
    property AsObject: string read GetAsString write SetAsObject;
    property AsByteString: string read GetByteString;
    property AsWideString: WideString read GetAsWideString write SetAsWideString;
    property AsAnsiString: ansistring read GetAsAnsiString write SetAsAnsiString;
    property AsMemo: string read GetAsString write SetAsString;
    property AsBase64: StringRAL read GetAsBase64 write SetAsBase64;
    property AsStream: TStream read GetAsStream write SetAsStream;
  end;

  { TRALRESTDWParams }

  TRALRESTDWParams = class
  private
    FParams: TList;
    FRequest: TRALRequest;
    FModule: TComponent;
  protected
    procedure ClearParams;

    function GetParamIndex(AIndex: IntegerRAL): TRALRESTDWJSONParam;
    function GetParamName(AName: StringRAL): TRALRESTDWJSONParam;
    procedure SetParamIndex(AIndex: IntegerRAL; AValue: TRALRESTDWJSONParam);
    procedure SetParamName(AName: StringRAL; AValue: TRALRESTDWJSONParam);
  public
    constructor Create;
    destructor Destroy; override;

    function Count: integer;
    function NewParam: TRALRESTDWJSONParam;

    procedure AssignRequest(ARequest: TRALRequest);
    procedure AppendRequest(ARequest: TRALRequest);

    procedure AssignResponse(AResponse: TRALResponse);
    procedure AppendResponse(AResponse: TRALResponse);

    property Items[AIndex: IntegerRAL]: TRALRESTDWJSONParam read GetParamIndex write SetParamIndex;
    property ItemsString[AName: StringRAL]: TRALRESTDWJSONParam read GetParamName write SetParamName;
  published
    property Request : TRALRequest read FRequest write FRequest;
    property Module : TComponent read FModule write FModule;
  end;

implementation

{ TRALRESTDWJSONParam }

function TRALRESTDWJSONParam.GetAsAnsiString: ansistring;
begin
  Result := StreamToString(FValue)
end;

function TRALRESTDWJSONParam.GetAsBCD: currency;
begin
  Result := StrToCurrDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsBoolean: boolean;
var
  vStr : StringRAL;
begin
  vStr := StreamToString(FValue);
  Result := (vStr = '1') or (SameText(vStr, 'true'));
end;

function TRALRESTDWJSONParam.GetAsCurrency: currency;
begin
  Result := StrToCurrDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsDateTime: TDateTime;
begin
  Result := StrToFloatDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsFloat: double;
begin
  Result := StrToFloatDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsFMTBCD: currency;
begin
  Result := StrToCurrDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsInteger: integer;
begin
  Result := StrToIntDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsLargeInt: Int64;
begin
  Result := StrToInt64Def(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsLongWord: longword;
begin
  Result := StrToInt64Def(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsSingle: single;
begin
  Result := StrToFloatDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsStream: TStream;
begin
  Result := SaveToStream;
end;

function TRALRESTDWJSONParam.GetAsString: string;
begin
  Result := StreamToString(FValue);
end;

function TRALRESTDWJSONParam.GetAsWideString: WideString;
begin
  Result := WideString(StreamToString(FValue));
end;

function TRALRESTDWJSONParam.GetAsWord: word;
begin
  Result := StrToIntDef(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetByteString: string;
begin
  Result := StreamToString(FValue);
end;

function TRALRESTDWJSONParam.IsEmpty: Boolean;
begin
  Result := (FValue <> nil) and (FValue.Size = 0);
end;

function TRALRESTDWJSONParam.IsNull: Boolean;
begin
  Result := FValue = nil;
end;

procedure TRALRESTDWJSONParam.LoadFromStream(AStream: TStream);
begin
  FObjectValue := ovStream;

  if FValue <> nil then
    FreeAndNil(FValue);

  AStream.Position := 0;

  FValue := TRALStringStream.Create(AStream);
  FValue.Position := 0;
end;

procedure TRALRESTDWJSONParam.SaveToStream(AStream: TStream);
begin
  if (FValue = nil) or (FValue.Size = 0) then
    Exit;

  FValue.Position := 0;
  AStream.CopyFrom(FValue, FValue.Size);
end;

function TRALRESTDWJSONParam.SaveToStream: TStream;
begin
  Result := TRALStringStream.Create;
  SaveToStream(Result);

  Result.Position := 0;
end;

procedure TRALRESTDWJSONParam.SetAsAnsiString(AValue: ansistring);
begin
  FObjectValue := ovString;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsBCD(AValue: currency);
begin
  FObjectValue := ovBCD;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(CurrToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsBoolean(AValue: boolean);
begin
  FObjectValue := ovBoolean;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(BooleanToString(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsCurrency(AValue: currency);
begin
  FObjectValue := ovCurrency;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(CurrToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsDate(AValue: TDateTime);
begin
  FObjectValue := ovDate;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(DateToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsDateTime(AValue: TDateTime);
begin
  FObjectValue := ovDateTime;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(DateTimeToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsFloat(AValue: double);
begin
  FObjectValue := ovFloat;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(FloatToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsFMTBCD(AValue: currency);
begin
  FObjectValue := ovFMTBcd;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(CurrToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsInteger(AValue: integer);
begin
  FObjectValue := ovInteger;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsLargeInt(AValue: Int64);
begin
  FObjectValue := ovLargeint;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsLongWord(AValue: longword);
begin
  FObjectValue := ovLongWord;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsObject(AValue: string);
begin
  FObjectValue := ovObject;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsShortInt(AValue: integer);
begin
  FObjectValue := ovShortint;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsSingle(AValue: single);
begin
  FObjectValue := ovSingle;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(FloatToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsSmallInt(AValue: integer);
begin
  FObjectValue := ovSmallint;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsStream(const AValue: TStream);
begin
  LoadFromStream(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsString(AValue: string);
begin
  FObjectValue := ovString;

  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsTime(AValue: TDateTime);
begin
  FObjectValue := ovTime;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(TimeToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsWideString(AValue: wideString);
begin
  FObjectValue := ovWideString;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsWord(AValue: word);
begin
  FObjectValue := ovWord;
  if FValue <> nil then
    FreeAndNil(FValue);

  FValue := StringToStreamUTF8(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsBase64(AValue: StringRAL);
begin
  SetAsString(TRALBase64.Decode(AValue));
end;

constructor TRALRESTDWJSONParam.Create;
begin
  inherited Create;
  FObjectDirection := odINOUT;
  FTypeObject := toParam;
  FEncoded := False;
  FObjectValue := ovString;
  FValue := nil;
end;

destructor TRALRESTDWJSONParam.Destroy;
begin
  FreeAndNil(FValue);
  inherited;
end;

function TRALRESTDWJSONParam.ToJSONObject: TRALJSONObject;
begin
  Result := TRALJSONObject.Create;
  Result.Add('ObjectType', GetEnumName(TypeInfo(TRALRESTDWTypeObject), Ord(FTypeObject)));
  Result.Add('Direction', GetEnumName(TypeInfo(TRALRESTDWObjectDirection), Ord(FObjectDirection)));
  Result.Add('Encoded', BooleanToString(FEncoded));
  Result.Add('ValueType', GetEnumName(TypeInfo(TRALRESTDWObjectValue), Ord(FObjectValue)));
  if FEncoded then
    Result.Add(FParamName, GetAsBase64)
  else
    Result.Add(FParamName, GetAsString);
end;

function TRALRESTDWJSONParam.ToJSON: StringRAL;
var
  vJson : TRALJSONObject;
begin
  vJson := ToJSONObject;
  try
    Result := vJson.ToJson;
  finally
    FreeAndNil(vJson);
  end;
end;

procedure TRALRESTDWJSONParam.AssignTo(ADest: TPersistent);
var
  vStream : TStream;
begin
  if ADest.InheritsFrom(TRALRESTDWJSONParam) then
  begin
    with ADest as TRALRESTDWJSONParam do
    begin
      TypeObject := Self.TypeObject;
      ObjectDirection := Self.ObjectDirection;
      ObjectValue := Self.ObjectValue;
      ParamName := Self.ParamName;
      Alias := Self.Alias;
      AsStream := Self.Value;
    end;
  end;
end;

function TRALRESTDWJSONParam.GetAsBase64: StringRAL;
begin
  Result := TRALBase64.Encode(GetAsString);
end;

{ TRALRESTDWParams }

function TRALRESTDWParams.GetParamIndex(AIndex: IntegerRAL): TRALRESTDWJSONParam;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < FParams.Count) then
    Result := TRALRESTDWJSONParam(FParams.Items[AIndex]);
end;

function TRALRESTDWParams.GetParamName(AName: StringRAL): TRALRESTDWJSONParam;
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
begin
  Result := nil;
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if (SameText(vParam.ParamName, AName)) or (SameText(vParam.Alias, AName)) then
    begin
      Result := vParam;
      Break;
    end;
  end;
end;

procedure TRALRESTDWParams.SetParamIndex(AIndex: IntegerRAL; AValue: TRALRESTDWJSONParam);
var
  vParam: TRALRESTDWJSONParam;
begin
  if (AIndex >= 0) and (AIndex < FParams.Count) then
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[AIndex]);
    vParam.AssignTo(AValue);
    FreeAndNil(AValue);
  end;
end;

procedure TRALRESTDWParams.SetParamName(AName: StringRAL; AValue: TRALRESTDWJSONParam);
var
  vParam: TRALRESTDWJSONParam;
begin
  vParam := GetParamName(AName);
  if vParam = nil then
    vParam := NewParam;

  vParam.Assign(AValue);

  FreeAndNil(AValue);
end;

procedure TRALRESTDWParams.ClearParams;
begin
  while FParams.Count > 0 do
  begin
    TObject(FParams.Items[FParams.Count - 1]).Free;
    FParams.Delete(FParams.Count - 1);
  end;
end;

constructor TRALRESTDWParams.Create;
begin
  inherited;
  FParams := TList.Create;
  FRequest := nil;
  FModule := nil;
end;

destructor TRALRESTDWParams.Destroy;
begin
  ClearParams;
  FreeAndNil(FParams);
  inherited;
end;

function TRALRESTDWParams.Count: integer;
begin
  Result := FParams.Count;
end;

function TRALRESTDWParams.NewParam: TRALRESTDWJSONParam;
begin
  Result := TRALRESTDWJSONParam.Create;
  FParams.Add(Result);
end;

procedure TRALRESTDWParams.AssignRequest(ARequest: TRALRequest);
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
  vRALParam: TRALParam;
begin
  FRequest := ARequest;
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if (vParam.ObjectDirection in [odIN, odINOUT]) then
    begin
      vRALParam := ARequest.ParamByName(vParam.ParamName);
      if vRALParam <> nil then
        vParam.AsStream := vRALParam.Content;
    end;
  end;
end;

procedure TRALRESTDWParams.AssignResponse(AResponse: TRALResponse);
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
  vRALParam: TRALParam;
begin
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if (vParam.ObjectDirection in [odOUT, odINOUT]) then
    begin
      // a resposta so traz o que o servidor devolveu: sem o teste, um param
      // ausente era um AV no cliente
      vRALParam := AResponse.ParamByName(vParam.ParamName);
      if vRALParam <> nil then
        vParam.AsStream := vRALParam.Content;
    end;
  end;
end;

procedure TRALRESTDWParams.AppendRequest(ARequest: TRALRequest);
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
  vRALParam : TRALParam;
begin
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if (vParam.ObjectDirection in [odIN, odINOUT]) then
    begin
      vRALParam := ARequest.ParamByName(vParam.ParamName);
      if vRALParam = nil then
      begin
        vRALParam := ARequest.Params.NewParam;
        vRALParam.ParamName := vParam.ParamName;
      end;
      vRALParam.AsStream := vParam.Value;
      vRALParam.Kind := rpkBODY;
    end;
  end;
end;

procedure TRALRESTDWParams.AppendResponse(AResponse: TRALResponse);
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
begin
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if (vParam.ObjectDirection in [odOUT, odINOUT]) then
      AResponse.Params.AddParam(vParam.ParamName, vParam.Value, rpkBODY);
  end;
end;

end.
