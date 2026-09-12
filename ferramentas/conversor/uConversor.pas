{ O motor da conversao, sem interface nenhuma.

  A linha de comando (rdw2ral) e a janela (rdw2ralgui) sao duas caras da mesma
  coisa: toda a regra mora aqui, para as duas nao divergirem com o tempo.

  Tres niveis de trabalho, do mais simples ao mais invasivo:

  1. uses       - tira as units do RDW e poe RALRESTDWCompat
  2. nomes      - renomeia classes de componente e propriedades no formulario
  3. transporte - troca o pooler do RDW pelo servidor do RAL escolhido, leva as
                  propriedades que tem equivalente, descarta as que nao tem e
                  injeta o TRALRESTDWModule, que e a peca que liga o servidor
                  aos eventos

  O passo 3 descarta de proposito tudo que nao souber mapear: o leitor de DFM
  para no primeiro membro que a classe nao tem e leva o formulario inteiro
  junto. Descartar e o unico jeito de o resultado abrir - por isso cada descarte
  vira um aviso, para quem migra reconfigurar o que importava. }
unit uConversor;

interface

uses
  {$IFDEF FPC}
    SysUtils, Classes, StrUtils;
  {$ELSE}
    System.SysUtils, System.Classes, System.StrUtils;
  {$ENDIF}

type
  { A forma do handler de evento: o RDW 2.x entrega o resultado num TStringList
    e o 1.4.3 numa string. }
  TFormaHandler = (fhIndefinida, fhStringList, fhString);

  TTipoAviso = (taUnitRemovida, taRenomeado, taPortado, taDescartado,
                taInjetado, taSemEquivalente);

  TAvisoEvento = procedure(const AArquivo, ATexto: string;
                           ATipo: TTipoAviso) of object;
  TArquivoEvento = procedure(const AArquivo: string;
                             AAlteracoes: Integer) of object;

  { TServidorRAL }

  { Um motor do RAL que o conversor sabe gerar.

    O que entra no formulario nao e a classe do RAL e sim a casca deste
    projeto, que publica a cara do pooler do RDW e faz o de/para por dentro.
    Por isso ha uma casca por motor: o TRALServer e abstrato, quem implementa
    o transporte e a classe filha. }
  { Os motores que o conversor sabe gerar. Tipo com nome em vez de TArray<T>:
    o FPC 3.2 nao tem generico em modo objfpc, e o motor tem de compilar nos
    dois compiladores - a janela do Lazarus usa esta mesma unit. }
  TServidorRAL = record
    Classe: string;    // TRALRESTDWIndyServicePooler, a casca
    UnitName: string;  // RALRESTDWIndyPooler
    Pacote: string;    // IndyRAL, o .bpl do motor que o Delphi registra
    Rotulo: string;    // o que aparece na janela
    TemCasca: Boolean; // False enquanto a casca daquele motor nao existir
    { O pacote deste projeto que traz a casca daquele motor, como o .lpi de um
      projeto Lazarus precisa declarar. Vazio quando a casca nao existe. }
    PacoteCasca: string;
  end;

  TServidoresRAL = array of TServidorRAL;

  { TConversor }

  TConversor = class
  private
    FAplicar: Boolean;
    FBackup: Boolean;
    FTrocarTipos: Boolean;
    FConverterTransporte: Boolean;
    FServidorRAL: string;
    FClasseModulo: string;
    { o projeto usa a metade de banco - resposta do conjunto, nao de um arquivo,
      e e o que decide se o RALRESTDWDB entra nas dependencias do .lpi }
    FUsaBanco: Boolean;
    FLidos: Integer;
    FAlterados: Integer;
    FTotalAlteracoes: Integer;
    FOnAviso: TAvisoEvento;
    FOnArquivo: TArquivoEvento;
    { o .pas do par, guardado: um formulario pergunta a forma uma vez por
      evento, e sao sempre do mesmo arquivo }
    FParArquivo: string;
    FParTexto: string;

    procedure Avisar(const AArquivo, ATexto: string; ATipo: TTipoAviso);

    { Tira as units do RDW e poe as que a conversao passou a exigir. AUnits
      chega com o que o transporte precisou: o servidor, a engine, o modulo. }
    function AjustarUses(const ATexto: RawByteString; const AArquivo: string;
                         AUnits: TStrings; out AQtd: Integer): RawByteString;
    { Um item de Events do RDW antigo, onde Routes era um conjunto e a
      autorizacao vinha no item. No RDW 2.1 - e aqui - cada verbo e um
      objeto proprio, entao [crAll] vira Routes.All.Active. }
    function ItemDeEventoLegado(ALinhas: TStringList; AIdx: Integer): Boolean;
    procedure ReescreverItemEvento(ALinhas, ASaida: TStringList;
                                   var AIdx: Integer; const AArquivo: string;
                                   var AQtd: Integer);
    { A forma e de cada handler, e nao do arquivo: a demo FullServer do RDW tem
      handlers das duas geracoes lado a lado no mesmo .pas. Decidir por arquivo
      ligava metade dos eventos na assinatura errada, e o DFM liga por nome sem
      conferir - dava violacao de acesso na primeira chamada, nao erro de
      compilacao. }
    function FormaDoMetodo(const AArquivoDFM, AMetodo: string): TFormaHandler;

    /// Registra a classe do DataModule, que e como o modulo a encontra
    function InjetarRegisterClass(const ATexto: RawByteString;
                                  const AArquivo: string;
                                  out AQtd: Integer): RawByteString;
    /// O mesmo para um bloco que so troca de nome e perde o que nao mapeia
    procedure ReescreverBloco(ALinhas, ASaida: TStringList; var AIdx: Integer;
                              const AArquivo, ANome, AClasseOrig, AClasseNova,
                              AMapa: string; var AQtd: Integer);
    { Quais pacotes deste projeto entram no lugar de um do RDW }
    function PacotesEquivalentes(const APacoteRDW: string;
                                 ALista: TStrings): Boolean;
    { O projeto do Lazarus: e no .lpi que moram as dependencias de pacote }
    function ConverterLPI(const ATexto: RawByteString; const AArquivo: string;
                          var AQtd: Integer): RawByteString;
    function ConverterDFM(const ATexto: RawByteString; const AArquivo: string;
                          out AQtd: Integer): RawByteString;
    function ConverterPAS(const ATexto: RawByteString; const AArquivo: string;
                          out AQtd: Integer): RawByteString;
    procedure Converter(const AArquivo: string);
    { Uma passada pelo projeto antes de converter: a classe do DataModule dos
      eventos e se o projeto usa a metade de banco }
    procedure ExaminarProjeto(const ACaminho: string);
  public
    constructor Create;

    procedure Executar(const ACaminho: string);
    class function ExtensaoAceita(const AArquivo: string): Boolean;
    /// Os servidores do RAL que o conversor sabe gerar
    class function ServidoresRAL: TServidoresRAL;
    /// Os que estao instalados nesta maquina, na frente da lista
    class procedure ServidoresInstalados(ALista: TStrings);
    /// A unit que declara a classe de servidor escolhida
    class function UnitDoServidor(const AClasse: string): string;

    property Aplicar: Boolean read FAplicar write FAplicar;
    property Backup: Boolean read FBackup write FBackup;
    /// Troca tambem os nomes de tipo (desnecessario com RALRESTDWCompat)
    property TrocarTipos: Boolean read FTrocarTipos write FTrocarTipos;
    { Troca o pooler do RDW pelo servidor do RAL e injeta o TRALRESTDWModule.
      E o passo que faz o projeto convertido rodar, e o mais invasivo. }
    property ConverterTransporte: Boolean read FConverterTransporte
      write FConverterTransporte;
    /// Classe do servidor RAL a gerar, p.ex. TRALIndyServer
    property ServidorRAL: string read FServidorRAL write FServidorRAL;
    /// Classe do DataModule dos eventos; descoberta sozinha se ficar vazia
    property ClasseModulo: string read FClasseModulo write FClasseModulo;

    property Lidos: Integer read FLidos;
    property Alterados: Integer read FAlterados;
    property TotalAlteracoes: Integer read FTotalAlteracoes;

    property OnAviso: TAvisoEvento read FOnAviso write FOnAviso;
    property OnArquivo: TArquivoEvento read FOnArquivo write FOnArquivo;
  end;

implementation

{$IFNDEF FPC}
uses
  System.Win.Registry, Winapi.Windows;
{$ENDIF}

type
  TTroca = record
    De: string;
    Para: string;
    Nota: string;
  end;

