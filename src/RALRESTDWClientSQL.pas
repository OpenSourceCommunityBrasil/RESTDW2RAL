{ O dataset remoto, no formato do TRESTDWClientSQL.

  Descende do memtable remoto do PascalRAL - TRALDBFDMemTable no Delphi,
  TRALDBBufDataset no Lazarus - e acrescenta os nomes e os comportamentos que o
  REST Dataware expoe, para que um formulario portado continue dizendo
  `qry.DataBase`, `qry.UpdateTableName`, `qry.RaiseErrors` e o codigo que abre,
  percorre e grava nao mude.

  O que ja vem de graca da base do RAL: SQL, Params, ParamByName, Active, Open,
  Close, ExecSQL, ApplyUpdates, RowsAffected, LastId, UpdateSQL, UpdateMode,
  Storage e todos os eventos de TDataSet. }
unit RALRESTDWClientSQL;

interface

uses
  Classes, SysUtils, DateUtils, DB,
  RALTypes, RALDBTypes, RALDBConnection,
  {$IFDEF FPC}
    RALDBBufDataset;
  {$ELSE}
    RALDBFiredacMemTable;
  {$ENDIF}

type
  ERALRESTDWClientSQL = class(Exception);

  /// Mesma forma do TOnEventConnection do RDW
  TRALRESTDWDataError = procedure(ASuccess: Boolean; const AError: StringRAL) of object;

  { A base muda por compilador, mas a superficie e a mesma nos dois: os drivers
    do RAL sao paralelos de proposito. }
  {$IFDEF FPC}
  TRALRESTDWClientSQLBase = TRALDBBufDataset;
  {$ELSE}
  TRALRESTDWClientSQLBase = TRALDBFDMemTable;
  {$ENDIF}

  { TRALRESTDWClientSQL }

  TRALRESTDWClientSQL = class(TRALRESTDWClientSQLBase)
  private
    FAutoCommitData: boolean;
    FAutoRefreshAfterCommit: boolean;
    FCacheUpdateRecords: boolean;
    FRaiseErrors: boolean;
    FReflectChanges: boolean;
    FApplying: boolean;
    FThreadRequest: boolean;
    FRequestTimeout: IntegerRAL;
    FWaiting: boolean;
    FResponseDone: boolean;
    FLastError: StringRAL;
    FMasterFields: StringRAL;
    FMasterSource: TDataSource;
    FOnGetDataError: TRALRESTDWDataError;
    FOnErrorUser: TRALDBTableOnError;

    function GetDataBase: TRALDBConnection;
    procedure SetDataBase(AValue: TRALDBConnection);
    function GetUpdateTableName: StringRAL;
    procedure SetUpdateTableName(const AValue: StringRAL);
    function GetMasterDataSet: TDataSet;
    procedure SetMasterDataSet(AValue: TDataSet);
    procedure SetMasterFields(const AValue: StringRAL);
    procedure MasterChanged(ASender: TObject; AField: TField);
    /// True quando a alteracao tem de ir ao servidor na hora
    function CommitOnChange: boolean;
  protected
    { O erro do RAL morre em silencio quando OnError nao esta atribuido. Aqui ele
      sempre passa por este metodo, que avisa quem estiver ouvindo e, se ninguem
      estiver, levanta - que e o que o RaiseErrors do RDW promete. }
    procedure InternalError(ASender: TObject; AException: StringRAL);

    procedure InternalPost; override;
    procedure InternalDelete; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    { O RAL dispara a consulta aqui, no SetActive, e so ativa o dataset quando a
      resposta chega - entao e aqui que os params do master tem de estar
      prontos, e nao no OpenCursor, que so roda depois dos dados. }
    procedure SetActive(AValue: boolean); override;
    { Segura a chamada ate a resposta chegar.

      O RAL manda as operacoes de banco com callback e ExecBehavior padrao
      ebMultiThread: Open, ExecSQL e ApplyUpdates voltam antes de a resposta
      existir. No RDW essas tres sao sincronas, e codigo portado conta com isso
      - le RecordCount na linha seguinte ao Open, RowsAffected depois do ExecSQL.
      A espera aqui devolve essa semantica; ThreadRequest desliga. }
    function WaitResponse(AUntilActive: boolean): boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure ApplyUpdates; reintroduce;
    procedure ExecSQL; reintroduce;
    /// Fecha e reabre, refazendo a consulta no servidor
    procedure RefreshData;
    /// Copia os campos do master para os params de mesmo nome
    procedure ApplyMasterParams;
  published
    /// A conexao com o TRALDBModule do servidor - o DataBase do RDW
    property DataBase: TRALDBConnection read GetDataBase write SetDataBase;
    /// Tabela usada para montar insert/update/delete - o UpdateTableName do RDW
    property UpdateTableName: StringRAL read GetUpdateTableName write SetUpdateTableName;
    { Com False, cada Post e cada Delete vao ao servidor na hora. Com True (o
      padrao, e o que o RAL faz), ficam no cache ate ApplyUpdates. }
    property CacheUpdateRecords: boolean read FCacheUpdateRecords write FCacheUpdateRecords default True;
    /// Chama ApplyUpdates sozinho depois de cada Post/Delete
    property AutoCommitData: boolean read FAutoCommitData write FAutoCommitData default False;
    /// Refaz a consulta depois de um ApplyUpdates bem-sucedido
    property AutoRefreshAfterCommit: boolean read FAutoRefreshAfterCommit write FAutoRefreshAfterCommit default False;
    /// Mesmo efeito do AutoRefreshAfterCommit, com o nome que o RDW usa
    property ReflectChanges: boolean read FReflectChanges write FReflectChanges default False;
    { Sem ninguem ouvindo o erro, levanta excecao em vez de engolir. Ligado por
      padrao: um erro silencioso e o pior desfecho possivel. }
    property RaiseErrors: boolean read FRaiseErrors write FRaiseErrors default True;
    /// Master do relacionamento; a cada troca de registro os params sao refeitos
    property MasterDataSet: TDataSet read GetMasterDataSet write SetMasterDataSet;
    /// Campos do master, separados por ';', copiados para os params de mesmo nome
    property MasterFields: StringRAL read FMasterFields write SetMasterFields;
    { Com True, Open/ExecSQL/ApplyUpdates voltam na hora e o resultado chega
      depois - o comportamento nativo do RAL. Desligado por padrao, porque no
      RDW essas chamadas sao sincronas. }
    property ThreadRequest: boolean read FThreadRequest write FThreadRequest default False;
    /// Quanto esperar pela resposta, em milissegundos
    property RequestTimeout: IntegerRAL read FRequestTimeout write FRequestTimeout default 30000;
    /// O OnGetDataError do RDW
    property OnGetDataError: TRALRESTDWDataError read FOnGetDataError write FOnGetDataError;
    { Redeclarado sobre um campo proprio: o da base fica com o InternalError, que
      e quem faz o RaiseErrors funcionar. }
    property OnError: TRALDBTableOnError read FOnErrorUser write FOnErrorUser;
  end;

  { O nome do RDW, para o codigo portado nao mudar. Fica aqui e nao no
    RALRESTDWCompat porque aquela unit vive no pacote base, que nao depende do
    pacote de banco - a dependencia so anda nesse sentido. }
  TRESTDWClientSQL = TRALRESTDWClientSQL;

