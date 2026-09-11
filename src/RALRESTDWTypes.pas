/// Enums and conversions shared by the whole adapter.
///
/// The enum member names are the ones REST Dataware uses, on purpose: only the
/// type names carry the RAL prefix, so RALRESTDWCompat can alias the types and
/// existing RDW code keeps compiling unchanged.
unit RALRESTDWTypes;

interface

uses
  Classes, SysUtils, DB,
  RALTypes, RALRoutes;

const
  { A mensagem que o RDW devolve quando a autenticacao falha. O codigo portado
    a usa direto. }
  { A versao que o codigo do RDW mostra na tela. Diz o que realmente esta
    rodando, e nao uma versao do RDW que nao existe mais aqui. }
  RESTDWVERSAO = 'RESTDW2RAL sobre PascalRAL';
  cInvalidAuth = 'Invalid authentication';
  cInvalidLogin = 'Invalid login';

type
  { O TRESTDWMIMEType do RDW e chamado como classe (TRESTDWMIMEType.GetMIMEType);
    o do RAL e instancia. Esta casca de uma linha so acerta a forma da chamada. }
  TRALRESTDWMIMEType = class
  public
    class function GetMIMEType(const AFileName: StringRAL): StringRAL;
  end;

  TRALRESTDWTypeObject = (toDataset, toParam, toMassive, toVariable, toObject);
  TRALRESTDWObjectDirection = (odIN, odOUT, odINOUT);
  TRALRESTDWDataMode = (dmDataware, dmRAW);
  { RDW asked which encoding to put on the wire. RAL speaks UTF-8 on every
    engine, so the member survives for the .dfm and the value is ignored. }
  TRALRESTDWEncodeSelect = (esASCII, esUtf8, esANSI);
  { O ClientSQL do RDW ordena por estes dois. Sairam do RDW 2.1, mas continuam
    gravados no DFM de quem vem de antes, e sem eles o formulario nao abre. }
  TRALRESTDWSortOrder = (soAsc, soDesc);
  TRALRESTDWSortCaseSens = (scYes, scNo);
  /// TMassiveType do RDW
  TRALRESTDWMassiveType = (mtMassiveCache, mtMassiveObject);
  TRALRESTDWObjectValue = (ovUnknown,     ovString,          ovSmallint,
                           ovInteger,     ovWord,            ovBoolean,
                           ovFloat,       ovCurrency,        ovBCD,
                           ovDate,        ovTime,            ovDateTime,
                           ovBytes,       ovVarBytes,        ovAutoInc,
                           ovBlob,        ovMemo,            ovGraphic,
                           ovFmtMemo,     ovParadoxOle,      ovDBaseOle,
                           ovTypedBinary, ovCursor,          ovFixedChar,
                           ovWideString,  ovLargeint,        ovADT,
                           ovArray,       ovReference,       ovDataSet,
                           ovOraBlob,     ovOraClob,         ovVariant,
                           ovInterface,   ovIDispatch,       ovGuid,
                           ovTimeStamp,   ovFMTBcd,          ovFixedWideChar,
                           ovWideMemo,    ovOraTimeStamp,    ovOraInterval,
                           ovLongWord,    ovShortint,        ovByte,
                           ovExtended,    ovConnection,      ovParams,
                           ovStream,      ovTimeStampOffset, ovObject,
                           ovSingle);

const
   cUndefined = 'undefined';
   /// Marks the stream produced by TRALRESTDWServerEvents.GetEvents
   cEventsSignature = 'RALRDWEV';
   /// Bumped whenever that stream's layout changes, so a mismatched pair fails
   /// loudly instead of reading the next field as a length prefix
   cEventsVersion = 2;

function BooleanToString(AValue : boolean) : StringRAL;
function ObjectValueToRouteParamType(AValue: TRALRESTDWObjectValue) : TRALRouteParamType;
/// How the value should travel on the wire. Anything without a binary
/// representation stays rptText.
function ObjectValueToParamType(AValue: TRALRESTDWObjectValue) : TRALParamType;
function ObjectValueToFieldType(AValue: TRALRESTDWObjectValue) : TFieldType;
function FieldTypeToObjectValue(AValue: TFieldType) : TRALRESTDWObjectValue;
/// True for the values that carry bytes rather than readable text
function ObjectValueIsBinary(AValue: TRALRESTDWObjectValue) : boolean;

