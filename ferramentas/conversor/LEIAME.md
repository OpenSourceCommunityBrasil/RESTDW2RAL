# rdw2ral — conversor de projetos

Faz o trabalho mecânico da migração do REST Dataware para o RESTDW2RAL.

Vem em duas formas, **com a mesma regra por baixo**: `uConversor.pas` tem todo o
motor, e os dois programas são só a casca. Mexeu na regra, mexeu para os dois.

| | |
| --- | --- |
| `gui/rdw2ralgui.dpr` | **janela** — escolha a pasta, simule, veja o que muda, aplique |
| `rdw2ral.dpr` | linha de comando, para script e automação |

## Compilar

Nenhuma dependência além da RTL e da VCL:

```
dcc32 gui\rdw2ralgui.dpr      # a janela
dcc32 rdw2ral.dpr             # o console
```

Ou abra o `.dpr` no Delphi e compile.

## A janela

É o caminho recomendado, porque o fluxo seguro fica óbvio em vez de depender de você
lembrar de um argumento:

1. **Escolha a pasta** — pelo botão, ou arraste a pasta para dentro da janela.
2. **Simular** — nada é gravado. A lista mostra cada arquivo que mudaria e quantas
   alterações; o painel de baixo mostra os avisos. Duplo clique num arquivo abre a
   pasta dele no Explorer.
3. **Aplicar** — só habilita depois de uma simulação que achou algo, e pede
   confirmação. Se você tiver desmarcado o `.bak`, o aviso diz isso na cara.

Os avisos vêm marcados: `[uses]` é unit do RDW removida, `[nome]` é classe ou
propriedade renomeada, e **`[ATENCAO]`** é o que o conversor não sabe converter e
precisa de decisão sua. A barra de status conta quantos `[ATENCAO]` apareceram.

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

**Rode sem `--aplicar` primeiro e leia os avisos.**

## O que ele faz

| arquivo | o que muda |
| --- | --- |
| `.pas` `.dpr` `.lpr` | tira do `uses` toda unit que comece com `uRESTDW` ou `uDW` e põe `RALRESTDWCompat` no lugar (mais `RALRESTDWClientSQL` quando o arquivo usa o dataset) |
| `.dfm` `.lfm` | renomeia as classes dos componentes e as propriedades que trocaram de nome |

Renomeações no formulário:

| de | para |
| --- | --- |
| `TRESTDWServerEvents` | `TRALRESTDWServerEvents` |
| `TRESTDWClientEvents` | `TRALRESTDWClientEvents` |
| `TRESTDWClientSQL` | `TRALRESTDWClientSQL` |
| `RESTClientPooler =` | `RALClient =` |

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