implementation

{ TRALRESTDWClientSQL }

constructor TRALRESTDWClientSQL.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FCacheUpdateRecords := True;
  FAutoCommitData := False;
  FAutoRefreshAfterCommit := False;
  FReflectChanges := False;
  FRaiseErrors := True;
  FApplying := False;
  FThreadRequest := False;
  FRequestTimeout := 30000;
  FWaiting := False;
  FResponseDone := False;

  FMasterSource := TDataSource.Create(Self);
  FMasterSource.OnDataChange := {$IFDEF FPC}@{$ENDIF}MasterChanged;

  { O cast para a base e o que alcanca o OnError dela, ja que este componente
    redeclara um OnError proprio. }
  TRALRESTDWClientSQLBase(Self).OnError := {$IFDEF FPC}@{$ENDIF}InternalError;
end;

destructor TRALRESTDWClientSQL.Destroy;
begin
  FMasterSource.OnDataChange := nil;
  FreeAndNil(FMasterSource);
  inherited Destroy;
end;

function TRALRESTDWClientSQL.GetDataBase: TRALDBConnection;
begin
  Result := RALConnection;
end;

procedure TRALRESTDWClientSQL.SetDataBase(AValue: TRALDBConnection);
begin
  RALConnection := AValue;
end;

function TRALRESTDWClientSQL.GetUpdateTableName: StringRAL;
begin
  Result := UpdateTable;
end;

procedure TRALRESTDWClientSQL.SetUpdateTableName(const AValue: StringRAL);
begin
  UpdateTable := AValue;
end;

function TRALRESTDWClientSQL.GetMasterDataSet: TDataSet;
begin
  Result := FMasterSource.DataSet;
end;

procedure TRALRESTDWClientSQL.SetMasterDataSet(AValue: TDataSet);
begin
  if AValue = TDataSet(Self) then
    raise ERALRESTDWClientSQL.Create('MasterDataSet nao pode ser o proprio dataset');

  FMasterSource.DataSet := AValue;
end;

procedure TRALRESTDWClientSQL.SetMasterFields(const AValue: StringRAL);
begin
  if FMasterFields = AValue then
    Exit;

  FMasterFields := AValue;
  if Active then
    RefreshData;
end;

procedure TRALRESTDWClientSQL.ApplyMasterParams;
var
  vList: TStringList;
  vInt1: IntegerRAL;
  vField: TField;
  vParam: TParam;
  vMaster: TDataSet;
