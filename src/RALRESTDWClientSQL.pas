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
  RALTypes, RALDBTypes, RALDBConnection, RALJson, RALRESTDWTypes,
  RALRESTDWMassive,
  {$IFDEF FPC}
    RALDBBufDataset;
  {$ELSE}
    RALDBFiredacMemTable;
  {$ENDIF}

type
  ERALRESTDWClientSQL = class(Exception);

  { Codigo do RDW manda o lote pela conexao: DataBase.ApplyUpdates(cache,...).
    O DataBase aqui e tipado como TRALDBConnection, para que quem trabalha ao
    modo do RAL tambem possa usa-lo, entao o metodo entra por um helper em vez
    de amarrar a propriedade a casca. Quem aplica e o dataset ligado ao cache,
    e nao a conexao - por isso funciona para qualquer uma. }
  TRALDBConnectionRDW = class helper for TRALDBConnection
  public
    procedure ApplyUpdates(ACache: TRALRESTDWMassiveCache; var AError: Boolean;
                           var AMessage: string); overload;
  end;

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
    FBinaryCompatibleMode: boolean;
    FRequestTimeout: IntegerRAL;
    FWaiting: boolean;
    { Quantas alteracoes esperam ApplyUpdates. O RAL guarda o SQL pendente num
      TRALDBSQLCache privado e deixa o CachedUpdates do FireDAC desligado,
      entao nem ChangeCount nem a lista dele servem de fora. }
    FPendentes: IntegerRAL;
    FResponseDone: boolean;
    FLastError: StringRAL;
    FMasterFields: StringRAL;
    FAutoRefreshOnFilterChanged: boolean;
    FAutoSortOnOpen: boolean;
    FBinaryRequest: boolean;
    FDataCache: boolean;
    FDatapacks: IntegerRAL;
    FMassiveType: TRALRESTDWMassiveType;
    FMasterCascadeDelete: boolean;
    FSequenceField: StringRAL;
    FSequenceName: StringRAL;
    FSortCaseSens: TRALRESTDWSortCaseSens;
    FSortFields: StringRAL;
    FSortOrder: TRALRESTDWSortOrder;
    FMassiveCache: TRALRESTDWMassiveCache;
    FMasterSource: TDataSource;
    FOnGetDataError: TRALRESTDWDataError;
    FOnErrorUser: TRALDBTableOnError;

    { SortFields + SortOrder + SortCaseSens viram o IndexFieldNames do memtable,
      que e onde o RAL guarda ordenacao. }
    procedure AplicarOrdenacao;
    procedure SetMassiveCache(AValue: TRALRESTDWMassiveCache);
    /// repassados ao MassiveCache, que nao enxerga este pacote
    function ContarPendentes: IntegerRAL;
    procedure AplicarPendentes(var AError: Boolean; var AMessage: string);
    procedure SetSortFields(const AValue: StringRAL);
    procedure SetSortOrder(AValue: TRALRESTDWSortOrder);
    procedure SetSortCaseSens(AValue: TRALRESTDWSortCaseSens);
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

    procedure ApplyUpdates; reintroduce; overload;
    { A forma do RDW: devolve False e a mensagem em vez de levantar excecao. }
    function ApplyUpdates(var AError: string): Boolean; reintroduce; overload;
    { Quantas alteracoes esperam para ser enviadas. No RDW vinha do buffer
      massivo; aqui e o cache do proprio dataset, que e onde elas estao. }
    function MassiveCount: IntegerRAL;
    { Um resumo do que esta pendente, para diagnostico - nao e o formato que
      viaja. O lote do RAL vai binario pelo TRALDBSQLCache, e nao ha JSON
      equivalente ao do RDW para devolver aqui. }
    function MassiveToJSON: StringRAL;
    procedure ExecSQL; reintroduce; overload;
    { A forma do RDW: devolve False e a mensagem em vez de levantar excecao.
      Respeita o RaiseErrors do componente - com ele desligado o erro ja vinha
      por aqui de qualquer jeito. }
    function ExecSQL(var AError: string): Boolean; reintroduce; overload;
    /// Fecha e reabre, refazendo a consulta no servidor
    procedure RefreshData;
    /// Copia os campos do master para os params de mesmo nome
    procedure ApplyMasterParams;

    { Enche o dataset com um JSON, sem servidor nenhum - o mesmo OpenJson do
      TRESTDWClientSQL. Aceita um array de objetos ou um objeto so, e cria os
      campos a partir das chaves do primeiro elemento quando o dataset ainda
      nao tem estrutura.

      E o que faz um cliente REST puro continuar funcionando: consulta uma API
      qualquer com Get e joga a resposta aqui. }
    procedure OpenJson(const AJson: StringRAL);
  published
    /// A conexao com o TRALDBModule do servidor - o DataBase do RDW
    property DataBase: TRALDBConnection read GetDataBase write SetDataBase;

    { --- ordenacao: vira o IndexFieldNames do memtable --- }
    { O cache de alteracoes. No RAL ele ja e o do proprio dataset, entao apontar
      o componente so serve para o codigo do RDW continuar consultando
      MassiveCount e mandando ApplyUpdates por ele. }
    property MassiveCache: TRALRESTDWMassiveCache read FMassiveCache
      write SetMassiveCache;
    property SortFields: StringRAL read FSortFields write SetSortFields;
    property SortOrder: TRALRESTDWSortOrder read FSortOrder write SetSortOrder
      default soAsc;
    property SortCaseSens: TRALRESTDWSortCaseSens read FSortCaseSens
      write SetSortCaseSens default scYes;
    /// Aplica a ordenacao sozinho depois de cada abertura
    property AutoSortOnOpen: boolean read FAutoSortOnOpen write FAutoSortOnOpen
      default True;

    { --- aceitos e inertes ---
      Existem para o formulario abrir e para o codigo que os le continuar
      compilando. Cada um diz ao lado por que nao faz nada; quem avisa em cima
      do projeto e o conversor. }
    property AutoRefreshOnFilterChanged: boolean read FAutoRefreshOnFilterChanged
      write FAutoRefreshOnFilterChanged default False;
      // inerte: o filtro do RAL e local, nao refaz a consulta no servidor
    property BinaryRequest: boolean read FBinaryRequest write FBinaryRequest
      default True;
      // inerte: o dataset do RAL ja viaja binario, pelo TRALStorageBIN
    property DataCache: boolean read FDataCache write FDataCache default False;
      // inerte: nao ha cache de resultado entre aberturas
    property Datapacks: IntegerRAL read FDatapacks write FDatapacks default -1;
      // inerte: o RAL traz o resultado inteiro, sem paginacao por pacote
    property MassiveType: TRALRESTDWMassiveType read FMassiveType
      write FMassiveType default mtMassiveCache;
      // inerte: o buffer massivo do RDW nao tem equivalente (ver o LEIAME)
    property MasterCascadeDelete: boolean read FMasterCascadeDelete
      write FMasterCascadeDelete default False;
      // inerte: cascata quem resolve e o banco, pela constraint
    property SequenceName: StringRAL read FSequenceName write FSequenceName;
      // inerte: o RAL nao busca generator antes do insert
    property SequenceField: StringRAL read FSequenceField write FSequenceField;
      // inerte: idem; use um trigger ou um campo auto-incremento
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
    property BinaryCompatibleMode: boolean read FBinaryCompatibleMode
      write FBinaryCompatibleMode default False;
      // inerte: o formato binario do RAL e um so, sem modo de compatibilidade
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

