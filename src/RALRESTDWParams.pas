/// The RDW-shaped parameter container, over PascalRAL's TRALParams.
///
/// The public surface mirrors REST Dataware's TRESTDWParams/TRESTDWJSONParam so
/// that the body of an existing event handler compiles and behaves the same.
unit RALRESTDWParams;

interface

uses
  Classes, SysUtils, Variants, TypInfo, DB,
  RALTypes, RALRESTDWTypes, RALRequest, RALResponse, RALParams, RALJson,
  RALBase64, RALStream, RALStorage, RALStorageBIN;

type

  { So o AppendTo usa - e o que faz o append do request e o do response
    serem a mesma rotina. }
  TRALRESTDWDirections = set of TRALRESTDWObjectDirection;

  { TRALRESTDWJSONParam }

  TRALRESTDWJSONParam = class(TPersistent)
  private
    { Existe porque o codigo do RDW atribui Encoding em valor que ele mesmo
      cria. O RAL fala UTF-8 sempre, entao o valor e guardado e ignorado. }
    FEncoding: TRALRESTDWEncodeSelect;
    { Aceito e inerte: o RAL escreve UTF-8 sempre, entao nao ha o que ligar. }
    FUtf8SpecialChars: Boolean;
    FTypeObject: TRALRESTDWTypeObject;
    FObjectDirection: TRALRESTDWObjectDirection;
    FObjectValue: TRALRESTDWObjectValue;
    FParamName: StringRAL;
    FAlias: StringRAL;
    FParamFileName: StringRAL;
    FParamContentType: StringRAL;
    FFloatDecimalFormat: StringRAL;
    FDataMode: TRALRESTDWDataMode;
    FDefaultValue: Variant;
    FValue: TStream;
    FEncoded: boolean;
  protected
    procedure AssignTo(ADest: TPersistent); override;

    { Writes the payload without touching ObjectValue.

      Every SetAs* stamps the type it just wrote - which is right when the
      application says "this is an integer", and wrong for the paths that only
      carry a value across (cloning a declared param, reading the wire, applying
      a DefaultValue): those used to flatten the declared type to ovString. }
    procedure StoreText(const AValue: StringRAL);
    procedure StoreStream(AStream: TStream);

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
    function GetBinary: boolean;
    function GetVariantValue: Variant;
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
    procedure SetVariantValue(const AValue: Variant);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    function ToJSONObject: TRALJSONObject;
    function ToJSON: StringRAL;
    procedure FromJSON(const AJSON: StringRAL);

    procedure SaveToStream(AStream: TStream); overload;
    function SaveToStream : TStream; overload;
    procedure LoadFromStream(AStream: TStream);
    procedure SaveToFile(const AFileName: StringRAL);
    procedure LoadFromFile(const AFileName: StringRAL);

    { Sets the payload and keeps the declared ObjectValue - the RDW SetValue }
    procedure SetValue(const AValue: StringRAL); overload;
    procedure SetValue(AValue: TStream); overload;

    procedure CopyFrom(ASource: TRALRESTDWJSONParam);

    /// TParam bridge, so a handler can feed a query straight from a param
    procedure LoadFromParam(AParam: TParam);
    procedure SaveFromParam(AParam: TParam);

    { Dataset payload (TypeObject = toDataset).

      Serialized with PascalRAL's own storage (BIN), which is what TRALDBModule
      uses, so the bytes are readable by any RAL dataset consumer. }
    procedure LoadFromDataSet(ADataSet: TDataSet); overload;
    { A forma do RDW, com os seis argumentos. TableName so rotula o conteudo;
      EncodedValue, o formato de data e o separador decimal nao entram porque
      o dataset do RAL viaja binario, onde numero e data tem tipo proprio e
      nao dependem de formatacao nenhuma - que e justamente o que torna a
      chamada imune ao locale da maquina. }
    procedure LoadFromDataset(ATableName: StringRAL; ADataSet: TDataSet;
                              AEncodedValue: Boolean = True;
                              ADataMode: TRALRESTDWDataMode = dmDataware;
                              const ADateTimeFormat: StringRAL = '';
                              const ADelimiterFormat: StringRAL = ''); overload;
    procedure SaveToDataSet(ADataSet: TDataSet);

    /// Writes this param into a RAL param, typed when the declared type has a
    /// binary form. Text and binary payloads travel as a stream, as before.
    procedure WriteToRALParam(AParam: TRALParam);
    /// Reads a RAL param back into this one, honouring the typed marker
    procedure ReadFromRALParam(AParam: TRALParam);

    function IsNull : Boolean;
    function IsEmpty : Boolean;
    function TestNilParam : Boolean;
    function Size : Int64;
  published
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
    property Utf8SpecialChars: Boolean read FUtf8SpecialChars
      write FUtf8SpecialChars default True;
      // inerte: o RAL escreve UTF-8 sempre
    property TypeObject: TRALRESTDWTypeObject read FTypeObject write FTypeObject;
    property ObjectDirection: TRALRESTDWObjectDirection read FObjectDirection write FObjectDirection;
    property ObjectValue: TRALRESTDWObjectValue read FObjectValue write FObjectValue;
    property ParamName: StringRAL read FParamName write FParamName;
    property Alias: StringRAL read FAlias write FAlias;
    property ParamFileName: StringRAL read FParamFileName write FParamFileName;
    property ParamContentType: StringRAL read FParamContentType write FParamContentType;
    property FloatDecimalFormat: StringRAL read FFloatDecimalFormat write FFloatDecimalFormat;
    property DataMode: TRALRESTDWDataMode read FDataMode write FDataMode;
    property Encoded: boolean read FEncoded write FEncoded;
    property Binary: boolean read GetBinary;
    property Value: Variant read GetVariantValue write SetVariantValue;
    property DefaultValue: Variant read FDefaultValue write FDefaultValue;
    property Content: TStream read FValue;

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
    FDataMode: TRALRESTDWDataMode;
  protected
    procedure ClearParams;

    function GetParamIndex(AIndex: IntegerRAL): TRALRESTDWJSONParam;
    function GetParamName(AName: StringRAL): TRALRESTDWJSONParam;
    function GetRawBody: TRALRESTDWJSONParam;
    procedure SetParamIndex(AIndex: IntegerRAL; AValue: TRALRESTDWJSONParam);
    procedure SetParamName(AName: StringRAL; AValue: TRALRESTDWJSONParam);
    /// Writes every param of the given directions into a RAL container
    procedure AppendTo(ARALParams: TRALParams; ADirections: TRALRESTDWDirections);
  public
    constructor Create;
    destructor Destroy; override;

    function Count: integer;
    function NewParam: TRALRESTDWJSONParam;
    /// Creates (or reuses) a param by name - the RDW CreateParam
    function CreateParam(const AParamName: StringRAL;
                         const AValue: StringRAL = ''): TRALRESTDWJSONParam;
    function Add(AItem: TRALRESTDWJSONParam): IntegerRAL;
    procedure Delete(AIndex: IntegerRAL); overload;
    procedure Delete(AParam: TRALRESTDWJSONParam); overload;
    procedure Clear;
    procedure CopyFrom(AParams: TRALRESTDWParams);

    function IndexOf(const AName: StringRAL): IntegerRAL;
    function CountInParams: IntegerRAL;
    function CountOutParams: IntegerRAL;
    /// True when at least one param comes back from the server
    function ParamsReturn: boolean;

    function ToJSON: StringRAL;
    procedure FromJSON(const AJSON: StringRAL);
    procedure SaveToFile(const AFileName: StringRAL);
    procedure LoadFromFile(const AFileName: StringRAL);

    /// Fills the container from a dataset/query TParams collection
    procedure LoadFromParams(AParams: TParams);
    /// And back, so a handler can hand the values straight to a query
    procedure SaveToParams(AParams: TParams);

    procedure AssignRequest(ARequest: TRALRequest);
    procedure AppendRequest(ARequest: TRALRequest);

    procedure AssignResponse(AResponse: TRALResponse);
    procedure AppendResponse(AResponse: TRALResponse);

    property Items[AIndex: IntegerRAL]: TRALRESTDWJSONParam read GetParamIndex write SetParamIndex; default;
    property ItemsString[AName: StringRAL]: TRALRESTDWJSONParam read GetParamName write SetParamName;
    /// The lone body param - what a handler's Result travelled as
    property RawBody: TRALRESTDWJSONParam read GetRawBody;
    /// The raw request being answered, for header, IP, cookie and the like
    property Request : TRALRequest read FRequest write FRequest;
    { The TRALRESTDWModule that dispatched this call. Typed as TComponent to
      keep this unit independent of the module; cast it when you need Server. }
    property Module : TComponent read FModule write FModule;
    property DataMode: TRALRESTDWDataMode read FDataMode write FDataMode;
  end;

