# Demos

Três projetos, prontos para rodar. Rode o **servidor** primeiro.

| pasta | o que é |
| --- | --- |
| `delphi/servidor` | servidor VCL: `TRALIndyServer` + `TRALRESTDWModule` |
| `delphi/cliente` | cliente VCL: `TRALClient` + `TRALRESTDWClientEvents` |
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

## O que olhar no código

**No servidor:** não há rota escrita em lugar nenhum. O `TRALRESTDWModule` tem só
`Server`, `Domain` e `ClassModule` — o resto ele descobre. O log da janela mostra as
rotas que ele publicou sozinho.

**No cliente:** a coleção `Events` está **vazia** no formulário e o `ServerEventName`
também. O `AutoFetch` busca as definições na primeira chamada e o servidor resolve o
componente quando há só um.