{ TRALDBConnectionRDW }

procedure TRALDBConnectionRDW.ApplyUpdates(ACache: TRALRESTDWMassiveCache;
  var AError: Boolean; var AMessage: string);
begin
  if ACache = nil then
  begin
    AError := True;
    AMessage := 'ApplyUpdates sem MassiveCache';
    Exit;
  end;

  ACache.Aplicar(AError, AMessage);
end;

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

  FSortOrder := soAsc;
  FSortCaseSens := scYes;
  FAutoSortOnOpen := True;
  FBinaryRequest := True;
  FDatapacks := -1;
  FMassiveType := mtMassiveCache;
  FPendentes := 0;

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

{ SortFields e uma lista separada por ponto-e-virgula, igual nos dois lados; o
  que muda e como cada base marca direcao e caixa. No FireDAC os modificadores
  vao no proprio IndexFieldNames (:D e :C); o TBufDataset do FPC nao os tem, e
  ali a ordenacao sai sempre ascendente e sensivel a caixa. }
procedure TRALRESTDWClientSQL.SetMassiveCache(AValue: TRALRESTDWMassiveCache);
begin
  if FMassiveCache = AValue then
    Exit;

  if FMassiveCache <> nil then
    FMassiveCache.Desligar(Self);

  FMassiveCache := AValue;

  if FMassiveCache <> nil then
    FMassiveCache.Ligar(Self, {$IFDEF FPC}@{$ENDIF}ContarPendentes,
                        {$IFDEF FPC}@{$ENDIF}AplicarPendentes);
end;

function TRALRESTDWClientSQL.ContarPendentes: IntegerRAL;
begin
  Result := FPendentes;
end;

procedure TRALRESTDWClientSQL.AplicarPendentes(var AError: Boolean;
  var AMessage: string);
begin
  AError := False;
  AMessage := '';
  try
    Self.ApplyUpdates();
  except
    on E: Exception do
    begin
      AError := True;
      AMessage := E.Message;
    end;
  end;
end;

