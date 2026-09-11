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
    procedure Arquivo(const AArquivo: string; AAlteracoes: Integer);
    procedure Aviso(const AArquivo, ATexto: string; ATipo: TTipoAviso);
  end;

procedure TSaida.Arquivo(const AArquivo: string; AAlteracoes: Integer);
begin
  Writeln(Format('  %-45s %d alteracao(oes)',
                 [ExtractFileName(AArquivo), AAlteracoes]));
end;

procedure TSaida.Aviso(const AArquivo, ATexto: string; ATipo: TTipoAviso);
begin
  // renomeacao e o trabalho normal; no console so interessa o que pede atencao
  if ATipo = taRenomeado then
    Exit;

  Avisos.Add(Format('  %s: %s', [ExtractFileName(AArquivo), ATexto]));
end;

procedure Ajuda;
begin
  Writeln('rdw2ral - converte um projeto REST Dataware para RESTDW2RAL');
  Writeln('');
  Writeln('  rdw2ral <pasta ou arquivo> [opcoes]');
  Writeln('');
  Writeln('  --aplicar    grava as alteracoes (sem isso apenas simula)');
  Writeln('  --backup     guarda o original como .bak antes de gravar');
  Writeln('  --tipos      troca tambem os nomes de tipo no codigo');
  Writeln('               (desnecessario se voce usar a unit RALRESTDWCompat)');
  Writeln('');
  Writeln('  O que ele faz:');
  Writeln('    .pas .dpr .lpr   tira as units do RDW do uses e poe RALRESTDWCompat');
  Writeln('    .dfm .lfm        renomeia as classes e as propriedades que mudaram');
  Writeln('');
  Writeln('  Rode sem --aplicar primeiro e leia os avisos.');
  Writeln('  Ha tambem uma versao com janela: rdw2ralgui.exe');
end;

var
  gConv: TConversor;
  gSaida: TSaida;
  vCaminho: string;
  vInt1: Integer;
begin
  gConv := TConversor.Create;
  gSaida := TSaida.Create;
  gSaida.Avisos := TStringList.Create;
  try
    gConv.Backup := False;
    vCaminho := '';

    for vInt1 := 1 to ParamCount do
    begin
      if SameText(ParamStr(vInt1), '--aplicar') then
        gConv.Aplicar := True
      else if SameText(ParamStr(vInt1), '--backup') then
        gConv.Backup := True
      else if SameText(ParamStr(vInt1), '--tipos') then
        gConv.TrocarTipos := True
      else if vCaminho = '' then
        vCaminho := ParamStr(vInt1);
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
    if (not gConv.Aplicar) and (gConv.Alterados > 0) then
      Writeln('repita com --aplicar para gravar');
  finally
    FreeAndNil(gSaida.Avisos);
    FreeAndNil(gSaida);
    FreeAndNil(gConv);
  end;
end.
