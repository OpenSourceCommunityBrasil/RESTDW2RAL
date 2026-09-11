# Demos

Três projetos, prontos para rodar. Rode o **servidor** primeiro.

| pasta | o que é |
| --- | --- |
| `delphi/servidor` | servidor VCL: `TRALIndyServer` + `TRALRESTDWModule` |
| `delphi/cliente` | cliente VCL: `TRALClient` + `TRALRESTDWClientEvents` |
| `delphi/cliente_db` | cliente DBWare: `TRALRESTDWClientSQL` + `TRALDBConnection` |
| `lazarus/cliente` | o mesmo cliente em Lazarus/FPC, engine `fpHTTP` |

## Antes de abrir

Instale, nesta ordem: `PascalRAL`, `PascalRALDsgn`, o pacote do engine
(`IndyRAL` para o servidor, `NetHttpRAL` para o cliente Delphi, `fpHttpRAL`
para o Lazarus) e por fim `RALRESTDW`.

No Delphi, abra o `.dpr` — a IDE cria o `.dproj` sozinho. No Lazarus, abra o `.lpi`.

## Os cinco eventos da demo

| evento | mostra |
| --- | --- |
| `ping` | o mínimo: sem parâmetro, retorno no `cUndefined` |
| `soma` | dois `odIN` inteiros e um `odOUT`, todos tipados |
| `cadastro` | `odINOUT` com float e data — o tráfego tipado que não depende do locale |
| `clientes` | um dataset inteiro dentro de um parâmetro (`toDataset`) |
| `sigilo` | `OnAuthRequest`: autorização por evento, antes do handler |

## O banco da demo

O servidor cria um SQLite ao lado do executável na primeira execução — FireDAC com
SQLite embutido, sem servidor e sem DLL. Duas tabelas, `clientes` e `pedidos`, com
alguns registros.

O `delphi/cliente_db` mostra as principais operações do DBWare: `Open` de um SELECT,
`ExecSQL` com parâmetros lendo `RowsAffected`, edição na grade com `ApplyUpdates`,
`Delete`, master/detail por `MasterDataSet` + `MasterFields`, e os metadados do banco
por `GetTables`.

> **Compile a demo de banco em Release, ou desligue o range checking.** Há um defeito
> no PascalRAL (`RALDBSQLCache.pas`, `GetQueryParams`) que derruba com `ERangeError`
> qualquer consulta com parâmetro em build Debug. Está descrito no README, em
> *Limitações conhecidas*. A demo de eventos não é afetada.

## O que olhar no código

**No servidor:** não há rota escrita em lugar nenhum. O `TRALRESTDWModule` tem só
`Server`, `Domain` e `ClassModule` — o resto ele descobre. O log da janela mostra as
rotas que ele publicou sozinho.

**No cliente:** a coleção `Events` está **vazia** no formulário e o `ServerEventName`
também. O `AutoFetch` busca as definições na primeira chamada e o servidor resolve o
componente quando há só um.
