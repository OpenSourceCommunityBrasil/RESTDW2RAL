# RESTDW to RAL

Um pequeno adaptador para converter projetos RESTDW para RAL.

A ideia é simples: quem já programa com **REST Dataware** continua programando do mesmo
jeito — `ServerEvents`, `ClientEvents`, `Events`, `Params`, `ItemsString['x'].AsString`,
`Result.Text := ...` — só que rodando em cima do **[PascalRAL](https://github.com/OpenSourceCommunityBrasil/PascalRAL)**,
e **sem nenhuma unit do RDW no projeto**. Não é uma ponte para o RDW: é uma reimplementação
do jeito de trabalhar do RDW usando só RAL por baixo.

---

## Índice

- [O que é e o que não é](#o-que-é-e-o-que-não-é)
- [Requisitos](#requisitos)
- [Instalação](#instalação)
- [Os três componentes](#os-três-componentes)
- [Passo a passo — Servidor](#passo-a-passo--servidor)
- [Passo a passo — Cliente](#passo-a-passo--cliente)
- [Parâmetros (TRALRESTDWParams)](#parâmetros-tralrestdwparams)
- [Publicando as rotas dos eventos](#publicando-as-rotas-dos-eventos)
- [AccessTag](#accesstag)
- [Diretiva RDW143](#diretiva-rdw143)
- [De/Para: RDW → RAL RESTDW](#depara-rdw--ral-restdw)
- [Limitações conhecidas](#limitações-conhecidas)
- [Licença](#licença)

---

## O que é e o que não é

**É:** uma camada de componentes que reproduz o modelo *ServerEvents/ClientEvents* do RDW
sobre o PascalRAL. Os nomes de propriedades, coleções, tipos e assinaturas de evento foram
copiados do RDW de propósito, para que o **corpo dos seus handlers continue igual**.

**Não é:** um wrapper do RDW. Nenhuma unit `uRESTDW*` é referenciada. Também não é um
conversor automático de projeto — você troca as declarações (tipos e componentes no
DFM/LFM); o código de dentro dos eventos é que fica como está.

Na prática, migrar um evento é isto:

```pascal
// antes (RDW)
procedure Tdm.srvEventsping(var Params: TRESTDWParams; const Result: TStringList);
begin
  Result.Text := 'olá ' + Params.ItemsString['nome'].AsString;
end;

// depois (RAL RESTDW) — só mudou o tipo do parâmetro
procedure Tdm.srvEventsping(AParams: TRALRESTDWParams; const AResult: TStringList);
begin
  AResult.Text := 'olá ' + AParams.ItemsString['nome'].AsString;
end;
```

---

## Requisitos

| | |
| --- | --- |
| Delphi | XE ou superior (testado em Athens/12) |
| Lazarus | 2.x / FPC 3.2+ |
| PascalRAL | pacotes `PascalRAL` + `PascalRALDsgn` instalados |
| Engine | um engine RAL qualquer (`IndyRAL`, `SynopseRAL`, `NetHttpRAL`, `SaguiRAL`, ...) |

---

## Instalação

A ordem importa, porque este pacote depende do `PascalRALDsgn`, que depende do `PascalRAL`.

**Delphi**

1. Instale `PascalRAL.dproj` e `PascalRALDsgn.dproj` (projeto PascalRAL).
2. Abra `pkg/delphi/RALRESTDW.dproj`, compile e **Install**.
3. Adicione a pasta `src` ao *Library Path* (ou ao *Search Path* de cada projeto que usar
   os componentes) — o pacote é de design-time e as units são compiladas junto da sua
   aplicação.

**Lazarus**

1. Instale `pascalral.lpk` e `pascalraldsgn.lpk`.
2. Abra `pkg/lazarus/RALRESTDW.lpk` → **Use → Install** (a IDE será recompilada).

Após instalar, a paleta ganha:

- **RAL - RDWModule** → `TRALRESTDWServerEvents`, `TRALRESTDWClientEvents`
- **RAL - Modules** → `TRALRESTDWModule`

---

## Os três componentes

```
     SERVIDOR                                          CLIENTE

  TRALServer (engine)                            TRALClient (engine)
        │                                                │
  TRALRESTDWModule ─── ClassModule ──┐            TRALRESTDWClientEvents
   (publica as rotas)                │             (cópia local dos eventos)
                                     ▼
                            TDataModule registrado
                                     │
                          TRALRESTDWServerEvents
                                     │
                                  Events[]
                              (seus handlers)
```

| Componente | Onde fica | Para que serve |
| --- | --- | --- |
| `TRALRESTDWServerEvents` | num `TDataModule` | guarda a coleção `Events` e os seus handlers `OnReplyEvent` |
| `TRALRESTDWModule` | junto do `TRALServer` | publica as rotas no servidor e despacha cada request para o evento certo |
| `TRALRESTDWClientEvents` | na aplicação cliente | guarda uma cópia das definições dos eventos e envia as chamadas |

---

## Passo a passo — Servidor

### 1. O DataModule com os eventos

Crie um `TDataModule`, solte um `TRALRESTDWServerEvents` nele e monte a coleção `Events`.
Para cada item:

| Propriedade | O que é |
| --- | --- |
| `EventName` | nome do evento (é o que o cliente chama) |
| `BaseURL` | prefixo da rota; deixe `/` no caso simples |
| `DefaultContentType` | content-type da resposta (`application/json` por padrão) |
| `Description` | texto livre; vai junto na exportação e aparece no Swagger |
| `Params` | declaração dos parâmetros de entrada/saída |
| `OnReplyEvent` | seu handler |

> **A rota do evento é `BaseURL + '/' + EventName`.** Com `BaseURL = '/'` e
> `EventName = 'ping'`, a rota é `/ping`. Se você puser `BaseURL = '/ping'` **e**
> `EventName = 'ping'`, a rota vira `/ping/ping` — é um erro comum.

```pascal
unit udm_eventos;

interface

uses
  System.SysUtils, System.Classes,
  RALRESTDWServerEvents, RALRESTDWParams;

type
  Tdm_eventos = class(TDataModule)
    srv: TRALRESTDWServerEvents;
    procedure srvEventspingReplyEvent(AParams: TRALRESTDWParams;
      const AResult: TStringList);
  end;

implementation

{$R *.dfm}

procedure Tdm_eventos.srvEventspingReplyEvent(AParams: TRALRESTDWParams;
  const AResult: TStringList);
begin
  AResult.Text := 'olá ' + AParams.ItemsString['nome'].AsString;
end;

initialization
  RegisterClass(Tdm_eventos);   // <<< OBRIGATÓRIO

end.
```

**O `RegisterClass` não é opcional.** O `TRALRESTDWModule` acha o DataModule pelo *nome*,
via `GetClass()`. Sem o registro, toda chamada responde **403**. A unit também precisa estar
no `uses` de algum lugar do projeto, senão o linker a descarta.

### 2. O módulo no servidor

No form (ou DataModule) onde está o `TRALServer`, solte um `TRALRESTDWModule`:

| Propriedade | Valor |
| --- | --- |
| `Server` | o seu `TRALServer` |
| `Domain` | prefixo de todas as rotas do módulo (padrão `/`) |
| `ClassModule` | `'Tdm_eventos'` — o nome da classe registrada |
| `FileExporter` | caminho do arquivo de exportação de rotas (opcional) |
| `Routes` | uma rota por evento (veja a seção seguinte) |

```pascal
procedure Tfprincipal.FormCreate(Sender: TObject);
begin
  server.Start;
end;
```

### 3. Como o request é atendido

1. O RAL casa a URL com um item de `TRALRESTDWModule.Routes`.
2. O módulo assume o handler e instancia **uma cópia nova do DataModule** (`ClassModule`)
   para aquele request, liberando-a no fim.
3. Procura nos componentes do DataModule um `TRALRESTDWServerEvents` cujo
   `'<ClasseDoDataModule>.<NomeDoComponente>'` bata com o `servereventname` enviado.
4. Compara o `AccessTag`.
5. Acha o evento pela rota e dispara o `OnReplyEvent`.

> Cada request cria e destrói o DataModule. Não guarde estado entre chamadas em campos do
> DataModule — e lembre que conexões de banco criadas ali são abertas e fechadas a cada
> request.

> **Respondeu 403?** Quase sempre é (a) classe não registrada / nome errado em
> `ClassModule`, (b) `ServerEventName` diferente de `'<Classe>.<Componente>'`, ou
> (c) `AccessTag` divergente. Não é falha de autenticação.

---

## Passo a passo — Cliente

### 1. Ligue o engine

Solte um `TRALIndyClient` (ou outro engine) e aponte o `BaseURL` para o servidor
(`localhost:8000`).

### 2. Configure o `TRALRESTDWClientEvents`

| Propriedade | Valor |
| --- | --- |
| `RALClient` | o componente de engine |
| `ModuleRoute` | o mesmo valor do `Domain` do módulo no servidor |
| `ServerEventName` | `'Tdm_eventos.srv'` |
| `AccessTag` | igual ao do servidor, se usar |

Com o servidor **no ar**, a propriedade `ServerEventName` abre uma lista consultando o
servidor em tempo real (`/getservereventslist`).

### 3. Traga os eventos

Clique com o botão direito no componente → **Get Events**. Ele chama `/getevents` no
servidor e preenche a coleção `Events` local com nomes, rotas e parâmetros. É o equivalente
ao `GetEvents` do RDW.

> Depois de usar o *Get Events*, **salve o formulário na mão** (Ctrl+S) — o editor não marca
> o form como modificado.

### 4. Chame o evento

```pascal
procedure TForm1.Button1Click(Sender: TObject);
var
  vParams: TRALRESTDWParams;
  vErro: StringRAL;
begin
  ce.CreateDWParams('ping', vParams);
  if vParams = nil then          // evento não existe na coleção local
    Exit;
  try
    vParams.ItemsString['nome'].AsString := 'fernando';

    if ce.SendEvent('ping', vParams, vErro) then
      ShowMessage(vParams.ItemsString[cUndefined].AsString)
    else
      ShowMessage('Erro: ' + vErro);
  finally
    vParams.Free;                // <<< o objeto é seu
  end;
end;
```

Pontos importantes:

- `CreateDWParams` **cria** o objeto e devolve na variável — quem chama é dono e precisa
  liberar. Se o `EventName` não existir na coleção local, a variável volta `nil`.
- O retorno do handler (o `AResult`) chega no parâmetro de nome `cUndefined`
  (constante de `RALRESTDWTypes`, valor `'undefined'`) — igual ao `RawBody` do RDW.
- Os parâmetros `odOUT`/`odINOUT` voltam preenchidos no mesmo objeto.
- O verbo é escolhido no 4º argumento (`sePOST` por padrão):
  `sePOST`, `sePUT`, `seDELETE`, `sePATCH`. Evite `seGET` — os parâmetros vão no *body*.

---

## Parâmetros (`TRALRESTDWParams`)

Cada parâmetro declarado em `Events[i].Params` tem:

| Propriedade | Significado |
| --- | --- |
| `ParamName` | nome usado no `ItemsString[...]` |
| `Alias` | nome alternativo (a busca aceita os dois) |
| `ObjectDirection` | `odIN`, `odOUT`, `odINOUT` |
| `ObjectValue` | tipo (`ovString`, `ovInteger`, `ovFloat`, `ovDateTime`, ...) |
| `TypeObject` | `toParam`, `toVariable`, `toObject` (veja *Limitações*) |
| `DefaultValue` | valor inicial |
| `Encoded` | trafega em Base64 |

A direção decide o sentido de cada cópia:

| | entra (`odIN` / `odINOUT`) | sai (`odOUT` / `odINOUT`) |
| --- | --- | --- |
| **servidor** | lê do request antes do handler | escreve no body da resposta depois |
| **cliente** | manda no body do request | lê de volta da resposta |

Leitura e escrita pelos acessores no estilo RDW:

```pascal
AParams.ItemsString['nome'].AsString;
AParams.ItemsString['valor'].AsFloat := 1.5;
AParams.ItemsString['data'].AsDateTime;
AParams.ItemsString['ativo'].AsBoolean;
AParams.ItemsString['arquivo'].AsBase64;
AParams.ItemsString['bin'].AsStream;
```

Disponíveis: `AsString`, `AsAnsiString`, `AsWideString`, `AsMemo`, `AsObject`,
`AsByteString`, `AsInteger`, `AsSmallInt`, `AsShortInt`, `AsWord`, `AsLongWord`,
`AsLargeInt`, `AsFloat`, `AsSingle`, `AsCurrency`, `AsExtended`, `AsBCD`, `AsFMTBCD`,
`AsBoolean`, `AsDate`, `AsTime`, `AsDateTime`, `AsBase64`, `AsStream`.

Também há `IsNull`, `IsEmpty`, `SaveToStream`, `LoadFromStream` e, no container,
`Count`, `Items[i]`, `ItemsString[nome]`, `NewParam`, `Request` (o `TRALRequest` cru,
para header, IP, cookie etc.) e `Module` (o `TRALRESTDWModule` que atendeu, de onde se
chega no `Server`):

```pascal
if AParams.Module <> nil then
  vPorta := TRALRESTDWModule(AParams.Module).Server.Port;
```

> `ItemsString['naoexiste']` devolve **nil** (mesmo comportamento do RDW). Teste antes de
> usar, ou crie com `NewParam`.

---

## Publicando as rotas dos eventos

O `TRALRESTDWModule` só responde por rotas que estejam na coleção `Routes`. Há dois
caminhos:

**a) Na mão (projeto pequeno)** — adicione um item em `Routes` com `Route` igual à rota do
evento (`BaseURL + '/' + EventName`).

**b) Exportando/importando (recomendado)** — gera as rotas com nome, descrição e parâmetros
de entrada, o que faz os eventos aparecerem no Swagger e no export do Postman do RAL.

```pascal
// uma vez, em tempo de execução, para gerar o arquivo:
rdw.FileExporter := 'C:\projeto\eventos.dat';
rdw.ExportToFile;
```

Depois, em design-time: botão direito no `TRALRESTDWModule` → **Import Events** (lê o
arquivo de `FileExporter` e preenche `Routes`). Também dá para importar em runtime com
`ImportFromFile` / `ImportFromStream`.

> O *Import Events* **limpa** a coleção `Routes` antes de importar, e também não marca o
> form como modificado — salve na mão.

---

## AccessTag

`AccessTag` existe nos três componentes e funciona como um filtro de visibilidade: o valor
do `TRALRESTDWServerEvents` precisa ser **exatamente igual** ao enviado pelo cliente (os dois
vazios também vale). Diferente → 403, e o componente nem aparece no
`/getservereventslist`.

Serve para separar conjuntos de eventos (por aplicação, por versão, por cliente). **Não é
autenticação** — é uma string comparada com *case-sensitive* que trafega no body. Para
segurança de verdade use a autenticação do `TRALServer` (Basic, JWT, OAuth2 — tudo do RAL
continua valendo).

---

## Diretiva `RDW143`

`src/RALRESTDW.inc` escolhe a assinatura dos handlers, para bater com a versão de RDW de
onde você está vindo:

```pascal
{.$DEFINE RDW143}   // comentado = padrão
```

| | Assinatura de `OnReplyEvent` | Equivale ao |
| --- | --- | --- |
| **desligado (padrão)** | `(AParams: TRALRESTDWParams; const AResult: TStringList)` | RDW 2.0 |
| **`{$DEFINE RDW143}`** | `(AParams: TRALRESTDWParams; var AResult: StringRAL)` | RDW 1.4.3 |

Mudar a diretiva muda um tipo publicado: **todos** os handlers já ligados nos DFM/LFM
quebram e o pacote precisa ser reinstalado. Decida no começo do projeto.

---

## De/Para: RDW → RAL RESTDW

| REST Dataware | RAL RESTDW |
| --- | --- |
| `TRESTDWServerEvents` | `TRALRESTDWServerEvents` |
| `TRESTDWClientEvents` | `TRALRESTDWClientEvents` |
| service pooler / server | `TRALServer` (engine) + `TRALRESTDWModule` |
| `TRESTClientPooler` | `TRALClient` (`TRALIndyClient`, `TRALSynopseClient`, ...) |
| `TRESTDWParams` | `TRALRESTDWParams` |
| `TRESTDWJSONParam` | `TRALRESTDWJSONParam` |
| `TRESTDWParamsMethods` / `TRESTDWParamMethod` | `TRALRESTDWParamsMethods` / `TRALRESTDWParamMethod` |
| `TDWReplyEvent` / `TDWReplyEventByType` | `TRALRESTDWReplyEvent` / `TRALRESTDWReplyEventByType` |
| `TObjectValue` / `TObjectDirection` / `TTypeObject` | `TRALRESTDWObjectValue` / `TRALRESTDWObjectDirection` / `TRALRESTDWTypeObject` |
| `TSendEvent` (`sePOST`, ...) | `TRALRESTDWSendEvent` (mesmos valores) |
| `Params.RawBody` | `Params.ItemsString[cUndefined]` |
| `CreateDWParams` / `SendEvent` | mesmos nomes |

Diferenças de assinatura que você vai encontrar ao colar código antigo:

- `OnReplyEvent` recebe `AParams` **sem `var`** (no RDW é `var Params`).
- `SendEvent` recebe `AParams` **sem `var`**.

---

## Limitações conhecidas

Vale ler antes de planejar a migração:

- **Sem suporte a DataSet / Massive.** Os valores `toDataset` e `toMassive` existem no enum
  mas não têm implementação. Eventos de RDW que devolvem dataset ainda não têm equivalente
  aqui — por enquanto, serialize você mesmo (JSON/base64) ou use o `TRALDBModule` do RAL.
- **`OnlyPreDefinedParams` não é aplicado.** A propriedade existe, mas nada valida os
  parâmetros recebidos contra os declarados.
- **Sem `IgnoreInvalidParams`, `DefaultEvent`, `OnCreate`, `Routes` (verbos por evento),
  `DataMode`, `CallbackEvent` e `OnAuthRequest`** — presentes no RDW, ainda não portados.
- **`TRALRESTDWParams` não tem** `RawBody`, `Clear`, `Delete`, `Add`, `CreateParam`,
  `CopyFrom`, `ToJSON`/`FromJSON`, `LoadFromParams(TParams)`, `ParamsReturn`,
  `CountInParams`/`CountOutParams`. Nem `Value: Variant` no parâmetro.
- **Não derive de `TRALRESTDWServerEvents`**: a coleção escolhe a classe dos itens
  comparando o nome da classe dona com o literal `'TRALRESTDWServerEvents'`; um descendente
  recebe itens sem `OnReplyEvent`.
- **`AsSyncExec` do `SendEvent` é aceito e ignorado** — a chamada é sempre síncrona.
- O exemplo Delphi mantém um `TRESTDWServerEvents` ao lado do RAL (comparação lado a
  lado), então precisa do pacote do RDW instalado para abrir.

---

## Licença

MIT — veja [LICENSE](LICENSE).