procedure TRALRESTDWClientSQL.AplicarOrdenacao;
var
  vCampos: TStringList;
  vInt1: IntegerRAL;
  vNome: StringRAL;
begin
  if not Active then
    Exit;

  if Trim(FSortFields) = '' then
  begin
    IndexFieldNames := '';
    Exit;
  end;

  vCampos := TStringList.Create;
  try
    vCampos.StrictDelimiter := True;
    vCampos.Delimiter := ';';
    vCampos.DelimitedText := FSortFields;

    vNome := '';
    for vInt1 := 0 to vCampos.Count - 1 do
    begin
      if Trim(vCampos[vInt1]) = '' then
        Continue;

      if vNome <> '' then
        vNome := vNome + ';';
      vNome := vNome + Trim(vCampos[vInt1]);

      {$IFNDEF FPC}
      if FSortOrder = soDesc then
        vNome := vNome + ':D';
      if FSortCaseSens = scNo then
        vNome := vNome + ':C';
      {$ENDIF}
    end;

    IndexFieldNames := vNome;
  finally
    FreeAndNil(vCampos);
  end;
end;

procedure TRALRESTDWClientSQL.SetSortFields(const AValue: StringRAL);
begin
  if FSortFields = AValue then
    Exit;

  FSortFields := AValue;
  if not (csLoading in ComponentState) then
    AplicarOrdenacao;
end;

procedure TRALRESTDWClientSQL.SetSortOrder(AValue: TRALRESTDWSortOrder);
begin
  if FSortOrder = AValue then
    Exit;

  FSortOrder := AValue;
  if not (csLoading in ComponentState) then
    AplicarOrdenacao;
end;

procedure TRALRESTDWClientSQL.SetSortCaseSens(AValue: TRALRESTDWSortCaseSens);
begin
  if FSortCaseSens = AValue then
    Exit;

  FSortCaseSens := AValue;
  if not (csLoading in ComponentState) then
    AplicarOrdenacao;
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

function TRALRESTDWClientSQL.ApplyUpdates(var AError: string): Boolean;
begin
  AError := '';
  Result := True;
  try
    Self.ApplyUpdates();
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

function TRALRESTDWClientSQL.MassiveCount: IntegerRAL;
begin
  Result := ContarPendentes;
end;

function TRALRESTDWClientSQL.MassiveToJSON: StringRAL;
begin
  Result := StringRAL(Format('{"table":"%s","pending":%d}',
                             [GetUpdateTableName, ContarPendentes]));
end;

function TRALRESTDWClientSQL.ExecSQL(var AError: string): Boolean;
begin
  AError := '';
  Result := True;
  try
    Self.ExecSQL();
  except
    on E: Exception do
    begin
      AError := E.Message;
      Result := False;
    end;
  end;
end;

procedure TRALRESTDWClientSQL.OpenJson(const AJson: StringRAL);
var
  vRaiz, vItem: TRALJSONValue;
  vObjeto: TRALJSONObject;
  vLista: TRALJSONArray;
  vInt1, vInt2, vTotal: IntegerRAL;
  vNome: StringRAL;
  vCampo: TField;
  vValor: TRALJSONValue;
  vInsertAntes: StringRAL;
