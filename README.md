# RESTDW2RAL

Sair do **REST Dataware** para o **[PascalRAL](https://github.com/OpenSourceCommunityBrasil/PascalRAL)**
sem reescrever o código que você já tem.

Este projeto reimplementa o modelo *ServerEvents / ClientEvents* do RDW em cima do
PascalRAL — **sem nenhuma unit do RDW no projeto**. Não é uma ponte, não é um wrapper:
é o mesmo jeito de trabalhar, com RAL por baixo.

```pascal
// o seu handler do RDW                       // depois de migrar
procedure Tdm.evPing(                         procedure Tdm.evPing(
  var Params: TRESTDWParams;                    var Params: TRESTDWParams;
  const Result: TStringList);                   const Result: TStringList);
begin                                         begin
  Result.Text := 'olá ' +                       Result.Text := 'olá ' +
    Params.ItemsString['nome'].AsString;          Params.ItemsString['nome'].AsString;
end;                                          end;
```

Não é erro de impressão: com a unit `RALRESTDWCompat` no `uses`, o corpo **e a
assinatura** ficam idênticos.

---

## Índice

- [Migrar em três passos](#migrar-em-três-passos)
  - [Por que existem as "cascas"](#por-que-existem-as-cascas)
  - [Os dois lados migram igual](#os-dois-lados-migram-igual)
- [Requisitos e instalação](#requisitos-e-instalação)
- [Os três componentes](#os-três-componentes)
- [Servidor](#servidor)
- [Cliente](#cliente)
- [Parâmetros](#parâmetros)
- [Datasets](#datasets)
- [Banco de dados: o ClientSQL](#banco-de-dados-o-clientsql)
- [Conversor de projetos](#conversor-de-projetos)
- [Autorização](#autorização)
- [De/Para: RDW → RESTDW2RAL](#depara-rdw--restdw2ral)
- [As duas gerações de handler](#as-duas-gerações-de-handler)
- [Demos](#demos)
- [Limitações conhecidas](#limitações-conhecidas)
- [Licença](#licença)

---

## Migrar em três passos

**1. Troque o `uses`.** Onde havia as units do RDW, ponha uma só:

```pascal
uses uRESTDWParams, uRESTDWServerEvents, uRESTDWConsts;   // antes
uses RALRESTDWCompat;                                     // depois
```

`RALRESTDWCompat` traz `TRESTDWParams`, `TRESTDWJSONParam`, `TObjectValue`,
`TObjectDirection`, `TDataMode`, `cUndefined`, `ovString`, `odINOUT`, `toParam` — todos os
nomes que o seu código usa, inclusive os valores dos enums.

**2. Troque a classe dos componentes no DFM/LFM.** Isto é busca e substituição:

| no formulário | vira |
| --- | --- |
| `TRESTDWServerEvents` | `TRALRESTDWServerEvents` |
| `TRESTDWClientEvents` | `TRALRESTDWClientEvents` |

**3. Troque a classe do transporte.** Também busca e substituição, porque do outro lado
há uma classe com **a mesma cara do pooler do RDW**:

| no formulário | vira |
| --- | --- |
| `TRESTDWIdServicePooler`, `TRESTDWIcsServicePooler` | `TRALRESTDWIndyServicePooler` |
| `TRESTDWIdClientPooler`, `TRESTDWIdClientREST` | `TRALRESTDWClient` |
| `TRESTDWIdDatabase` | `TRALRESTDWDatabase` |
| `TRESTDWPoolerDB` | `TRALRESTDWPoolerDB` |
| `TRESTDWFireDACDriver` | `TRALRESTDWFireDACDriver` |
| `TRESTDWMassiveCache` | `TRALRESTDWMassiveCache` |
| `TRESTDWServerContext` | `TRALRESTDWServerContext` |
| `TRESTDWAuthBasic` | `TRALServerBasicAuth` |

`ServicePort`, `RootPath`, `ServerMethodClass`, `Host`, `Port`, `UseSSL`,
`AuthenticationOptions.OptionParams.Username`, `CriptOptions`, `CORS_CustomHeaders` —
todos continuam existindo, com o mesmo nome, e por dentro viram o que o RAL entende.
Nenhuma propriedade sai do formulário, nenhuma linha de código muda.

**O corpo dos seus handlers não muda.** Nem os nomes dos parâmetros, nem os acessores
`As*`, nem o `Result`, nem o `ItemsString`.

### Por que existem as "cascas"

Um conversor consegue reescrever um `.dfm`. Reescrever **código** ele não consegue com
segurança — e o pooler do RDW é usado em código o tempo todo. Nas demos oficiais do RDW,
`AuthenticationOptions.OptionParams` aparece 40 vezes, `Active` 26, `RootPath` 9,
`ServerMethodClass` 5.

Por isso o projeto tem uma classe com a cara de cada transporte do RDW, com o RAL
implementado por dentro. O conversor só troca o nome; o de/para acontece em tempo de
execução:

| você escreve (RDW) | a casca faz (RAL) |
| --- | --- |
| `ServicePort := 8082` | `Port := 8082` |
| `RootPath := '/api/'` | `Domain` do módulo interno |
| `ServerMethodClass := TDM` | `RegisterClass(TDM)` + `ClassModule := 'TDM'` |
| `Host`, `Port`, `UseSSL` | uma `BaseURL` só |
| `PoolerService`, `PoolerPort` | idem, no `TRALClient` interno da conexão |
| `DataRoute := '/datadm/'` | `ModuleRoute` da conexão |
| `AuthenticationOptions...Username` | um `TRALClientBasicAuth` em `Authentication` |
| `AuthOptions.GetToken(payload)` | um JWT HS256 assinado, que o `TRALServerJWTAuth` valida |
| `CriptOptions.Use/Key` | `CriptoOptions.CriptType/Key` |
| `CORS_CustomHeaders` | `CORSOptions.AllowOrigin` e `.AllowHeaders` |
| `PathTraversalRaiseError` | `Security.Options` |
| `SSLCertFile` e afins | `SSL.SSLOptions.*` |
| `DWClientREST.Get(url, hdr, resp)` | uma requisição pelo `TRALClient`, devolvendo o código HTTP |
| `ClientSQL.OpenJson(texto)` | os campos saem das chaves do JSON e o dataset é preenchido |
| `DataBase.GetKeyFieldNames(tab, lista)` | pergunta a estrutura ao servidor e lê a marca de chave |
| `MassiveCache.MassiveCount` | quantas alterações o cache do dataset tem para enviar |
| `SortFields`, `SortOrder` | `IndexFieldNames` do memtable |

O que o RAL não tem — `FailOver`, `ProxyOptions`, `ThreadRequest`, `Encoding`,
`ForceWelcomeAccess` — continua **publicado e inerte**: o formulário abre, o código
compila, e cada membro diz ao lado do próprio código por que não faz nada. Publicar é
obrigatório, e não gentileza: o leitor de DFM para na primeira propriedade que a classe
não tem e leva o formulário inteiro junto.

Uma casca por **motor do RAL**, e não por transporte do RDW: quem escolhe o motor é quem
migra. Hoje existe a do Indy (`TRALRESTDWIndyServicePooler`); o conversor lista os
outros motores e avisa quando ainda não há casca.

### Os dois lados migram igual

Servidor e cliente seguem exatamente os mesmos três passos. No cliente, o código de chamada
fica intacto — `CreateDWParams`, `SendEvent`, `ItemsString`, `cUndefined`, o `var` nos
parâmetros, os verbos `sePOST`/`sePUT`/`seDELETE`, o `AsSyncExec`, o `OnBeforeSend` e até a
propriedade `GetEvents: Boolean` têm o nome e a assinatura do RDW:

```pascal
// este trecho é válido nos dois, sem uma vírgula de diferença
ClientEvents.CreateDWParams('ping', DWParams);
DWParams.ItemsString['nome'].AsString := 'fernando';
if ClientEvents.SendEvent('ping', DWParams, Erro) then
  ShowMessage(DWParams.ItemsString[cUndefined].AsString);
```

As duas únicas coisas que mudam no cliente, e nenhuma unit de compatibilidade resolve porque
vivem no formulário: a **classe** do componente (`TRESTDWClientEvents` →
`TRALRESTDWClientEvents`) e a **propriedade do transporte** (`RESTClientPooler` →
`RALClient`). Em troca, o cliente pede menos configuração do que pedia no RDW: com
`AutoFetch` a coleção `Events` pode ficar vazia, porque ele busca as definições na primeira
chamada.

---

## Requisitos e instalação

| | |
| --- | --- |
| Delphi | XE ou superior (validado no 12 Athens) |
| Lazarus | 2.x / FPC 3.2+ |
| PascalRAL | pacotes `PascalRAL` + `PascalRALDsgn` instalados |
| Engine | qualquer um do RAL: `IndyRAL`, `SynopseRAL`, `NetHttpRAL`, `fpHttpRAL`, `SaguiRAL`… |

**Delphi:** instale `PascalRAL` e `PascalRALDsgn`, depois abra `pkg/delphi/RALRESTDW.dproj`,
compile e **Install**. Adicione `src` ao *Library Path*.

**Lazarus:** instale `pascalral` e `pascalraldsgn`, depois `pkg/lazarus/RALRESTDW.lpk` →
**Use → Install**.

A paleta ganha **RAL - RDWModule** (`TRALRESTDWServerEvents`, `TRALRESTDWClientEvents`,
`TRALRESTDWClient`) e **RAL - Modules** (`TRALRESTDWModule`).

### Três pacotes, e por quê

| pacote | o que traz | do que depende |
| --- | --- | --- |
| `RALRESTDW` | eventos, params, o cliente, o DataModule, massive, contexto | só do PascalRAL |
| `RALRESTDWDB` | `TRALRESTDWClientSQL`, `TRALRESTDWDatabase`, `TRALRESTDWPoolerDB` | link de banco do RAL |
| `RALRESTDWIndy` | `TRALRESTDWIndyServicePooler` | `IndyRAL` |

A separação existe para ninguém carregar o que não usa: quem só é cliente de eventos
não puxa FireDAC nem Indy junto.

### O pacote de banco, separado

Quem vem do `TRESTDWClientSQL` instala também `RALRESTDWDB` — `pkg/delphi/RALRESTDWDB.dproj`
ou `pkg/lazarus/RALRESTDWDB.lpk`. Ele é um pacote à parte de propósito: depende do link de
banco do RAL (`RALDBFireDACLink` no Delphi, `raldbsqldblink` no Lazarus), e quem só usa
eventos não deve carregar FireDAC junto. Ele traz o `TRALRESTDWClientSQL` para a mesma
paleta **RAL - RDWModule**.

---

## Os três componentes

```
   SERVIDOR                                       CLIENTE

 TRALServer  ──────── engine HTTP ────────────  TRALClient
      │                                              │
 TRALRESTDWModule                            TRALRESTDWClientEvents
   ClassModule ─┐                             (espelho dos eventos,
                ▼                              preenchido sozinho)
      DataModule registrado
                │
      TRALRESTDWServerEvents
                │
             Events[]  ← os seus handlers
```

| Componente | Onde | Papel |
| --- | --- | --- |
| `TRALRESTDWServerEvents` | num `TDataModule` | os eventos e os handlers |
| `TRALRESTDWModule` | junto do `TRALServer` | acha os eventos e publica as rotas |
| `TRALRESTDWClientEvents` | no cliente | espelha os eventos e faz a chamada |

---

## Servidor

### 1. O DataModule

Crie um `TDataModule`, solte um `TRALRESTDWServerEvents` e monte a coleção `Events` —
exatamente como no RDW.

| Propriedade do evento | O que é |
| --- | --- |
| `EventName` | nome do evento; com `BaseURL` forma a rota |
| `BaseURL` | prefixo; deixe `/` no caso simples |
| `DefaultContentType` | content-type da resposta |
| `Description` | vai para o Swagger e para o export |
| `Params` | declaração dos parâmetros |
| `Routes` | quais verbos o evento atende (`All`, `Get`, `Post`, …) |
| `DataMode` | `dmRAW` / `dmDataware` |
| `OnlyPreDefinedParams` | recusa parâmetro não declarado |
| `OnReplyEvent` | o seu handler |
| `OnAuthRequest` | autorização só deste evento |
| `OnBeforeExecute` | roda antes do handler |

> **A rota é `BaseURL + '/' + EventName`.** Com `BaseURL = '/'` e `EventName = 'ping'` a
> rota é `/ping`. Pôr `/ping` nos dois faz `/ping/ping` — é o engano mais comum.

```pascal
unit udm_eventos;

interface

uses
  System.SysUtils, System.Classes,
  RALTypes, RALRESTDWServerEvents, RALRESTDWParams, RALRESTDWTypes;

type
  Tdm_eventos = class(TDataModule)
    srv: TRALRESTDWServerEvents;
    procedure srvEventspingReplyEvent(var AParams: TRALRESTDWParams;
      const AResult: TStringList);
  end;

implementation

{$R *.dfm}

procedure Tdm_eventos.srvEventspingReplyEvent(var AParams: TRALRESTDWParams;
  const AResult: TStringList);
begin
  AResult.Text := 'olá ' + AParams.ItemsString['nome'].AsString;
end;

initialization
  RegisterClass(Tdm_eventos);   // <<< OBRIGATÓRIO

end.
```

**O `RegisterClass` não é opcional.** O módulo acha o DataModule pelo *nome da classe*, via
`GetClass`. Sem ele, toda chamada responde **403**. A unit também precisa estar no `uses` de
algum lugar do projeto, senão o linker a descarta.

### 2. O módulo

| Propriedade | Valor |
| --- | --- |
| `Server` | o seu `TRALServer` |
| `Domain` | prefixo de todas as rotas (padrão `/`) |
| `ClassModule` | `'Tdm_eventos'` |
| `AutoRoutes` | **`True`** (padrão) |
| `FileExporter` | opcional, só para exportar/importar rotas |

**É só isso.** Com `AutoRoutes` ligado o módulo instancia a classe de `ClassModule`, acha os
`TRALRESTDWServerEvents` dentro dela e publica uma rota por evento — com os verbos,
a descrição e os parâmetros de entrada. Você não escreve rota nenhuma, nem exporta nada.

```pascal
procedure Tfprincipal.FormCreate(Sender: TObject);
begin
  server.Start;      // e pronto
end;
```

Precisa conferir no design-time? Botão direito no módulo → **Refresh Routes**, e a coleção
`Routes` aparece preenchida. Se preferir controlar na mão, desligue `AutoRoutes` e monte
`Routes` você mesmo — o que estiver lá tem prioridade e nunca é sobrescrito.

### 3. O que acontece em cada requisição

1. O RAL casa a URL com uma rota do módulo.
2. O módulo instancia **uma cópia nova do DataModule** e dispara o `OnCreate` de cada
   `TRALRESTDWServerEvents` — é o gancho para preparar conexão, cache, o que for.
3. Acha o evento pela rota, confere o `AccessTag`, roda o `OnAuthRequest` se houver.
4. Chama o seu handler.
5. Libera o DataModule.

> Cada requisição cria e destrói o DataModule: não guarde estado entre chamadas em campos
> dele. Em compensação, os handlers são naturalmente isolados entre threads.

> **Levou 403?** É (a) classe não registrada ou nome errado em `ClassModule`, ou
> (b) `AccessTag` divergente. Não é falha de autenticação.

### Chamando de fora do Delphi

As rotas são REST comuns. Um `curl`, um front em JavaScript ou um cliente Python chamam o
evento direto, sem saber que existe um `ServerEventName`:

```bash
curl -X POST http://localhost:8000/soma -F a=17 -F b=25
```

---

## Cliente

```pascal
cliente := TRALClient;                 // BaseURL = 'localhost:8000'
                                       // EngineType = 'netHTTP' (ou 'Indy', 'fpHTTP'…)
ce := TRALRESTDWClientEvents;          // RALClient = cliente
                                       // ModuleRoute = '/'  (o Domain do servidor)
```

E acabou a configuração. Com `AutoFetch` ligado (padrão), a primeira chamada busca as
definições dos eventos no servidor sozinha. `ServerEventName` pode ficar vazio quando o
DataModule do servidor tem um único `TRALRESTDWServerEvents`.

```pascal
var
  vParams: TRALRESTDWParams;
  vErro: StringRAL;
begin
  ce.CreateDWParams('soma', vParams);
  if vParams = nil then                 // evento não existe no servidor
    Exit;
  try
    vParams.ItemsString['a'].AsInteger := 17;
    vParams.ItemsString['b'].AsInteger := 25;

    if ce.SendEvent('soma', vParams, vErro) then
      ShowMessage(IntToStr(vParams.ItemsString['total'].AsInteger))
    else
      ShowMessage('erro: ' + vErro);
  finally
    vParams.Free;                       // o objeto é seu
  end;
end;
```

- `CreateDWParams` **cria** o objeto e devolve na variável — quem chama libera. Evento
  desconhecido devolve `nil`.
- O retorno do handler chega no parâmetro `cUndefined` (o `RawBody` do RDW):
  `vParams.ItemsString[cUndefined].AsString`, ou `vParams.RawBody.AsString`.
- Os parâmetros `odOUT`/`odINOUT` voltam preenchidos no mesmo objeto.
- Verbo no 4º argumento: `sePOST` (padrão), `sePUT`, `seDELETE`, `sePATCH`, `seGET`.
- 5º argumento `AsSyncExec = True` dispara e volta na hora, sem ler resposta.

Outras propriedades, todas com o nome que o RDW usa:

| | |
| --- | --- |
| `GetEvents: Boolean` | `:= True` baixa as definições agora (também é o verbo **Get Events**) |
| `Events` | o espelho local, editável no Object Inspector |
| `ServerEventName` | o dropdown consulta o servidor em tempo real |
| `AccessTag` | filtro de visibilidade, igual ao do servidor |
| `OnBeforeSend` | roda antes de cada envio |
| `ClearEvents` / `FetchEvents` | limpa / recarrega o espelho |

---

## Parâmetros

Cada item de `Params` declara:

| | |
| --- | --- |
| `ParamName` / `Alias` | a busca do `ItemsString` aceita os dois |
| `ObjectDirection` | `odIN`, `odOUT`, `odINOUT` |
| `ObjectValue` | `ovString`, `ovInteger`, `ovFloat`, `ovDate`, `ovDataSet`… |
| `TypeObject` | `toParam`, `toDataset`, `toVariable`, `toObject` |
| `DefaultValue` | valor inicial |
| `Encoded` | trafega em Base64 |

| | entra (`odIN`/`odINOUT`) | sai (`odOUT`/`odINOUT`) |
| --- | --- | --- |
| **servidor** | lê do request antes do handler | escreve na resposta depois |
| **cliente** | manda no request | lê de volta da resposta |

Leitura e escrita como sempre:

```pascal
AParams.ItemsString['nome'].AsString;
AParams.ItemsString['valor'].AsFloat := 1234.56;
AParams.ItemsString['quando'].AsDateTime := Now;
AParams.ItemsString['ativo'].AsBoolean;
AParams.ItemsString['anexo'].AsBase64;
AParams.ItemsString['qualquer'].Value;        // Variant
```

Disponíveis: `AsString`, `AsAnsiString`, `AsWideString`, `AsMemo`, `AsObject`,
`AsByteString`, `AsInteger`, `AsSmallInt`, `AsShortInt`, `AsWord`, `AsLongWord`,
`AsLargeInt`, `AsFloat`, `AsSingle`, `AsCurrency`, `AsExtended`, `AsBCD`, `AsFMTBCD`,
`AsBoolean`, `AsDate`, `AsTime`, `AsDateTime`, `AsBase64`, `AsStream`, `Value`,
`DefaultValue`.

No container: `Count`, `Items[i]` (índice padrão), `ItemsString[nome]`, `RawBody`,
`NewParam`, `CreateParam`, `Add`, `Delete`, `Clear`, `CopyFrom`, `IndexOf`,
`CountInParams`, `CountOutParams`, `ParamsReturn`, `ToJSON`, `FromJSON`, `SaveToFile`,
`LoadFromFile`, `LoadFromParams(TParams)`, `SaveToParams(TParams)`.

E mais dois, que o RDW não tem:

```pascal
AParams.Request;   // o TRALRequest cru: header, IP, cookie, método
AParams.Module;    // o TRALRESTDWModule que atendeu — e dele o Server
```

### Números e datas não dependem do locale

Todo valor com representação binária (inteiro, float, currency, boolean, data) viaja
**tipado**, usando os *typed params* do PascalRAL — não passa por `FloatToStr` em lugar
nenhum. Um servidor pt-BR e um cliente en-US trocam `1234.56` sem que vire `123456`. Onde o
valor precisa virar texto (JSON, `AsString`), a formatação é invariante, com `.` decimal e
data `yyyy-mm-dd`.

> `ItemsString['naoexiste']` devolve **nil**, igual ao RDW. Teste antes de usar, ou crie com
> `CreateParam`.

---

## Datasets

Um parâmetro `toDataset` carrega um dataset inteiro, serializado pelo storage do próprio
PascalRAL:

```pascal
// servidor
AParams.ItemsString['dados'].LoadFromDataSet(FQuery);

// cliente
vParams.ItemsString['dados'].SaveToDataSet(FMemTable);
```

Também dá para ir e voltar de um `TParams` de query:

```pascal
AParams.SaveToParams(FQuery.Params);     // params → query
AParams.LoadFromParams(FQuery.Params);   // query → params
```

---

## Banco de dados: o ClientSQL

`TRALRESTDWClientSQL` é o `TRESTDWClientSQL` vestido sobre o dataset remoto do PascalRAL.
Descende dele — `TRALDBFDMemTable` no Delphi, `TRALDBBufDataset` no Lazarus — então é um
`TDataSet` de verdade: liga em `TDataSource`, em grade, em campos persistentes.

```pascal
qry.DataBase := conexao;                    // TRALDBConnection
qry.SQL.Text := 'SELECT * FROM clientes WHERE uf = :uf';
qry.ParamByName('uf').AsString := 'PR';
qry.UpdateTableName := 'clientes';
qry.Open;                                   // síncrono, como no RDW

qry.Edit;
qry.FieldByName('nome').AsString := 'novo';
qry.Post;
qry.ApplyUpdates;                           // manda as alterações do cache
```

No servidor não há nada a escrever: um `TRALDBModule` do PascalRAL, apontado para o banco,
publica as rotas e executa o SQL que chega.

| propriedade | vem do RDW | o que faz |
| --- | --- | --- |
| `DataBase` | sim | o `TRALDBConnection` — era o pooler de banco do RDW |
| `SQL`, `Params`, `ParamByName` | sim | iguais |
| `UpdateTableName` | sim | tabela usada para montar insert/update/delete |
| `MasterDataSet` + `MasterFields` | sim | master/detail: a cada troca de registro no master, os campos nomeados vão para os params de mesmo nome e o detalhe refaz a consulta |
| `CacheUpdateRecords` | sim | `True` (padrão) guarda Post/Delete até o `ApplyUpdates` |
| `AutoCommitData` | sim | manda cada Post/Delete na hora |
| `AutoRefreshAfterCommit` / `ReflectChanges` | sim | refaz a consulta depois de gravar |
| `RaiseErrors` | sim | **`True` por padrão** |
| `OnGetDataError` | sim | mesma assinatura do RDW |
| `RowsAffected`, `LastId` | sim / novo | quantas linhas o servidor mexeu |
| `ThreadRequest` | sim | `True` volta na hora e entrega depois |
| `RequestTimeout` | novo | quanto esperar pela resposta, em ms |
| `ExecSQL`, `ApplyUpdates`, `RefreshData` | sim | iguais |

### Duas coisas que o adaptador conserta

**As chamadas são síncronas.** O dataset remoto do RAL manda `Open`, `ExecSQL` e
`ApplyUpdates` com callback e `ebMultiThread`: as três voltam antes de a resposta existir,
e ler `RecordCount` na linha seguinte ao `Open` dava zero. No RDW essas três são síncronas
e o código portado conta com isso, então aqui a chamada espera a resposta. `ThreadRequest`
devolve o comportamento assíncrono para quem o quiser.

**Erro não passa calado.** O RAL só avisa a falha se `OnError` estiver atribuído; sem
handler, a operação falhava em silêncio. Aqui, sem `OnGetDataError` e sem `OnError`, o
`RaiseErrors` levanta exceção — e levanta no contexto de quem chamou, não de dentro do
callback, para que o seu `try..except` em volta do `Open` funcione.

---

## Conversor de projetos

`ferramentas/conversor` faz o trabalho mecânico. Tem **janela**
(`ferramentas/conversor/gui`) e linha de comando, as duas sobre o mesmo motor:

```
rdw2ral <pasta>                        # simula e mostra o relatório
rdw2ral <pasta> --aplicar --backup
rdw2ral --servidores                   # os motores do RAL desta máquina
```

Na janela: escolhe a pasta, **escolhe o motor do RAL**, clica em Simular, vê o que
mudaria, e só então aplica. A lista de motores sai do registro do Delphi, com os que
você tem instalados na frente — não é um catálogo fixo.

O que ele faz é pouco, de propósito, porque as cascas fazem o resto:

- tira do `uses` toda unit que comece com `uRESTDW` ou `uDW` e põe `RALRESTDWCompat`
  (mais a unit do motor escolhido, quando há transporte no arquivo);
- troca no `.dfm`/`.lfm` **só o nome da classe** dos componentes — nenhuma propriedade
  é alterada ou descartada;
- troca o tipo do campo correspondente no `.pas`, para os dois casarem;
- acrescenta `RegisterClass(TSeuDataModule)`, que é como o módulo acha a classe;
- converte o formato antigo de `Routes = [crAll]` para `Routes.All.Active`, que é a
  forma do RDW 2.1 e a daqui;
- aponta cada handler para a propriedade da assinatura que ele tem, `OnReplyEvent` ou
  `OnReplyEventStr`, e relata cada troca;
- avisa, um a um, os componentes sem equivalente (`TRESTDWPoolerDB`,
  `TRESTDWIdDatabase`, `TRESTDWMassiveCache`, `TRESTDWServerContext`…).

Ele **não** mexe no corpo do seu código: com a unit de compatibilidade e as cascas, não
precisa.

Trabalha em bytes e nunca decodifica, então fonte em CP1252 não vira mojibake; e só troca
identificador isolado, então o componente `RESTDWClientSQL1` e o handler
`RESTDWClientSQL1CalcFields` não são reescritos junto com a classe.

Detalhes em [`ferramentas/conversor/LEIAME.md`](ferramentas/conversor/LEIAME.md).

---

## Autorização

Três camadas, da mais fraca para a mais forte:

**`AccessTag`** — o valor no `TRALRESTDWServerEvents` precisa ser igual ao enviado pelo
cliente (os dois vazios também vale). Serve para separar conjuntos de eventos por aplicação
ou por versão. **Não é autenticação**: é uma string comparada, que trafega no corpo.

**`OnAuthRequest`** — por evento, roda antes do handler e pode recusar sozinho:

```pascal
procedure Tdm.srvEventssigiloAuthRequest(const AParams: TRALRESTDWParams;
  var ARejected: Boolean; var AResultError: StringRAL;
  var AStatusCode: IntegerRAL; ARequestHeader: TStringList);
begin
  ARejected := AParams.ItemsString['token'].AsString <> MeuToken;
  if ARejected then
  begin
    AResultError := 'token inválido';
    AStatusCode := 401;
  end;
end;
```

**A autenticação do `TRALServer`** — Basic, JWT, OAuth, OAuth2, Digest. É a de verdade, e
continua toda disponível. O `Routes.<verbo>.NeedAuthorization` de cada evento vira o
`SkipAuthMethods` da rota, então dá para liberar um `GET` público e exigir token no `POST`
do mesmo evento.

---

## De/Para: RDW → RESTDW2RAL

| REST Dataware | RESTDW2RAL |
| --- | --- |
| `TRESTDWServerEvents` | `TRALRESTDWServerEvents` |
| `TRESTDWClientEvents` | `TRALRESTDWClientEvents` |
| `TRESTDWIdServicePooler`, `TRESTDWIcsServicePooler` | `TRALRESTDWIndyServicePooler` |
| `TRESTDWIdClientPooler`, `TRESTDWIdClientREST`, `TRESTClientPooler` | `TRALRESTDWClient` |
| `TRESTDWAuthBasic` | `TRALServerBasicAuth` |
| `TServerMethodDataModule` | `TRALRESTDWDataModule` |
| `TRESTDWClientInfo` | `TRALRESTDWClientInfo` |
| `TRESTDWAuthOption` / `TRESTDWAuthOptionBasic` | `TRALRESTDWAuthOption` / `TRALRESTDWAuthOptionBasic` |
| `TRequestType` (`rtGet`, `rtPost`…) | `TRALMethod` (`amGET`, `amPOST`…) |
| `TEncodeSelect` (`esUtf8`…) | `TRALRESTDWEncodeSelect` |
| `TRESTDWJSONValue` | `TRALRESTDWJSONParam` |
| `TRESTDWParams` / `TDWParams` | `TRALRESTDWParams` |
| `TRESTDWJSONParam` | `TRALRESTDWJSONParam` |
| `TRESTDWParamsMethods` / `TRESTDWParamMethod` | `TRALRESTDWParamsMethods` / `TRALRESTDWParamMethod` |
| `TRESTDWEvent` / `TRESTDWEventList` | `TRALRESTDWEventServer` / `TRALRESTDWEventList` |
| `TRESTDWRoutes` / `TRESTDWRoute` | `TRALRESTDWRoutes` / `TRALRESTDWRoute` |
| `TDWReplyEvent` / `TDWReplyEventByType` | `TRALRESTDWReplyEvent` / `TRALRESTDWReplyEventByType` |
| `TDWAuthRequest` | `TRALRESTDWAuthRequest` |
| `TObjectEvent` / `TObjectExecute` / `TOnBeforeSend` | `TRALRESTDWObjectEvent` / `TRALRESTDWObjectExecute` / `TRALRESTDWBeforeSend` |
| `TObjectValue` / `TObjectDirection` / `TTypeObject` / `TDataMode` | `TRALRESTDWObjectValue` / `TRALRESTDWObjectDirection` / `TRALRESTDWTypeObject` / `TRALRESTDWDataMode` |
| `TSendEvent` | `TRALRESTDWSendEvent` |
| `TRESTDWClientSQL` | `TRALRESTDWClientSQL` |
| `TRESTClientPooler` (banco) | `TRALDBConnection` |
| pooler de banco do servidor | `TRALDBModule` do PascalRAL |
| `Params.RawBody` | `Params.RawBody` |

Todos os nomes da coluna da esquerda continuam valendo se você usar `RALRESTDWCompat` — é
para isso que ela existe. Ela também re-exporta `StringRAL`, `IntegerRAL` e `Int64RAL`.

> **`var` de string é sempre `String`.** `StringRAL` é `UTF8String`, um byte por
> caractere; o `String` do Delphi moderno tem dois. Em parâmetro `var` o compilador não
> converte, e no caso dos handlers ligados pelo DFM — que casam por nome, sem conferir
> assinatura — nem erro daria: daria texto corrompido na primeira chamada. Por isso
> `SendEvent(..., var AError)`, `OnAuthRequest` e o `Result` do `OnReplyEventStr` usam `String`,
> exatamente como o RDW declara.

---

## As duas gerações de handler

O RDW 2.x entrega o resultado do evento num `TStringList` e o 1.4.3 numa `string`. Você não
escolhe: **as duas formas ficam publicadas**, com nomes diferentes, e o mesmo pacote
instalado atende projetos das duas gerações.

| propriedade | assinatura | vem do |
| --- | --- | --- |
| `OnReplyEvent` | `(var AParams: TRALRESTDWParams; const AResult: TStringList)` | RDW 2.x |
| `OnReplyEventStr` | `(var AParams: TRALRESTDWParams; var AResult: String)` | RDW 1.4.3 |

O conversor aponta o `.dfm` para a certa, **handler a handler** — e isso importa: a demo
`FullServer` do RDW tem handlers das duas formas lado a lado no mesmo `.pas`. Vale a que
estiver ligada.

> Isto já foi a diretiva `RDW143` em `src/RALRESTDW.inc`, que obrigava a escolher uma forma
> por pacote instalado. O arquivo continua lá, vazio, porque as units o incluem.

---

## Demos

Em `exemplo/`, prontas para rodar:

| | |
| --- | --- |
| `delphi/servidor` | `TRALIndyServer` + `TRALRESTDWModule`, cinco eventos cobrindo params de entrada/saída, `odINOUT`, dataset e autorização por evento |
| `delphi/cliente` | `TRALClient` + `TRALRESTDWClientEvents` com a coleção vazia — mostra o `AutoFetch` funcionando |
| `delphi/cliente_db` | `TRALRESTDWClientSQL` sobre SQLite: Open, ExecSQL com params, ApplyUpdates, master/detail e metadados |
| `lazarus/cliente` | o mesmo cliente em Lazarus/FPC, com o engine `fpHTTP` |

Abra o `.dpr`/`.lpi` na IDE (o Delphi cria o `.dproj` sozinho ao abrir o `.dpr`), rode o
servidor e depois o cliente. O servidor loga as rotas que descobriu sozinho:

```
5 rota(s) publicada(s) automaticamente a partir de "Tdm_eventos":
   ping         /ping        (0 param de entrada)
   soma         /soma        (2 param de entrada)
   cadastro     /cadastro    (3 param de entrada)
   clientes     /clientes    (0 param de entrada)
   sigilo       /sigilo      (1 param de entrada)
```

---

## Limitações conhecidas

- **Um defeito do PascalRAL derruba a metade de banco em build Debug.** Em
  `src/database/RALDBSQLCache.pas`, `GetQueryParams` faz
  `vParam.Size := GetInt64Prop(vColetItem, 'Size')` — lê como `Int64` uma propriedade
  `Size` que é `Integer`. Com *range checking* ligado, que é o padrão do Debug no IDE,
  qualquer consulta **com parâmetro** morre em `ERangeError`; sem ele, o valor é truncado e
  passa. Não há contorno pelo lado do cliente: a leitura acontece dentro do RAL, sobre o
  parâmetro que você passou. Até ser corrigido lá (`GetOrdProp` resolve), desligue o range
  checking no projeto ou use build Release. A metade de eventos não é afetada.
- **`toMassive` não tem implementação.** O `MassiveDataset` do RDW (buffer de alterações
  para aplicar em lote) não tem equivalente aqui. Para escrita em lote, use o
  `TRALDBModule` do RAL.
- **O nome da classe dentro do DFM/LFM tem que ser trocado.** Nenhuma unit de
  compatibilidade resolve isso — o formulário guarda o nome real da classe — e é
  justamente o que o conversor faz.
- **Casca de servidor só para o Indy, por enquanto.** `TRALRESTDWIndyServicePooler`
  existe; Synopse, Sagui e UniGUI aparecem na lista do conversor marcados como sem
  casca. A regra do de/para já está fora da casca (`RALRESTDWOptions`), então cada motor
  novo é um arquivo fino.
- **O gancho por registro do massive não é disparado.** Acumular as alterações e mandar
  em lote funciona — é o `CacheUpdateRecords` mais o `ApplyUpdates`, e `MassiveCount`,
  `MassiveToJSON` e `DataBase.ApplyUpdates(cache, …)` passam por ali de verdade. O que
  não existe é o `OnMassiveProcess`: o laço que aplica cada linha mora dentro do
  `TRALDBModule`, no PascalRAL, e este projeto não mexe no RAL. Os eventos são
  declarados (senão o formulário não abre e o método não compila) e **nunca chamados**;
  o conversor reporta cada um. Código que atribuía sequência ou vetava registro ali
  precisa mudar de lugar — para um trigger, para o próprio `SQL`, ou para um evento
  chamado antes do `ApplyUpdates`.
- **Sem lista de servidores de reserva.** `FailOver`, `FailOverConnections` e os eventos
  de failover são aceitos e inertes: o RAL não troca de servidor sozinho.
- **`TRESTDWMassiveBuffer` e `TRESTDWUpdateSQL`** continuam sem equivalente, e o
  conversor aponta cada ocorrência.
- **Sem `CriptOptions` por parâmetro.** A criptografia no RAL é configurada no
  servidor/cliente e vale para a requisição inteira (`CriptoOptions`), o que cobre o mesmo
  caso com menos peça.
- **Sem `DatabaseCharSet`, `Encoding` e `Url_Redirect`** no container de parâmetros.
- **`CallbackEvent` é publicado e propagado** para a rota do RAL, mas não há um mecanismo de
  callback pronto como o do RDW.
- **O Lazarus não foi compilado.** As units estão nos pacotes
  (`pkg/lazarus/RALRESTDW.lpk` e `RALRESTDWIndy.lpk`), mas a validação ponta a ponta
  feita até aqui foi toda no Delphi 12.

### O que já foi verificado em demo real do RDW

As demos oficiais do REST Dataware que acompanham este repositório, em
`ferramentas/conversor/demos/` — sem conversão, para você mesmo converter e rodar:

| demo | o que exercita | resultado |
| --- | --- | --- |
| `SimpleServer` | servidor, handler na forma do RDW 1.4.3 | converte, compila e **responde**: GET/DELETE 200, POST/PUT/PATCH 201, rota inexistente 404 |
| `FileTransfer/Server` + `Client` | basic auth montada em código, transferência de arquivo | converte, compila e **transfere**: lista, baixa e envia, conteúdo idêntico dos dois lados |
| `FullServer` | servidor grande: pooler de banco, driver FireDAC, contexto, token, massive | converte, compila e **serve** eventos e banco |
| `FullClient` | cliente com banco sobre REST, massive cache, failover, bearer | converte, compila e **conversa** com o FullServer: eventos e banco, com ApplyUpdates gravando no Firebird |

Em todas, a única mudança no formulário foi o **nome da classe**: nenhuma propriedade do
RDW foi alterada ou descartada.

Nos dois compiladores: Delphi 12 (os três pacotes contra o `.dcp` instalado, com range
check ligado, e as demos) e Lazarus 3 / FPC 3.2.2 (os três pacotes e a demo cliente).

---

## Licença

MIT — veja [LICENSE](LICENSE).
