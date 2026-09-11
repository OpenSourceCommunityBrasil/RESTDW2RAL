{ Conversor de projetos REST Dataware para RESTDW2RAL - linha de comando.

  A regra toda mora em uConversor; aqui so ha a leitura dos argumentos e a
  impressao. A versao com janela (gui/rdw2ralgui.dpr) usa o mesmo motor. }
program rdw2ral;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  uConversor in 'uConversor.pas';

type
  TSaida = class
    Avisos: TStringList;
    Atencao: Integer;
    procedure Arquivo(const AArquivo: string; AAlteracoes: Integer);
    procedure Aviso(const AArquivo, ATexto: string; ATipo: TTipoAviso);
  end;

procedure TSaida.Arquivo(const AArquivo: string; AAlteracoes: Integer);
begin
  Writeln(Format('  %-45s %d alteracao(oes)',
                 [ExtractFileName(AArquivo), AAlteracoes]));
end;

procedure TSaida.Aviso(const AArquivo, ATexto: string; ATipo: TTipoAviso);
const
  cMarca: array[TTipoAviso] of string = ('uses', 'nome', 'portado', 'DESCARTADO',
                                         'modulo', 'ATENCAO');
begin
  // renomeacao e o trabalho normal; no console so interessa o resto
  if ATipo = taRenomeado then
    Exit;

  if ATipo in [taDescartado, taSemEquivalente] then
    Inc(Atencao);

  Avisos.Add(Format('  [%s] %s: %s', [cMarca[ATipo], ExtractFileName(AArquivo),
                                      ATexto]));
end;

procedure ListarServidores;
var
  vLista: TStringList;
  vInt1: Integer;
begin
  vLista := TStringList.Create;
  try
    TConversor.ServidoresInstalados(vLista);
    Writeln('servidores do RAL (os instalados nesta maquina vem primeiro):');
    for vInt1 := 0 to vLista.Count - 1 do
      Writeln('  ', vLista[vInt1]);
  finally
    FreeAndNil(vLista);
  end;
end;

procedure Ajuda;
begin
  Writeln('rdw2ral - converte um projeto REST Dataware para RESTDW2RAL');
  Writeln('');
  Writeln('  rdw2ral <pasta ou arquivo> [opcoes]');
  Writeln('');
  Writeln('  --aplicar          grava as alteracoes (sem isso apenas simula)');
  Writeln('  --backup           guarda o original como .bak antes de gravar');
  Writeln('  --tipos            troca tambem os nomes de tipo no codigo');
  Writeln('                     (desnecessario se voce usar a RALRESTDWCompat)');
  Writeln('  --servidor <cls>   qual servidor do RAL gerar no lugar do pooler');
  Writeln('                     do RDW; o padrao e TRALIndyServer');
  Writeln('  --modulo <cls>     classe do DataModule dos eventos; descoberta');
  Writeln('                     sozinha quando nao informada');
  Writeln('  --sem-transporte   nao mexe no pooler nem injeta o modulo');
  Writeln('  --servidores       lista os servidores do RAL e sai');
  Writeln('');
  Writeln('  O que ele faz:');
  Writeln('    .pas .dpr .lpr   tira as units do RDW do uses e poe RALRESTDWCompat;');
  Writeln('                     troca o campo do pooler pelo servidor do RAL');
  Writeln('    .dfm .lfm        renomeia as classes que mudaram, converte o pooler');
  Writeln('                     no servidor escolhido levando o que tem equivalente');
  Writeln('                     e injeta o TRALRESTDWModule ligado a ele');
  Writeln('');
  Writeln('  Rode sem --aplicar primeiro e leia os avisos: o que sai marcado');
  Writeln('  [DESCARTADO] ou [ATENCAO] precisa de decisao sua.');
  Writeln('  Ha tambem uma versao com janela: rdw2ralgui.exe');
end;

var
  gConv: TConversor;
  gSaida: TSaida;
  vCaminho, vArg: string;
  vInt1: Integer;
begin
  gConv := TConversor.Create;
  gSaida := TSaida.Create;
  gSaida.Avisos := TStringList.Create;
  try
    gConv.Backup := False;
    vCaminho := '';
    vInt1 := 1;

    while vInt1 <= ParamCount do
    begin
      vArg := ParamStr(vInt1);

      if SameText(vArg, '--servidores') then
      begin
        ListarServidores;
        Exit;
      end
      else if SameText(vArg, '--aplicar') then
        gConv.Aplicar := True
      else if SameText(vArg, '--backup') then
        gConv.Backup := True
      else if SameText(vArg, '--tipos') then
        gConv.TrocarTipos := True
      else if SameText(vArg, '--sem-transporte') then
        gConv.ConverterTransporte := False
      else if SameText(vArg, '--servidor') and (vInt1 < ParamCount) then
      begin
        Inc(vInt1);
        gConv.ServidorRAL := ParamStr(vInt1);
      end
      else if SameText(vArg, '--modulo') and (vInt1 < ParamCount) then
      begin
        Inc(vInt1);
        gConv.ClasseModulo := ParamStr(vInt1);
      end
      else if vCaminho = '' then
        vCaminho := vArg;

      Inc(vInt1);
    end;

    if vCaminho = '' then
    begin
      Ajuda;
      Exit;
    end;

    gConv.OnArquivo := gSaida.Arquivo;
    gConv.OnAviso := gSaida.Aviso;

    if gConv.Aplicar then
      Writeln('== GRAVANDO as alteracoes ==')
    else
      Writeln('== SIMULACAO - nada sera gravado (use --aplicar) ==');
    if gConv.ConverterTransporte then
      Writeln('servidor do RAL: ', gConv.ServidorRAL);
    Writeln('');

    try
      gConv.Executar(vCaminho);
    except
      on E: Exception do
      begin
        Writeln('ERRO: ', E.Message);
        ExitCode := 1;
        Exit;
      end;
    end;

    Writeln('');
    if gSaida.Avisos.Count > 0 then
    begin
      Writeln('avisos:');
      Writeln(gSaida.Avisos.Text);
    end;

    Writeln(Format('%d arquivo(s) lido(s), %d com alteracao, %d alteracao(oes) no total',
                   [gConv.Lidos, gConv.Alterados, gConv.TotalAlteracoes]));
    if gSaida.Atencao > 0 then
      Writeln(Format('%d aviso(s) precisam de decisao sua', [gSaida.Atencao]));
    if (not gConv.Aplicar) and (gConv.Alterados > 0) then
      Writeln('repita com --aplicar para gravar');
  finally
    FreeAndNil(gSaida.Avisos);
    FreeAndNil(gSaida);
    FreeAndNil(gConv);
  end;
end.
