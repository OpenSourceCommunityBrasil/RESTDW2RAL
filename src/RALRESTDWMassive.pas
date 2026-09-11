/// RDW's Massive types, so the handlers that mention them keep compiling.
///
/// **Read this before counting on it.** RDW's *massive* is two things, and only
/// one of them survives the move:
///
/// - **Batching the changes and applying them in one round trip** - that RAL
///   does, and it is what `TRALRESTDWClientSQL` already uses:
///   `CacheUpdateRecords` holds every Post and Delete, `ApplyUpdates` sends the
///   lot, and the server applies them in a single transaction. A project whose
///   massive was just "write a lot at once" needs nothing else.
///
/// - **`OnMassiveProcess`, the per-record hook the server fires before applying
///   each change** - that one has nowhere to live. The apply loop is inside
///   PascalRAL (`TRALDBModule`), this project does not change RAL, and there is
///   no hook to hang it on. **The event is declared and never fired.**
///
/// The types exist so a migrated unit compiles; what fills the buffer does not
/// exist. The converter reports every `OnMassive*` it finds for exactly this
/// reason: code that assigned a sequence value or vetoed a record in that
/// handler has to move - into a trigger, into the `SQL` itself, or into a
/// `TRALRESTDWServerEvents` event called before `ApplyUpdates`.
unit RALRESTDWMassive;

interface

{$I RALRESTDW.inc}

uses
  Classes, SysUtils, Variants, DB,
  RALTypes,
  RALRESTDWTypes, RALRESTDWParams;