implementation

{ TRALRESTDWJSONParam }

constructor TRALRESTDWJSONParam.Create;
begin
  inherited Create;
  FObjectDirection := odINOUT;
  FTypeObject := toParam;
  FEncoded := False;
  FObjectValue := ovString;
  FDataMode := dmRAW;
  FDefaultValue := Null;
  FEncoding := esUtf8;
  FUtf8SpecialChars := True;
  FValue := nil;
end;

destructor TRALRESTDWJSONParam.Destroy;
begin
  FreeAndNil(FValue);
  inherited;
end;

procedure TRALRESTDWJSONParam.Clear;
begin
  FreeAndNil(FValue);
end;

{ Conteudo vazio nao pode passar pelos construtores de TRALStringStream.

  Eles terminam em WriteBytes, que faz Write(ABytes[0], Length(ABytes)): com um
  array vazio isso indexa a posicao 0 de um array de tamanho 0. Sem range check
  e inofensivo, porque o Length e zero e nada e lido; com range check ligado - o
  padrao do Debug no IDE - e um ERangeError. E o caso corriqueiro: todo param
  declarado sem DefaultValue chega aqui com string vazia. }
procedure TRALRESTDWJSONParam.StoreText(const AValue: StringRAL);
begin
  FreeAndNil(FValue);

  if AValue = '' then
    FValue := TRALStringStream.Create
  else
    FValue := StringToStreamUTF8(AValue);

  FValue.Position := 0;