{ Text conversions that do not depend on the machine's locale.

  RDW writes numbers and dates into a string when the param travels as text,
  and FloatToStr/DateTimeToStr follow the local settings: a server in pt-BR
  answered "1,5" and a client in en-US read it back as 15. These are the
  invariant equivalents, used everywhere a value becomes text. }
function RALRESTDWFormatSettings: TFormatSettings;
function RALRESTDWFloatToStr(const AValue: Double): StringRAL;
function RALRESTDWStrToFloat(const AValue: StringRAL; const ADefault: Double = 0): Double;
function RALRESTDWCurrToStr(const AValue: Currency): StringRAL;
function RALRESTDWStrToCurr(const AValue: StringRAL; const ADefault: Currency = 0): Currency;
/// ISO-8601-like, sortable and locale-free: yyyy-mm-dd hh:nn:ss.zzz
function RALRESTDWDateTimeToStr(const AValue: TDateTime): StringRAL;
function RALRESTDWStrToDateTime(const AValue: StringRAL; const ADefault: TDateTime = 0): TDateTime;

{ Os utilitarios globais que o codigo do RDW chama sem pensar. }

{ O RDW encodava caracteres especiais em %XX para atravessar a URL. Aqui a
  volta e a mesma, e serve tambem para quem so quer decodificar. }
function RALRESTDWDecodeStrings(const AValue: StringRAL): StringRAL;
function RALRESTDWEncodeStrings(const AValue: StringRAL): StringRAL;

{ A primeira posicao de uma string: 1 no Delphi e no FPC em modo Delphi, 0
  quando o FPC usa strings baseadas em zero. O RDW expoe isso como constante
  porque o codigo dele indexa string na mao. }
function RALRESTDWInitStrPos: IntegerRAL;

implementation

uses
  RALTools, RALMIMETypes;

var
  gFormat: TFormatSettings;
  gFormatReady: boolean = False;

function RALRESTDWFormatSettings: TFormatSettings;
begin
  if not gFormatReady then
  begin
    { built by hand instead of TFormatSettings.Invariant, which does not exist on
      the older Delphi versions this package still targets }
    {$IFDEF FPC}
      gFormat := DefaultFormatSettings;
    {$ELSE}
      gFormat := FormatSettings;
    {$ENDIF}
    gFormat.DecimalSeparator := '.';
    gFormat.ThousandSeparator := #0;
    gFormat.DateSeparator := '-';
    gFormat.TimeSeparator := ':';
    gFormat.ShortDateFormat := 'yyyy-mm-dd';
    gFormat.LongDateFormat := 'yyyy-mm-dd';
    gFormat.ShortTimeFormat := 'hh:nn:ss';
    gFormat.LongTimeFormat := 'hh:nn:ss';
    gFormatReady := True;
  end;
  Result := gFormat;
end;

function RALRESTDWFloatToStr(const AValue: Double): StringRAL;
begin
  Result := StringRAL(FloatToStr(AValue, RALRESTDWFormatSettings));
end;

function RALRESTDWStrToFloat(const AValue: StringRAL; const ADefault: Double): Double;
begin
  Result := StrToFloatDef(String(AValue), ADefault, RALRESTDWFormatSettings);
end;

function RALRESTDWCurrToStr(const AValue: Currency): StringRAL;
begin
  Result := StringRAL(CurrToStr(AValue, RALRESTDWFormatSettings));
end;

function RALRESTDWStrToCurr(const AValue: StringRAL; const ADefault: Currency): Currency;
begin
  Result := StrToCurrDef(String(AValue), ADefault, RALRESTDWFormatSettings);
end;

function RALRESTDWDateTimeToStr(const AValue: TDateTime): StringRAL;
begin
  Result := StringRAL(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AValue,
                                    RALRESTDWFormatSettings));
