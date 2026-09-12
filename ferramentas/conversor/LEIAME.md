# rdw2ral — conversor de projetos

Faz o trabalho mecânico da migração do REST Dataware para o RESTDW2RAL.

**Ele troca nomes, e é só isso.** Quem faz o de/para de verdade são as classes do
projeto que vestem a cara do RDW — `TRALRESTDWIndyServicePooler`, `TRALRESTDWClient`,
`TRALRESTDWDataModule` — com o RAL implementado por dentro. É por isso que nenhuma
propriedade do seu formulário é alterada ou descartada: `ServicePort`, `RootPath`,
`CORS_CustomHeaders`, `AuthenticationOptions`, `CriptOptions` continuam lá, com o mesmo
nome, e viram configuração do RAL em tempo de execução.

Vem em três formas, **com a mesma regra por baixo**: `uConversor.pas` tem todo o
motor, e os três programas são só a casca. Mexeu na regra, mexeu para os três.

| | |
| --- | --- |
| `gui/rdw2ralgui.dpr` | **janela do Delphi** — escolha a pasta, simule, veja o que muda, aplique |
| `gui-lazarus/rdw2ralgui.lpi` | **a mesma janela no Lazarus**, em LCL |
| `rdw2ral.dpr` | linha de comando, para script e automação |

O motor compila nos dois compiladores. Por isso ele não usa `System.IOUtils` nem
genérico: os utilitários de arquivo no começo da implementação fazem esse papel. O
único trecho que muda de um lado para o outro é o `PacotesDoIDE`, que responde
*quais motores do RAL você tem instalados* — no Delphi lendo o registro, no Lazarus
lendo o `staticpackages.inc` da configuração do usuário.

## Compilar

Nenhuma dependência além da RTL e da VCL:

```
dcc32 gui\rdw2ralgui.dpr                      # a janela do Delphi
dcc32 rdw2ral.dpr                             # o console
lazbuild gui-lazarus\rdw2ralgui.lpi       # a janela do Lazarus
```

A janela do Lazarus não tem diretiva de recurso de propósito: o `lazbuild` não gera
o `.res` do projeto - só o IDE -, e com ela um checkout limpo não compilaria pela
linha de comando.

Abrir o `.dpr` no Delphi e compilar é mais simples, porque a IDE gera o `.res` do
projeto sozinha. Pela linha de comando o `.res` da janela não existe — é saída de
build e o repositório não o versiona — então gere um antes, com `brcc32` sobre um
`.rc` de uma linha **sem BOM**:

```powershell
Set-Content -Encoding ascii gui\res.rc '1 24 "manifest.txt"'
brcc32 -fogui\rdw2ralgui.res gui\res.rc
```

## A janela

É o caminho recomendado, porque o fluxo seguro fica óbvio em vez de depender de você
lembrar de um argumento:

1. **Escolha a pasta** — pelo botão, ou arraste a pasta para dentro da janela.
1. **Escolha o motor do RAL** — a lista sai do registro do Delphi, com os que você tem
   instalados na frente. Quem decide o motor é você: `TRESTDWIdServicePooler` e
   `TRESTDWIcsServicePooler` vão os dois para o motor escolhido. Um motor marcado como
   *casca ainda não feita* ainda não tem a classe correspondente no projeto; escolhê-lo
   faz o conversor deixar o transporte como está e dizer isso no relatório.
2. **Simular** — nada é gravado. A lista mostra cada arquivo que mudaria e quantas
   alterações; o painel de baixo mostra os avisos. Duplo clique num arquivo abre a
   pasta dele no Explorer.
3. **Aplicar** — só habilita depois de uma simulação que achou algo, e pede
   confirmação. Se você tiver desmarcado o `.bak`, o aviso diz isso na cara.

Os avisos vêm marcados:

| marca | o que é |
| --- | --- |
| `[uses]` | unit do RDW removida do `uses` |
| `[nome]` | classe renomeada |
| `[portado]` | uma regra do RDW que virou outra coisa no RAL |
| `[modulo]` | algo que o conversor acrescentou, como o `RegisterClass` |
| **`[ATENCAO]`** | o que ele não sabe converter e precisa de decisão sua |

A barra de status conta quantos `[ATENCAO]` apareceram.

A janela também aceita a pasta como argumento, então dá para chamá-la de um atalho
ou do menu "Enviar para" do Windows.

## A linha de comando

```
rdw2ral <pasta ou arquivo> [opções]
```

