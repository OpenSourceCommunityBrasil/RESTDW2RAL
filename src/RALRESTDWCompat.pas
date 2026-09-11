{ Source-level compatibility with REST Dataware.

  Put this unit in the `uses` of a unit ported from RDW and the RDW type and
  enum names resolve to their RESTDW2RAL equivalents, so the body of an event
  handler, and everything it touches, compiles unchanged:

      uses uRESTDWParams, uRESTDWServerEvents;      // antes
      uses RALRESTDWCompat;                         // depois

  Pascal has no transitive exports, so the enum *values* are re-declared here as
  constants on purpose - without them `ovString` would not resolve from a unit
  that only uses this one.

  What this unit cannot do is rename a class inside a DFM/LFM: the form still
  stores `TRESTDWServerEvents` and has to be pointed at `TRALRESTDWServerEvents`
  by hand (or by search and replace over the .dfm). }
unit RALRESTDWCompat;

interface

uses
  RALTypes, RALRESTDWTypes, RALRESTDWParams, RALRESTDWParamsMethods,
  RALRESTDWEvents, RALRESTDWServerEvents, RALRESTDWClientEvents;

type
  { aliases do RAL: um handler portado declara String e Integer, mas as
    assinaturas do RAL usam StringRAL e IntegerRAL - re-exportados aqui para
    que esta unit sozinha baste no uses }
  StringRAL  = RALTypes.StringRAL;
  IntegerRAL = RALTypes.IntegerRAL;
  Int64RAL   = RALTypes.Int64RAL;
  CharRAL    = RALTypes.CharRAL;

  { containers e parametros }
  TRESTDWParams        = TRALRESTDWParams;
  TDWParams            = TRALRESTDWParams;
  TRESTDWJSONParam     = TRALRESTDWJSONParam;
  TRESTDWParamsMethods = TRALRESTDWParamsMethods;
  TRESTDWParamMethod   = TRALRESTDWParamMethod;

  { enums }
  TObjectValue         = TRALRESTDWObjectValue;
  TObjectDirection     = TRALRESTDWObjectDirection;
  TTypeObject          = TRALRESTDWTypeObject;
  TDataMode            = TRALRESTDWDataMode;
  TSendEvent           = TRALRESTDWSendEvent;

  { eventos }
  TRESTDWEvent         = TRALRESTDWEventServer;
  TRESTDWEventList     = TRALRESTDWEventList;
  TRESTDWRoute         = TRALRESTDWRoute;
  TRESTDWRoutes        = TRALRESTDWRoutes;
  TDWReplyEvent        = TRALRESTDWReplyEvent;
  TDWReplyEventByType  = TRALRESTDWReplyEventByType;
  TDWAuthRequest       = TRALRESTDWAuthRequest;
  TObjectExecute       = TRALRESTDWObjectExecute;
  TObjectEvent         = TRALRESTDWObjectEvent;
  TOnBeforeSend        = TRALRESTDWBeforeSend;

  { componentes }
  TRESTDWServerEvents  = TRALRESTDWServerEvents;
  TRESTDWClientEvents  = TRALRESTDWClientEvents;