type
  /// Mesmos membros e ordem do TMassiveMode do RDW
  TRALRESTDWMassiveMode = (mmInactive, mmBrowse, mmInsert, mmUpdate, mmDelete,
                           mmExec);
  TRALRESTDWMassiveSQLMode = (msqlQuery, msqlExecute);

  { TRALRESTDWMassiveField }

  /// Um campo dentro do buffer: nome e valor, que e o que os handlers usam
  TRALRESTDWMassiveField = class(TCollectionItem)
  private
    FFieldName: StringRAL;
    FFieldType: TFieldType;
    FModified: Boolean;
    FValue: Variant;

    procedure SetValue(const AValue: Variant);
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    procedure Assign(ASource: TPersistent); override;
  published
    property FieldName: StringRAL read FFieldName write FFieldName;
    property FieldType: TFieldType read FFieldType write FFieldType;
    /// True depois que o handler escreveu no campo
    property Modified: Boolean read FModified write FModified default False;
    property Value: Variant read FValue write SetValue;
  end;

  { TRALRESTDWMassiveFields }

  TRALRESTDWMassiveFields = class(TCollection)
  private
    FOwner: TPersistent;

    function GetItem(AIndex: Integer): TRALRESTDWMassiveField;
    procedure SetItem(AIndex: Integer; AValue: TRALRESTDWMassiveField);
  protected
    function GetOwner: TPersistent; override;
  public
    constructor Create(AOwner: TPersistent);

    function Add: TRALRESTDWMassiveField; reintroduce;
    /// nil quando o campo nao existe - igual ao RDW, e o codigo portado confere
    function FieldByName(const AFieldName: StringRAL): TRALRESTDWMassiveField;

    property Items[AIndex: Integer]: TRALRESTDWMassiveField read GetItem
      write SetItem; default;
  end;

  { TRALRESTDWMassiveDatasetBuffer }

  TRALRESTDWMassiveDatasetBuffer = class(TPersistent)
  private
    FDataexec: TStringList;
    FEncoding: TRALRESTDWEncodeSelect;
    FFields: TRALRESTDWMassiveFields;
    FLastOpen: IntegerRAL;
    FMasterCompFields: StringRAL;
    FMasterCompTag: StringRAL;
    FMassiveMode: TRALRESTDWMassiveMode;
    FMassiveType: TRALRESTDWMassiveType;
    FMyCompTag: StringRAL;
    FOnLoad: Boolean;
    FParams: TRALRESTDWParams;
    FReflectChanges: Boolean;
    FSequenceField: StringRAL;
    FSequenceName: StringRAL;
    FTableName: StringRAL;

    procedure SetDataexec(AValue: TStringList);
    procedure SetFields(AValue: TRALRESTDWMassiveFields);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(ASource: TPersistent); override;
    procedure Clear;
  published
    property TableName: StringRAL read FTableName write FTableName;
    property MassiveMode: TRALRESTDWMassiveMode read FMassiveMode
      write FMassiveMode default mmInactive;
    property MassiveType: TRALRESTDWMassiveType read FMassiveType
      write FMassiveType default mtMassiveCache;
    property Fields: TRALRESTDWMassiveFields read FFields write SetFields;
    property Dataexec: TStringList read FDataexec write SetDataexec;
    property Params: TRALRESTDWParams read FParams;
    property OnLoad: Boolean read FOnLoad write FOnLoad default False;
    property SequenceName: StringRAL read FSequenceName write FSequenceName;
    property SequenceField: StringRAL read FSequenceField write FSequenceField;
    property ReflectChanges: Boolean read FReflectChanges write FReflectChanges
      default False;
    property LastOpen: IntegerRAL read FLastOpen write FLastOpen default 0;
    property Encoding: TRALRESTDWEncodeSelect read FEncoding write FEncoding
      default esUtf8;
    property MyCompTag: StringRAL read FMyCompTag write FMyCompTag;
    property MasterCompTag: StringRAL read FMasterCompTag write FMasterCompTag;
    property MasterCompFields: StringRAL read FMasterCompFields
      write FMasterCompFields;
  end;

  { Mesmas assinaturas do RDW. Nenhum deles e disparado - ver o cabecalho da
    unit; existem para o .dfm abrir e para o metodo continuar compilando. }
  TRALRESTDWMassiveProcess = procedure(var MassiveDataset: TRALRESTDWMassiveDatasetBuffer;
                                       var Ignore: Boolean) of object;
  TRALRESTDWMassiveEvent = procedure(var MassiveDataset: TRALRESTDWMassiveDatasetBuffer) of object;
  TRALRESTDWMassiveLineProcess = procedure(var MassiveDataset: TRALRESTDWMassiveDatasetBuffer;
                                           var Accept: Boolean) of object;

  { TRALRESTDWMassiveCache }

  TRALRESTDWMassiveContar = function: IntegerRAL of object;
  TRALRESTDWMassiveAplicar = procedure(var AError: Boolean;
                                       var AMessage: string) of object;

  { O TRESTDWMassiveCache do RDW acumulava as alteracoes ate o ApplyUpdates. No
    RAL isso ja e o cache do proprio dataset (CacheUpdateRecords + ApplyUpdates),
    entao o componente nao guarda nada: ele aponta para o dataset ligado a ele
    e repassa a contagem e a aplicacao.

    O repasse e por callback, e nao por chamada direta, porque o dataset mora
    no pacote de banco e este componente no de eventos - amarrar um no outro
    obrigaria quem so usa eventos a carregar o FireDAC junto. }
  TRALRESTDWMassiveCache = class(TComponent)
  private
    FMassiveType: TRALRESTDWMassiveType;
    FDataset: TComponent;
    FOnContar: TRALRESTDWMassiveContar;
    FOnAplicar: TRALRESTDWMassiveAplicar;

    function GetMassiveCount: IntegerRAL;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;

    /// Chamado pelo dataset quando ele aponta o MassiveCache para este
    procedure Ligar(ADataset: TComponent; AContar: TRALRESTDWMassiveContar;
                    AAplicar: TRALRESTDWMassiveAplicar);
    procedure Desligar(ADataset: TComponent);
    /// Envia o lote acumulado; e o que o ApplyUpdates do database chama
    procedure Aplicar(var AError: Boolean; var AMessage: string);

    /// Quantas alteracoes esperam para ser enviadas
    property MassiveCount: IntegerRAL read GetMassiveCount;
    property Dataset: TComponent read FDataset;
  published
    property MassiveType: TRALRESTDWMassiveType read FMassiveType
      write FMassiveType default mtMassiveCache;
      // inerte: o modo de acumulo do RAL e sempre o cache do dataset
  end;

implementation

{ TRALRESTDWMassiveField }

constructor TRALRESTDWMassiveField.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FFieldType := ftUnknown;
  FModified := False;
  FValue := Null;
end;

function TRALRESTDWMassiveField.GetDisplayName: string;
begin
  Result := string(FFieldName);
  if Result = '' then
    Result := inherited GetDisplayName;
end;

procedure TRALRESTDWMassiveField.SetValue(const AValue: Variant);
begin
  FValue := AValue;
  FModified := True;
end;

procedure TRALRESTDWMassiveField.Assign(ASource: TPersistent);
begin
  if not (ASource is TRALRESTDWMassiveField) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  FFieldName := TRALRESTDWMassiveField(ASource).FieldName;
  FFieldType := TRALRESTDWMassiveField(ASource).FieldType;
  FModified := TRALRESTDWMassiveField(ASource).Modified;
  FValue := TRALRESTDWMassiveField(ASource).Value;
end;

{ TRALRESTDWMassiveFields }

constructor TRALRESTDWMassiveFields.Create(AOwner: TPersistent);
begin
  inherited Create(TRALRESTDWMassiveField);
  FOwner := AOwner;
end;

function TRALRESTDWMassiveFields.GetOwner: TPersistent;
begin
  Result := FOwner;
end;

function TRALRESTDWMassiveFields.GetItem(AIndex: Integer): TRALRESTDWMassiveField;
begin
  Result := TRALRESTDWMassiveField(inherited Items[AIndex]);