begin
  vMaster := FMasterSource.DataSet;
  if (vMaster = nil) or (Trim(FMasterFields) = '') or (not vMaster.Active) then
    Exit;

  vList := TStringList.Create;
  try
    vList.Delimiter := ';';
    vList.StrictDelimiter := True;
    vList.DelimitedText := String(FMasterFields);

    for vInt1 := 0 to Pred(vList.Count) do
    begin
      vField := vMaster.FindField(Trim(vList.Strings[vInt1]));
      if vField = nil then
        Continue;

      vParam := Params.FindParam(vField.FieldName);
      if vParam = nil then
        Continue;

      if vField.IsNull then
        vParam.Clear
      else
        vParam.Value := vField.Value;
    end;
  finally
    FreeAndNil(vList);
  end;
end;

procedure TRALRESTDWClientSQL.MasterChanged(ASender: TObject; AField: TField);
begin
  { OnDataChange dispara tambem a cada campo editado no master; so a troca de
    registro interessa, e ela e a unica que chega com AField nil. Sem esse
    teste o detalhe refazia a consulta a cada tecla digitada no master. }
  if (AField <> nil) or (csDestroying in ComponentState) or (not Active) then
    Exit;

  RefreshData;
end;

function TRALRESTDWClientSQL.CommitOnChange: boolean;
begin
  Result := FAutoCommitData or (not FCacheUpdateRecords);
end;

procedure TRALRESTDWClientSQL.InternalError(ASender: TObject; AException: StringRAL);
begin
  // a falha tambem encerra a espera, senao ela ia ate o timeout
  FResponseDone := True;

  if Assigned(FOnGetDataError) then
  begin
    FOnGetDataError(False, AException);
  end
  else if Assigned(FOnErrorUser) then
  begin
    FOnErrorUser(ASender, AException);
  end
  else
  begin
    { Nao levanta daqui: este metodo roda dentro do callback do RAL, entregue
      pela fila do Synchronize, e uma excecao ali escapa do try..except de quem
      chamou Open. O WaitResponse levanta no contexto certo. }
    FLastError := AException;
  end;
end;

procedure TRALRESTDWClientSQL.InternalPost;
begin
  inherited InternalPost;

  if CommitOnChange and (not FApplying) then
    ApplyUpdates;
end;

procedure TRALRESTDWClientSQL.InternalDelete;
begin
  inherited InternalDelete;

  if CommitOnChange and (not FApplying) then
    ApplyUpdates;
end;

procedure TRALRESTDWClientSQL.ExecSQL;
begin
  FResponseDone := False;
  inherited ExecSQL;

  if not FThreadRequest then
    WaitResponse(False);
end;

procedure TRALRESTDWClientSQL.ApplyUpdates;
begin
  if FApplying then
    Exit;

  FApplying := True;
  try
    FResponseDone := False;
    inherited ApplyUpdates;

    if not FThreadRequest then
      WaitResponse(False);
  finally
    FApplying := False;
  end;

  if FAutoRefreshAfterCommit or FReflectChanges then
    RefreshData;
end;

procedure TRALRESTDWClientSQL.RefreshData;
begin
  if not Active then
    Exit;

  DisableControls;
  try
    Close;
    Open;
  finally
    EnableControls;
  end;
end;

procedure TRALRESTDWClientSQL.SetActive(AValue: boolean);
begin
  { Reentra por dentro do WaitResponse: o callback do RAL chama SetActive de
    novo para ativar o dataset de verdade. Nessa volta nao se espera nada. }
  if FWaiting or FThreadRequest or (not AValue) or
     (csLoading in ComponentState) or (csDestroying in ComponentState) then
  begin
    inherited SetActive(AValue);
    Exit;
  end;

  ApplyMasterParams;

  FWaiting := True;
  try
    FResponseDone := False;
    inherited SetActive(AValue);
    WaitResponse(True);
  finally
    FWaiting := False;
  end;
end;

function TRALRESTDWClientSQL.WaitResponse(AUntilActive: boolean): boolean;
var
  vLimite: TDateTime;
  vPrincipal: boolean;
  vErro: StringRAL;
begin
  Result := False;
  vLimite := IncMilliSecond(Now, FRequestTimeout);
  vPrincipal := MainThreadID = TThread.CurrentThread.ThreadID;

  FLastError := '';

  while Now < vLimite do
  begin
    if FResponseDone or (AUntilActive and Active) then
    begin
      Result := True;
      Break;
    end;

    { O callback do RAL volta pela fila do TThread.Synchronize, entao quem
      espera na thread principal tem de rodar a fila - senao a resposta nunca
      chega e um aplicativo de console trava ate o timeout. Fora da principal,
      quem roda a fila e o proprio loop da aplicacao. }
    if vPrincipal then
    begin
      if CheckSynchronize(10) then
        FResponseDone := True;
    end
    else
    begin
      Sleep(10);
    end;
  end;

  // levanta aqui, onde quem chamou Open/ExecSQL/ApplyUpdates consegue capturar
  if (FLastError <> '') and FRaiseErrors then
  begin
    vErro := FLastError;
    FLastError := '';
    raise ERALRESTDWClientSQL.Create(String(vErro));
  end;
end;

procedure TRALRESTDWClientSQL.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  if (Operation = opRemove) and (FMasterSource <> nil) and
     (AComponent = FMasterSource.DataSet) then
    FMasterSource.DataSet := nil;
end;

end.
