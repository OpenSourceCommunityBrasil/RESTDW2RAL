unit RALRESTDWParams;

interface

uses
  Classes, SysUtils, Variants, TypInfo,
  RALTypes, RALRESTDWTypes, RALRequest, RALResponse, RALParams, RALJson,
  RALBase64;

type

  { TRALRESTDWJSONParam }

  TRALRESTDWJSONParam = class(TPersistent)
  private
    FTypeObject: TRALRESTDWTypeObject;
    FObjectDirection: TRALRESTDWObjectDirection;
    FObjectValue: TRALRESTDWObjectValue;
    FParamName: StringRAL;
    FAlias: StringRAL;
    FValue: variant;
    FEncoded: boolean;
  protected
    procedure AssignTo(ADest: TPersistent); override;

    procedure SetDataValue(AValue: variant; ADataType: TRALRESTDWObjectValue);

    function GetAsBase64 : StringRAL;
    function GetAsAnsiString: ansistring;
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
    procedure SetAsAnsiString(AValue: ansistring);
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

    function ToJSONObject: TRALJSONObject;
    function ToJSON: StringRAL;
  published
    property TypeObject: TRALRESTDWTypeObject read FTypeObject write FTypeObject;
    property ObjectDirection: TRALRESTDWObjectDirection read FObjectDirection write FObjectDirection;
    property ObjectValue: TRALRESTDWObjectValue read FObjectValue write FObjectValue;
    property ParamName: StringRAL read FParamName write FParamName;
    property Alias: StringRAL read FAlias write FAlias;
    property Value: variant read FValue write FValue;
    property Encoded: boolean read FEncoded write FEncoded;

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
  end;

  { TRALRESTDWParams }

  TRALRESTDWParams = class
  private
    FParams: TList;
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
    procedure AppendResponse(AResponse: TRALResponse);

    property Items[AIndex: IntegerRAL]: TRALRESTDWJSONParam read GetParamIndex write SetParamIndex;
    property ItemsString[AName: StringRAL]: TRALRESTDWJSONParam read GetParamName write SetParamName;
  end;

implementation

{ TRALRESTDWJSONParam }

function TRALRESTDWJSONParam.GetAsAnsiString: ansistring;
begin

end;

function TRALRESTDWJSONParam.GetAsBCD: currency;
begin

end;

function TRALRESTDWJSONParam.GetAsBoolean: boolean;
begin

end;

function TRALRESTDWJSONParam.GetAsCurrency: currency;
begin

end;

function TRALRESTDWJSONParam.GetAsDateTime: TDateTime;
begin

end;

function TRALRESTDWJSONParam.GetAsFloat: double;
begin

end;

function TRALRESTDWJSONParam.GetAsFMTBCD: currency;
begin

end;

function TRALRESTDWJSONParam.GetAsInteger: integer;
begin

end;

function TRALRESTDWJSONParam.GetAsLargeInt: Int64;
begin

end;

function TRALRESTDWJSONParam.GetAsLongWord: longword;
begin

end;

function TRALRESTDWJSONParam.GetAsSingle: single;
begin

end;

function TRALRESTDWJSONParam.GetAsString: string;
begin

end;

function TRALRESTDWJSONParam.GetAsWideString: WideString;
begin

end;

function TRALRESTDWJSONParam.GetAsWord: word;
begin

end;

function TRALRESTDWJSONParam.GetByteString: string;
begin

end;

procedure TRALRESTDWJSONParam.SetAsAnsiString(AValue: ansistring);
begin

end;

procedure TRALRESTDWJSONParam.SetAsBCD(AValue: currency);
begin

end;

procedure TRALRESTDWJSONParam.SetAsBoolean(AValue: boolean);
begin

end;

procedure TRALRESTDWJSONParam.SetAsCurrency(AValue: currency);
begin

end;

procedure TRALRESTDWJSONParam.SetAsDate(AValue: TDateTime);
begin

end;

procedure TRALRESTDWJSONParam.SetAsDateTime(AValue: TDateTime);
begin

end;

procedure TRALRESTDWJSONParam.SetAsFloat(AValue: double);
begin

end;

procedure TRALRESTDWJSONParam.SetAsFMTBCD(AValue: currency);
begin

end;

procedure TRALRESTDWJSONParam.SetAsInteger(AValue: integer);
begin

end;

procedure TRALRESTDWJSONParam.SetAsLargeInt(AValue: Int64);
begin

end;

procedure TRALRESTDWJSONParam.SetAsLongWord(AValue: longword);
begin

