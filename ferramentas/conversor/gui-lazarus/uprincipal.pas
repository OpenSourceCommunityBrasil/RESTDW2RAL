{ Conversor de projetos REST Dataware para RESTDW2RAL - a janela do Lazarus.

  Toda a regra esta em uConversor, a mesma unit que a linha de comando e a
  janela do Delphi usam: sao tres cascas sobre um motor so, para nao divergirem
  com o tempo. Aqui so ha tela.

  O que muda em relacao a janela do Delphi e o que a LCL faz diferente:
  arrastar pasta e uma propriedade do formulario em vez de uma mensagem do
  Windows, a caixa de escolher pasta ja e a nativa, e abrir a pasta de um
  arquivo e OpenDocument em vez de ShellExecute. }
unit uprincipal;

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, Forms, Controls, StdCtrls, ComCtrls, ExtCtrls,
  Dialogs, LCLIntf,
  uConversor;

type

  { Tfprincipal }

  Tfprincipal = class(TForm)
    btAplicar: TButton;
    btEscolher: TButton;
    btSimular: TButton;
    cbServidor: TComboBox;
    chkBackup: TCheckBox;
    chkTipos: TCheckBox;
    edPasta: TEdit;
    lbArquivos: TLabel;
    lbAvisos: TLabel;
    lbPasta: TLabel;
    lbServidor: TLabel;
    lvArquivos: TListView;
    mAvisos: TMemo;
    pnTopo: TPanel;
    sb: TStatusBar;
    spl: TSplitter;
    procedure btAplicarClick(Sender: TObject);
    procedure btEscolherClick(Sender: TObject);
    procedure btSimularClick(Sender: TObject);
    procedure edPastaChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of string);
    procedure lvArquivosDblClick(Sender: TObject);
  private
    FConv: TConversor;
    FRaiz: string;

    procedure AoArquivo(const AArquivo: string; AAlteracoes: Integer);
    procedure AoAviso(const AArquivo, ATexto: string; ATipo: TTipoAviso);
    procedure Rodar(AAplicar: Boolean);
    procedure Limpar;
    /// Preenche a lista de motores, com os instalados na frente
    procedure CarregarServidores;
    /// A casca correspondente ao motor escolhido; vazio se nao houver
    function ClasseEscolhida: string;
    procedure AtualizarBotoes;
  public
    destructor Destroy; override;
  end;

var
  fprincipal: Tfprincipal;

implementation

{$R *.lfm}

destructor Tfprincipal.Destroy;
begin
  FreeAndNil(FConv);
  inherited Destroy;
end;

procedure Tfprincipal.FormCreate(Sender: TObject);
begin
  FConv := TConversor.Create;
  { na LCL arrastar arquivo para dentro da janela e uma propriedade, nao uma
    mensagem do Windows: o Delphi precisa de DragAcceptFiles e WM_DROPFILES }
  AllowDropFiles := True;

  CarregarServidores;
  sb.SimpleText := '  Escolha a pasta do projeto e clique em Simular. ' +
                   'Nada e gravado ate voce mandar aplicar.';

  // a pasta tambem pode vir na linha de comando
  if (ParamCount >= 1) and
     (DirectoryExists(ParamStr(1)) or FileExists(ParamStr(1))) then
    edPasta.Text := ParamStr(1);

  AtualizarBotoes;
end;

procedure Tfprincipal.FormDropFiles(Sender: TObject;
  const FileNames: array of string);
begin
  if Length(FileNames) = 0 then
    Exit;

  edPasta.Text := FileNames[0];
  Limpar;
end;

procedure Tfprincipal.edPastaChange(Sender: TObject);
begin
  AtualizarBotoes;
end;

procedure Tfprincipal.AtualizarBotoes;
var
  vTem: Boolean;
begin
  vTem := Trim(edPasta.Text) <> '';
  btSimular.Enabled := vTem;
  // so libera o Aplicar depois de uma simulacao que achou algo
  btAplicar.Enabled := vTem and (lvArquivos.Items.Count > 0);
end;

procedure Tfprincipal.btEscolherClick(Sender: TObject);
var
  vDlg: TSelectDirectoryDialog;
begin
  vDlg := TSelectDirectoryDialog.Create(nil);
  try
    vDlg.Title := 'Pasta do projeto a converter';
    { a caixa nativa do Windows, que tem barra de endereco, atalhos da lateral
      e campo para digitar ou colar o caminho - nao a arvore antiga }
    vDlg.Options := vDlg.Options + [ofPathMustExist, ofEnableSizing];
    if DirectoryExists(edPasta.Text) then
      vDlg.InitialDir := edPasta.Text;

    if not vDlg.Execute then
      Exit;

    edPasta.Text := vDlg.FileName;
    Limpar;
  finally
    FreeAndNil(vDlg);
  end;
end;

{ A lista sai do proprio IDE, e nao de um catalogo fixo: quem migra ve os
  motores que tem instalados na frente, e os outros marcados. }
procedure Tfprincipal.CarregarServidores;
var
  vLista: TStringList;
begin
  vLista := TStringList.Create;
  try
    TConversor.ServidoresInstalados(vLista);
    cbServidor.Items.Assign(vLista);
    if cbServidor.Items.Count > 0 then
      cbServidor.ItemIndex := 0;
  finally
    FreeAndNil(vLista);
  end;
end;

function Tfprincipal.ClasseEscolhida: string;
var
  vServidores: TServidoresRAL;
  vIdx: Integer;
