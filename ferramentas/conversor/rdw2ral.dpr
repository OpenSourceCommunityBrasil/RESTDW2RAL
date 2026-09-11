{ Conversor de projetos REST Dataware para RESTDW2RAL.

  Faz o trabalho mecanico da migracao:

    .pas .dpr .lpr   tira as units do RDW do uses e poe as do RESTDW2RAL
    .dfm .lfm        renomeia as classes dos componentes e as propriedades que
                     mudaram de nome

  O que ele NAO faz, de proposito: reescrever o corpo do seu codigo. Com a unit
  RALRESTDWCompat no uses, os nomes de tipo do RDW (TRESTDWParams, TObjectValue,
  ovString, odINOUT...) continuam valendo, entao o corpo dos handlers nao muda.

  Roda em modo simulacao por padrao: mostra o que faria e nao grava nada.

  Trabalha em bytes, nao em texto: fonte Delphi costuma estar em CP1252 e
  reescrever o arquivo como UTF-8 transformaria todo acento em mojibake. Como
  todo identificador Pascal e ASCII, a troca byte a byte e segura em CP1252,
  em UTF-8 e em qualquer outra codificacao de um byte. }
program rdw2ral;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.Generics.Collections;

type
  TTroca = record
    De: string;
    Para: string;
    Nota: string;
  end;

const
  { Classes de componente: e o unico ponto que nenhuma unit de compatibilidade
    resolve, porque o formulario guarda o nome real da classe. }
  cClasses: array[0..2] of TTroca = (
    (De: 'TRESTDWServerEvents'; Para: 'TRALRESTDWServerEvents'; Nota: ''),
    (De: 'TRESTDWClientEvents'; Para: 'TRALRESTDWClientEvents'; Nota: ''),
    (De: 'TRESTDWClientSQL';    Para: 'TRALRESTDWClientSQL';    Nota: '')
  );

  { Propriedades que trocaram de nome no formulario }
  cPropriedades: array[0..0] of TTroca = (
    (De: 'RESTClientPooler'; Para: 'RALClient';
     Nota: 'o pooler do RDW virou um TRALClient')
  );

  { Componentes do RDW sem equivalente direto: o conversor nao mexe, so avisa }
  cSemEquivalente: array[0..5] of string = (
    'TRESTDWServicePooler',
    'TRESTDWPoolerDB',
    'TRESTDWDataBase',
    'TRESTClientPooler',
    'TRESTDWMassiveBuffer',
    'TRESTDWUpdateSQL'
  );

  { Tipos, para quem preferir trocar em vez de usar o RALRESTDWCompat }
  cTipos: array[0..12] of TTroca = (
    (De: 'TRESTDWParams';        Para: 'TRALRESTDWParams';        Nota: ''),
    (De: 'TDWParams';            Para: 'TRALRESTDWParams';        Nota: ''),
    (De: 'TRESTDWJSONParam';     Para: 'TRALRESTDWJSONParam';     Nota: ''),
    (De: 'TRESTDWParamsMethods'; Para: 'TRALRESTDWParamsMethods'; Nota: ''),
    (De: 'TRESTDWParamMethod';   Para: 'TRALRESTDWParamMethod';   Nota: ''),
    (De: 'TRESTDWEventList';     Para: 'TRALRESTDWEventList';     Nota: ''),
    (De: 'TRESTDWEvent';         Para: 'TRALRESTDWEventServer';   Nota: ''),
    (De: 'TObjectDirection';     Para: 'TRALRESTDWObjectDirection'; Nota: ''),
    (De: 'TObjectValue';         Para: 'TRALRESTDWObjectValue';   Nota: ''),
    (De: 'TTypeObject';          Para: 'TRALRESTDWTypeObject';    Nota: ''),
    (De: 'TDataMode';            Para: 'TRALRESTDWDataMode';      Nota: ''),
    (De: 'TSendEvent';           Para: 'TRALRESTDWSendEvent';     Nota: ''),
    (De: 'TDWReplyEvent';        Para: 'TRALRESTDWReplyEvent';    Nota: '')
  );