const
  { Classes de componente: e o unico ponto que nenhuma unit de compatibilidade
    resolve, porque o formulario guarda o nome real da classe. }
  cClasses: array[0..9] of TTroca = (
    (De: 'TRESTDWServerEvents';   Para: 'TRALRESTDWServerEvents';   Nota: ''),
    (De: 'TRESTDWClientEvents';   Para: 'TRALRESTDWClientEvents';   Nota: ''),
    (De: 'TRESTDWClientSQL';      Para: 'TRALRESTDWClientSQL';      Nota: ''),
    (De: 'TRESTDWIdDatabase';     Para: 'TRALRESTDWDatabase';       Nota: ''),
    (De: 'TRESTDWPoolerDB';       Para: 'TRALRESTDWPoolerDB';       Nota: ''),
    (De: 'TRESTDWFireDACDriver';  Para: 'TRALRESTDWFireDACDriver';  Nota: ''),
    (De: 'TRESTDWMassiveCache';   Para: 'TRALRESTDWMassiveCache';   Nota: ''),
    (De: 'TRESTDWServerContext';  Para: 'TRALRESTDWServerContext';  Nota: ''),
    { o autenticador do RAL publica AuthDialog, UserName e Password com os
      mesmos nomes, entao e troca de nome e nada mais }
    (De: 'TRESTDWAuthBasic';      Para: 'TRALServerBasicAuth';      Nota: ''),
    { O ancestral do DataModule do servidor. A unit de compatibilidade faz o
      alias e o compilador se satisfaz, mas a IDE le esse nome do .pas para
      montar o DataModule no designer, e alias nao e classe - sem a troca o
      DataModule convertido nao abre. }
    (De: 'TServerMethodDataModule'; Para: 'TRALRESTDWDataModule';  Nota: '')
  );

  { Propriedades que trocaram de nome no formulario }
  cPropriedades: array[0..0] of TTroca = (
    (De: 'RESTClientPooler'; Para: 'RALClient';
     Nota: 'o pooler do RDW virou um TRALClient')
  );

  { Componentes do RDW sem equivalente: o conversor nao mexe, so avisa.

    Os drivers de banco: destes so o FireDAC tem casca aqui. Os outros ficam
    com o nome do RDW no formulario e no .pas, e o projeto para de compilar
    nesse ponto - avisar e o unico jeito de quem migra saber por que, em vez de
    receber um "Identifier not found" solto. Os de Lazarus (LazarusDriver,
    LazSQLDriver, ZeosDriver) sao os que mais aparecem, porque e o que as demos
    de Lazarus do RDW usam. }
  cSemEquivalente: array[0..13] of string = (
    'TRESTDWMassiveBuffer',
    'TRESTDWUpdateSQL',
    'TRESTDWLazarusDriver',
    'TRESTDWLazSQLDriver',
    'TRESTDWZeosDriver',
    'TRESTDWNativeDriver',
    'TRESTDWUniDACDriver',
    'TRESTDWIBDACDriver',
    'TRESTDWMyDACDriver',
    'TRESTDWADODriver',
    'TRESTDWAnyDACDriver',
    'TRESTDWApolloDBDriver',
    'TRESTDWDBExpressDriver',
    'TRESTDWInterbaseDriver'
  );

  { As classes cuja casca mora no pacote RALRESTDWDB. No Delphi o library path
    do IDE resolve a unit e ninguem percebe; no Lazarus o pacote tem de estar
    declarado no .lpi, entao quem usa uma destas precisa do RALRESTDWDB junto. }
  cClassesDeBanco: array[0..4] of string = (
    'TRESTDWClientSQL',
    'TRESTDWPoolerDB',
    'TRESTDWIdDatabase',
    'TRESTDWDataBase',
    'TRESTDWFireDACDriver'
  );

  { Eventos que so existiam no TServerMethodDataModule e nao tem equivalente.
    Saem da raiz do DFM do DataModule, senao ele nao abre; o metodo continua no
    .pas e o desenvolvedor precisa resolver - por isso o aviso e em ATENCAO. }
  cEventosDMSemEquivalente: array[0..9] of string = (
    'OnMassiveProcess',
    'OnAfterMassiveLineProcess',
    'OnMassiveBegin',
    'OnMassiveAfterStartTransaction',
    'OnMassiveAfterBeforeCommit',
    'OnMassiveAfterAfterCommit',
    'OnMassiveEnd',
    'OnWelcomeMessage',
    'OnUserTokenAuth',
    'OnGetToken'
  );

  { Tipos, para quem preferir trocar em vez de usar o RALRESTDWCompat }
  { Tipos do espaco de nomes do RDW. Trocam SEMPRE, e nao e capricho: a unit de
    compatibilidade faz o alias e o compilador se satisfaz, mas o designer da
    IDE resolve o nome do tipo pelo pacote de design do RDW quando ele esta
    instalado - e ai recusa o handler com "incompatible parameter list" ao
    abrir o formulario, mesmo com tudo compilando. Sao nomes do RDW, sem risco
    de colidir com o que o projeto tenha de proprio. }
  cTiposSempre: array[0..30] of TTroca = (
    (De: 'TRESTDWParams';        Para: 'TRALRESTDWParams';        Nota: ''),
    (De: 'TDWParams';            Para: 'TRALRESTDWParams';        Nota: ''),
    (De: 'TRESTDWJSONParam';     Para: 'TRALRESTDWJSONParam';     Nota: ''),
    (De: 'TRESTDWJSONValue';     Para: 'TRALRESTDWJSONParam';     Nota: ''),
    (De: 'TRESTDWParamsMethods'; Para: 'TRALRESTDWParamsMethods'; Nota: ''),
    (De: 'TRESTDWParamMethod';   Para: 'TRALRESTDWParamMethod';   Nota: ''),
    (De: 'TRESTDWEventList';     Para: 'TRALRESTDWEventList';     Nota: ''),
    (De: 'TRESTDWEvent';         Para: 'TRALRESTDWEventServer';   Nota: ''),
    (De: 'TRESTDWClientInfo';    Para: 'TRALRESTDWClientInfo';    Nota: ''),
    (De: 'TRESTDWRoute';         Para: 'TRALRESTDWRoute';         Nota: ''),
    (De: 'TRESTDWRoutes';        Para: 'TRALRESTDWRoutes';        Nota: ''),
    (De: 'TRESTDWContext';       Para: 'TRALRESTDWContext';       Nota: ''),
    (De: 'TRESTDWContextList';   Para: 'TRALRESTDWContextList';   Nota: ''),
    (De: 'TRESTDWCriptOptions';  Para: 'TRALRESTDWCriptOptions';  Nota: ''),
    (De: 'TRESTDWProxyOptions';  Para: 'TRALRESTDWProxyOptions';  Nota: ''),
    (De: 'TRESTDWConnectionServer'; Para: 'TRALRESTDWConnectionServer'; Nota: ''),
    (De: 'TRESTDWMIMEType';      Para: 'TRALRESTDWMIMEType';      Nota: ''),
    (De: 'TRESTDWTokenType';     Para: 'TRALRESTDWTokenType';     Nota: ''),
    (De: 'TRESTDWTokenRequest';  Para: 'TRALRESTDWTokenRequest';  Nota: ''),
    (De: 'TRESTDWCryptType';     Para: 'TRALRESTDWCryptType';     Nota: ''),
    (De: 'TRESTDWAuthOption';    Para: 'TRALRESTDWAuthOption';    Nota: ''),
    (De: 'TRESTDWAuthOptionParam'; Para: 'TRALRESTDWAuthOptionParam'; Nota: ''),
    (De: 'TRESTDWAuthOptionBasic'; Para: 'TRALRESTDWAuthOptionBasic'; Nota: ''),
    (De: 'TRESTDWAuthOptionBearer'; Para: 'TRALRESTDWAuthOptionBearer'; Nota: ''),
    (De: 'TRESTDWAuthOptionBearerClient'; Para: 'TRALRESTDWAuthOptionBearer'; Nota: ''),
    (De: 'TRESTDWAuthOptionTokenClient';  Para: 'TRALRESTDWAuthOptionBearer'; Nota: ''),
    (De: 'TRESTDWAuthTokenParam'; Para: 'TRALRESTDWAuthTokenParam'; Nota: ''),
    (De: 'TDWAuthRequest';       Para: 'TRALRESTDWAuthRequest';   Nota: ''),
    (De: 'TDWReplyEvent';        Para: 'TRALRESTDWReplyEvent';    Nota: ''),
    (De: 'TDWReplyEventStr';     Para: 'TRALRESTDWReplyEventStr'; Nota: ''),
    (De: 'TDWReplyEventByType';  Para: 'TRALRESTDWReplyEventByType'; Nota: '')
  );

  { Estes tem nome generico demais para trocar sem o usuario pedir: um projeto
    pode ter um TDataMode ou um TObjectValue proprio. So com --tipos. }
  cTipos: array[0..4] of TTroca = (
    (De: 'TObjectDirection';     Para: 'TRALRESTDWObjectDirection'; Nota: ''),
    (De: 'TObjectValue';         Para: 'TRALRESTDWObjectValue';   Nota: ''),
    (De: 'TTypeObject';          Para: 'TRALRESTDWTypeObject';    Nota: ''),
    (De: 'TDataMode';            Para: 'TRALRESTDWDataMode';      Nota: ''),
    (De: 'TSendEvent';           Para: 'TRALRESTDWSendEvent';     Nota: '')
  );

  { TRESTDWAuthBasic e TRALServerBasicAuth usam os mesmos nomes: a conversao e
    so a troca da classe. }
  cMapaAuth =
    'AuthDialog=AuthDialog;UserName=UserName;Password=Password;' +
    'Tag=Tag;Left=Left;Top=Top';

  { crAll..crOption do RDW antigo, na ordem em que o conjunto os guarda }
  cVerbosRota: array[0..6] of TTroca = (
    (De: 'crAll';    Para: 'All';    Nota: ''),
    (De: 'crGet';    Para: 'Get';    Nota: ''),
    (De: 'crPost';   Para: 'Post';   Nota: ''),
    (De: 'crPut';    Para: 'Put';    Nota: ''),
    (De: 'crPatch';  Para: 'Patch';  Nota: ''),
    (De: 'crDelete'; Para: 'Delete'; Nota: ''),
    (De: 'crOption'; Para: 'Option'; Nota: '')
  );

  cRegBDS = 'SOFTWARE\Embarcadero\BDS';

{ Os utilitarios de arquivo daqui para baixo eram System.IOUtils, que so o
  Delphi tem. Escritos a mao, o motor compila nos dois compiladores - e e o
  motor que precisa ser unico, porque e nele que mora toda a regra da
  conversao. Nenhum deles converte texto: um .pas de projeto RDW e ANSI da
  pagina de codigo da maquina e o conversor so procura identificadores ASCII,
  entao os bytes passam inteiros e voltam inteiros. }

function LerBytes(const AArquivo: string): TBytes;
var
  vStream: TFileStream;
begin
  vStream := TFileStream.Create(AArquivo, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, vStream.Size);
    if vStream.Size > 0 then
      vStream.ReadBuffer(Result[0], vStream.Size);
  finally
    FreeAndNil(vStream);
  end;
end;

function LerTextoAnsi(const AArquivo: string): string;
var
  vBytes: TBytes;
  vAnsi: RawByteString;
begin
  vBytes := LerBytes(AArquivo);
  SetLength(vAnsi, Length(vBytes));
  if Length(vBytes) > 0 then
    Move(vBytes[0], vAnsi[1], Length(vBytes));
  Result := string(vAnsi);
end;

procedure CopiarArquivo(const AOrigem, ADestino: string);
var
  vEntrada, vSaida: TFileStream;
begin
  vEntrada := TFileStream.Create(AOrigem, fmOpenRead or fmShareDenyWrite);
  try
    vSaida := TFileStream.Create(ADestino, fmCreate);
    try
      if vEntrada.Size > 0 then
        vSaida.CopyFrom(vEntrada, vEntrada.Size);
    finally
      FreeAndNil(vSaida);
    end;
  finally
    FreeAndNil(vEntrada);
  end;
end;

{ Todos os arquivos da pasta e das que estao dentro dela. }
procedure ListarArquivos(const APasta: string; ALista: TStrings);
var
  vBusca: TSearchRec;
  vDir: string;
begin
  vDir := IncludeTrailingPathDelimiter(APasta);
  if FindFirst(vDir + '*', faAnyFile, vBusca) <> 0 then
    Exit;
  try
    repeat
      if (vBusca.Name = '.') or (vBusca.Name = '..') then
        Continue;

      if (vBusca.Attr and faDirectory) <> 0 then
        ListarArquivos(vDir + vBusca.Name, ALista)
      else
        ALista.Add(vDir + vBusca.Name);
    until FindNext(vBusca) <> 0;
  finally
    { qualificado de proposito: no Delphi o Winapi.Windows entra depois da RTL
      no uses e leva o FindClose dele, que recebe um handle e nao o TSearchRec }
    {$IFDEF FPC}
      SysUtils.FindClose(vBusca);
    {$ELSE}
      System.SysUtils.FindClose(vBusca);
    {$ENDIF}
  end;
