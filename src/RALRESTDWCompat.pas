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
  RALRESTDWEvents, RALRESTDWServerEvents, RALRESTDWClientEvents,
  RALRESTDWDataModule, RALRESTDWOptions, RALRESTDWClient, RALRESTDWMassive,
  RALAuthentication, RALMIMETypes, RALRESTDWServerContext;

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
  TRESTDWJSONValue     = TRALRESTDWJSONParam;
  TRESTDWParamsMethods = TRALRESTDWParamsMethods;
  TRESTDWParamMethod   = TRALRESTDWParamMethod;

  { enums }
  TObjectValue         = TRALRESTDWObjectValue;
  TObjectDirection     = TRALRESTDWObjectDirection;
  TTypeObject          = TRALRESTDWTypeObject;
  TDataMode            = TRALRESTDWDataMode;
  TEncodeSelect        = TRALRESTDWEncodeSelect;
  { o verbo que chega ao OnReplyEventByType. O RAL ja tem o enum com os
    mesmos sete membros, entao o alias basta e o handler nem percebe. }
  TRequestType         = RALTypes.TRALMethod;
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

  { o massive: os tipos existem para o codigo compilar, mas o gancho por
    registro nao e disparado - ver o cabecalho de RALRESTDWMassive }
  TMassiveDatasetBuffer  = TRALRESTDWMassiveDatasetBuffer;
  TRESTDWAuthTokenParam   = TRALRESTDWAuthTokenParam;
  TConnectionDefs         = TRALRESTDWConnectionDefs;
  TRESTDWConnectionServer = TRALRESTDWConnectionServer;
  TConnStatus             = TRALRESTDWConnStatus;
  TRESTDWTokenType        = TRALRESTDWTokenType;
  TTyperequest            = TRALRESTDWTypeRequest;
  TRESTDWMIMEType         = TRALRESTDWMIMEType;
  TRESTDWCryptType        = TRALRESTDWCryptType;
  TRESTDWAuthOptionBearer = TRALRESTDWAuthOptionBearer;
  TRESTDWTokenRequest     = TRALRESTDWTokenRequest;
  TRESTDWAuthOptionBearerClient = TRALRESTDWAuthOptionBearer;
  { bearer e token guardam a mesma coisa aqui - o valor que vai no cabecalho
    Authorization - entao a mesma classe atende os dois }
  TRESTDWAuthOptionTokenClient  = TRALRESTDWAuthOptionBearer;
  TMassiveFields         = TRALRESTDWMassiveFields;
  TMassiveField          = TRALRESTDWMassiveField;
  TMassiveMode           = TRALRESTDWMassiveMode;
  TMassiveSQLMode        = TRALRESTDWMassiveSQLMode;
  TMassiveType           = TRALRESTDWMassiveType;
  TMassiveProcess        = TRALRESTDWMassiveProcess;
  TMassiveEvent          = TRALRESTDWMassiveEvent;
  TMassiveLineProcess    = TRALRESTDWMassiveLineProcess;

  { ordenacao do ClientSQL, que saiu do RDW 2.1 mas continua no .dfm de quem
    vem de antes }
  TSortOrder             = TRALRESTDWSortOrder;
  TSortCaseSens          = TRALRESTDWSortCaseSens;

  { as opcoes de transporte: as mesmas classes dos dois lados, entao um cast
    escrito para o pooler continua valendo para o cliente e vice-versa }
  TRESTDWAuthOption      = TRALRESTDWAuthOption;
  TRESTDWAuthOptionParam = TRALRESTDWAuthOptionParam;
  TRESTDWAuthOptionBasic = TRALRESTDWAuthOptionBasic;
  TRESTDWCriptOptions    = TRALRESTDWCriptOptions;
  TRESTDWProxyOptions    = TRALRESTDWProxyOptions;

  { o transporte do lado do cliente. O do servidor nao entra aqui de
    proposito: ele depende do motor escolhido, e arrastar o Indy para
    dentro desta unit obrigaria todo projeto cliente a carrega-lo. }
  TRALRESTDWClient       = RALRESTDWClient.TRALRESTDWClient;

  { o DataModule do servidor e o que ele carrega }
  TServerMethodDataModule = TRALRESTDWDataModule;
  TRESTDWClientInfo       = TRALRESTDWClientInfo;
  TUserBasicAuth          = TRALRESTDWUserBasicAuth;

  { o autenticador do servidor: o do RAL tem UserName, Password e AuthDialog
    com os mesmos nomes, entao o alias resolve o .pas e o conversor so precisa
    trocar a classe no formulario }
  TRESTDWAuthBasic       = TRALServerBasicAuth;

  { componentes }
  TRESTDWServerEvents  = TRALRESTDWServerEvents;
  TRESTDWClientEvents  = TRALRESTDWClientEvents;
  TRESTDWServerContext = TRALRESTDWServerContext;
  TRESTDWContext       = TRALRESTDWContext;
  TRESTDWContextList   = TRALRESTDWContextList;

  { e os mesmos com o nome do RAL: o Pascal nao exporta o que a unit so
    usa, e depois da conversao o uses do formulario so tem esta unit }
  TRALRESTDWServerEvents = RALRESTDWServerEvents.TRALRESTDWServerEvents;
  TRALRESTDWClientEvents = RALRESTDWClientEvents.TRALRESTDWClientEvents;
  TRALRESTDWDataModule   = RALRESTDWDataModule.TRALRESTDWDataModule;
  TRALRESTDWParams       = RALRESTDWParams.TRALRESTDWParams;
  TRALRESTDWMassiveCache = RALRESTDWMassive.TRALRESTDWMassiveCache;
  TRALRESTDWServerContext = RALRESTDWServerContext.TRALRESTDWServerContext;