var
  gAplicar: Boolean = False;
  gBackup: Boolean = False;
  gTrocarTipos: Boolean = False;
  gArquivos: Integer = 0;
  gAlterados: Integer = 0;
  gAvisos: TStringList;

{ ---------------------------------------------------------------- utilidades }

function EhIdentChar(AByte: Byte): Boolean;
begin
  Result := (AByte in [Ord('a')..Ord('z'), Ord('A')..Ord('Z'),
                       Ord('0')..Ord('9'), Ord('_')]);
end;

{ Troca A por B somente quando A esta isolado, isto e, nao faz parte de um
  identificador maior. Sem isso, TRESTDWClientSQL viraria TRALRESTDWClientSQL
  dentro de TRESTDWClientSQLBase. }
function TrocaPalavra(const ATexto, ADe, APara: RawByteString;
  out AQtd: Integer): RawByteString;
var
  vPos, vIni: Integer;
  vAntes, vDepois: Byte;
begin
  Result := '';
  AQtd := 0;
  vIni := 1;

  repeat
    vPos := PosEx(LowerCase(string(ADe)), LowerCase(string(ATexto)), vIni);
    if vPos = 0 then
      Break;

    vAntes := 0;
    if vPos > 1 then
      vAntes := Ord(ATexto[vPos - 1]);

    vDepois := 0;
    if vPos + Length(ADe) <= Length(ATexto) then
      vDepois := Ord(ATexto[vPos + Length(ADe)]);

    if EhIdentChar(vAntes) or EhIdentChar(vDepois) then
    begin
      Result := Result + Copy(ATexto, vIni, vPos - vIni + Length(ADe));
    end
    else
    begin
      Result := Result + Copy(ATexto, vIni, vPos - vIni) + APara;
      Inc(AQtd);
    end;

    vIni := vPos + Length(ADe);
  until False;

  Result := Result + Copy(ATexto, vIni, MaxInt);
end;

function Contem(const ATexto, AAlvo: RawByteString): Boolean;
begin
  Result := Pos(LowerCase(string(AAlvo)), LowerCase(string(ATexto))) > 0;
end;

procedure Aviso(const AArquivo, ATexto: string);
begin
  gAvisos.Add(Format('  %s: %s', [ExtractFileName(AArquivo), ATexto]));
end;

{ ------------------------------------------------------------- clausula uses }

{ Reescreve uma clausula uses: tira toda unit do RDW (prefixo uRESTDW ou uDW) e
  poe no lugar as do RESTDW2RAL que o arquivo precisa. }
function AjustarUses(const ATexto: RawByteString; const AArquivo: string;
  out AQtd: Integer): RawByteString;
var
  vBaixo, vItem, vNomeUnit: string;
  vPosUses, vPosFim, vInicio, vInt1: Integer;
  vBloco, vNovo: string;
  vItens, vSaida: TStringList;
  vRemoveu, vTemCompat, vTemSQL, vPrecisaSQL: Boolean;
  vIndent: string;