end;

procedure TRALRESTDWMassiveFields.SetItem(AIndex: Integer;
  AValue: TRALRESTDWMassiveField);
begin
  inherited Items[AIndex] := AValue;
end;

function TRALRESTDWMassiveFields.Add: TRALRESTDWMassiveField;
begin
  Result := TRALRESTDWMassiveField(inherited Add);
end;

function TRALRESTDWMassiveFields.FieldByName(
  const AFieldName: StringRAL): TRALRESTDWMassiveField;
var
  vInt1: Integer;
begin
  Result := nil;
  for vInt1 := 0 to Count - 1 do
    if SameText(string(Items[vInt1].FieldName), string(AFieldName)) then
      Exit(Items[vInt1]);
end;

{ TRALRESTDWMassiveDatasetBuffer }

constructor TRALRESTDWMassiveDatasetBuffer.Create;
begin
  inherited Create;
  FFields := TRALRESTDWMassiveFields.Create(Self);
  FDataexec := TStringList.Create;
  FParams := TRALRESTDWParams.Create;
  FMassiveMode := mmInactive;
  FMassiveType := mtMassiveCache;
  FEncoding := esUtf8;
end;

destructor TRALRESTDWMassiveDatasetBuffer.Destroy;
begin
  FreeAndNil(FParams);
  FreeAndNil(FDataexec);
  FreeAndNil(FFields);
  inherited Destroy;
end;

procedure TRALRESTDWMassiveDatasetBuffer.SetFields(AValue: TRALRESTDWMassiveFields);
begin
  FFields.Assign(AValue);
end;

procedure TRALRESTDWMassiveDatasetBuffer.SetDataexec(AValue: TStringList);
begin
  FDataexec.Assign(AValue);
end;

procedure TRALRESTDWMassiveDatasetBuffer.Clear;
begin
  FFields.Clear;
  FDataexec.Clear;
  FTableName := '';
  FMassiveMode := mmInactive;
end;

procedure TRALRESTDWMassiveDatasetBuffer.Assign(ASource: TPersistent);
var
  vSource: TRALRESTDWMassiveDatasetBuffer;
begin
  if not (ASource is TRALRESTDWMassiveDatasetBuffer) then
  begin
    inherited Assign(ASource);
    Exit;
  end;

  vSource := TRALRESTDWMassiveDatasetBuffer(ASource);
  FTableName := vSource.TableName;
  FMassiveMode := vSource.MassiveMode;
  FMassiveType := vSource.MassiveType;
  FOnLoad := vSource.OnLoad;
  FSequenceName := vSource.SequenceName;
  FSequenceField := vSource.SequenceField;
  FReflectChanges := vSource.ReflectChanges;
  FLastOpen := vSource.LastOpen;
  FEncoding := vSource.Encoding;
  FMyCompTag := vSource.MyCompTag;
  FMasterCompTag := vSource.MasterCompTag;
  FMasterCompFields := vSource.MasterCompFields;
  FFields.Assign(vSource.Fields);
  FDataexec.Assign(vSource.Dataexec);
end;

{ TRALRESTDWMassiveCache }

constructor TRALRESTDWMassiveCache.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMassiveType := mtMassiveCache;
end;

procedure TRALRESTDWMassiveCache.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FDataset) then
    Desligar(AComponent);
end;

procedure TRALRESTDWMassiveCache.Ligar(ADataset: TComponent;
  AContar: TRALRESTDWMassiveContar; AAplicar: TRALRESTDWMassiveAplicar);
begin
  if FDataset <> nil then
    FDataset.RemoveFreeNotification(Self);

  FDataset := ADataset;
  FOnContar := AContar;
  FOnAplicar := AAplicar;

  if FDataset <> nil then
    FDataset.FreeNotification(Self);
end;

procedure TRALRESTDWMassiveCache.Desligar(ADataset: TComponent);
begin
  if FDataset <> ADataset then
    Exit;

  FDataset := nil;
  FOnContar := nil;
  FOnAplicar := nil;
end;

function TRALRESTDWMassiveCache.GetMassiveCount: IntegerRAL;
begin
  Result := 0;
  { com parenteses: no ObjFPC o nome do ponteiro de metodo e o ponteiro, e
    nao a chamada - sem eles o FPC nao compila e o Delphi compila calado }
  if Assigned(FOnContar) then
    Result := FOnContar();
end;

procedure TRALRESTDWMassiveCache.Aplicar(var AError: Boolean;
  var AMessage: string);
begin
  AError := False;
  AMessage := '';

  if not Assigned(FOnAplicar) then
  begin
    AError := True;
    AMessage := 'MassiveCache sem dataset ligado';
    Exit;
  end;

  FOnAplicar(AError, AMessage);
end;

end.
