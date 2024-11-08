unit RALRESTDWTypes;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

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

implementation

end.