begin
  Result := ATexto;
  AQtd := 0;
  vPrecisaSQL := Contem(ATexto, 'TRESTDWClientSQL') or
                 Contem(ATexto, 'TRALRESTDWClientSQL');

  vInicio := 1;
  repeat
    vBaixo := LowerCase(string(Result));
    vPosUses := 0;

    // 'uses' no comeco de uma linha
    for vInt1 := vInicio to Length(vBaixo) - 4 do
    begin
      if (Copy(vBaixo, vInt1, 4) = 'uses') and
         ((vInt1 = 1) or (vBaixo[vInt1 - 1] = #10) or (vBaixo[vInt1 - 1] = #13)) and
         (not EhIdentChar(Ord(vBaixo[vInt1 + 4]))) then
      begin
        vPosUses := vInt1;
        Break;
      end;
    end;

    if vPosUses = 0 then
      Break;

    vPosFim := PosEx(';', string(Result), vPosUses);
    if vPosFim = 0 then
      Break;

    vBloco := Copy(string(Result), vPosUses + 4, vPosFim - vPosUses - 4);

    vItens := TStringList.Create;
    vSaida := TStringList.Create;
    try
      vItens.StrictDelimiter := True;
      vItens.Delimiter := ',';
      vItens.DelimitedText := StringReplace(
        StringReplace(vBloco, #13, '', [rfReplaceAll]), #10, '', [rfReplaceAll]);

      vRemoveu := False;
      vTemCompat := False;
      vTemSQL := False;

      for vInt1 := 0 to vItens.Count - 1 do
      begin
        vItem := Trim(vItens[vInt1]);
        if vItem = '' then
          Continue;

        // 'Unit in ''arquivo.pas''' dos .dpr
        vNomeUnit := vItem;
        if Pos(' in ', LowerCase(vNomeUnit)) > 0 then
          vNomeUnit := Trim(Copy(vNomeUnit, 1, Pos(' in ', LowerCase(vNomeUnit))));

        if StartsText('uRESTDW', vNomeUnit) or StartsText('uDW', vNomeUnit) then
        begin
          vRemoveu := True;
          Aviso(AArquivo, Format('unit do RDW removida do uses: %s', [vNomeUnit]));
          Continue;
        end;

        if SameText(vNomeUnit, 'RALRESTDWCompat') then
          vTemCompat := True;
        if SameText(vNomeUnit, 'RALRESTDWClientSQL') then
          vTemSQL := True;

        vSaida.Add(vItem);
      end;

      if not vRemoveu then
      begin
        vInicio := vPosFim + 1;
        Continue;
      end;

      if not vTemCompat then
        vSaida.Add('RALRESTDWCompat');
      if vPrecisaSQL and (not vTemSQL) then
        vSaida.Add('RALRESTDWClientSQL');

      // indentacao: duas colunas, como o Delphi escreve
      vIndent := '  ';
      vNovo := '';
      for vInt1 := 0 to vSaida.Count - 1 do
      begin
        if vInt1 > 0 then
          vNovo := vNovo + ',' + sLineBreak;
        vNovo := vNovo + vIndent + vSaida[vInt1];
      end;

      Result := Copy(Result, 1, vPosUses + 3) + RawByteString(sLineBreak + vNovo) +
                Copy(Result, vPosFim, MaxInt);
      Inc(AQtd);
      vInicio := vPosUses + 4 + Length(vNovo);
    finally
      FreeAndNil(vSaida);
      FreeAndNil(vItens);
    end;
  until False;
end;

{ ---------------------------------------------------------------- conversao }

procedure Converter(const AArquivo: string);
var
  vBytes: TBytes;
  vTexto, vOriginal: RawByteString;
  vExt: string;
  vInt1, vQtd, vTotal: Integer;
  vStream: TFileStream;
begin
  Inc(gArquivos);
  vExt := LowerCase(ExtractFileExt(AArquivo));

  vBytes := TFile.ReadAllBytes(AArquivo);
  SetLength(vTexto, Length(vBytes));
  if Length(vBytes) > 0 then
    Move(vBytes[0], vTexto[1], Length(vBytes));
  vOriginal := vTexto;
  vTotal := 0;

  // avisa sobre o que nao tem equivalente, em qualquer tipo de arquivo
  for vInt1 := Low(cSemEquivalente) to High(cSemEquivalente) do
    if Contem(vTexto, RawByteString(cSemEquivalente[vInt1])) then
      Aviso(AArquivo, Format('%s nao tem equivalente automatico - veja o README',
                             [cSemEquivalente[vInt1]]));

  if (vExt = '.dfm') or (vExt = '.lfm') then
  begin
    for vInt1 := Low(cClasses) to High(cClasses) do
    begin
      vTexto := TrocaPalavra(vTexto, RawByteString(cClasses[vInt1].De),
                             RawByteString(cClasses[vInt1].Para), vQtd);
      Inc(vTotal, vQtd);
    end;

    for vInt1 := Low(cPropriedades) to High(cPropriedades) do
    begin
      vTexto := TrocaPalavra(vTexto, RawByteString(cPropriedades[vInt1].De),
                             RawByteString(cPropriedades[vInt1].Para), vQtd);
      Inc(vTotal, vQtd);
      if (vQtd > 0) and (cPropriedades[vInt1].Nota <> '') then
        Aviso(AArquivo, Format('%s -> %s (%s)', [cPropriedades[vInt1].De,
              cPropriedades[vInt1].Para, cPropriedades[vInt1].Nota]));
    end;
  end
  else if (vExt = '.pas') or (vExt = '.dpr') or (vExt = '.lpr') then
  begin
    vTexto := AjustarUses(vTexto, AArquivo, vQtd);
    Inc(vTotal, vQtd);

    // as classes tambem aparecem no .pas, no campo do formulario
    for vInt1 := Low(cClasses) to High(cClasses) do
    begin
      vTexto := TrocaPalavra(vTexto, RawByteString(cClasses[vInt1].De),
                             RawByteString(cClasses[vInt1].Para), vQtd);
      Inc(vTotal, vQtd);
    end;

    if gTrocarTipos then
    begin
      for vInt1 := Low(cTipos) to High(cTipos) do
      begin
        vTexto := TrocaPalavra(vTexto, RawByteString(cTipos[vInt1].De),
                               RawByteString(cTipos[vInt1].Para), vQtd);
        Inc(vTotal, vQtd);
      end;
    end;
  end
  else
  begin
    Exit;
  end;

  if vTexto = vOriginal then
    Exit;

  Inc(gAlterados);
  Writeln(Format('  %-45s %d alteracao(oes)', [ExtractFileName(AArquivo), vTotal]));

  if not gAplicar then
    Exit;

  if gBackup then
    TFile.Copy(AArquivo, AArquivo + '.bak', True);

  vStream := TFileStream.Create(AArquivo, fmCreate);
  try
    if Length(vTexto) > 0 then
      vStream.WriteBuffer(vTexto[1], Length(vTexto));
  finally
    FreeAndNil(vStream);
  end;
end;

procedure Percorrer(const ACaminho: string);
var
  vArquivo: string;
begin
  if TFile.Exists(ACaminho) then
  begin
    Converter(ACaminho);
    Exit;
  end;

  if not TDirectory.Exists(ACaminho) then
  begin
    Writeln('caminho nao encontrado: ', ACaminho);
    Exit;
  end;

  for vArquivo in TDirectory.GetFiles(ACaminho, '*.*', TSearchOption.soAllDirectories) do
    if MatchText(ExtractFileExt(vArquivo), ['.pas', '.dpr', '.lpr', '.dfm', '.lfm']) then
      Converter(vArquivo);
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
end;

var
  vCaminho: string;
  vInt1: Integer;
begin
  gAvisos := TStringList.Create;
  try
    vCaminho := '';
    for vInt1 := 1 to ParamCount do
    begin
      if SameText(ParamStr(vInt1), '--aplicar') then
        gAplicar := True
      else if SameText(ParamStr(vInt1), '--backup') then
        gBackup := True
      else if SameText(ParamStr(vInt1), '--tipos') then
        gTrocarTipos := True
      else if vCaminho = '' then
        vCaminho := ParamStr(vInt1);
    end;

    if vCaminho = '' then
    begin
      Ajuda;
      Exit;
    end;

    if gAplicar then
      Writeln('== GRAVANDO as alteracoes ==')
    else
      Writeln('== SIMULACAO - nada sera gravado (use --aplicar) ==');
    Writeln('');

    try
      Percorrer(ExcludeTrailingPathDelimiter(vCaminho));
    except
      on E: Exception do
        Writeln('ERRO: ', E.ClassName, ': ', E.Message);
    end;

    Writeln('');
    if gAvisos.Count > 0 then
    begin
      Writeln('avisos:');
      Writeln(gAvisos.Text);
    end;

    Writeln(Format('%d arquivo(s) lido(s), %d com alteracao', [gArquivos, gAlterados]));
    if (not gAplicar) and (gAlterados > 0) then
      Writeln('repita com --aplicar para gravar');
  finally
    FreeAndNil(gAvisos);
  end;
end.
