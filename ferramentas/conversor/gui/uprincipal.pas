{ Conversor de projetos REST Dataware para RESTDW2RAL - versao com janela.

  Toda a regra esta em uConversor, a mesma unit que a linha de comando usa.
  Aqui so ha a tela. }
unit uprincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Variants, System.Classes, System.IOUtils, System.StrUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ComCtrls, Vcl.ExtCtrls, Vcl.FileCtrl,
  uConversor;

type
  Tfprincipal = class(TForm)
    pnTopo: TPanel;
    pnCima: TPanel;
    pnBaixo: TPanel;
    lbPasta: TLabel;
    edPasta: TEdit;
    btEscolher: TButton;
    chkBackup: TCheckBox;
    chkTipos: TCheckBox;
    btSimular: TButton;
    btAplicar: TButton;
    lvArquivos: TListView;
    mAvisos: TMemo;
    sb: TStatusBar;
    spl: TSplitter;
    lbArquivos: TLabel;
    lbAvisos: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btEscolherClick(Sender: TObject);
    procedure btSimularClick(Sender: TObject);
    procedure btAplicarClick(Sender: TObject);
    procedure lvArquivosDblClick(Sender: TObject);
    procedure edPastaChange(Sender: TObject);
  private
    FConv: TConversor;
    FRaiz: string;

    procedure AoArquivo(const AArquivo: string; AAlteracoes: Integer);
    procedure AoAviso(const AArquivo, ATexto: string; ATipo: TTipoAviso);
    procedure Rodar(AAplicar: Boolean);
    procedure Limpar;
    procedure AtualizarBotoes;
    /// Aceita uma pasta arrastada para dentro da janela
    procedure WMDropFiles(var AMsg: TWMDropFiles); message WM_DROPFILES;
  public
    destructor Destroy; override;
  end;

var
  fprincipal: Tfprincipal;

implementation

{$R *.dfm}

destructor Tfprincipal.Destroy;
begin
  FreeAndNil(FConv);
  inherited;
end;

procedure Tfprincipal.FormCreate(Sender: TObject);
begin
  FConv := TConversor.Create;
  DragAcceptFiles(Handle, True);

  sb.SimpleText := '  Escolha a pasta do projeto e clique em Simular. ' +
                   'Nada e gravado ate voce mandar aplicar.';

  // a pasta tambem pode vir na linha de comando
  if (ParamCount >= 1) and
     (TDirectory.Exists(ParamStr(1)) or TFile.Exists(ParamStr(1))) then
    edPasta.Text := ParamStr(1);

  AtualizarBotoes;
end;

procedure Tfprincipal.WMDropFiles(var AMsg: TWMDropFiles);
var
  vBuf: array[0..MAX_PATH] of Char;
begin
  try
    if DragQueryFile(AMsg.Drop, 0, vBuf, MAX_PATH) > 0 then
    begin
      edPasta.Text := vBuf;
      Limpar;
    end;
  finally
    DragFinish(AMsg.Drop);
  end;
  AMsg.Result := 0;
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
  vDir: string;
begin
  vDir := edPasta.Text;
  if SelectDirectory('Pasta do projeto a converter', '', vDir) then
  begin
    edPasta.Text := vDir;
    Limpar;
  end;
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
  cMarca: array[TTipoAviso] of string = ('[uses]  ', '[nome]  ', '[ATENCAO] ');
begin
  mAvisos.Lines.Add(Format('%s%s: %s',
                           [cMarca[ATipo], ExtractFileName(AArquivo), ATexto]));
end;

procedure Tfprincipal.lvArquivosDblClick(Sender: TObject);
begin
  if (lvArquivos.Selected = nil) or (lvArquivos.Selected.SubItems.Count < 3) then
    Exit;

  // abre o Explorer ja com o arquivo selecionado
  ShellExecute(Handle, 'open', 'explorer.exe',
               PChar('/select,"' + lvArquivos.Selected.SubItems[2] + '"'),
               nil, SW_SHOWNORMAL);
end;

procedure Tfprincipal.Rodar(AAplicar: Boolean);
var
  vSemEquivalente: Integer;
  vInt1: Integer;
begin
  Limpar;

  FRaiz := IncludeTrailingPathDelimiter(ExtractFilePath(
             IncludeTrailingPathDelimiter(Trim(edPasta.Text))));
  if TFile.Exists(Trim(edPasta.Text)) then
    FRaiz := ExtractFilePath(Trim(edPasta.Text));

  FConv.Aplicar := AAplicar;
  FConv.Backup := chkBackup.Checked;
  FConv.TrocarTipos := chkTipos.Checked;
  FConv.OnArquivo := AoArquivo;
  FConv.OnAviso := AoAviso;

  Screen.Cursor := crHourGlass;
  lvArquivos.Items.BeginUpdate;
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
    lvArquivos.Items.EndUpdate;
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
    vMsg := vMsg + sLineBreak + sLineBreak +
            'Sem copia de seguranca: o original sera sobrescrito.' + sLineBreak +
            'Se o projeto nao estiver num controle de versao, marque "Guardar .bak".';

  if MessageDlg(vMsg, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;

  Rodar(True);
end;

end.