end;

function RALRESTDWStrToDateTime(const AValue: StringRAL; const ADefault: TDateTime): TDateTime;
var
  vStr: String;
begin
  vStr := Trim(String(AValue));
  if vStr = '' then
  begin
    Result := ADefault;
    Exit;
  end;

  // 'T' separator of a full ISO-8601 stamp
  if (Length(vStr) > 10) and (vStr[11] = 'T') then
    vStr[11] := ' ';

  Result := StrToDateTimeDef(vStr, ADefault, RALRESTDWFormatSettings);
end;

function BooleanToString(AValue: boolean): StringRAL;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

function ObjectValueToRouteParamType(AValue: TRALRESTDWObjectValue): TRALRouteParamType;
begin
  case AValue of
    ovInteger,
    ovWord,
    ovSmallint,
    ovLargeint,
    ovShortint,
    ovByte,
    ovLongWord,
    ovAutoInc : Result := prtInteger;

    ovBoolean : Result := prtBoolean;

    ovFloat,
    ovCurrency,
    ovBCD,
    ovFMTBcd,
    ovExtended,
    ovSingle  : Result := prtNumber;

    else
      Result := prtString;
  end;
end;

function ObjectValueToParamType(AValue: TRALRESTDWObjectValue): TRALParamType;
begin
  case AValue of
    ovSmallint,
    ovInteger,
    ovWord,
    ovAutoInc,
    ovShortint,
    ovByte,
    ovLongWord : Result := rptInteger;

    ovLargeint : Result := rptInt64;

    ovBoolean  : Result := rptBoolean;

    ovFloat,
    ovSingle,
    ovExtended : Result := rptDouble;

    ovCurrency,
    ovBCD,
    ovFMTBcd   : Result := rptCurrency;

    ovDate,
    ovTime,
    ovDateTime,
    ovTimeStamp,
    ovTimeStampOffset,
    ovOraTimeStamp : Result := rptDateTime;

    else
      Result := rptText;
  end;
end;

function ObjectValueToFieldType(AValue: TRALRESTDWObjectValue): TFieldType;
begin
  case AValue of
    ovString,     ovFixedChar   : Result := ftString;
    ovWideString, ovFixedWideChar : Result := ftWideString;
    ovSmallint                  : Result := ftSmallint;
    ovInteger,    ovByte        : Result := ftInteger;
    ovWord                      : Result := ftWord;
    ovShortint                  : Result := ftSmallint;
    ovLongWord,   ovLargeint    : Result := ftLargeint;
    ovAutoInc                   : Result := ftAutoInc;
    ovBoolean                   : Result := ftBoolean;
    ovFloat,      ovSingle,
    ovExtended                  : Result := ftFloat;
    ovCurrency                  : Result := ftCurrency;
    ovBCD                       : Result := ftBCD;
    ovFMTBcd                    : Result := ftFMTBcd;
    ovDate                      : Result := ftDate;
    ovTime                      : Result := ftTime;
    ovDateTime                  : Result := ftDateTime;
    ovTimeStamp                 : Result := ftTimeStamp;
    ovBytes                     : Result := ftBytes;
    ovVarBytes                  : Result := ftVarBytes;
    ovBlob,       ovOraBlob,
    ovTypedBinary, ovStream     : Result := ftBlob;
    ovMemo,       ovFmtMemo,
    ovOraClob                   : Result := ftMemo;
    ovWideMemo                  : Result := ftWideMemo;
    ovGraphic                   : Result := ftGraphic;
    ovGuid                      : Result := ftGuid;
    ovVariant                   : Result := ftVariant;
    ovDataSet                   : Result := ftDataSet;
    else
      Result := ftUnknown;
  end;
end;

