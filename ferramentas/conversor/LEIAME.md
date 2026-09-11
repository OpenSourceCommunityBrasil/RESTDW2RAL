# rdw2ral — conversor de projetos

Faz o trabalho mecânico da migração do REST Dataware para o RESTDW2RAL.

## Compilar

Console, sem dependência nenhuma além da RTL:

```
dcc32 rdw2ral.dpr
```

Ou abra o `.dpr` no Delphi e compile.

## Usar

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