const
  cUndefined    = RALRESTDWTypes.cUndefined;
  RESTDWVERSAO  = RALRESTDWTypes.RESTDWVERSAO;
  cInvalidAuth  = RALRESTDWTypes.cInvalidAuth;
  cInvalidLogin = RALRESTDWTypes.cInvalidLogin;

  { TConnStatus }
  hsResolving     = RALRESTDWOptions.hsResolving;
  hsConnecting    = RALRESTDWOptions.hsConnecting;
  hsConnected     = RALRESTDWOptions.hsConnected;
  hsDisconnecting = RALRESTDWOptions.hsDisconnecting;
  hsDisconnected  = RALRESTDWOptions.hsDisconnected;
  hsStatusText    = RALRESTDWOptions.hsStatusText;

  { TRESTDWTokenRequest }
  rdwtHeader  = RALRESTDWOptions.rdwtHeader;
  rdwtRequest = RALRESTDWOptions.rdwtRequest;

  { TRESTDWTokenType }
  rdwTS       = RALRESTDWOptions.rdwTS;
  rdwJWT      = RALRESTDWOptions.rdwJWT;
  rdwPersonal = RALRESTDWOptions.rdwPersonal;

  { TRESTDWCryptType }
  rdwMD5    = RALRESTDWOptions.rdwMD5;
  rdwSHA1   = RALRESTDWOptions.rdwSHA1;
  rdwSHA256 = RALRESTDWOptions.rdwSHA256;
  rdwSHA512 = RALRESTDWOptions.rdwSHA512;

  { TTyperequest }
  trHttp      = RALRESTDWOptions.trHttp;
  trHttps     = RALRESTDWOptions.trHttps;
  trSocket    = RALRESTDWOptions.trSocket;
  trWebSocket = RALRESTDWOptions.trWebSocket;

  { TMassiveMode }
  mmInactive = RALRESTDWMassive.mmInactive;
  mmBrowse   = RALRESTDWMassive.mmBrowse;
  mmInsert   = RALRESTDWMassive.mmInsert;
  mmUpdate   = RALRESTDWMassive.mmUpdate;
  mmDelete   = RALRESTDWMassive.mmDelete;
  mmExec     = RALRESTDWMassive.mmExec;

  { TMassiveType }
  mtMassiveCache  = RALRESTDWTypes.mtMassiveCache;
  mtMassiveObject = RALRESTDWTypes.mtMassiveObject;

  { TSortOrder / TSortCaseSens }
  soAsc  = RALRESTDWTypes.soAsc;
  soDesc = RALRESTDWTypes.soDesc;
  scYes  = RALRESTDWTypes.scYes;
  scNo   = RALRESTDWTypes.scNo;

  { TRESTDWAuthOption }
  rdwAONone  = RALRESTDWOptions.rdwAONone;
  rdwAOBasic = RALRESTDWOptions.rdwAOBasic;
  rdwAOBearer = RALRESTDWOptions.rdwAOBearer;
  rdwAOToken = RALRESTDWOptions.rdwAOToken;
  rdwOAuth   = RALRESTDWOptions.rdwOAuth;

  { TRequestType }
  rtGet    = RALTypes.amGET;
  rtPost   = RALTypes.amPOST;
  rtPut    = RALTypes.amPUT;
  rtPatch  = RALTypes.amPATCH;
  rtDelete = RALTypes.amDELETE;
  rtOption = RALTypes.amOPTIONS;
  rtAll    = RALTypes.amALL;

  { TEncodeSelect }
  esASCII  = RALRESTDWTypes.esASCII;
  esUtf8   = RALRESTDWTypes.esUtf8;
  esANSI   = RALRESTDWTypes.esANSI;

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

{ Os utilitarios globais que o codigo do RDW chama direto. O Pascal nao
  exporta em cadeia, entao aqui eles sao repasses de uma linha - nao ha
  como alias-los como se faz com tipo e constante. }
function InitStrPos: IntegerRAL;
function DecodeStrings(const AValue: StringRAL): StringRAL;
function EncodeStrings(const AValue: StringRAL): StringRAL;

implementation

function InitStrPos: IntegerRAL;
begin
  Result := RALRESTDWTypes.RALRESTDWInitStrPos;
end;

function DecodeStrings(const AValue: StringRAL): StringRAL;
begin
  Result := RALRESTDWTypes.RALRESTDWDecodeStrings(AValue);
end;

function EncodeStrings(const AValue: StringRAL): StringRAL;
begin
  Result := RALRESTDWTypes.RALRESTDWEncodeStrings(AValue);
end;

end.