const
  cUndefined = RALRESTDWTypes.cUndefined;

  { TObjectDirection }
  odIN     = RALRESTDWTypes.odIN;
  odOUT    = RALRESTDWTypes.odOUT;
  odINOUT  = RALRESTDWTypes.odINOUT;

  { TTypeObject }
  toDataset  = RALRESTDWTypes.toDataset;
  toParam    = RALRESTDWTypes.toParam;
  toMassive  = RALRESTDWTypes.toMassive;
  toVariable = RALRESTDWTypes.toVariable;
  toObject   = RALRESTDWTypes.toObject;

  { TDataMode }
  dmDataware = RALRESTDWTypes.dmDataware;
  dmRAW      = RALRESTDWTypes.dmRAW;

  { TSendEvent }
  seGET    = RALRESTDWClientEvents.seGET;
  sePOST   = RALRESTDWClientEvents.sePOST;
  sePUT    = RALRESTDWClientEvents.sePUT;
  seDELETE = RALRESTDWClientEvents.seDELETE;
  sePATCH  = RALRESTDWClientEvents.sePATCH;

  { TObjectValue }
  ovUnknown         = RALRESTDWTypes.ovUnknown;
  ovString          = RALRESTDWTypes.ovString;
  ovSmallint        = RALRESTDWTypes.ovSmallint;
  ovInteger         = RALRESTDWTypes.ovInteger;
  ovWord            = RALRESTDWTypes.ovWord;
  ovBoolean         = RALRESTDWTypes.ovBoolean;
  ovFloat           = RALRESTDWTypes.ovFloat;
  ovCurrency        = RALRESTDWTypes.ovCurrency;
  ovBCD             = RALRESTDWTypes.ovBCD;
  ovDate            = RALRESTDWTypes.ovDate;
  ovTime            = RALRESTDWTypes.ovTime;
  ovDateTime        = RALRESTDWTypes.ovDateTime;
  ovBytes           = RALRESTDWTypes.ovBytes;
  ovVarBytes        = RALRESTDWTypes.ovVarBytes;
  ovAutoInc         = RALRESTDWTypes.ovAutoInc;
  ovBlob            = RALRESTDWTypes.ovBlob;
  ovMemo            = RALRESTDWTypes.ovMemo;
  ovGraphic         = RALRESTDWTypes.ovGraphic;
  ovFmtMemo         = RALRESTDWTypes.ovFmtMemo;
  ovParadoxOle      = RALRESTDWTypes.ovParadoxOle;
  ovDBaseOle        = RALRESTDWTypes.ovDBaseOle;
  ovTypedBinary     = RALRESTDWTypes.ovTypedBinary;
  ovCursor          = RALRESTDWTypes.ovCursor;
  ovFixedChar       = RALRESTDWTypes.ovFixedChar;
  ovWideString      = RALRESTDWTypes.ovWideString;
  ovLargeint        = RALRESTDWTypes.ovLargeint;
  ovADT             = RALRESTDWTypes.ovADT;
  ovArray           = RALRESTDWTypes.ovArray;
  ovReference       = RALRESTDWTypes.ovReference;
  ovDataSet         = RALRESTDWTypes.ovDataSet;
  ovOraBlob         = RALRESTDWTypes.ovOraBlob;
  ovOraClob         = RALRESTDWTypes.ovOraClob;
  ovVariant         = RALRESTDWTypes.ovVariant;
  ovInterface       = RALRESTDWTypes.ovInterface;
  ovIDispatch       = RALRESTDWTypes.ovIDispatch;
  ovGuid            = RALRESTDWTypes.ovGuid;
  ovTimeStamp       = RALRESTDWTypes.ovTimeStamp;
  ovFMTBcd          = RALRESTDWTypes.ovFMTBcd;
  ovFixedWideChar   = RALRESTDWTypes.ovFixedWideChar;
  ovWideMemo        = RALRESTDWTypes.ovWideMemo;
  ovOraTimeStamp    = RALRESTDWTypes.ovOraTimeStamp;
  ovOraInterval     = RALRESTDWTypes.ovOraInterval;
  ovLongWord        = RALRESTDWTypes.ovLongWord;
  ovShortint        = RALRESTDWTypes.ovShortint;
  ovByte            = RALRESTDWTypes.ovByte;
  ovExtended        = RALRESTDWTypes.ovExtended;
  ovConnection      = RALRESTDWTypes.ovConnection;
  ovParams          = RALRESTDWTypes.ovParams;
  ovStream          = RALRESTDWTypes.ovStream;
  ovTimeStampOffset = RALRESTDWTypes.ovTimeStampOffset;
  ovObject          = RALRESTDWTypes.ovObject;
  ovSingle          = RALRESTDWTypes.ovSingle;

implementation

end.
