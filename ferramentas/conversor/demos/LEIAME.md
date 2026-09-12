# Demos do REST Dataware, sem conversão

Cópias de demos oficiais do RDW (`CORE/demos/Delphi/VCL`), **intactas quanto à
conversão**: nenhuma classe foi trocada, nenhum `uses` foi mexido. Elas estão aqui para
serem convertidas por quem quiser testar o caminho inteiro — da conversão ao programa
rodando — sem precisar caçar o repositório do RDW.

```
rdw2ral demos\SimpleServer                      simula e mostra o relatório
rdw2ral demos\SimpleServer --aplicar --backup   grava, guardando o original como .bak
```

Pela janela: abra `rdw2ralgui.exe`, arraste a pasta da demo, escolha o motor do RAL,
**1. Simular** e depois **2. Aplicar**.

| pasta | o que é | o que exercita |
| --- | --- | --- |
| `SimpleServer` | servidor mínimo, porta 8083 | `Routes = [crAll]` e o handler que só define o status |
| `FileTransfer` | servidor + cliente, porta 8082 | basic auth montada em código, lista/download/upload de arquivo |
| `FullServer` | servidor grande, porta 8082 | pooler de banco, driver FireDAC, contexto, token, massive |
| `FullClient` | cliente completo | eventos, banco sobre REST, massive cache, failover, bearer |

## O que muda quando você converte

Compare o `.dfm` antes e depois: no bloco do componente, a **única** linha diferente é o
nome da classe. `ServicePort`, `RootPath`, `CORS_CustomHeaders`, `AuthenticationOptions`,
`CriptOptions` continuam lá, palavra por palavra — quem faz o de/para é a classe casca,
em tempo de execução. O mesmo no código: `pooler.ServerMethodClass := TDM` e
`TRESTDWAuthOptionBasic(cliente.AuthenticationOptions.OptionParams).Username := x`
continuam compilando sem serem tocados.

O `FullServer` tem handlers das duas gerações do RDW lado a lado no mesmo `.pas` — uns
devolvem `TStringList`, outros `string`. O conversor decide **por handler** e renomeia a
propriedade no `.dfm` (`OnReplyEvent` ou `OnReplyEventStr`) conforme cada um. Ele relata
cada troca que fez.

## O que foi tirado das cópias

Credencial e caminho de máquina não entram em repositório. Onde as demos originais traziam
valores preenchidos, aqui está vazio:

- `FullServer`: o caminho do `.fdb` e o usuário/senha do banco, no `.dfm` das duas
  DataModules, nos campos da tela e nos valores default das leituras de `.ini`.
- `FullServer`, `FileTransfer`: o par usuário/senha do basic auth das demos.
- `FullClient`: a *Access TAG*.

Preencha o que for seu antes de rodar. No `FullServer` isso vai para o `.ini` ao lado do
executável, cujo nome vem do **nome do exe** (`Config_<exe>.ini`) — há um
`Config_RESTDWFullServer.ini.exemplo` para copiar.

Duas alterações além da limpeza, ambas comentadas no fonte:

- O `FullServer` sumia para a bandeja no instante em que o servidor subia, e no Windows 11
  a janela não volta — quem abre a demo fica sem como pará-la. A chamada automática saiu; o
  método continua lá e o duplo clique no ícone da bandeja ainda traz a janela de volta.
- No `FullClient`, o `SetKeys` (que o botão **Execute** chama) fazia
  `FindField(chave).ProviderFlags := ...` sem testar `Nil`. A chave vem da tabela do
  *UpdateTableName*, que não é necessariamente a tabela do `SELECT` aberto — e com os
  próprios valores que a demo traz (`IMAGELIST` no comando, `PACIENTES` no campo) o
  `FindField` devolve `Nil` e o Execute terminava em violação de acesso, no RDW igual.
  Ganhou o mesmo teste de `Nil` que o `btnOpenClick` já fazia com `FULL_NAME` e `UF`.
- Ainda no `FullClient`, o comando que vem no memo passou de `select * from IMAGELIST`
  para `select * from PACIENTES`. Eram a grid de uma tabela e o *UpdateTableName* de
  outra: o **ApplyUpdates** montava o update contra `PACIENTES` com as colunas da
  `IMAGELIST` e o Firebird recusava por coluna inexistente — de fábrica, a demo não
  conseguia gravar o que era editado na grid. Nada mais mudou; o campo
  *UpdateTableName* continua editável, e é ele que manda.

## O `.fdb` das demos não serve num Firebird novo

O `EMPLOYEE.FDB` que acompanha as demos do RDW é ODS 11.2 (Firebird 2.5) e um Firebird 5
recusa: *unsupported on-disk structure; found 11.2, support 13.1*. O exemplo que vem com o
próprio Firebird 5 (`examples/empbuild/EMPLOYEE.FDB`) já está em ODS 13 e tem `EMPLOYEE` e
`SALARY_HISTORY`. As demos ainda pedem duas tabelas que não estão lá:

```sql
CREATE TABLE IMAGELIST (
  ID INTEGER NOT NULL PRIMARY KEY, NOME VARCHAR(100), DESCRICAO VARCHAR(255));

CREATE TABLE PACIENTES (
  ID_PAC INTEGER NOT NULL PRIMARY KEY, NM_PAC VARCHAR(100) NOT NULL,
  END_PAC VARCHAR(100), DTNASC_PAC DATE, DUM DATE, VALID_CART DATE,
  DT_CADASTRO_PAC TIMESTAMP, DT_ALTERACAO TIMESTAMP, DT_ALTA TIMESTAMP,
  DT_OBITO TIMESTAMP, VALID_CART_EPS DATE, PESO_PAC FLOAT, ALTURA_PAC FLOAT);
```

Os campos de `PACIENTES` são exatamente os `FieldDefs` que o `TRESTDWClientSQL` do
`FullClient` traz no `.dfm`.

## Estado de cada uma, convertida

| demo | converte | compila | roda |
| --- | --- | --- | --- |
| `SimpleServer` | sim | sim | 200 no GET e DELETE, 201 no POST/PUT/PATCH, 404 em rota inexistente |
| `FileTransfer` | sim | sim | lista, baixa e envia arquivo, conteúdo idêntico dos dois lados |
| `FullServer` + `FullClient` | sim | sim | eventos (`helloworld`, `servertime`), banco (Open, Execute, ApplyUpdates gravando no Firebird), edição na grid + ApplyUpdates |

O botão **Get Employee** do `FullClient` responde *Event "getemployee" not found*, e está
certo: o `.dfm` do `FullServer` não publica esse evento — os handlers `DWServerEvents1...`
ficaram no `.pas` de uma versão anterior da demo, sem componente que os declare. É assim no
RDW original também.

## Detalhes de build

- O `.res` de cada demo é gerado (156 bytes, só bloco de versão) e **está versionado**, ao
  contrário do resto do repositório: sem ele o `{$R *.res}` do `.dpr` não compila fora da
  IDE. Abrir o `.dpr` no Delphi regenera um com ícone, e tudo bem.
- Os `.dproj` não vêm: o Delphi cria um ao abrir o `.dpr`, e o que ele grava carrega a lista
  inteira de pacotes instalados na máquina.
- A variante ICS do `FullServer` ficou de fora — a casca de transporte hoje é a do Indy.
