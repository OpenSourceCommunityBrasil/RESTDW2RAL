{ O motor da conversao, sem interface nenhuma.

  A linha de comando (rdw2ral) e a janela (rdw2ralgui) sao duas caras da mesma
  coisa: toda a regra mora aqui, para as duas nao divergirem com o tempo. }
unit uConversor;

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.IOUtils;

type
  TTipoAviso = (taUnitRemovida, taRenomeado, taSemEquivalente);

  TAvisoEvento = procedure(const AArquivo, ATexto: string;
                           ATipo: TTipoAviso) of object;
  TArquivoEvento = procedure(const AArquivo: string;
                             AAlteracoes: Integer) of object;

  { TConversor }

  TConversor = class
  private
    FAplicar: Boolean;
    FBackup: Boolean;
    FTrocarTipos: Boolean;
    FLidos: Integer;
    FAlterados: Integer;
    FTotalAlteracoes: Integer;
    FOnAviso: TAvisoEvento;
    FOnArquivo: TArquivoEvento;

    procedure Avisar(const AArquivo, ATexto: string; ATipo: TTipoAviso);
    function AjustarUses(const ATexto: RawByteString; const AArquivo: string;
                         out AQtd: Integer): RawByteString;
    procedure Converter(const AArquivo: string);
  public
    constructor Create;

    /// Converte um arquivo ou, recursivamente, tudo que houver numa pasta
    procedure Executar(const ACaminho: string);
    /// Extensoes que o conversor reconhece
    class function ExtensaoAceita(const AArquivo: string): Boolean;

    /// Grava as alteracoes. Com False apenas simula.
    property Aplicar: Boolean read FAplicar write FAplicar;
    /// Guarda o original como .bak antes de gravar
    property Backup: Boolean read FBackup write FBackup;
    /// Troca tambem os nomes de tipo (desnecessario com RALRESTDWCompat)
    property TrocarTipos: Boolean read FTrocarTipos write FTrocarTipos;

    property Lidos: Integer read FLidos;
    property Alterados: Integer read FAlterados;
    property TotalAlteracoes: Integer read FTotalAlteracoes;

    property OnAviso: TAvisoEvento read FOnAviso write FOnAviso;
    property OnArquivo: TArquivoEvento read FOnArquivo write FOnArquivo;
  end;

implementation

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

function EhIdentChar(AByte: Byte): Boolean;
begin
  Result := (AByte in [Ord('a')..Ord('z'), Ord('A')..Ord('Z'),
                       Ord('0')..Ord('9'), Ord('_')]);
end;

{ Troca A por B somente quando A esta isolado, isto e, nao faz parte de um
  identificador maior. Sem isso, o componente RESTDWClientSQL1 e o handler
  RESTDWClientSQL1CalcFields seriam reescritos junto com a classe. }
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

{ TConversor }

constructor TConversor.Create;
begin
  inherited Create;
  FAplicar := False;
  FBackup := True;
  FTrocarTipos := False;
end;

class function TConversor.ExtensaoAceita(const AArquivo: string): Boolean;
begin
  Result := MatchText(LowerCase(ExtractFileExt(AArquivo)),
                      ['.pas', '.dpr', '.lpr', '.dfm', '.lfm']);
end;

procedure TConversor.Avisar(const AArquivo, ATexto: string; ATipo: TTipoAviso);
begin
  if Assigned(FOnAviso) then
    FOnAviso(AArquivo, ATexto, ATipo);
end;

function TConversor.AjustarUses(const ATexto: RawByteString;
  const AArquivo: string; out AQtd: Integer): RawByteString;
var
  vBaixo, vItem, vNomeUnit: string;
  vPosUses, vPosFim, vInicio, vInt1: Integer;
  vBloco, vNovo: string;
  vItens, vSaida: TStringList;
  vRemoveu, vTemCompat, vTemSQL, vPrecisaSQL: Boolean;
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
          Avisar(AArquivo, Format('unit do RDW removida do uses: %s', [vNomeUnit]),
                 taUnitRemovida);
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

      vNovo := '';
      for vInt1 := 0 to vSaida.Count - 1 do
      begin
        if vInt1 > 0 then
          vNovo := vNovo + ',' + sLineBreak;
        vNovo := vNovo + '  ' + vSaida[vInt1];
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

procedure TConversor.Converter(const AArquivo: string);
var
  vBytes: TBytes;
  vTexto, vOriginal: RawByteString;
  vExt: string;
  vInt1, vQtd, vTotal: Integer;
  vStream: TFileStream;
begin
  Inc(FLidos);
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
      Avisar(AArquivo, Format('%s nao tem equivalente automatico', [cSemEquivalente[vInt1]]),
             taSemEquivalente);

  if (vExt = '.dfm') or (vExt = '.lfm') then
  begin
    for vInt1 := Low(cClasses) to High(cClasses) do
    begin
      vTexto := TrocaPalavra(vTexto, RawByteString(cClasses[vInt1].De),
                             RawByteString(cClasses[vInt1].Para), vQtd);
      Inc(vTotal, vQtd);
      if vQtd > 0 then
        Avisar(AArquivo, Format('%s -> %s (%d)', [cClasses[vInt1].De,
               cClasses[vInt1].Para, vQtd]), taRenomeado);
    end;

    for vInt1 := Low(cPropriedades) to High(cPropriedades) do
    begin
      vTexto := TrocaPalavra(vTexto, RawByteString(cPropriedades[vInt1].De),
                             RawByteString(cPropriedades[vInt1].Para), vQtd);
      Inc(vTotal, vQtd);
      if vQtd > 0 then
        Avisar(AArquivo, Format('%s -> %s (%s)', [cPropriedades[vInt1].De,
               cPropriedades[vInt1].Para, cPropriedades[vInt1].Nota]), taRenomeado);
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

    if FTrocarTipos then
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

  Inc(FAlterados);
  Inc(FTotalAlteracoes, vTotal);

  if Assigned(FOnArquivo) then
    FOnArquivo(AArquivo, vTotal);

  if not FAplicar then
    Exit;

  if FBackup then
    TFile.Copy(AArquivo, AArquivo + '.bak', True);

  vStream := TFileStream.Create(AArquivo, fmCreate);
  try
    if Length(vTexto) > 0 then
      vStream.WriteBuffer(vTexto[1], Length(vTexto));
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TConversor.Executar(const ACaminho: string);
var
  vArquivo, vCaminho: string;
begin
  FLidos := 0;
  FAlterados := 0;
  FTotalAlteracoes := 0;

  vCaminho := ExcludeTrailingPathDelimiter(Trim(ACaminho));
  if vCaminho = '' then
    raise Exception.Create('Informe a pasta ou o arquivo a converter');

  if TFile.Exists(vCaminho) then
  begin
    Converter(vCaminho);
    Exit;
  end;

  if not TDirectory.Exists(vCaminho) then
    raise Exception.CreateFmt('Caminho nao encontrado: %s', [vCaminho]);

  for vArquivo in TDirectory.GetFiles(vCaminho, '*.*', TSearchOption.soAllDirectories) do
    if ExtensaoAceita(vArquivo) then
      Converter(vArquivo);
end;

end.
