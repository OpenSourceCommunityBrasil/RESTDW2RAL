unit RALRESTDWTypes;

interface

uses
  Classes, SysUtils,
  RALTypes;

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

implementation

function BooleanToString(AValue: boolean): StringRAL;
begin
  if AValue then
    Result := 'true'
  else
    Result := 'false';
end;

end.