function FieldTypeToObjectValue(AValue: TFieldType): TRALRESTDWObjectValue;
begin
  case AValue of
    ftString, ftFixedChar        : Result := ovString;
    ftWideString, ftFixedWideChar : Result := ovWideString;
    ftSmallint                   : Result := ovSmallint;
    ftInteger                    : Result := ovInteger;
    ftWord                       : Result := ovWord;
    ftLargeint                   : Result := ovLargeint;
    ftAutoInc                    : Result := ovAutoInc;
    ftBoolean                    : Result := ovBoolean;
    { ftExtended e ftSingle so existem no Delphi; no FPC 3.2.2 nem o
      identificador existe, entao a linha inteira tem de sair }
    {$IFDEF FPC}
    ftFloat                      : Result := ovFloat;
    {$ELSE}
    ftFloat, ftExtended          : Result := ovFloat;
    ftSingle                     : Result := ovSingle;
    {$ENDIF}
    ftCurrency                   : Result := ovCurrency;
    ftBCD                        : Result := ovBCD;
    ftFMTBcd                     : Result := ovFMTBcd;
    ftDate                       : Result := ovDate;
    ftTime                       : Result := ovTime;
    ftDateTime                   : Result := ovDateTime;
    ftTimeStamp                  : Result := ovTimeStamp;
    ftBytes                      : Result := ovBytes;
    ftVarBytes                   : Result := ovVarBytes;
    ftBlob, ftOraBlob            : Result := ovBlob;
    ftMemo, ftOraClob            : Result := ovMemo;
    ftWideMemo                   : Result := ovWideMemo;
    ftGraphic                    : Result := ovGraphic;
    ftGuid                       : Result := ovGuid;
    ftVariant                    : Result := ovVariant;
    ftDataSet                    : Result := ovDataSet;
    else
      Result := ovUnknown;
  end;
end;

function ObjectValueIsBinary(AValue: TRALRESTDWObjectValue): boolean;
begin
  Result := AValue in [ovBytes, ovVarBytes, ovBlob, ovGraphic, ovParadoxOle,
                       ovDBaseOle, ovTypedBinary, ovOraBlob, ovStream,
                       ovDataSet, ovObject];
end;

class function TRALRESTDWMIMEType.GetMIMEType(const AFileName: StringRAL): StringRAL;
begin
  Result := TRALMIMEType.GetInstance.GetMIMEType(AFileName);
end;

function RALRESTDWInitStrPos: IntegerRAL;
begin
  {$IFDEF FPC}
    Result := 1;
  {$ELSE}
    Result := Low(StringRAL);
  {$ENDIF}
end;

function RALRESTDWDecodeStrings(const AValue: StringRAL): StringRAL;
var
  vInt1: IntegerRAL;
  vHex: string;
  vCod: Integer;
begin
  Result := '';
  vInt1 := 1;
  while vInt1 <= Length(AValue) do
  begin
    if (AValue[vInt1] = '%') and (vInt1 + 2 <= Length(AValue)) then
    begin
      vHex := '$' + string(Copy(AValue, vInt1 + 1, 2));
      vCod := StrToIntDef(vHex, -1);
      if vCod >= 0 then
      begin
        Result := Result + StringRAL(AnsiChar(Byte(vCod)));
        Inc(vInt1, 3);
        Continue;
      end;
    end;

    if AValue[vInt1] = '+' then
      Result := Result + ' '
    else
      Result := Result + AValue[vInt1];
    Inc(vInt1);
  end;
end;

function RALRESTDWEncodeStrings(const AValue: StringRAL): StringRAL;
var
  vInt1: IntegerRAL;
  vByte: Byte;
begin
  Result := '';
  for vInt1 := 1 to Length(AValue) do
  begin
    vByte := Byte(AValue[vInt1]);
    if (vByte >= 48) and (vByte <= 57) then          // 0-9
      Result := Result + AValue[vInt1]
    else if (vByte >= 65) and (vByte <= 90) then     // A-Z
      Result := Result + AValue[vInt1]
    else if (vByte >= 97) and (vByte <= 122) then    // a-z
      Result := Result + AValue[vInt1]
    else if AValue[vInt1] in ['-', '_', '.', '~'] then
      Result := Result + AValue[vInt1]
    else
      Result := Result + StringRAL('%' + IntToHex(vByte, 2));
  end;
end;

end.