begin
  Result := '';
  if cbServidor.ItemIndex < 0 then
    Exit;

  vIdx := PtrInt(cbServidor.Items.Objects[cbServidor.ItemIndex]);
  vServidores := TConversor.ServidoresRAL;
  if (vIdx >= 0) and (vIdx <= High(vServidores)) and
     vServidores[vIdx].TemCasca then
    Result := vServidores[vIdx].Classe;
end;

procedure Tfprincipal.Limpar;
begin
  lvArquivos.Items.Clear;
  mAvisos.Clear;
  AtualizarBotoes;
end;

procedure Tfprincipal.AoArquivo(const AArquivo: string; AAlteracoes: Integer);
var
  vItem: TListItem;
  vRel: string;
begin
  vRel := ExtractFilePath(AArquivo);
  if (FRaiz <> '') and StartsText(FRaiz, vRel) then
    vRel := Copy(vRel, Length(FRaiz) + 1, MaxInt);

  vItem := lvArquivos.Items.Add;
  vItem.Caption := ExtractFileName(AArquivo);
  vItem.SubItems.Add(IntToStr(AAlteracoes));
  vItem.SubItems.Add(vRel);
  // guardado inteiro para o duplo clique abrir a pasta
  vItem.SubItems.Add(AArquivo);
end;

procedure Tfprincipal.AoAviso(const AArquivo, ATexto: string; ATipo: TTipoAviso);
const
  cMarca: array[TTipoAviso] of string = ('[uses]    ', '[nome]    ',
                                         '[portado] ', '[perdido] ',
                                         '[modulo]  ', '[ATENCAO] ');
begin
  mAvisos.Lines.Add(Format('%s%s: %s',
                           [cMarca[ATipo], ExtractFileName(AArquivo), ATexto]));
end;

procedure Tfprincipal.lvArquivosDblClick(Sender: TObject);
begin
  if (lvArquivos.Selected = nil) or (lvArquivos.Selected.SubItems.Count < 3) then
    Exit;

  // abre a pasta onde o arquivo esta
  OpenDocument(ExtractFilePath(lvArquivos.Selected.SubItems[2]));
end;

procedure Tfprincipal.Rodar(AAplicar: Boolean);
var
  vSemEquivalente: Integer;
  vInt1: Integer;
begin
  Limpar;

  FRaiz := IncludeTrailingPathDelimiter(ExtractFilePath(
             IncludeTrailingPathDelimiter(Trim(edPasta.Text))));
  if FileExists(Trim(edPasta.Text)) then
    FRaiz := ExtractFilePath(Trim(edPasta.Text));

  FConv.Aplicar := AAplicar;
  FConv.Backup := chkBackup.Checked;
  FConv.TrocarTipos := chkTipos.Checked;
  FConv.ServidorRAL := ClasseEscolhida;
  { sem casca daquele motor a conversao sairia apontando para uma classe que
    nao existe, e o projeto so quebraria na hora de compilar }
  FConv.ConverterTransporte := FConv.ServidorRAL <> '';
  if not FConv.ConverterTransporte then
    mAvisos.Lines.Add('[ATENCAO] o motor escolhido ainda nao tem casca neste ' +
                      'projeto - o transporte fica como esta e so o resto e ' +
                      'convertido');
  FConv.OnArquivo := AoArquivo;
  FConv.OnAviso := AoAviso;

  Screen.Cursor := crHourGlass;
  lvArquivos.BeginUpdate;
  try
    try
      FConv.Executar(edPasta.Text);
    except
      on E: Exception do
      begin
        sb.SimpleText := '  ' + E.Message;
        MessageDlg(E.Message, mtError, [mbOK], 0);
        Exit;
      end;
    end;
  finally
    lvArquivos.EndUpdate;
    Screen.Cursor := crDefault;
  end;

  vSemEquivalente := 0;
  for vInt1 := 0 to mAvisos.Lines.Count - 1 do
    if Pos('[ATENCAO]', mAvisos.Lines[vInt1]) = 1 then
      Inc(vSemEquivalente);

  if AAplicar then
    sb.SimpleText := Format('  GRAVADO: %d arquivo(s) alterado(s), %d alteracao(oes). %s',
                            [FConv.Alterados, FConv.TotalAlteracoes,
                             IfThen(chkBackup.Checked, 'Originais guardados como .bak.', '')])
  else if FConv.Alterados = 0 then
    sb.SimpleText := Format('  %d arquivo(s) lido(s), nada a converter.', [FConv.Lidos])
  else
    sb.SimpleText := Format('  Simulacao: %d de %d arquivo(s) mudariam, %d alteracao(oes). ' +
                            'Nada foi gravado.',
                            [FConv.Alterados, FConv.Lidos, FConv.TotalAlteracoes]);

  if vSemEquivalente > 0 then
    sb.SimpleText := sb.SimpleText +
      Format('  %d ponto(s) precisam de decisao sua - veja os avisos.', [vSemEquivalente]);

  AtualizarBotoes;
end;

procedure Tfprincipal.btSimularClick(Sender: TObject);
begin
  Rodar(False);
end;

procedure Tfprincipal.btAplicarClick(Sender: TObject);
var
  vMsg: string;
begin
  vMsg := Format('Gravar as alteracoes em %d arquivo(s)?', [lvArquivos.Items.Count]);
  if not chkBackup.Checked then
    vMsg := vMsg + LineEnding + LineEnding +
            'Sem copia de seguranca: o original sera sobrescrito.' + LineEnding +
            'Se o projeto nao estiver num controle de versao, marque "Guardar .bak".';

  if MessageDlg(vMsg, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Rodar(True);
end;

end.
