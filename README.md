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
  - [Os dois lados migram igual](#os-dois-lados-migram-igual)
- [Requisitos e instalação](#requisitos-e-instalação)
- [Os três componentes](#os-três-componentes)
- [Servidor](#servidor)
- [Cliente](#cliente)
- [Parâmetros](#parâmetros)
- [Datasets](#datasets)
- [Autorização](#autorização)
- [De/Para: RDW → RESTDW2RAL](#depara-rdw--restdw2ral)
- [Diretiva RDW143](#diretiva-rdw143)
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

**3. Troque o transporte.** No lugar do pooler/servidor do RDW entram componentes do RAL:

| lado | no RDW | aqui |
| --- | --- | --- |
| servidor | o pooler/servidor do RDW | `TRALServer` (o engine) + `TRALRESTDWModule` apontando para o DataModule |
| cliente | `TRESTClientPooler` | `TRALClient` — e a propriedade `RESTClientPooler` do ClientEvents vira `RALClient` |

**O corpo dos seus handlers não muda.** Nem os nomes dos parâmetros, nem os acessores
`As*`, nem o `Result`, nem o `ItemsString`.

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

A paleta ganha **RAL - RDWModule** (`TRALRESTDWServerEvents`, `TRALRESTDWClientEvents`) e
**RAL - Modules** (`TRALRESTDWModule`).

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
| pooler / servidor | `TRALServer` + `TRALRESTDWModule` |
| `TRESTClientPooler` | `TRALClient` |
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
| `Params.RawBody` | `Params.RawBody` |

Todos os nomes da coluna da esquerda continuam valendo se você usar `RALRESTDWCompat` — é
para isso que ela existe. Ela também re-exporta `StringRAL`, `IntegerRAL` e `Int64RAL`, que
aparecem nas assinaturas do `OnAuthRequest` e do `OnReplyEventByType`.

---

## Diretiva `RDW143`

`src/RALRESTDW.inc` escolhe a assinatura do handler, conforme a versão de RDW de onde você
vem:

| | `OnReplyEvent` | Equivale a |
| --- | --- | --- |
| **padrão** | `(var AParams: TRALRESTDWParams; const AResult: TStringList)` | RDW 2.x |
| **`{$DEFINE RDW143}`** | `(var AParams: TRALRESTDWParams; var AResult: StringRAL)` | RDW 1.4.3 |

Mudar a diretiva muda um tipo publicado: todos os handlers já ligados nos DFM/LFM quebram e
o pacote precisa ser reinstalado. Decida no começo.

---

## Demos

Em `exemplo/`, prontas para rodar:

| | |
| --- | --- |
| `delphi/servidor` | `TRALIndyServer` + `TRALRESTDWModule`, cinco eventos cobrindo params de entrada/saída, `odINOUT`, dataset e autorização por evento |
| `delphi/cliente` | `TRALClient` + `TRALRESTDWClientEvents` com a coleção vazia — mostra o `AutoFetch` funcionando |
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

- **`toMassive` não tem implementação.** O `MassiveDataset` do RDW (buffer de alterações
  para aplicar em lote) não tem equivalente aqui. Para escrita em lote, use o
  `TRALDBModule` do RAL.
- **O nome da classe dentro do DFM/LFM tem que ser trocado na mão.** Nenhuma unit de
  compatibilidade resolve isso: o formulário guarda o nome real da classe.
- **Sem `CriptOptions` por parâmetro.** A criptografia no RAL é configurada no
  servidor/cliente e vale para a requisição inteira (`CriptoOptions`), o que cobre o mesmo
  caso com menos peça.
- **Sem `DatabaseCharSet`, `Encoding` e `Url_Redirect`** no container de parâmetros.
- **`CallbackEvent` é publicado e propagado** para a rota do RAL, mas não há um mecanismo de
  callback pronto como o do RDW.
- A demo Lazarus não foi compilada aqui — só a Delphi foi validada ponta a ponta.

---

## Licença

MIT — veja [LICENSE](LICENSE).