end;

function EhIdentChar(AByte: Byte): Boolean;
begin
  Result := (AByte in [Ord('a')..Ord('z'), Ord('A')..Ord('Z'),
                       Ord('0')..Ord('9'), Ord('_')]);
end;

{ Troca A por B somente quando A esta isolado, isto e, nao faz parte de um
  identificador maior. Sem isso, o componente RESTDWClientSQL1 e o handler
  RESTDWClientSQL1CalcFields seriam reescritos junto com a classe. }
function TrocaPalavra(const ATexto, ADe, APara: RawByteString;
  out AQtd: Integer): RawByteString;
var
  vPos, vIni: Integer;
  vAntes, vDepois: Byte;
  vBaixoTexto, vBaixoDe: string;
begin
  Result := '';
  AQtd := 0;
  vIni := 1;
  vBaixoTexto := LowerCase(string(ATexto));
  vBaixoDe := LowerCase(string(ADe));

  repeat
    vPos := PosEx(vBaixoDe, vBaixoTexto, vIni);
    if vPos = 0 then
      Break;

    vAntes := 0;
    if vPos > 1 then
      vAntes := Ord(ATexto[vPos - 1]);

    vDepois := 0;
    if vPos + Length(ADe) <= Length(ATexto) then
      vDepois := Ord(ATexto[vPos + Length(ADe)]);

    if EhIdentChar(vAntes) or EhIdentChar(vDepois) then
    begin
      Result := Result + Copy(ATexto, vIni, vPos - vIni + Length(ADe));
    end
    else
    begin
      Result := Result + Copy(ATexto, vIni, vPos - vIni) + APara;
      Inc(AQtd);
    end;

    vIni := vPos + Length(ADe);
  until False;

  Result := Result + Copy(ATexto, vIni, MaxInt);
end;

function Contem(const ATexto, AAlvo: RawByteString): Boolean;
begin
  Result := Pos(LowerCase(string(AAlvo)), LowerCase(string(ATexto))) > 0;
end;

{ True para TRESTDWIdServicePooler, TDWIdServicePooler, TRESTServicePooler e
  TServicePooler - os quatro nomes que as demos do RDW usam. }
function EhPoolerRDW(const AClasse: string): Boolean;
begin
  Result := StartsText('T', AClasse) and EndsText('ServicePooler', AClasse);
end;

/// A unit que registra a engine do cliente
function UnitDaEngine(const AEngine: string): string;
begin
  if SameText(AEngine, 'netHTTP') then
    Result := 'RALnetHTTPClient'
  else
    Result := 'RALIndyClient';
end;

{ True para TRESTDWIdClientPooler, TRESTDWIdClientREST e afins - o transporte
  do lado do cliente, que no RAL e um TRALClient so. }
function EhClienteRDW(const AClasse: string): Boolean;
begin
  Result := StartsText('TRESTDW', AClasse) and
            (EndsText('ClientPooler', AClasse) or
             EndsText('ClientREST', AClasse));
end;

{ Qual engine do RAL corresponde ao transporte que o nome da classe diz.
  O RDW poe a sigla no meio do nome: TRESTDWIdClientPooler e Indy. }
function EngineDoCliente(const AClasse: string): string;
begin
  if ContainsText(AClasse, 'netHTTP') then
    Result := 'netHTTP'
  else
    Result := 'Indy';
end;

/// Procura ANome no mapa 'De=Para;De=Para'. False quando nao ha equivalente.
function MapearProp(const AMapa, ANome: string; out ANovo: string): Boolean;
var
  vPos, vIni, vFim: Integer;
begin
  Result := False;
  ANovo := '';
  vIni := 1;

  while vIni <= Length(AMapa) do
  begin
    vFim := PosEx(';', AMapa, vIni);
    if vFim = 0 then
      vFim := Length(AMapa) + 1;

    vPos := PosEx('=', AMapa, vIni);
    if (vPos > vIni) and (vPos < vFim) and
       SameText(Copy(AMapa, vIni, vPos - vIni), ANome) then
    begin
      ANovo := Copy(AMapa, vPos + 1, vFim - vPos - 1);
      Result := True;
      Exit;
    end;

    vIni := vFim + 1;
  end;
end;

/// 'ServicePort = 8082' -> 'ServicePort'. Vazio quando a linha nao e propriedade.
function NomeDaProp(const ALinha: string): string;
var
  vPos, vInt1: Integer;
begin
  Result := '';
  vPos := Pos('=', ALinha);
  if vPos = 0 then
    Exit;

  Result := Trim(Copy(ALinha, 1, vPos - 1));
  if Result = '' then
    Exit;

  // so identificador e ponto: 'item', 'object x: T' e '<' nao passam
  for vInt1 := 1 to Length(Result) do
    if not CharInSet(Result[vInt1], ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) then
    begin
      Result := '';
      Exit;
    end;
end;

/// O valor, ja sem o nome e o '='. Vazio quando a linha nao tem '='.
function ValorDaProp(const ALinha: string): string;
var
  vTrim: string;
  vPos: Integer;
begin
  Result := '';
  vTrim := Trim(ALinha);
  vPos := Pos('=', vTrim);
  if vPos > 0 then
    Result := Trim(Copy(vTrim, vPos + 1, MaxInt));
end;

