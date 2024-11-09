unit RALRESTDWTypes;

interface

uses
  Classes, SysUtils,
  RALTypes, RALRoutes;

type
  TRALRESTDWTypeObject = (toDataset, toParam, toMassive, toVariable, toObject);
  TRALRESTDWObjectDirection = (odIN, odOUT, odINOUT);
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

function BooleanToString(AValue : boolean) : StringRAL;
function ObjectValueToRouteParamType(AValue: TRALRESTDWObjectValue) : TRALRouteParamType;

implementation

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

end.