begin
  Close;

  { Duas coisas do RAL atrapalham um dataset puramente local, que e o que o
    OpenJson e: o JSON veio de uma API qualquer e nao ha servidor nenhum.

    A primeira da para contornar: o InternalPost do RAL monta o SQL de insert
    em toda gravacao e pede a conexao para isso. Um InsertSQL qualquer o faz
    tomar o caminho que nao consulta a conexao; o que ele cacheia com isso sai
    no proximo Close (o SetActive(False) do RAL limpa o cache) e nunca e
    enviado, porque ApplyUpdates so envia quando ha alteracao contada aqui - e
    o contador volta a zero no fim.

    A segunda nao da: TRALDBFDMemTable.SetActive recusa abrir sem conexao, e
    abrir e o que CreateDataSet faz. Sem mexer no PascalRAL nao ha caminho
    local - ver o aviso logo abaixo. }
  vInsertAntes := UpdateSQL.InsertSQL.Text;
  UpdateSQL.InsertSQL.Text := '-- OpenJson';
  { nil antes do try: o finally libera, e ParseJSON pode levantar }
  vRaiz := nil;
  try
    vRaiz := TRALJSON.ParseJSON(AJson);
    if vRaiz = nil then
      raise ERALRESTDWClientSQL.Create('OpenJson: conteudo nao e um JSON valido');
    { um objeto solto vale como uma linha so - e o que APIs de consulta por
      chave costumam devolver, e o caso da demo de CNPJ }
    vLista := nil;
    if vRaiz is TRALJSONArray then
      vLista := TRALJSONArray(vRaiz);

    if (vLista <> nil) and (vLista.Count = 0) then
    begin
      if FieldDefs.Count > 0 then
        CreateDataSet;
      Exit;
    end;

    if vLista <> nil then
      vItem := vLista.Get(0)
    else
      vItem := vRaiz;

    if not (vItem is TRALJSONObject) then
      raise ERALRESTDWClientSQL.Create('OpenJson: esperado objeto ou array de objetos');

    { sem estrutura definida, os campos saem das chaves do primeiro elemento.
      Tudo entra como texto largo de proposito: adivinhar o tipo por uma linha
      erra na segunda, e o dataset e so o transporte para a tela. }
    if FieldDefs.Count = 0 then
    begin
      vObjeto := TRALJSONObject(vItem);
      for vInt1 := 0 to vObjeto.Count - 1 do
        FieldDefs.Add(string(vObjeto.GetName(vInt1)), ftString, 4096);
    end;

    { Sem DataBase o RAL diz "Connection not set", que nao ajuda quem so
      queria ler um JSON; com DataBase ele vai ao servidor e volta 404. Das
      duas, nenhuma e o que OpenJson quer. Nomear o motivo e o que da para
      fazer daqui - a correcao e uma linha no PascalRAL. }
    raise ERALRESTDWClientSQL.Create(
      'OpenJson depende de abrir o dataset sem servidor, e o ' +
      'TRALDBFDMemTable do PascalRAL nao permite: o SetActive dele levanta ' +
      'quando RALConnection e nil e vai buscar no servidor quando nao e. ' +
      'Falta ao RAL, no ramo de conexao nula, chamar o inherited em vez de ' +
      'levantar.');

    CreateDataSet;

    if vLista = nil then
      vTotal := 1
    else
      vTotal := vLista.Count;

    for vInt1 := 0 to vTotal - 1 do
    begin
      if vLista <> nil then
        vItem := vLista.Get(vInt1)
      else
        vItem := vRaiz;

      if not (vItem is TRALJSONObject) then
        Continue;

      vObjeto := TRALJSONObject(vItem);
      Append;
      try
        for vInt2 := 0 to vObjeto.Count - 1 do
        begin
          vNome := vObjeto.GetName(vInt2);
          vCampo := FindField(string(vNome));
          if vCampo = nil then
            Continue;

          vValor := vObjeto.Get(vInt2);
          if (vValor = nil) or vValor.IsNull then
            vCampo.Clear
          else
            vCampo.AsString := string(vValor.AsString);
        end;
        Post;
      except
        Cancel;
        raise;
      end;
    end;

    First;
  finally
    FreeAndNil(vRaiz);
    UpdateSQL.InsertSQL.Text := vInsertAntes;
    FPendentes := 0;
  end;
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
  Inc(FPendentes);

  if CommitOnChange and (not FApplying) then
    Self.ApplyUpdates();
end;

procedure TRALRESTDWClientSQL.InternalDelete;
begin
  inherited InternalDelete;
  Inc(FPendentes);

  if CommitOnChange and (not FApplying) then
    Self.ApplyUpdates();
end;

procedure TRALRESTDWClientSQL.ExecSQL;
begin
  FResponseDone := False;
  inherited ExecSQL;

  { Destes tres, so o Open e assincrono: o RAL despacha ExecSQL e ApplyUpdates
    com ebSingleThread, e o callback ja rodou quando o inherited retorna. Como
    nada mais chega pela fila do Synchronize, a espera ia ate o timeout - eram
    trinta segundos de janela travada a cada Execute, com o comando ja
    executado. O WaitResponse continua sendo chamado porque e ele quem levanta
    o erro guardado, no contexto de quem chamou. }
  FResponseDone := True;
  if not FThreadRequest then
    WaitResponse(False);
end;

procedure TRALRESTDWClientSQL.ApplyUpdates;
begin
  if FApplying then
    Exit;

  { A edicao aberta entra junto. Numa grid o registro fica em dsEdit ate
    alguem mudar de linha, e o botao de aplicar do projeto chama ApplyUpdates
    direto: sem este Post a alteracao que esta na tela nunca virou pendencia,
    e o proximo Open a devolvia como estava. E o que o RDW faz. }
  if State in [dsEdit, dsInsert] then
    Post;

  { Sem nada pendente nao se chama o RAL: ele nao trata cache vazio e quebra
    com violacao de acesso la dentro. No RDW aplicar sem alteracao e no-op, e
    e isso que o codigo migrado espera. }
  if (not Active) or (FPendentes = 0) then
    Exit;

  FApplying := True;
  try
    FResponseDone := False;
    inherited ApplyUpdates;

    { sincrono no RAL, como o ExecSQL - ver o comentario la }
    FResponseDone := True;
    if not FThreadRequest then
      WaitResponse(False);
  finally
    FApplying := False;
  end;
  FPendentes := 0;

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
