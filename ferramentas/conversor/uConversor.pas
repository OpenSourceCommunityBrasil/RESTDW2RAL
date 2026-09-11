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
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils;

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
  TServidorRAL = record
    Classe: string;    // TRALRESTDWIndyServicePooler, a casca
    UnitName: string;  // RALRESTDWIndyPooler
    Pacote: string;    // IndyRAL, o .bpl do motor que o Delphi registra
    Rotulo: string;    // o que aparece na janela
    TemCasca: Boolean; // False enquanto a casca daquele motor nao existir
  end;

  { TConversor }

  TConversor = class
  private
    FAplicar: Boolean;
    FBackup: Boolean;
    FTrocarTipos: Boolean;
    FConverterTransporte: Boolean;
    FServidorRAL: string;
    FClasseModulo: string;
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
    function ConverterDFM(const ATexto: RawByteString; const AArquivo: string;
                          out AQtd: Integer): RawByteString;
    function ConverterPAS(const ATexto: RawByteString; const AArquivo: string;
                          out AQtd: Integer): RawByteString;
    procedure Converter(const AArquivo: string);
    /// Acha no projeto a classe do DataModule que carrega os ServerEvents
    procedure DescobrirClasseModulo(const ACaminho: string);
  public
    constructor Create;

    procedure Executar(const ACaminho: string);
    class function ExtensaoAceita(const AArquivo: string): Boolean;
    /// Os servidores do RAL que o conversor sabe gerar
    class function ServidoresRAL: TArray<TServidorRAL>;
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

uses
  System.Win.Registry, Winapi.Windows;

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

  { Componentes do RDW sem equivalente: o conversor nao mexe, so avisa }
  cSemEquivalente: array[0..1] of string = (
    'TRESTDWMassiveBuffer',
    'TRESTDWUpdateSQL'
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

class function TConversor.ServidoresRAL: TArray<TServidorRAL>;
begin
  SetLength(Result, 4);
  Result[0].Classe := 'TRALRESTDWIndyServicePooler';
  Result[0].UnitName := 'RALRESTDWIndyPooler';
  Result[0].Pacote := 'IndyRAL';
  Result[0].Rotulo := 'Indy';
  Result[0].TemCasca := True;

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
class procedure TConversor.ServidoresInstalados(ALista: TStrings);
var
  vReg: TRegistry;
  vVersoes, vPacotes, vDaVersao: TStringList;
  vServidores: TArray<TServidorRAL>;
  vInt1, vInt2, vTopo: Integer;
  vInstalado: Boolean;
  vNome: string;
begin
  ALista.Clear;
  vServidores := ServidoresRAL;

  vPacotes := TStringList.Create;
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
        vPacotes.AddStrings(vDaVersao);
      finally
        vReg.CloseKey;
      end;
    end;
  finally
    FreeAndNil(vReg);
    FreeAndNil(vDaVersao);
    FreeAndNil(vVersoes);
  end;

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
  vServidores: TArray<TServidorRAL>;
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
                      ['.pas', '.dpr', '.lpr', '.dfm', '.lfm']);
end;

procedure TConversor.Avisar(const AArquivo, ATexto: string; ATipo: TTipoAviso);
begin
  if Assigned(FOnAviso) then
    FOnAviso(AArquivo, ATexto, ATipo);
end;

{ Acha a classe do DataModule que tem um TRESTDWServerEvents dentro: e o valor
  que o TRALRESTDWModule precisa em ClassModule para publicar as rotas. }
procedure TConversor.DescobrirClasseModulo(const ACaminho: string);
var
  vArquivo, vTexto, vLinha, vClasse: string;
  vLinhas: TStringList;
  vInt1, vPos: Integer;
begin
  if (FClasseModulo <> '') or (not TDirectory.Exists(ACaminho)) then
    Exit;

  for vArquivo in TDirectory.GetFiles(ACaminho, '*.pas',
                                      TSearchOption.soAllDirectories) do
  begin
    vTexto := TFile.ReadAllText(vArquivo, TEncoding.ANSI);
    if not ContainsText(vTexto, 'TRESTDWServerEvents') then
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
          Exit;
        end;
      end;
    finally
      FreeAndNil(vLinhas);
    end;
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
    if TFile.Exists(vPas) then
    begin
      vBytes := TFile.ReadAllBytes(vPas);
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

      for vInt1 := 0 to vItens.Count - 1 do
      begin
        vItem := Trim(vItens[vInt1]);
        if vItem = '' then
          Continue;

        vNomeUnit := vItem;
        if Pos(' in ', LowerCase(vNomeUnit)) > 0 then
          vNomeUnit := Trim(Copy(vNomeUnit, 1, Pos(' in ', LowerCase(vNomeUnit))));

        if StartsText('uRESTDW', vNomeUnit) or StartsText('uDW', vNomeUnit) then
        begin
          vRemoveu := True;
          Avisar(AArquivo, Format('unit do RDW removida do uses: %s', [vNomeUnit]),
                 taUnitRemovida);
          Continue;
        end;

        vSaida.Add(vItem);
      end;

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

  vBytes := TFile.ReadAllBytes(AArquivo);
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
    TFile.Copy(AArquivo, AArquivo + '.bak', True);

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
  vArquivo, vCaminho: string;
begin
  FLidos := 0;
  FAlterados := 0;
  FTotalAlteracoes := 0;

  vCaminho := ExcludeTrailingPathDelimiter(Trim(ACaminho));
  if vCaminho = '' then
    raise Exception.Create('Informe a pasta ou o arquivo a converter');

  if TFile.Exists(vCaminho) then
  begin
    DescobrirClasseModulo(ExtractFilePath(vCaminho));
    Converter(vCaminho);
    Exit;
  end;

  if not TDirectory.Exists(vCaminho) then
    raise Exception.CreateFmt('Caminho nao encontrado: %s', [vCaminho]);

  // duas passadas: a classe do DataModule precisa ser conhecida antes do DFM
  DescobrirClasseModulo(vCaminho);

  for vArquivo in TDirectory.GetFiles(vCaminho, '*.*',
                                      TSearchOption.soAllDirectories) do
    if ExtensaoAceita(vArquivo) then
      Converter(vArquivo);
end;

end.