{ Indice da ultima linha do valor que comeca em AIni. Um valor de DFM ocupa
  varias linhas de tres jeitos: aberto por (, < ou {, quebrado depois do '=' ou
  emendado com '+'. }
function FimDoValor(ALinhas: TStringList; AIni: Integer): Integer;
var
  vValor: string;
  vFecha: Char;
begin
  Result := AIni;
  if Pos('=', ALinhas[AIni]) = 0 then
    Exit;

  vValor := ValorDaProp(ALinhas[AIni]);

  vFecha := #0;
  if vValor <> '' then
    case vValor[Length(vValor)] of
      '(': vFecha := ')';
      '<': vFecha := '>';
      '{': vFecha := '}';
    end;

  if vFecha <> #0 then
  begin
    while Result < ALinhas.Count - 1 do
    begin
      Inc(Result);
      vValor := Trim(ALinhas[Result]);
      if (vValor <> '') and (vValor[Length(vValor)] = vFecha) then
        Break;
    end;
    Exit;
  end;

  while (Result < ALinhas.Count - 1) and
        ((vValor = '') or (vValor[Length(vValor)] = '+')) do
  begin
    Inc(Result);
    vValor := Trim(ALinhas[Result]);
  end;
end;

{ Le a lista de um valor de DFM: literais Pascal, com '' escapando a aspa e '+'
  emendando o item que a linha anterior deixou pela metade. }
procedure LerListaDFM(const ATexto: string; ALista: TStrings);
var
  vInt1: Integer;
  vItem: string;
  vAberto: Boolean;
begin
  ALista.Clear;
  vItem := '';
  vAberto := False;
  vInt1 := 1;

  while vInt1 <= Length(ATexto) do
  begin
    if ATexto[vInt1] <> '''' then
    begin
      Inc(vInt1);
      Continue;
    end;

    Inc(vInt1);
    vAberto := True;
    while vInt1 <= Length(ATexto) do
    begin
      if ATexto[vInt1] = '''' then
      begin
        if (vInt1 < Length(ATexto)) and (ATexto[vInt1 + 1] = '''') then
        begin
          vItem := vItem + '''';
          Inc(vInt1, 2);
          Continue;
        end;
        Inc(vInt1);
        Break;
      end;
      vItem := vItem + ATexto[vInt1];
      Inc(vInt1);
    end;

    // '+' emenda o mesmo item; qualquer outra coisa fecha
    while (vInt1 <= Length(ATexto)) and
          CharInSet(ATexto[vInt1], [' ', #9, #13, #10]) do
      Inc(vInt1);

    if (vInt1 <= Length(ATexto)) and (ATexto[vInt1] = '+') then
    begin
      Inc(vInt1);
      Continue;
    end;

    ALista.Add(vItem);
    vItem := '';
    vAberto := False;
  end;

  if vAberto then
    ALista.Add(vItem);
end;

/// Junta as linhas AIni..AFim num texto so
function JuntarLinhas(ALinhas: TStringList; AIni, AFim: Integer): string;
var
  vInt1: Integer;
begin
  Result := '';
  for vInt1 := AIni to AFim do
    Result := Result + ALinhas[vInt1] + sLineBreak;
end;

/// True para 'True', do jeito que o DFM escreve
function ValorBooleano(const AValor: string): Boolean;
begin
  Result := SameText(Trim(AValor), 'True');
end;

{ Separa as diretivas coladas nas pontas de um item do uses do nome da unit.

  Elas vem coladas mesmo: a demo FullServer do RDW tem um ENDIF grudado no
  uRESTDWDataUtils, no uses da implementacao. Sem separar, o nome nao comeca
  por uRESTDW e a unit do RDW fica no arquivo. Separadas, a unit sai e a
  diretiva fica - tirar um ENDIF junto com a unit deixaria o IFDEF de cima sem
  fechamento, e ai nao compila mais nada.

  (as diretivas estao escritas sem as chaves neste comentario de proposito: o
  compilador le a de dentro do comentario e fecha o comentario nela) }
procedure PartirItemUses(const AItem: string; out APrefixo, ANome,
  ASufixo: string);
var
  vPos: Integer;
begin
  ANome := Trim(AItem);
  APrefixo := '';
  ASufixo := '';

  while StartsText('{$', ANome) do
  begin
    vPos := Pos('}', ANome);
    if vPos = 0 then
      Break;
    APrefixo := APrefixo + Copy(ANome, 1, vPos);
    ANome := TrimLeft(Copy(ANome, vPos + 1, MaxInt));
  end;

  while EndsText('}', ANome) do
  begin
    vPos := LastDelimiter('{', ANome);
    if (vPos = 0) or (Copy(ANome, vPos, 2) <> '{$') then
      Break;
    ASufixo := Copy(ANome, vPos, MaxInt) + ASufixo;
    ANome := TrimRight(Copy(ANome, 1, vPos - 1));
  end;
end;

{ De quem e o pacote. Prefixo em vez de lista fechada: sao dezessete so no
  Phoenix, o 1.4 batiza os dele de outro jeito - RESTDWLazDriver,
  RestDatawareIndySockets, restdatawarecomponents - e as duas geracoes passam
  por aqui. O que identifica e o comeco do nome, em qualquer caixa.

  Sao quatro prefixos porque o RDW ja teve quatro nomes: RestEasyObjects e como
  ele se chamava antes de ser REST Dataware, e o resteasyobjectscore continua
  sendo a dependencia de projeto de 1.4 que vem daquela epoca. RESTDriver pega
  os drivers de banco batizados sem o DW no meio (RESTDriverFD, RESTDriverZEOS,
  RESTDriverUniDAC).

  O que **nao** entra aqui e o TntUnicodeVcl, que vem junto no repositorio do
  RDW mas e de terceiro: tirar do projeto quebraria quem usa os controles. }
function PacoteEhRDW(const ANome: string): Boolean;
begin
  Result := StartsText('RESTDW', ANome) or
            StartsText('RESTDataWare', ANome) or
            StartsText('RestEasyObjects', ANome) or
            StartsText('RESTDriver', ANome);
end;

{ True para o core da geracao antiga, que trazia o transporte dentro dele.

  O resteasyobjectscore e o RestDatawareCORE registram TRESTServicePooler e
  TDWClientREST no proprio pacote - o 2.x so passou o transporte para um pacote
  de sockets a parte. Quem depende de um deles fica sem motor nenhum se sair
  daqui apenas o pacote base. }
function PacoteAntigoComTransporte(const ANome: string): Boolean;
begin
  Result := StartsText('RestEasyObjects', ANome) or
            StartsText('RestDatawareCORE', ANome);
end;

{ O valor de um Value="..." da linha. Devolve string porque nome de pacote e
  ASCII; o resto da linha continua intocado, em bytes. }
function ValorDaTag(const ALinha: RawByteString): string;
var
  vTexto: string;
  vIni, vFim: Integer;
begin
  Result := '';
  vTexto := string(ALinha);

  vIni := Pos('value="', LowerCase(vTexto));
  if vIni = 0 then
    Exit;

  Inc(vIni, Length('value="'));
  vFim := vIni;
  while (vFim <= Length(vTexto)) and (vTexto[vFim] <> '"') do
    Inc(vFim);

  Result := Copy(vTexto, vIni, vFim - vIni);
end;

/// Os brancos com que a linha comeca, para o que entrar sair alinhado
function RecuoDaLinha(const ALinha: RawByteString): RawByteString;
var
  vInt1: Integer;
begin
  vInt1 := 1;
  while (vInt1 <= Length(ALinha)) and (ALinha[vInt1] in [' ', #9]) do
    Inc(vInt1);
  Result := Copy(ALinha, 1, vInt1 - 1);
end;

/// A quebra que a linha traz, para o arquivo continuar no fim de linha dele
function QuebraDaLinha(const ALinha: RawByteString): RawByteString;
var
  vLen: Integer;
begin
  Result := #13#10;
  vLen := Length(ALinha);
  if (vLen >= 1) and (ALinha[vLen] = #10) and
     ((vLen < 2) or (ALinha[vLen - 1] <> #13)) then
    Result := #10;
end;

{ Troca o numero do Count="N" e deixa o resto da linha como esta. E por esse
  atributo que o Lazarus decide como ler a lista: com ele le Item1..ItemN, sem
  ele conta os <Item>. }
function TrocarCount(const ALinha: RawByteString; AValor: Integer): RawByteString;
var
  vTexto: string;
  vIni, vFim: Integer;
begin
  Result := ALinha;
  vTexto := string(ALinha);

  vIni := Pos('count="', LowerCase(vTexto));
  if vIni = 0 then
    Exit;

  Inc(vIni, Length('count="'));
  vFim := vIni;
  while (vFim <= Length(vTexto)) and (vTexto[vFim] <> '"') do
    Inc(vFim);

  Result := RawByteString(Copy(vTexto, 1, vIni - 1) + IntToStr(AValor) +
                          Copy(vTexto, vFim, MaxInt));
end;

{ TConversor }

constructor TConversor.Create;
begin
  inherited Create;
  FAplicar := False;
  FBackup := True;
  FTrocarTipos := False;
  FConverterTransporte := True;
  FServidorRAL := 'TRALRESTDWIndyServicePooler';
  FClasseModulo := '';
end;

class function TConversor.ServidoresRAL: TServidoresRAL;
begin
  SetLength(Result, 4);
  Result[0].Classe := 'TRALRESTDWIndyServicePooler';
  Result[0].UnitName := 'RALRESTDWIndyPooler';
  Result[0].Pacote := 'IndyRAL';
  Result[0].Rotulo := 'Indy';
  Result[0].TemCasca := True;
  Result[0].PacoteCasca := 'RALRESTDWIndy';
  { os demais ficam com PacoteCasca vazio: enquanto nao ha casca, nao ha
    pacote deste projeto para entrar no lugar do pacote de transporte do RDW }

  Result[1].Classe := 'TRALRESTDWSynopseServicePooler';
  Result[1].UnitName := 'RALRESTDWSynopsePooler';
  Result[1].Pacote := 'SynopseRAL';
  Result[1].Rotulo := 'Synopse (mORMot)';
  Result[1].TemCasca := False;

  Result[2].Classe := 'TRALRESTDWSaguiServicePooler';
  Result[2].UnitName := 'RALRESTDWSaguiPooler';
  Result[2].Pacote := 'SaguiRAL';
  Result[2].Rotulo := 'Sagui';
  Result[2].TemCasca := False;

  Result[3].Classe := 'TRALRESTDWUniGUIServicePooler';
  Result[3].UnitName := 'RALRESTDWUniGUIPooler';
  Result[3].Pacote := 'UniGUIRAL';
  Result[3].Rotulo := 'UniGUI';
  Result[3].TemCasca := False;
end;

{ Le os pacotes que o Delphi tem registrados e devolve os servidores do RAL:
  primeiro os instalados, depois o resto marcado como tal. Assim quem migra
  escolhe de uma lista que corresponde a maquina dele, e nao a um catalogo. }
{ Os pacotes que o IDE tem instalados, para o conversor dizer quais motores
  quem migra ja tem a mao. A pergunta e a mesma nos dois lados; a fonte e que
  muda: no Delphi e o registro, e no Lazarus e o staticpackages.inc da
  configuracao do usuario, que lista o que foi de fato instalado no IDE. }
procedure PacotesDoIDE(ALista: TStrings);
{$IFDEF FPC}
var
  vArquivo, vLinha: string;
  vTexto: TStringList;
  vInt1: Integer;
begin
  vArquivo := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) +
              'lazarus' + PathDelim + 'staticpackages.inc';
  if not FileExists(vArquivo) then
    Exit;

  vTexto := TStringList.Create;
  try
    vTexto.LoadFromFile(vArquivo);
    for vInt1 := 0 to vTexto.Count - 1 do
    begin
      // cada linha e "nomedopacote,"; as de comentario comecam com //
      vLinha := Trim(vTexto[vInt1]);
      if (vLinha = '') or (Copy(vLinha, 1, 2) = '//') then
        Continue;

      vLinha := Trim(StringReplace(vLinha, ',', '', [rfReplaceAll]));
      if vLinha <> '' then
        ALista.Add(vLinha);
    end;
  finally
    FreeAndNil(vTexto);
  end;
end;
{$ELSE}
var
  vReg: TRegistry;
  vVersoes, vDaVersao: TStringList;
  vInt1: Integer;
begin
  vVersoes := TStringList.Create;
  vDaVersao := TStringList.Create;
  vReg := TRegistry.Create(KEY_READ);
  try
    vReg.RootKey := HKEY_CURRENT_USER;
    if vReg.OpenKeyReadOnly(cRegBDS) then
    begin
      vReg.GetKeyNames(vVersoes);
      vReg.CloseKey;
    end;

    // toda versao do Delphi instalada, para nao depender de qual esta aberta
    for vInt1 := 0 to vVersoes.Count - 1 do
    begin
      if not vReg.OpenKeyReadOnly(cRegBDS + '\' + vVersoes[vInt1] +
                                  '\Known Packages') then
        Continue;
      try
        // GetValueNames limpa a lista que recebe: acumular numa segunda
        vReg.GetValueNames(vDaVersao);
        ALista.AddStrings(vDaVersao);
      finally
        vReg.CloseKey;
      end;
    end;
  finally
    FreeAndNil(vReg);
    FreeAndNil(vDaVersao);
    FreeAndNil(vVersoes);
  end;
end;
{$ENDIF}

class procedure TConversor.ServidoresInstalados(ALista: TStrings);
var
  vPacotes: TStringList;
  vServidores: TServidoresRAL;
  vInt1, vInt2, vTopo: Integer;
  vInstalado: Boolean;
  vNome: string;
begin
  ALista.Clear;
  vServidores := ServidoresRAL;

  vPacotes := TStringList.Create;
  PacotesDoIDE(vPacotes);

  vTopo := 0;
  try
    for vInt1 := Low(vServidores) to High(vServidores) do
    begin
      vInstalado := False;
      for vInt2 := 0 to vPacotes.Count - 1 do
        if SameText(ChangeFileExt(ExtractFileName(vPacotes[vInt2]), ''),
                    vServidores[vInt1].Pacote) then
        begin
          vInstalado := True;
          Break;
        end;

      vNome := vServidores[vInt1].Rotulo;
      if not vServidores[vInt1].TemCasca then
      begin
        ALista.AddObject(vNome + '  - casca ainda nao feita',
                         TObject(NativeInt(vInt1)));
        Continue;
      end;

      if vInstalado then
      begin
        ALista.InsertObject(vTopo, vNome, TObject(NativeInt(vInt1)));
        Inc(vTopo);
      end
      else
        ALista.AddObject(vNome + '  - pacote nao instalado',
                         TObject(NativeInt(vInt1)));
    end;
  finally
    FreeAndNil(vPacotes);
  end;
end;

class function TConversor.UnitDoServidor(const AClasse: string): string;
var
  vServidores: TServidoresRAL;
  vInt1: Integer;
begin
  Result := '';
  vServidores := ServidoresRAL;
  for vInt1 := Low(vServidores) to High(vServidores) do
    if SameText(vServidores[vInt1].Classe, AClasse) then
      Exit(vServidores[vInt1].UnitName);
end;

class function TConversor.ExtensaoAceita(const AArquivo: string): Boolean;
begin
  Result := MatchText(LowerCase(ExtractFileExt(AArquivo)),
                      ['.pas', '.dpr', '.lpr', '.dfm', '.lfm', '.lpi']);
end;

procedure TConversor.Avisar(const AArquivo, ATexto: string; ATipo: TTipoAviso);
begin
  if Assigned(FOnAviso) then
    FOnAviso(AArquivo, ATexto, ATipo);
end;

{ Acha a classe do DataModule que tem um TRESTDWServerEvents dentro: e o valor
  que o TRALRESTDWModule precisa em ClassModule para publicar as rotas. }
procedure TConversor.ExaminarProjeto(const ACaminho: string);
var
  vArquivo, vTexto, vLinha, vClasse: string;
  vLinhas, vArquivos: TStringList;
  vInt1, vInt2, vInt3, vPos: Integer;
begin
  FUsaBanco := False;
  if not DirectoryExists(ACaminho) then
    Exit;

  vArquivos := TStringList.Create;
  try
    ListarArquivos(ACaminho, vArquivos);
    for vInt2 := 0 to vArquivos.Count - 1 do
    begin
    vArquivo := vArquivos[vInt2];
    if not SameText(ExtractFileExt(vArquivo), '.pas') then
      Continue;

    vTexto := LerTextoAnsi(vArquivo);

    { a metade de banco: quem usa uma dessas classes precisa do RALRESTDWDB
      declarado, e e a passada inteira que responde isso - o .lpi pode vir
      antes do .pas que as usa }
    if not FUsaBanco then
      for vInt3 := Low(cClassesDeBanco) to High(cClassesDeBanco) do
        if ContainsText(vTexto, cClassesDeBanco[vInt3]) then
        begin
          FUsaBanco := True;
          Break;
        end;

    if (FClasseModulo <> '') or (not ContainsText(vTexto, 'TRESTDWServerEvents')) then
      Continue;

    vLinhas := TStringList.Create;
    try
      vLinhas.Text := vTexto;
      vClasse := '';

      for vInt1 := 0 to vLinhas.Count - 1 do
      begin
        vLinha := Trim(vLinhas[vInt1]);

        // 'TDMPrincipal = CLASS(TServerMethodDataModule)'
        vPos := Pos('=', vLinha);
        if (vPos > 1) and ContainsText(vLinha, 'class(') then
          vClasse := Trim(Copy(vLinha, 1, vPos - 1))
        else if (vClasse <> '') and ContainsText(vLinha, ': TRESTDWServerEvents;') then
        begin
          FClasseModulo := vClasse;
          Break;
        end;
      end;
    finally
      FreeAndNil(vLinhas);
    end;

    // as duas respostas na mao: nao ha mais o que procurar
    if FUsaBanco and (FClasseModulo <> '') then
      Break;
    end;
  finally
    FreeAndNil(vArquivos);
  end;
end;

procedure TConversor.ReescreverBloco(ALinhas, ASaida: TStringList;
  var AIdx: Integer; const AArquivo, ANome, AClasseOrig, AClasseNova,
  AMapa: string; var AQtd: Integer);
var
  vIndent, vTrim, vProp, vNovo: string;
  vFim, vNivel: Integer;
begin
  vIndent := Copy(ALinhas[AIdx], 1,
                  Length(ALinhas[AIdx]) - Length(TrimLeft(ALinhas[AIdx])));
  ASaida.Add(vIndent + Format('object %s: %s', [ANome, AClasseNova]));
  Inc(AQtd);
  Avisar(AArquivo, Format('%s: %s -> %s', [ANome, AClasseOrig, AClasseNova]),
         taRenomeado);
  Inc(AIdx);

  while AIdx < ALinhas.Count do
  begin
    vTrim := Trim(ALinhas[AIdx]);

    if SameText(vTrim, 'end') then
    begin
      ASaida.Add(vIndent + 'end');
      Inc(AIdx);
      Exit;
    end;

    // subcomponente: o RAL nao tem nenhum equivalente, sai inteiro
    if StartsText('object ', vTrim) then
    begin
      Avisar(AArquivo, Format('%s: subcomponente %s descartado', [ANome, vTrim]),
             taDescartado);
      vNivel := 1;
      Inc(AIdx);
      while (AIdx < ALinhas.Count) and (vNivel > 0) do
      begin
        vTrim := Trim(ALinhas[AIdx]);
        if StartsText('object ', vTrim) then
          Inc(vNivel)
        else if SameText(vTrim, 'end') then
          Dec(vNivel);
        Inc(AIdx);
      end;
      Continue;
    end;

    vProp := NomeDaProp(vTrim);
    vFim := FimDoValor(ALinhas, AIdx);

    if (vProp <> '') and MapearProp(AMapa, vProp, vNovo) then
    begin
      ASaida.Add(StringReplace(ALinhas[AIdx], vProp, vNovo, [rfIgnoreCase]));
      while AIdx < vFim do
      begin
        Inc(AIdx);
        ASaida.Add(ALinhas[AIdx]);
      end;
    end
    else if vProp <> '' then
    begin
      Avisar(AArquivo, Format('%s.%s descartada - %s nao tem equivalente',
             [ANome, vProp, AClasseNova]), taDescartado);
      AIdx := vFim;
    end;

    Inc(AIdx);
  end;
end;

function TConversor.ItemDeEventoLegado(ALinhas: TStringList;
  AIdx: Integer): Boolean;
var
  vNivel: Integer;
  vTrim: string;
begin
  Result := False;
  vNivel := 1;
  Inc(AIdx);

  while (AIdx < ALinhas.Count) and (vNivel > 0) do
  begin
    vTrim := Trim(ALinhas[AIdx]);

    if SameText(vTrim, 'item') or StartsText('object ', vTrim) then
      Inc(vNivel)
    else if SameText(vTrim, 'end') or SameText(vTrim, 'end>') then
      Dec(vNivel)
    else if (vNivel = 1) and SameText(NomeDaProp(vTrim), 'Routes') and
            StartsText('[', ValorDaProp(vTrim)) then
      Exit(True);

    Inc(AIdx);
  end;
end;

procedure TConversor.ReescreverItemEvento(ALinhas, ASaida: TStringList;
  var AIdx: Integer; const AArquivo: string; var AQtd: Integer);
var
  vCorpo, vVerbos: TStringList;
  vNivel, vFim, vInt1, vPos: Integer;
  vTrim, vProp, vValor, vIndent, vAutoriza: string;
begin
  vIndent := '';
  vCorpo := TStringList.Create;
  vVerbos := TStringList.Create;
  try
    ASaida.Add(ALinhas[AIdx]);
    Inc(AIdx);
    vNivel := 1;
    vAutoriza := '';

    while AIdx < ALinhas.Count do
    begin
      vTrim := Trim(ALinhas[AIdx]);

      if SameText(vTrim, 'item') or StartsText('object ', vTrim) then
        Inc(vNivel)
      else if SameText(vTrim, 'end') or SameText(vTrim, 'end>') then
      begin
        Dec(vNivel);
        if vNivel = 0 then
          Break;
      end;

      vProp := '';
      if vNivel = 1 then
        vProp := NomeDaProp(vTrim);
      vFim := AIdx;

      if SameText(vProp, 'Routes') and StartsText('[', ValorDaProp(vTrim)) then
      begin
        vIndent := Copy(ALinhas[AIdx], 1,
                        Length(ALinhas[AIdx]) - Length(TrimLeft(ALinhas[AIdx])));
        vFim := FimDoValor(ALinhas, AIdx);
        vValor := LowerCase(JuntarLinhas(ALinhas, AIdx, vFim));

        for vInt1 := Low(cVerbosRota) to High(cVerbosRota) do
        begin
          vPos := Pos(LowerCase(cVerbosRota[vInt1].De), vValor);
          if (vPos > 0) and
             (not EhIdentChar(Ord(vValor[vPos + Length(cVerbosRota[vInt1].De)]))) then
            vVerbos.Add(cVerbosRota[vInt1].Para);
        end;
      end
      else if SameText(vProp, 'NeedAuthorization') then
      begin
        vFim := FimDoValor(ALinhas, AIdx);
        vAutoriza := ValorDaProp(vTrim);
      end
      else
        vCorpo.Add(ALinhas[AIdx]);

      AIdx := vFim + 1;
    end;

    for vInt1 := 0 to vCorpo.Count - 1 do
      ASaida.Add(vCorpo[vInt1]);

    if vIndent = '' then
      vIndent := '        ';

    for vInt1 := 0 to vVerbos.Count - 1 do
    begin
      ASaida.Add(Format('%sRoutes.%s.Active = True', [vIndent, vVerbos[vInt1]]));
      if vAutoriza <> '' then
        ASaida.Add(Format('%sRoutes.%s.NeedAuthorization = %s',
                          [vIndent, vVerbos[vInt1], vAutoriza]));
    end;

    if vVerbos.Count > 0 then
    begin
      Inc(AQtd);
      Avisar(AArquivo, Format('evento: Routes = [%s] -> Routes.<verbo>.Active; ' +
             'no RAL a autorizacao e por verbo', [vVerbos.CommaText]), taPortado);
    end;

    if AIdx < ALinhas.Count then
    begin
      ASaida.Add(ALinhas[AIdx]);
      Inc(AIdx);
    end;
  finally
    FreeAndNil(vVerbos);
    FreeAndNil(vCorpo);
  end;
end;

{ Quem declara o handler e o .pas do par; quem precisa saber o nome da
  propriedade e o .dfm. Ler o par evita depender da ordem da varredura. O texto
  fica guardado porque um formulario pergunta uma vez por evento. }
function TConversor.FormaDoMetodo(const AArquivoDFM,
  AMetodo: string): TFormaHandler;
var
  vPas, vDecl, vLinha: string;
  vBytes: TBytes;
  vTexto: RawByteString;
  vLinhas: TStringList;
  vInt1, vFim: Integer;
begin
  Result := fhIndefinida;
  if Trim(AMetodo) = '' then
    Exit;

  if not SameText(FParArquivo, AArquivoDFM) then
  begin
    FParArquivo := AArquivoDFM;
    FParTexto := '';
    vPas := ChangeFileExt(AArquivoDFM, '.pas');
    if FileExists(vPas) then
    begin
      vBytes := LerBytes(vPas);
      if Length(vBytes) > 0 then
      begin
        SetLength(vTexto, Length(vBytes));
        Move(vBytes[0], vTexto[1], Length(vBytes));
        FParTexto := string(vTexto);
      end;
    end;
  end;

  if FParTexto = '' then
    Exit;

  vLinhas := TStringList.Create;
  try
    vLinhas.Text := FParTexto;
    for vInt1 := 0 to vLinhas.Count - 1 do
    begin
      vLinha := vLinhas[vInt1];
      if not ContainsText(vLinha, AMetodo) then
        Continue;

      { a lista de parametros pode vir quebrada; junta ate o ')' }
      vDecl := '';
      vFim := vInt1;
      while (vFim < vLinhas.Count) and (vFim - vInt1 < 8) do
      begin
        vDecl := vDecl + ' ' + vLinhas[vFim];
        if Pos(')', vLinhas[vFim]) > 0 then
          Break;
        Inc(vFim);
      end;

      if not ContainsText(vDecl, 'Params') then
        Continue;

      if ContainsText(vDecl, 'Result: TStringList') or
         ContainsText(vDecl, 'Result : TStringList') then
        Exit(fhStringList);

      if ContainsText(vDecl, 'Result: string') or
         ContainsText(vDecl, 'Result : string') then
        Exit(fhString);
    end;
  finally
    FreeAndNil(vLinhas);
  end;
end;

function TConversor.InjetarRegisterClass(const ATexto: RawByteString;
  const AArquivo: string; out AQtd: Integer): RawByteString;
var
  vLinhas: TStringList;
  vInt1, vFim, vIni: Integer;
  vTrim: string;
begin
  Result := ATexto;
  AQtd := 0;

  if (FClasseModulo = '') or
     Contem(ATexto, RawByteString('RegisterClass(' + FClasseModulo)) then
    Exit;

  // so na unit que declara a classe
  if not Contem(ATexto, RawByteString(FClasseModulo + ' = class(')) then
    Exit;

  vLinhas := TStringList.Create;
  try
    vLinhas.Text := string(Result);
    vIni := -1;
    vFim := -1;

    for vInt1 := 0 to vLinhas.Count - 1 do
    begin
      vTrim := Trim(vLinhas[vInt1]);
      if SameText(vTrim, 'initialization') then
        vIni := vInt1
      else if SameText(vTrim, 'end.') then
        vFim := vInt1;
    end;

    if vIni >= 0 then
      vLinhas.Insert(vIni + 1, '  RegisterClass(' + FClasseModulo + ');')
    else if vFim >= 0 then
    begin
      vLinhas.Insert(vFim, '');
      vLinhas.Insert(vFim + 1, 'initialization');
      vLinhas.Insert(vFim + 2, '  RegisterClass(' + FClasseModulo + ');');
      vLinhas.Insert(vFim + 3, '');
    end
    else
      Exit;

    Result := RawByteString(vLinhas.Text);
    AQtd := 1;
    Avisar(AArquivo, Format('RegisterClass(%s) adicionado - e assim que o ' +
           'TRALRESTDWModule acha a classe', [FClasseModulo]), taInjetado);
  finally
    FreeAndNil(vLinhas);
  end;
end;

{ Os pacotes deste projeto que entram no lugar de um do RDW - podem ser dois:

    driver ou link  -> a metade de banco
    socket ou shell -> o transporte, que depende do motor escolhido. Vale para
                       projeto cliente tambem: e o pacote do motor que registra
                       a engine do RAL dentro do executavel, e sem ele o
                       cliente compila e nao acha engine nenhuma em tempo de
                       execucao
    core antigo     -> transporte **e** base, porque naquela geracao os dois
                       vinham no mesmo pacote
    o resto         -> so a base, que o ConverterLPI acrescenta de qualquer
                       jeito quando alguma dependencia do RDW sai

  O jClient do LAMW cai no base de proposito: e cliente, e o cliente mora la.

  Devolve False quando faltou o pacote do transporte - o unico caso em que o
  pacote do RDW tem de ficar onde esta. }
function TConversor.PacotesEquivalentes(const APacoteRDW: string;
  ALista: TStrings): Boolean;
var
  vServidores: TServidoresRAL;
  vCasca: string;
  vInt1: Integer;
begin
  Result := True;

  if ContainsText(APacoteRDW, 'Driver') or ContainsText(APacoteRDW, 'Link') then
  begin
    ALista.Add('RALRESTDWDB');
    Exit;
  end;

  if not (ContainsText(APacoteRDW, 'Socket') or
          ContainsText(APacoteRDW, 'Shell') or
          PacoteAntigoComTransporte(APacoteRDW)) then
  begin
    ALista.Add('RALRESTDW');
    Exit;
  end;

  { o transporte so tem substituto quando o motor escolhido tem casca aqui -
    e quando a conversao do transporte esta ligada, senao a classe do RDW
    continua no formulario e o pacote dela ainda faz falta }
  vCasca := '';
  if FConverterTransporte then
  begin
    vServidores := ServidoresRAL;
    for vInt1 := Low(vServidores) to High(vServidores) do
      if SameText(vServidores[vInt1].Classe, FServidorRAL) then
      begin
        vCasca := vServidores[vInt1].PacoteCasca;
        Break;
      end;
  end;

  if vCasca = '' then
    Exit(False);

  ALista.Add(vCasca);
  // o core antigo era as duas coisas, entao leva a base junto
  if PacoteAntigoComTransporte(APacoteRDW) then
    ALista.Add('RALRESTDW');
end;

{ O .lpi e o projeto do Lazarus, e e nele que moram as dependencias de pacote.

  Trocar o uses dos fontes nao basta ali: o projeto continua exigindo os
  pacotes do RDW - que podem nem estar instalados na maquina de quem recebe -
  e nao exige os daqui, entao o Lazarus nao acha as units e o projeto nem abre.
  No Delphi isso nao aparece, porque la as units vem do library path do IDE e
  nao de uma dependencia declarada dentro do projeto.

  Mexe so entre <RequiredPackages> e </RequiredPackages>, linha a linha e em
  bytes: o IDE grava uma tag por linha, e passar o arquivo inteiro por string
  estragaria acento de titulo ou de autor.

  Sao dois formatos e os dois aparecem nas demos do RDW: o novo repete <Item>,
  e o antigo traz Count="N" com <Item1>..<ItemN>. O Lazarus escolhe como ler
  pela presenca do Count, entao o que sai daqui mantem o formato que entrou -
  renumerando os itens e corrigindo o Count quando for o antigo. }
function TConversor.ConverterLPI(const ATexto: RawByteString;
  const AArquivo: string; var AQtd: Integer): RawByteString;
var
  vPos, vFim, vLinhaIni, vIniBloco, vFimBloco, vInt1, vIndice: Integer;
  vLinha, vEOL, vAbertura, vCorpo, vItem, vRecuo, vTag: RawByteString;
  vPacote, vNovo, vMotivo: string;
  vNovos, vTrocas: TStringList;
  vNoItem, vLegado: Boolean;
begin
  Result := ATexto;
  if not Contem(ATexto, '<RequiredPackages') then
    Exit;

  vNovos := TStringList.Create;
  vTrocas := TStringList.Create;
  try
    vNovos.Sorted := True;
    vNovos.Duplicates := dupIgnore;

    vAbertura := '';
    vCorpo := '';
    vItem := '';
    vRecuo := '      ';
    vEOL := #13#10;
    vPacote := '';
    vIniBloco := 0;
    vFimBloco := 0;
    vIndice := 0;
    vNoItem := False;
    vLegado := False;

    vPos := 1;
    while vPos <= Length(ATexto) do
    begin
      { a linha sai inteira, com a quebra que tiver - assim um arquivo em LF
        continua em LF e a ultima linha sem quebra continua sem }
      vLinhaIni := vPos;
      vFim := vPos;
      while (vFim <= Length(ATexto)) and (ATexto[vFim] <> #10) do
        Inc(vFim);
      if vFim <= Length(ATexto) then
        Inc(vFim);

      vLinha := Copy(ATexto, vPos, vFim - vPos);
      vPos := vFim;

      // fora do bloco so interessa achar onde ele comeca
      if vIniBloco = 0 then
      begin
        if Contem(vLinha, '<RequiredPackages') then
        begin
          vIniBloco := vLinhaIni;
          vAbertura := vLinha;
          vEOL := QuebraDaLinha(vLinha);
          vLegado := Contem(vLinha, 'Count="');
        end;
        Continue;
      end;

      { o fim do bloco encerra a leitura: o resto do arquivo sai inteiro do
        texto original, sem passar por aqui }
      if Contem(vLinha, '</RequiredPackages>') then
      begin
        vFimBloco := vLinhaIni;
        Break;
      end;

      if not vNoItem then
      begin
        if not Contem(vLinha, '<Item') then
        begin
          // linha solta dentro do bloco: sai como entrou, na mesma ordem
          vCorpo := vCorpo + vLinha;
          Continue;
        end;

        vNoItem := True;
        vItem := '';
        vPacote := '';
        // o recuo do arquivo, para o que entrar sair igual ao que ja esta
        vRecuo := RecuoDaLinha(vLinha);
        Continue;
      end;

      { as linhas de dentro do item ficam guardadas ate ele fechar, porque so
        no fim se sabe se o item era do RDW }
      if not Contem(vLinha, '</Item') then
      begin
        vItem := vItem + vLinha;
        if Contem(vLinha, '<PackageName') then
          vPacote := ValorDaTag(vLinha);
        Continue;
      end;

      vNoItem := False;

      if PacoteEhRDW(vPacote) then
      begin
        vTrocas.Clear;
        if PacotesEquivalentes(vPacote, vTrocas) then
        begin
          vNovo := '';
          for vInt1 := 0 to vTrocas.Count - 1 do
          begin
            vNovos.Add(vTrocas[vInt1]);
            if vNovo <> '' then
              vNovo := vNovo + ' + ';
            vNovo := vNovo + vTrocas[vInt1];
          end;

          Avisar(AArquivo, Format('dependencia de pacote %s -> %s',
                 [vPacote, vNovo]), taRenomeado);
          Inc(AQtd);
          Continue; // o item do RDW nao vai para a saida
        end;

        { o transporte nao foi convertido: tirar o pacote e deixar a classe do
          RDW no formulario seria trocar um projeto que compila por um que nao
          compila - fica como esta, com aviso }
        if FConverterTransporte then
          vMotivo := 'o motor escolhido ainda nao tem casca neste projeto'
        else
          vMotivo := 'o transporte ficou de fora desta conversao';
        Avisar(AArquivo, Format('dependencia de pacote %s mantida: %s',
               [vPacote, vMotivo]), taSemEquivalente);
      end;

      Inc(vIndice);
      vTag := 'Item';
      if vLegado then
        vTag := vTag + RawByteString(IntToStr(vIndice));
      vCorpo := vCorpo + vRecuo + '<' + vTag + '>' + vEOL + vItem +
                         vRecuo + '</' + vTag + '>' + vEOL;
    end;

    { nada a fazer, ou algo que nao se entendeu: o arquivo volta intocado.
      vNoItem aberto quer dizer item sem fechamento, e reescrever um bloco que
      nao se leu inteiro seria perder o que sobrou dele }
    if (vFimBloco = 0) or vNoItem or (vNovos.Count = 0) then
      Exit;

    { o base entra sempre que algo do RDW saiu: e dele que vem os eventos, o
      cliente e o DataModule }
    vNovos.Add('RALRESTDW');

    { e a metade de banco entra quando o projeto usa uma das classes dela, mesmo
      que nenhum pacote de driver tenha saido: um cliente magro com
      TRESTDWClientSQL nao depende de driver nenhum, e mesmo assim precisa do
      RALRESTDWDB, que e onde a casca desse dataset mora }
    if FUsaBanco then
      vNovos.Add('RALRESTDWDB');

    for vInt1 := 0 to vNovos.Count - 1 do
    begin
      // ja declarado: converter duas vezes nao duplica a dependencia
      if Contem(ATexto, RawByteString('Value="' + vNovos[vInt1] + '"')) then
        Continue;

      Inc(vIndice);
      vTag := 'Item';
      if vLegado then
        vTag := vTag + RawByteString(IntToStr(vIndice));
      vCorpo := vCorpo + vRecuo + '<' + vTag + '>' + vEOL +
                         vRecuo + '  <PackageName Value="' +
                         RawByteString(vNovos[vInt1]) + '"/>' + vEOL +
                         vRecuo + '</' + vTag + '>' + vEOL;
      Avisar(AArquivo, Format('dependencia de pacote %s adicionada',
             [vNovos[vInt1]]), taInjetado);
      Inc(AQtd);
    end;

    if vLegado then
      vAbertura := TrocarCount(vAbertura, vIndice);

    Result := Copy(ATexto, 1, vIniBloco - 1) + vAbertura + vCorpo +
              Copy(ATexto, vFimBloco, MaxInt);
  finally
    FreeAndNil(vTrocas);
    FreeAndNil(vNovos);
  end;
end;

function TConversor.ConverterDFM(const ATexto: RawByteString;
  const AArquivo: string; out AQtd: Integer): RawByteString;
var
  vLinhas, vSaida: TStringList;
  vInt1, vIdx, vQtd, vFim: Integer;
  vTrim, vNome, vClasse, vProp: string;
  vRaiz: Boolean;
begin
  AQtd := 0;

  vLinhas := TStringList.Create;
  vSaida := TStringList.Create;
  try
    vLinhas.Text := string(ATexto);
    vIdx := 0;

    while vIdx < vLinhas.Count do
    begin
      vTrim := Trim(vLinhas[vIdx]);

      if StartsText('object ', vTrim) and (Pos(':', vTrim) > 0) then
      begin
        vNome := Trim(Copy(vTrim, 8, Pos(':', vTrim) - 8));
        vClasse := Trim(Copy(vTrim, Pos(':', vTrim) + 1, MaxInt));

        { O transporte e so troca de nome: a casca do projeto publica a cara
          do RDW e faz o de/para por dentro, entao nenhuma propriedade
          precisa ser mexida nem descartada aqui. }
        if FConverterTransporte and EhPoolerRDW(vClasse) then
        begin
          vSaida.Add(StringReplace(vLinhas[vIdx], vClasse, FServidorRAL,
                                   [rfIgnoreCase]));
          Avisar(AArquivo, Format('%s: %s -> %s', [vNome, vClasse, FServidorRAL]),
                 taRenomeado);
          Inc(AQtd);
          Inc(vIdx);
          Continue;
        end;

        if FConverterTransporte and EhClienteRDW(vClasse) then
        begin
          vSaida.Add(StringReplace(vLinhas[vIdx], vClasse, 'TRALRESTDWClient',
                                   [rfIgnoreCase]));
          Avisar(AArquivo, Format('%s: %s -> TRALRESTDWClient', [vNome, vClasse]),
                 taRenomeado);
          Inc(AQtd);
          Inc(vIdx);
          Continue;
        end;

        // o autenticador vai pela tabela cClasses, como as demais classes
      end;

      { Routes como conjunto so existe no RDW antigo; no 2.1 e no RAL cada
        verbo e um objeto. O item inteiro precisa ser reescrito. }
      if SameText(vTrim, 'item') and ItemDeEventoLegado(vLinhas, vIdx) then
      begin
        ReescreverItemEvento(vLinhas, vSaida, vIdx, AArquivo, AQtd);
        Continue;
      end;

      { na raiz do DFM de um DataModule do RDW moram eventos que so o
        TServerMethodDataModule tinha - saem, senao o form nao abre }
      vRaiz := (vLinhas[vIdx] <> '') and (vLinhas[vIdx][1] = ' ') and
               ((Length(vLinhas[vIdx]) < 3) or (vLinhas[vIdx][3] <> ' '));
      if vRaiz then
      begin
        vProp := NomeDaProp(vTrim);
        if (vProp <> '') and MatchText(vProp, cEventosDMSemEquivalente) then
        begin
          vFim := FimDoValor(vLinhas, vIdx);
          Avisar(AArquivo, Format('%s descartado - sem equivalente no RAL; o ' +
                 'metodo continua no .pas e nao vai compilar', [vProp]),
                 taSemEquivalente);
          vIdx := vFim + 1;
          Inc(AQtd);
          Continue;
        end;
      end;

      { Cada handler decide sozinho: as duas formas estao publicadas, com nomes
        diferentes, e aqui so se aponta para a certa. }
      vProp := NomeDaProp(vTrim);
      if MatchText(vProp, ['OnReplyEvent', 'OnReplyEventByType']) and
         (FormaDoMetodo(AArquivo, ValorDaProp(vTrim)) = fhString) then
      begin
        vSaida.Add(StringReplace(vLinhas[vIdx], vProp, vProp + 'Str', []));
        Avisar(AArquivo, Format('%s = %s esta na forma do RDW 1.4.3 -> %sStr',
               [vProp, ValorDaProp(vTrim), vProp]), taRenomeado);
        Inc(AQtd);
        Inc(vIdx);
        Continue;
      end;

      vSaida.Add(vLinhas[vIdx]);
      Inc(vIdx);
    end;

    Result := RawByteString(vSaida.Text);
  finally
    FreeAndNil(vSaida);
    FreeAndNil(vLinhas);
  end;

  // os renames simples valem para o formulario inteiro
  for vInt1 := Low(cClasses) to High(cClasses) do
  begin
    Result := TrocaPalavra(Result, RawByteString(cClasses[vInt1].De),
                           RawByteString(cClasses[vInt1].Para), vQtd);
    Inc(AQtd, vQtd);
    if vQtd > 0 then
      Avisar(AArquivo, Format('%s -> %s (%d)', [cClasses[vInt1].De,
             cClasses[vInt1].Para, vQtd]), taRenomeado);
  end;

  for vInt1 := Low(cPropriedades) to High(cPropriedades) do
  begin
    Result := TrocaPalavra(Result, RawByteString(cPropriedades[vInt1].De),
                           RawByteString(cPropriedades[vInt1].Para), vQtd);
    Inc(AQtd, vQtd);
    if vQtd > 0 then
      Avisar(AArquivo, Format('%s -> %s (%s)', [cPropriedades[vInt1].De,
             cPropriedades[vInt1].Para, cPropriedades[vInt1].Nota]), taRenomeado);
  end;
end;

function TConversor.ConverterPAS(const ATexto: RawByteString;
  const AArquivo: string; out AQtd: Integer): RawByteString;
var
  vLinhas, vUnits: TStringList;
  vInt1, vQtd, vPos: Integer;
  vTrim, vClasse: string;
begin
  AQtd := 0;
  Result := ATexto;

  vUnits := TStringList.Create;
  try
    { O campo do pooler vira o transporte do RAL e ganha ao lado o que o
      formulario passou a ter. Se o .pas e o .dfm discordarem de um campo que
      seja, o formulario nao abre - por isso os dois lados saem daqui juntos. }
    if FConverterTransporte then
    begin
      vLinhas := TStringList.Create;
      try
        vLinhas.Text := string(Result);
        vInt1 := 0;
        while vInt1 < vLinhas.Count do
        begin
          vTrim := Trim(vLinhas[vInt1]);
          vPos := Pos(':', vTrim);
          if (vPos > 0) and EndsText(';', vTrim) then
          begin
            vClasse := Trim(Copy(vTrim, vPos + 1, Length(vTrim) - vPos - 1));
            if EhPoolerRDW(vClasse) then
            begin
              vLinhas[vInt1] := StringReplace(vLinhas[vInt1], vClasse,
                                              FServidorRAL, [rfIgnoreCase]);
              Inc(AQtd);
              vUnits.Add(UnitDoServidor(FServidorRAL));
            end
            else if EhClienteRDW(vClasse) then
            begin
              vLinhas[vInt1] := StringReplace(vLinhas[vInt1], vClasse,
                                              'TRALRESTDWClient', [rfIgnoreCase]);
              Inc(AQtd);
              vUnits.Add('RALRESTDWClient');
              vUnits.Add(UnitDaEngine(EngineDoCliente(vClasse)));
            end
            else if SameText(vClasse, 'TRESTDWAuthBasic') then
              vUnits.Add('RALAuthentication');
          end;
          Inc(vInt1);
        end;
        Result := RawByteString(vLinhas.Text);
      finally
        FreeAndNil(vLinhas);
      end;
    end;

    Result := AjustarUses(Result, AArquivo, vUnits, vQtd);
    Inc(AQtd, vQtd);
  finally
    FreeAndNil(vUnits);
  end;

  for vInt1 := Low(cClasses) to High(cClasses) do
  begin
    Result := TrocaPalavra(Result, RawByteString(cClasses[vInt1].De),
                           RawByteString(cClasses[vInt1].Para), vQtd);
    Inc(AQtd, vQtd);
  end;

  Result := InjetarRegisterClass(Result, AArquivo, vQtd);
  Inc(AQtd, vQtd);

  for vInt1 := Low(cTiposSempre) to High(cTiposSempre) do
  begin
    Result := TrocaPalavra(Result, RawByteString(cTiposSempre[vInt1].De),
                           RawByteString(cTiposSempre[vInt1].Para), vQtd);
    Inc(AQtd, vQtd);
    if vQtd > 0 then
      Avisar(AArquivo, Format('%s -> %s (%d)', [cTiposSempre[vInt1].De,
             cTiposSempre[vInt1].Para, vQtd]), taRenomeado);
  end;

  if FTrocarTipos then
    for vInt1 := Low(cTipos) to High(cTipos) do
    begin
      Result := TrocaPalavra(Result, RawByteString(cTipos[vInt1].De),
                             RawByteString(cTipos[vInt1].Para), vQtd);
      Inc(AQtd, vQtd);
    end;
end;

function TConversor.AjustarUses(const ATexto: RawByteString;
  const AArquivo: string; AUnits: TStrings;
  out AQtd: Integer): RawByteString;
var
  vBaixo, vItem, vNomeUnit, vBloco, vNovo: string;
  vPrefixo, vSufixo, vPendente: string;
  vPosUses, vPosFim, vInicio, vInt1: Integer;
  vItens, vSaida: TStringList;
  vRemoveu, vPrecisaCompat, vPrecisaSQL, vPrecisaDB, vPrecisaPooler: Boolean;
  vPrecisaContexto: Boolean;
begin
  Result := ATexto;
  AQtd := 0;
  { por arquivo, e nao por clausula: o Delphi recusa a mesma unit no uses da
    interface e no da implementacao, e um arquivo tem as duas }
  vPrecisaCompat := not Contem(ATexto, 'RALRESTDWCompat');
  vPrecisaSQL := (Contem(ATexto, 'TRESTDWClientSQL') or
                  Contem(ATexto, 'TRALRESTDWClientSQL')) and
                 (not Contem(ATexto, 'RALRESTDWClientSQL'));
  { as cascas de banco vivem no pacote RALRESTDWDB, entao a RALRESTDWCompat -
    que e do pacote de eventos - nao pode reexporta-las }
  vPrecisaContexto := (Contem(ATexto, 'TRESTDWServerContext') or
                       Contem(ATexto, 'TRALRESTDWServerContext')) and
                      (not Contem(ATexto, 'RALRESTDWServerContext,')) and
                      (not Contem(ATexto, 'RALRESTDWServerContext;'));
  vPrecisaDB := (Contem(ATexto, 'TRESTDWIdDatabase') or
                 Contem(ATexto, 'TRALRESTDWDatabase')) and
                (not Contem(ATexto, 'RALRESTDWDatabase'));
  vPrecisaPooler := (Contem(ATexto, 'TRESTDWPoolerDB') or
                     Contem(ATexto, 'TRESTDWFireDACDriver') or
                     Contem(ATexto, 'TRALRESTDWPoolerDB') or
                     Contem(ATexto, 'TRALRESTDWFireDACDriver')) and
                    (not Contem(ATexto, 'RALRESTDWPoolerDB'));

  vInicio := 1;
  repeat
    vBaixo := LowerCase(string(Result));
    vPosUses := 0;

    for vInt1 := vInicio to Length(vBaixo) - 4 do
      if (Copy(vBaixo, vInt1, 4) = 'uses') and
         ((vInt1 = 1) or (vBaixo[vInt1 - 1] = #10) or (vBaixo[vInt1 - 1] = #13)) and
         (not EhIdentChar(Ord(vBaixo[vInt1 + 4]))) then
      begin
        vPosUses := vInt1;
        Break;
      end;

    if vPosUses = 0 then
      Break;

    vPosFim := PosEx(';', string(Result), vPosUses);
    if vPosFim = 0 then
      Break;

    vBloco := Copy(string(Result), vPosUses + 4, vPosFim - vPosUses - 4);

    vItens := TStringList.Create;
    vSaida := TStringList.Create;
    try
      vItens.StrictDelimiter := True;
      vItens.Delimiter := ',';
      vItens.DelimitedText := StringReplace(
        StringReplace(vBloco, #13, '', [rfReplaceAll]), #10, '', [rfReplaceAll]);

      vRemoveu := False;
      vPendente := '';

      for vInt1 := 0 to vItens.Count - 1 do
      begin
        PartirItemUses(vItens[vInt1], vPrefixo, vItem, vSufixo);
        if (vItem = '') and (vPrefixo = '') and (vSufixo = '') then
          Continue;

        // item so de diretiva: ela vale para o proximo que ficar
        if vItem = '' then
        begin
          vPendente := vPendente + vPrefixo + vSufixo;
          Continue;
        end;

        vNomeUnit := vItem;
        if Pos(' in ', LowerCase(vNomeUnit)) > 0 then
          vNomeUnit := Trim(Copy(vNomeUnit, 1, Pos(' in ', LowerCase(vNomeUnit))));

        if StartsText('uRESTDW', vNomeUnit) or StartsText('uDW', vNomeUnit) then
        begin
          vRemoveu := True;
          // a unit sai, as diretivas dela ficam
          vPendente := vPendente + vPrefixo + vSufixo;
          Avisar(AArquivo, Format('unit do RDW removida do uses: %s', [vNomeUnit]),
                 taUnitRemovida);
          Continue;
        end;

        vSaida.Add(vPendente + vPrefixo + vItem + vSufixo);
        vPendente := '';
      end;

      { a diretiva que sobrou do ultimo item removido gruda no fim do que
        ficou. Se nao ficou nada ela some junto: o que abre e o que fecha
        estavam os dois dentro da clausula, entao o par sai inteiro }
      if (vPendente <> '') and (vSaida.Count > 0) then
        vSaida[vSaida.Count - 1] := vSaida[vSaida.Count - 1] + vPendente;

      { Uma clausula que ficou sem nenhuma unit nao e Pascal valido, e nao e
        so teoria: a demo FullClient do RDW ja vem com um 'uses;' vazio, que
        nem no RDW compila. Tirar a clausula inteira e o unico desfecho
        possivel, e de quebra conserta o projeto. }
      if (vSaida.Count = 0) and (not vPrecisaCompat) and (not vPrecisaSQL) and
         (not vPrecisaDB) and (not vPrecisaPooler) and
         (not vPrecisaContexto) and (AUnits.Count = 0) then
      begin
        Avisar(AArquivo, 'clausula uses vazia removida - ela ja estava assim e '
               + 'nao compilava nem no RDW', taRenomeado);
        Result := Copy(Result, 1, vPosUses - 1) + Copy(Result, vPosFim + 1, MaxInt);
        Inc(AQtd);
        vInicio := vPosUses;
        Continue;
      end;

      if (not vRemoveu) and (AUnits.Count = 0) and (not vPrecisaDB) and
         (not vPrecisaPooler) and (not vPrecisaSQL) and
         (not vPrecisaContexto) then
      begin
        vInicio := vPosFim + 1;
        Continue;
      end;

      if vPrecisaCompat then
      begin
        vSaida.Add('RALRESTDWCompat');
        vPrecisaCompat := False;
      end;
      if vPrecisaSQL then
      begin
        vSaida.Add('RALRESTDWClientSQL');
        vPrecisaSQL := False;
      end;
      if vPrecisaDB then
      begin
        vSaida.Add('RALRESTDWDatabase');
        vPrecisaDB := False;
      end;
      if vPrecisaContexto then
      begin
        vSaida.Add('RALRESTDWServerContext');
        vPrecisaContexto := False;
      end;
      if vPrecisaPooler then
      begin
        vSaida.Add('RALRESTDWPoolerDB');
        vPrecisaPooler := False;
      end;

      // as units do transporte entram na primeira clausula e so nela
      for vInt1 := 0 to AUnits.Count - 1 do
        if (AUnits[vInt1] <> '') and (vSaida.IndexOf(AUnits[vInt1]) < 0) then
          vSaida.Add(AUnits[vInt1]);
      AUnits.Clear;

      vNovo := '';
      for vInt1 := 0 to vSaida.Count - 1 do
      begin
        if vInt1 > 0 then
          vNovo := vNovo + ',' + sLineBreak;
        vNovo := vNovo + '  ' + vSaida[vInt1];
      end;

      Result := Copy(Result, 1, vPosUses + 3) +
                RawByteString(sLineBreak + vNovo) + Copy(Result, vPosFim, MaxInt);
      Inc(AQtd);
      vInicio := vPosUses + 4 + Length(vNovo);
    finally
      FreeAndNil(vSaida);
      FreeAndNil(vItens);
    end;
  until False;
end;

procedure TConversor.Converter(const AArquivo: string);
var
  vBytes: TBytes;
  vTexto, vOriginal: RawByteString;
  vExt: string;
  vInt1, vQtd: Integer;
  vStream: TFileStream;
begin
  Inc(FLidos);
  vExt := LowerCase(ExtractFileExt(AArquivo));

  vBytes := LerBytes(AArquivo);
  SetLength(vTexto, Length(vBytes));
  if Length(vBytes) > 0 then
    Move(vBytes[0], vTexto[1], Length(vBytes));
  vOriginal := vTexto;
  vQtd := 0;

  for vInt1 := Low(cSemEquivalente) to High(cSemEquivalente) do
    if Contem(vTexto, RawByteString(cSemEquivalente[vInt1])) then
      Avisar(AArquivo, Format('%s nao tem equivalente automatico',
             [cSemEquivalente[vInt1]]), taSemEquivalente);

  if MatchText(vExt, ['.dfm', '.lfm']) then
    vTexto := ConverterDFM(vTexto, AArquivo, vQtd)
  else if MatchText(vExt, ['.pas', '.dpr', '.lpr']) then
    vTexto := ConverterPAS(vTexto, AArquivo, vQtd)
  else if vExt = '.lpi' then
    vTexto := ConverterLPI(vTexto, AArquivo, vQtd)
  else
    Exit;

  if vTexto = vOriginal then
    Exit;

  Inc(FAlterados);
  Inc(FTotalAlteracoes, vQtd);

  if Assigned(FOnArquivo) then
    FOnArquivo(AArquivo, vQtd);

  if not FAplicar then
    Exit;

  if FBackup then
    CopiarArquivo(AArquivo, AArquivo + '.bak');

  vStream := TFileStream.Create(AArquivo, fmCreate);
  try
    if Length(vTexto) > 0 then
      vStream.WriteBuffer(vTexto[1], Length(vTexto));
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TConversor.Executar(const ACaminho: string);
var
  vCaminho: string;
  vArquivos: TStringList;
  vInt1: Integer;
begin
  FLidos := 0;
  FAlterados := 0;
  FTotalAlteracoes := 0;

  vCaminho := ExcludeTrailingPathDelimiter(Trim(ACaminho));
  if vCaminho = '' then
    raise Exception.Create('Informe a pasta ou o arquivo a converter');

  if FileExists(vCaminho) then
  begin
    ExaminarProjeto(ExtractFilePath(vCaminho));
    Converter(vCaminho);
    Exit;
  end;

  if not DirectoryExists(vCaminho) then
    raise Exception.CreateFmt('Caminho nao encontrado: %s', [vCaminho]);

  // duas passadas: o que o conjunto responde precisa ser sabido antes do DFM
  ExaminarProjeto(vCaminho);

  vArquivos := TStringList.Create;
  try
    ListarArquivos(vCaminho, vArquivos);
    for vInt1 := 0 to vArquivos.Count - 1 do
      if ExtensaoAceita(vArquivos[vInt1]) then
        Converter(vArquivos[vInt1]);
  finally
    FreeAndNil(vArquivos);
  end;
end;

end.