end;

procedure TRALRESTDWJSONParam.StoreStream(AStream: TStream);
begin
  FreeAndNil(FValue);
  if AStream = nil then
    Exit;

  AStream.Position := 0;
  if AStream.Size = 0 then
    FValue := TRALStringStream.Create
  else
    FValue := TRALStringStream.Create(AStream);

  FValue.Position := 0;
end;

procedure TRALRESTDWJSONParam.SetValue(const AValue: StringRAL);
begin
  StoreText(AValue);
end;

procedure TRALRESTDWJSONParam.SetValue(AValue: TStream);
begin
  StoreStream(AValue);
end;

function TRALRESTDWJSONParam.GetAsAnsiString: ansistring;
begin
  Result := StreamToString(FValue)
end;

function TRALRESTDWJSONParam.GetAsBCD: currency;
begin
  Result := RALRESTDWStrToCurr(StreamToString(FValue), 0);
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
  Result := RALRESTDWStrToCurr(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsDateTime: TDateTime;
begin
  Result := RALRESTDWStrToDateTime(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsFloat: double;
begin
  Result := RALRESTDWStrToFloat(StreamToString(FValue), 0);
end;

function TRALRESTDWJSONParam.GetAsFMTBCD: currency;
begin
  Result := RALRESTDWStrToCurr(StreamToString(FValue), 0);
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
  Result := RALRESTDWStrToFloat(StreamToString(FValue), 0);
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

function TRALRESTDWJSONParam.GetBinary: boolean;
begin
  Result := ObjectValueIsBinary(FObjectValue);
end;

function TRALRESTDWJSONParam.GetVariantValue: Variant;
begin
  if IsNull then
  begin
    Result := Null;
    Exit;
  end;

  case ObjectValueToParamType(FObjectValue) of
    rptInteger  : Result := GetAsInteger;
    rptInt64    : Result := GetAsLargeInt;
    rptDouble   : Result := GetAsFloat;
    rptCurrency : Result := GetAsCurrency;
    rptBoolean  : Result := GetAsBoolean;
    rptDateTime : Result := GetAsDateTime;
    else
      Result := GetAsString;
  end;
end;

procedure TRALRESTDWJSONParam.SetVariantValue(const AValue: Variant);
begin
  if VarIsNull(AValue) or VarIsEmpty(AValue) then
  begin
    Clear;
    Exit;
  end;

  { the declared type wins: a param declared ovFloat fed an integer Variant
    still has to keep its type, or the wire format changes per call }
  case ObjectValueToParamType(FObjectValue) of
    rptInteger  : StoreText(IntToStr(AValue));
    rptInt64    : StoreText(IntToStr(Int64(AValue)));
    rptDouble   : StoreText(RALRESTDWFloatToStr(AValue));
    rptCurrency : StoreText(RALRESTDWCurrToStr(AValue));
    rptBoolean  : StoreText(BooleanToString(AValue));
    rptDateTime : StoreText(RALRESTDWDateTimeToStr(VarToDateTime(AValue)));
    else
      StoreText(StringRAL(VarToStr(AValue)));
  end;
end;

function TRALRESTDWJSONParam.IsEmpty: Boolean;
begin
  Result := (FValue <> nil) and (FValue.Size = 0);
end;

function TRALRESTDWJSONParam.IsNull: Boolean;
begin
  Result := FValue = nil;
end;

function TRALRESTDWJSONParam.TestNilParam: Boolean;
begin
  Result := (Self = nil) or (FValue = nil);
end;

function TRALRESTDWJSONParam.Size: Int64;
begin
  Result := 0;
  if FValue <> nil then
    Result := FValue.Size;
end;

procedure TRALRESTDWJSONParam.LoadFromStream(AStream: TStream);
begin
  FObjectValue := ovStream;
  StoreStream(AStream);
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

procedure TRALRESTDWJSONParam.SaveToFile(const AFileName: StringRAL);
var
  vStream: TFileStream;
begin
  vStream := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(vStream);
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TRALRESTDWJSONParam.LoadFromFile(const AFileName: StringRAL);
var
  vStream: TFileStream;
begin
  vStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    StoreStream(vStream);
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TRALRESTDWJSONParam.SetAsAnsiString(AValue: ansistring);
begin
  FObjectValue := ovString;
  StoreText(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsBCD(AValue: currency);
begin
  FObjectValue := ovBCD;
  StoreText(RALRESTDWCurrToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsBoolean(AValue: boolean);
begin
  FObjectValue := ovBoolean;
  StoreText(BooleanToString(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsCurrency(AValue: currency);
begin
  FObjectValue := ovCurrency;
  StoreText(RALRESTDWCurrToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsDate(AValue: TDateTime);
begin
  FObjectValue := ovDate;
  StoreText(RALRESTDWDateTimeToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsDateTime(AValue: TDateTime);
begin
  FObjectValue := ovDateTime;
  StoreText(RALRESTDWDateTimeToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsFloat(AValue: double);
begin
  FObjectValue := ovFloat;
  StoreText(RALRESTDWFloatToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsFMTBCD(AValue: currency);
begin
  FObjectValue := ovFMTBcd;
  StoreText(RALRESTDWCurrToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsInteger(AValue: integer);
begin
  FObjectValue := ovInteger;
  StoreText(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsLargeInt(AValue: Int64);
begin
  FObjectValue := ovLargeint;
  StoreText(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsLongWord(AValue: longword);
begin
  FObjectValue := ovLongWord;
  StoreText(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsObject(AValue: string);
begin
  FObjectValue := ovObject;
  StoreText(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsShortInt(AValue: integer);
begin
  FObjectValue := ovShortint;
  StoreText(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsSingle(AValue: single);
begin
  FObjectValue := ovSingle;
  StoreText(RALRESTDWFloatToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsSmallInt(AValue: integer);
begin
  FObjectValue := ovSmallint;
  StoreText(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsStream(const AValue: TStream);
begin
  LoadFromStream(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsString(AValue: string);
begin
  FObjectValue := ovString;
  StoreText(AValue);
end;

procedure TRALRESTDWJSONParam.SetAsTime(AValue: TDateTime);
begin
  FObjectValue := ovTime;
  StoreText(RALRESTDWDateTimeToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsWideString(AValue: wideString);
begin
  FObjectValue := ovWideString;
  StoreText(StringRAL(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsWord(AValue: word);
begin
  FObjectValue := ovWord;
  StoreText(IntToStr(AValue));
end;

procedure TRALRESTDWJSONParam.SetAsBase64(AValue: StringRAL);
begin
  SetAsString(TRALBase64.Decode(AValue));
end;

function TRALRESTDWJSONParam.GetAsBase64: StringRAL;
begin
  Result := TRALBase64.Encode(GetAsString);
end;

procedure TRALRESTDWJSONParam.LoadFromParam(AParam: TParam);
begin
  if AParam = nil then
    Exit;

  FParamName := StringRAL(AParam.Name);
  FObjectValue := FieldTypeToObjectValue(AParam.DataType);
  if AParam.IsNull then
    Clear
  else
    SetVariantValue(AParam.Value);
end;

procedure TRALRESTDWJSONParam.SaveFromParam(AParam: TParam);
begin
  if AParam = nil then
    Exit;

  AParam.Name := String(FParamName);
  AParam.DataType := ObjectValueToFieldType(FObjectValue);
  if IsNull then
    AParam.Clear
  else
    AParam.Value := GetVariantValue;
end;

procedure TRALRESTDWJSONParam.LoadFromDataset(ATableName: StringRAL;
  ADataSet: TDataSet; AEncodedValue: Boolean; ADataMode: TRALRESTDWDataMode;
  const ADateTimeFormat: StringRAL; const ADelimiterFormat: StringRAL);
begin
  FDataMode := ADataMode;
  if ATableName <> '' then
    FParamName := ATableName;

  LoadFromDataSet(ADataSet);
end;

procedure TRALRESTDWJSONParam.LoadFromDataSet(ADataSet: TDataSet);
var
  vLink: TRALStorageBINLink;
  vStream: TMemoryStream;
begin
  FTypeObject := toDataset;
  FObjectValue := ovDataSet;

  vStream := TMemoryStream.Create;
  try
    vLink := TRALStorageBINLink.Create(nil);
    try
      vLink.SaveToStream(ADataSet, vStream);
    finally
      FreeAndNil(vLink);
    end;
    StoreStream(vStream);
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TRALRESTDWJSONParam.SaveToDataSet(ADataSet: TDataSet);
var
  vLink: TRALStorageBINLink;
begin
  if IsNull then
    Exit;

  FValue.Position := 0;
  vLink := TRALStorageBINLink.Create(nil);
  try
    vLink.LoadFromStream(ADataSet, FValue);
  finally
    FreeAndNil(vLink);
    FValue.Position := 0;
  end;
end;

procedure TRALRESTDWJSONParam.WriteToRALParam(AParam: TRALParam);
begin
  if AParam = nil then
    Exit;

  { Nada a escrever. Conteudo vazio quebra o RAL - a explicacao inteira esta no
    AppendTo, que e quem decide se o param chega a existir. }
  if Size = 0 then
    Exit;

  { A typed payload keeps the exact value and does not depend on either side's
    locale, which is what used to break floats and dates between machines. Text
    and binary have no typed form and travel as the stream, exactly as before. }
  case ObjectValueToParamType(FObjectValue) of
    rptInteger  : AParam.SetTypedInteger(GetAsInteger);
    rptInt64    : AParam.SetTypedInt64(GetAsLargeInt);
    rptDouble   : AParam.SetTypedDouble(GetAsFloat);
    rptCurrency : AParam.SetTypedCurrency(GetAsCurrency);
    rptBoolean  : AParam.SetTypedBoolean(GetAsBoolean);
    rptDateTime : AParam.SetTypedDateTime(GetAsDateTime);
    else
      AParam.AsStream := FValue;
  end;
end;

procedure TRALRESTDWJSONParam.ReadFromRALParam(AParam: TRALParam);
begin
  if AParam = nil then
    Exit;

  if AParam.IsTyped then
  begin
    { the RAL getters read whichever typed payload arrived and convert, so a
      declared type that disagrees with the sender still lands correctly }
    case ObjectValueToParamType(FObjectValue) of
      rptInteger  : StoreText(IntToStr(AParam.AsInteger));
      rptInt64    : StoreText(IntToStr(AParam.AsInt64));
      rptDouble   : StoreText(RALRESTDWFloatToStr(AParam.AsDouble));
      rptCurrency : StoreText(RALRESTDWCurrToStr(AParam.AsCurrency));
      rptBoolean  : StoreText(BooleanToString(AParam.AsBoolean));
      rptDateTime : StoreText(RALRESTDWDateTimeToStr(AParam.AsDateTime));
      else
        { Chegou tipado e aqui foi declarado como texto: as duas pontas
          discordam, e isso e normal - quem declarou o evento disse ovString e
          o codigo do outro lado chamou AsInteger, que carimba o tipo do que
          acabou de escrever. Guardar o Content cru gravaria os quatro bytes
          do inteiro como se fossem caracteres, e o AsInteger daqui leria 0:
          era o que fazia o helloworld da demo FullServer responder
          "Param 0 = 0" com o cliente tendo mandado 10. O GetAsString do RAL
          renderiza o valor tipado de forma invariante, que e a leitura certa.
          Binario de verdade nunca cai aqui: ele chega sem marca de tipo, pelo
          ramo de baixo. }
        StoreText(AParam.AsString);
    end;
  end
  else
  begin
    StoreStream(AParam.Content);
  end;
end;

function TRALRESTDWJSONParam.ToJSONObject: TRALJSONObject;
begin
  Result := TRALJSONObject.Create;
  Result.Add('ObjectType', GetEnumName(TypeInfo(TRALRESTDWTypeObject), Ord(FTypeObject)));
  Result.Add('Direction', GetEnumName(TypeInfo(TRALRESTDWObjectDirection), Ord(FObjectDirection)));
  Result.Add('Encoded', BooleanToString(FEncoded));
  Result.Add('ValueType', GetEnumName(TypeInfo(TRALRESTDWObjectValue), Ord(FObjectValue)));
  Result.Add('ParamName', FParamName);
  if FAlias <> '' then
    Result.Add('Alias', FAlias);
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

procedure TRALRESTDWJSONParam.FromJSON(const AJSON: StringRAL);
var
  vValue: TRALJSONValue;
  vObj: TRALJSONObject;
  vItem: TRALJSONValue;
  vInt: IntegerRAL;
begin
  vValue := TRALJSON.ParseJSON(AJSON);
  if vValue = nil then
    Exit;
  try
    if not (vValue is TRALJSONObject) then
      Exit;

    vObj := TRALJSONObject(vValue);

    vItem := vObj.Get('ObjectType');
    if vItem <> nil then
    begin
      vInt := GetEnumValue(TypeInfo(TRALRESTDWTypeObject), String(vItem.AsString));
      if vInt >= 0 then
        FTypeObject := TRALRESTDWTypeObject(vInt);
    end;

    vItem := vObj.Get('Direction');
    if vItem <> nil then
    begin
      vInt := GetEnumValue(TypeInfo(TRALRESTDWObjectDirection), String(vItem.AsString));
      if vInt >= 0 then
        FObjectDirection := TRALRESTDWObjectDirection(vInt);
    end;

    vItem := vObj.Get('ValueType');
    if vItem <> nil then
    begin
      vInt := GetEnumValue(TypeInfo(TRALRESTDWObjectValue), String(vItem.AsString));
      if vInt >= 0 then
        FObjectValue := TRALRESTDWObjectValue(vInt);
    end;

    vItem := vObj.Get('Encoded');
    if vItem <> nil then
      FEncoded := SameText(String(vItem.AsString), 'true');

    vItem := vObj.Get('ParamName');
    if vItem <> nil then
      FParamName := vItem.AsString;

    vItem := vObj.Get('Alias');
    if vItem <> nil then
      FAlias := vItem.AsString;

    // the value lives under the param's own name, as RDW writes it
    vItem := vObj.Get(FParamName);
    if vItem <> nil then
    begin
      if FEncoded then
        SetAsBase64(vItem.AsString)
      else
        StoreText(vItem.AsString);
    end;
  finally
    FreeAndNil(vValue);
  end;
end;

procedure TRALRESTDWJSONParam.CopyFrom(ASource: TRALRESTDWJSONParam);
begin
  if ASource = nil then
    Exit;

  FTypeObject := ASource.TypeObject;
  FObjectDirection := ASource.ObjectDirection;
  FObjectValue := ASource.ObjectValue;
  FParamName := ASource.ParamName;
  FAlias := ASource.Alias;
  FParamFileName := ASource.ParamFileName;
  FParamContentType := ASource.ParamContentType;
  FFloatDecimalFormat := ASource.FloatDecimalFormat;
  FDataMode := ASource.DataMode;
  FDefaultValue := ASource.DefaultValue;
  FEncoded := ASource.Encoded;
  StoreStream(ASource.Content);
end;

procedure TRALRESTDWJSONParam.AssignTo(ADest: TPersistent);
begin
  if ADest.InheritsFrom(TRALRESTDWJSONParam) then
    TRALRESTDWJSONParam(ADest).CopyFrom(Self)
  else
    inherited AssignTo(ADest);
end;

{ TRALRESTDWParams }

constructor TRALRESTDWParams.Create;
begin
  inherited;
  FParams := TList.Create;
  FRequest := nil;
  FModule := nil;
  FDataMode := dmRAW;
end;

destructor TRALRESTDWParams.Destroy;
begin
  ClearParams;
  FreeAndNil(FParams);
  inherited;
end;

procedure TRALRESTDWParams.ClearParams;
begin
  while FParams.Count > 0 do
  begin
    TObject(FParams.Items[FParams.Count - 1]).Free;
    FParams.Delete(FParams.Count - 1);
  end;
end;

procedure TRALRESTDWParams.Clear;
begin
  ClearParams;
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

function TRALRESTDWParams.CreateParam(const AParamName: StringRAL;
  const AValue: StringRAL): TRALRESTDWJSONParam;
begin
  Result := GetParamName(AParamName);
  if Result = nil then
  begin
    Result := NewParam;
    Result.ParamName := AParamName;
  end;
  Result.SetValue(AValue);
end;

function TRALRESTDWParams.Add(AItem: TRALRESTDWJSONParam): IntegerRAL;
begin
  Result := FParams.Add(AItem);
end;

procedure TRALRESTDWParams.Delete(AIndex: IntegerRAL);
begin
  if (AIndex < 0) or (AIndex >= FParams.Count) then
    Exit;

  TObject(FParams.Items[AIndex]).Free;
  FParams.Delete(AIndex);
end;

procedure TRALRESTDWParams.Delete(AParam: TRALRESTDWJSONParam);
begin
  Delete(FParams.IndexOf(AParam));
end;

function TRALRESTDWParams.IndexOf(const AName: StringRAL): IntegerRAL;
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
begin
  Result := -1;
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if (SameText(vParam.ParamName, AName)) or (SameText(vParam.Alias, AName)) then
    begin
      Result := vInt1;
      Break;
    end;
  end;
end;

function TRALRESTDWParams.CountInParams: IntegerRAL;
var
  vInt1: IntegerRAL;
begin
  Result := 0;
  for vInt1 := 0 to Pred(FParams.Count) do
    if TRALRESTDWJSONParam(FParams.Items[vInt1]).ObjectDirection in [odIN, odINOUT] then
      Result := Result + 1;
end;

function TRALRESTDWParams.CountOutParams: IntegerRAL;
var
  vInt1: IntegerRAL;
begin
  Result := 0;
  for vInt1 := 0 to Pred(FParams.Count) do
    if TRALRESTDWJSONParam(FParams.Items[vInt1]).ObjectDirection in [odOUT, odINOUT] then
      Result := Result + 1;
end;

function TRALRESTDWParams.ParamsReturn: boolean;
begin
  Result := CountOutParams > 0;
end;

procedure TRALRESTDWParams.CopyFrom(AParams: TRALRESTDWParams);
var
  vInt1: IntegerRAL;
begin
  if AParams = nil then
    Exit;

  ClearParams;
  for vInt1 := 0 to Pred(AParams.Count) do
    NewParam.CopyFrom(AParams.Items[vInt1]);
end;

function TRALRESTDWParams.GetParamIndex(AIndex: IntegerRAL): TRALRESTDWJSONParam;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < FParams.Count) then
    Result := TRALRESTDWJSONParam(FParams.Items[AIndex]);
end;

function TRALRESTDWParams.GetParamName(AName: StringRAL): TRALRESTDWJSONParam;
var
  vIdx: IntegerRAL;
begin
  Result := nil;
  vIdx := IndexOf(AName);
  if vIdx >= 0 then
    Result := TRALRESTDWJSONParam(FParams.Items[vIdx]);
end;

function TRALRESTDWParams.GetRawBody: TRALRESTDWJSONParam;
begin
  Result := GetParamName(cUndefined);
end;

procedure TRALRESTDWParams.SetParamIndex(AIndex: IntegerRAL; AValue: TRALRESTDWJSONParam);
var
  vParam: TRALRESTDWJSONParam;
begin
  if (AIndex >= 0) and (AIndex < FParams.Count) then
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[AIndex]);
    vParam.CopyFrom(AValue);
    FreeAndNil(AValue);
  end;
end;

procedure TRALRESTDWParams.SetParamName(AName: StringRAL; AValue: TRALRESTDWJSONParam);
var
  vParam: TRALRESTDWJSONParam;
begin
  vParam := GetParamName(AName);
  if vParam = nil then
  begin
    vParam := NewParam;
    vParam.ParamName := AName;
  end;

  vParam.CopyFrom(AValue);
  FreeAndNil(AValue);
end;

function TRALRESTDWParams.ToJSON: StringRAL;
var
  vArray: TRALJSONArray;
  vInt1: IntegerRAL;
begin
  vArray := TRALJSONArray.Create;
  try
    for vInt1 := 0 to Pred(FParams.Count) do
      vArray.Add(TRALRESTDWJSONParam(FParams.Items[vInt1]).ToJSONObject);
    Result := vArray.ToJSON;
  finally
    FreeAndNil(vArray);
  end;
end;

procedure TRALRESTDWParams.FromJSON(const AJSON: StringRAL);
var
  vValue: TRALJSONValue;
  vArray: TRALJSONArray;
  vInt1: IntegerRAL;
begin
  vValue := TRALJSON.ParseJSON(AJSON);
  if vValue = nil then
    Exit;
  try
    if not (vValue is TRALJSONArray) then
      Exit;

    ClearParams;
    vArray := TRALJSONArray(vValue);
    for vInt1 := 0 to Pred(vArray.Count) do
      NewParam.FromJSON(vArray.Get(vInt1).ToJSON);
  finally
    FreeAndNil(vValue);
  end;
end;

procedure TRALRESTDWParams.SaveToFile(const AFileName: StringRAL);
var
  vStream: TFileStream;
  vJson: StringRAL;
begin
  vJson := ToJSON;
  vStream := TFileStream.Create(AFileName, fmCreate);
  try
    if vJson <> '' then
      vStream.Write(vJson[POSINISTR], Length(vJson));
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TRALRESTDWParams.LoadFromFile(const AFileName: StringRAL);
var
  vStream: TFileStream;
begin
  vStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    FromJSON(StreamToString(vStream));
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TRALRESTDWParams.LoadFromParams(AParams: TParams);
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
begin
  if AParams = nil then
    Exit;

  for vInt1 := 0 to Pred(AParams.Count) do
  begin
    vParam := GetParamName(StringRAL(AParams[vInt1].Name));
    if vParam = nil then
      vParam := NewParam;
    vParam.LoadFromParam(AParams[vInt1]);
  end;
end;

procedure TRALRESTDWParams.SaveToParams(AParams: TParams);
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
  vTarget: TParam;
begin
  if AParams = nil then
    Exit;

  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    vTarget := AParams.FindParam(String(vParam.ParamName));
    if vTarget = nil then
      vTarget := AParams.CreateParam(ftUnknown, String(vParam.ParamName), ptInput);
    vParam.SaveFromParam(vTarget);
  end;
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
      if (vRALParam = nil) and (vParam.Alias <> '') then
        vRALParam := ARequest.ParamByName(vParam.Alias);
      if vRALParam <> nil then
        vParam.ReadFromRALParam(vRALParam);
    end;
  end;
end;

procedure TRALRESTDWParams.AssignResponse(AResponse: TRALResponse);
var
  vInt1: IntegerRAL;
  vParam, vUnico: TRALRESTDWJSONParam;
  vRALParam: TRALParam;
  vSaidas, vAchados: IntegerRAL;
begin
  vUnico := nil;
  vSaidas := 0;
  vAchados := 0;

  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if not (vParam.ObjectDirection in [odOUT, odINOUT]) then
      Continue;

    Inc(vSaidas);
    vUnico := vParam;

    // a resposta so traz o que o servidor devolveu: sem o teste, um param
    // ausente era um AV no cliente
    vRALParam := AResponse.ParamByName(vParam.ParamName);
    if vRALParam <> nil then
    begin
      vParam.ReadFromRALParam(vRALParam);
      Inc(vAchados);
    end;
  end;

  { Param de saida sozinho viaja sem o nome. O PascalRAL nao monta multipart
    para um unico param de corpo - manda o valor cru, e o nome chega como
    ral_body. Ler so por nome descartava o valor calado: era por isso que o
    servertime do FullServer voltava vazio, com o servidor respondendo certo.
    Mesma leitura em dois passos que o lado do servidor ja faz. }
  if (vSaidas = 1) and (vAchados = 0) then
  begin
    vRALParam := AResponse.Body;
    if vRALParam <> nil then
      vUnico.ReadFromRALParam(vRALParam);
  end;
end;

procedure TRALRESTDWParams.AppendTo(ARALParams: TRALParams;
  ADirections: TRALRESTDWDirections);
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWJSONParam;
  vRALParam: TRALParam;
begin
  for vInt1 := 0 to Pred(FParams.Count) do
  begin
    vParam := TRALRESTDWJSONParam(FParams.Items[vInt1]);
    if not (vParam.ObjectDirection in ADirections) then
      Continue;

    { Param sem conteudo nao viaja, e isso nao e escolha de estilo: e o unico
      formato que nao quebra. Escrever vazio cai no TRALStringStream, que
      termina todo write em Write(ABytes[0], 0) e todo read em
      Read(vBytes[0], 0) - indexar [0] de um array vazio: ERangeError em
      qualquer build com range check, que e o que o IDE gera em Debug, e era o
      erro que aparecia logo depois do Execute da demo. Criar o param e deixa-lo
      sem conteudo e pior ainda: o encoder multipart faz AsStream.Position := 0
      sobre nil e da violacao de acesso em qualquer build.

      O proprio RAL trata vazio assim - TRALParams.AddParam(nome, '') devolve
      nil sem criar param nenhum -, e do outro lado nada se perde: o param
      declarado continua existindo e responde como nulo, que e exatamente o que
      "sem valor" quer dizer no RDW. }
    if vParam.Size = 0 then
      Continue;

    vRALParam := ARALParams.Get[vParam.ParamName];
    if vRALParam = nil then
    begin
      vRALParam := ARALParams.NewParam;
      vRALParam.ParamName := vParam.ParamName;
    end;
    vParam.WriteToRALParam(vRALParam);
    vRALParam.Kind := rpkBODY;
  end;
end;

procedure TRALRESTDWParams.AppendRequest(ARequest: TRALRequest);
begin
  AppendTo(ARequest.Params, [odIN, odINOUT]);
end;

procedure TRALRESTDWParams.AppendResponse(AResponse: TRALResponse);
begin
  AppendTo(AResponse.Params, [odOUT, odINOUT]);
end;

end.