end;

procedure TRALRESTDWJSONParam.SetAsObject(AValue: string);
begin

end;

procedure TRALRESTDWJSONParam.SetAsShortInt(AValue: integer);
begin

end;

procedure TRALRESTDWJSONParam.SetAsSingle(AValue: single);
begin

end;

procedure TRALRESTDWJSONParam.SetAsSmallInt(AValue: integer);
begin

end;

procedure TRALRESTDWJSONParam.SetAsString(AValue: string);
begin
  SetDataValue(AValue, ovString);
end;

procedure TRALRESTDWJSONParam.SetAsTime(AValue: TDateTime);
begin

end;

procedure TRALRESTDWJSONParam.SetAsWideString(AValue: wideString);
begin

end;

procedure TRALRESTDWJSONParam.SetAsWord(AValue: word);
begin

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
      Value := Self.Value;
    end;
  end;
end;

procedure TRALRESTDWJSONParam.SetDataValue(AValue: variant; ADataType: TRALRESTDWObjectValue);
var
  vMem: TMemoryStream;
  vPointer: Pointer;
begin
{
  FObjectValue := ADataType;
  case ADataType Of
    ovBytes,
    ovVarBytes,
    ovBlob,
    ovByte,
    ovGraphic,
    ovParadoxOle,
    ovDBaseOle,
    ovTypedBinary,
    ovOraBlob,
    ovOraClob,
    ovStream : begin
      vMem := TMemoryStream.Create;
      try
        vPointer := VarArrayLock(AValue);
        vMem.Write(vPointer^, VarArrayHighBound(AValue, 1));
        VarArrayUnlock(AValue);
        vMem.Position := 0;
        if vMem.Size > 0 then
          LoadFromStream(vMem);
      finally
        vMem.Free;
      end;
    end;
    ovVariant,
    ovUnknown : begin
      FEncoded := True;
      FObjectValue := ovString;
//      SetValue(AValue, FEncoded);
    end;
    ovLargeInt,
    ovLongWord,
    ovShortInt,
    ovSmallInt,
    ovInteger,
    ovWord,
    ovBoolean,
    ovAutoInc,
    ovOraInterval : begin
      FEncoded := False;
      if FObjectValue = ovBoolean then
      begin
        if Boolean(AValue) then
          SetValue('true', FEncoded)
        else
          SetValue('false', FEncoded);
      end
      else
      begin
        {$IFNDEF FPC}
          {$if CompilerVersion <= 22}
            SetValue(inttostr(Value), vEncoded);
          {$ELSE}
            if vObjectValue <> ovInteger then
              SetValue(IntToStr(Int64(Value)), vEncoded)
            else
              SetValue(inttostr(Value), vEncoded);
          {$IFEND}
        {$ELSE}
                           If vObjectValue <> ovInteger Then
                            SetValue(IntToStr(Int64(Value)), vEncoded)
                           Else
                            SetValue(inttostr(Value), vEncoded);
                          {$ENDIF}
      end;
    end;
    ovSingle,
    ovFloat,
    ovCurrency,
    ovBCD,
    ovFMTBcd,
    ovExtended : begin
      FEncoded     := False;
      FObjectValue := ovFloat;
      SetValue(BuildStringFloat(FloatToStr(Value), DataMode, vFloatDecimalFormat), vEncoded);
    end;
    ovDate,
    ovTime,
    ovDateTime,
    ovTimeStamp,
    ovOraTimeStamp,
    ovTimeStampOffset : begin
      FEncoded     := False;
      FObjectValue := ovFloat;
      SetValue(BuildStringFloat(FloatToStr(Value), DataMode, vFloatDecimalFormat), vEncoded);
    end;
    ovString,
    ovFixedChar,
    ovWideString,
    ovWideMemo,
    ovFixedWideChar,
    ovMemo,
    ovFmtMemo,
    ovObject : begin
      if vObjectValue <> ovObject then
        FObjectValue := ovString
      else
        FObjectValue := ovObject;
        SetValue(AValue, vEncoded);
    end;
  end;
}
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
  vRALParam : TRALParam;
begin
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if (vParam.ObjectDirection in [odIN, odINOUT]) then
    begin
      vRALParam := ARequest.ParamByName(vParam.ParamName);
      if vRALParam <> nil then
        vParam.Value := vRALParam.AsString;
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
      AResponse.Params.AddParam(vParam.ParamName, vParam.AsString, rpkBODY);
  end;
end;

end.