| opção | |
| --- | --- |
| *(nenhuma)* | **simula**: mostra o que faria e não grava nada |
| `--aplicar` | grava as alterações |
| `--backup` | guarda o original como `.bak` antes de gravar |
| `--tipos` | troca também os nomes de tipo no código (desnecessário com a unit `RALRESTDWCompat`) |
| `--servidor <classe>` | qual casca de servidor gerar; o padrão é `TRALRESTDWIndyServicePooler` |
| `--modulo <classe>` | classe do DataModule dos eventos; descoberta sozinha quando não informada |
| `--sem-transporte` | não mexe no pooler |
| `--servidores` | lista os motores do RAL desta máquina e sai |

**Rode sem `--aplicar` primeiro e leia os avisos.**

## O que ele faz

| arquivo | o que muda |
| --- | --- |
| `.pas` `.dpr` `.lpr` | tira do `uses` toda unit que comece com `uRESTDW` ou `uDW` e põe `RALRESTDWCompat` no lugar (mais a unit da casca e `RALRESTDWClientSQL`, quando o arquivo precisa); troca o tipo do campo do transporte; acrescenta `RegisterClass(TSeuDataModule)` |
| `.dfm` `.lfm` | renomeia as classes dos componentes; converte o `Routes = [crAll]` do RDW antigo para `Routes.All.Active` |

Renomeações no formulário:

| de | para |
| --- | --- |
| `TRESTDWServerEvents` | `TRALRESTDWServerEvents` |
| `TRESTDWClientEvents` | `TRALRESTDWClientEvents` |
| `TRESTDWClientSQL` | `TRALRESTDWClientSQL` |
| `TRESTDWIdServicePooler`, `TRESTDWIcsServicePooler` | a casca do motor escolhido |
| `TRESTDWIdClientPooler`, `TRESTDWIdClientREST` | `TRALRESTDWClient` |
| `TRESTDWIdDatabase` | `TRALRESTDWDatabase` |
| `TRESTDWPoolerDB`, `TRESTDWFireDACDriver` | as cascas de mesmo nome |
| `TRESTDWMassiveCache` | `TRALRESTDWMassiveCache` |
| `TRESTDWServerContext` | `TRALRESTDWServerContext` |
| `TRESTDWAuthBasic` | `TRALServerBasicAuth` |
| `RESTClientPooler =` | `RALClient =` |

**Nenhuma propriedade é alterada nem descartada.** O bloco do componente sai do
conversor exatamente como entrou, só com outra classe em cima — é a casca que traduz.

## O que ele não faz, de propósito

**Não reescreve o corpo do seu código.** Com `RALRESTDWCompat` no `uses`, os nomes
de tipo do RDW continuam valendo — `TRESTDWParams`, `TObjectValue`, `ovString`,
`odINOUT`, `cUndefined`, `StringRAL`. O corpo dos handlers fica exatamente como
está, que é a razão de o projeto existir.

Também não inventa equivalente para o que não tem: `TRESTDWServicePooler`,
`TRESTDWPoolerDB`, `TRESTDWDataBase`, `TRESTClientPooler`, `TRESTDWMassiveBuffer` e
`TRESTDWUpdateSQL` só recebem um aviso no relatório. Esses são os componentes de
transporte e de banco, que viram `TRALServer` + `TRALRESTDWModule` no servidor e
`TRALClient` + `TRALDBConnection` no cliente — uma decisão de arquitetura, não uma
troca de nome.

## Dois cuidados que ele toma

**Codificação.** Trabalha em bytes, nunca decodifica. Fonte Delphi costuma estar
em CP1252 e reescrever como UTF-8 transformaria todo acento em mojibake. Como
identificador Pascal é sempre ASCII, a troca byte a byte é segura em CP1252, em
UTF-8 e em qualquer codificação de um byte.

**Palavra inteira.** Só troca o identificador quando ele está isolado. Sem isso,
o componente `RESTDWClientSQL1` viraria `RALRESTDWClientSQL1` e o handler
`RESTDWClientSQL1CalcFields` seria reescrito junto.

## Depois de rodar

1. Instale os pacotes: `PascalRAL`, `PascalRALDsgn`, o engine, `RALRESTDW` e —
   se usar dataset — `RALRESTDWDB`.
2. Troque o transporte: o pooler/servidor do RDW vira `TRALServer` +
   `TRALRESTDWModule`; no cliente, `TRALClient` (e `TRALDBConnection` para banco).
3. Compile e leia os erros que sobrarem: são exatamente os pontos que precisam de
   decisão humana.
