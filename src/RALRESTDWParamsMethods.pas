/// Design-time declaration of an event's parameters.
///
/// This is the collection you fill in the Object Inspector; at request time it
/// is cloned into the runtime TRALRESTDWParams the handler receives.
unit RALRESTDWParamsMethods;

interface

uses
  Classes, SysUtils,
  RALTypes, RALRESTDWParams, RALRESTDWTypes;

type
  { TRALRESTDWParamMethod }

  TRALRESTDWParamMethod = class(TCollectionItem)
  private
    FTypeObject: TRALRESTDWTypeObject;
    FObjectDirection: TRALRESTDWObjectDirection;
    FObjectValue: TRALRESTDWObjectValue;
    FDataMode: TRALRESTDWDataMode;
    FAlias: StringRAL;
    FDefaultValue: StringRAL;
    FParamName: StringRAL;
    FEncoded: Boolean;
  protected
    function GetDisplayName: string; override;
    procedure SetDisplayName(const AValue: string); override;

    procedure AssignTo(ADest: TPersistent); override;
  public
    constructor Create(ACollection: TCollection); override;

    function GetNamePath: string; override;
  published
    property TypeObject: TRALRESTDWTypeObject read FTypeObject write FTypeObject;
    property ObjectDirection: TRALRESTDWObjectDirection read FObjectDirection write FObjectDirection;
    property ObjectValue: TRALRESTDWObjectValue read FObjectValue write FObjectValue;
    property DataMode: TRALRESTDWDataMode read FDataMode write FDataMode;
    property Alias: StringRAL read FAlias write FAlias;
    property DefaultValue: StringRAL read FDefaultValue write FDefaultValue;
    property ParamName: StringRAL read FParamName write FParamName;
    property Encoded: Boolean read FEncoded write FEncoded;
  end;

  { TRALRESTDWParamsMethods }

  TRALRESTDWParamsMethods = class(TOwnedCollection)
  private
    function GetParamByName(AName: StringRAL): TRALRESTDWParamMethod;
    function GetParam(AIndex: IntegerRAL): TRALRESTDWParamMethod;
  public
    constructor Create(AOwner: TPersistent);

    /// Declares a param in code, the RDW AddParam shape
    function AddParam(const AParamName: StringRAL;
                      AObjectValue: TRALRESTDWObjectValue = ovString;
                      AObjectDirection: TRALRESTDWObjectDirection = odINOUT;
                      const ADefaultValue: StringRAL = '';
                      ATypeObject: TRALRESTDWTypeObject = toParam): TRALRESTDWParamMethod;

    /// Clones every declared param into the runtime container
    procedure CreateParams(AParam : TRALRESTDWParams);
    /// True when AName was declared here (used by OnlyPreDefinedParams)
    function Declared(const AName: StringRAL): boolean;

    property Items[AIndex: IntegerRAL]: TRALRESTDWParamMethod read GetParam; default;
    property ParamByName[AName: StringRAL]: TRALRESTDWParamMethod Read GetParamByName;
  end;

implementation

{ TRALRESTDWParamsMethods }

constructor TRALRESTDWParamsMethods.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TRALRESTDWParamMethod);
end;

function TRALRESTDWParamsMethods.AddParam(const AParamName: StringRAL;
  AObjectValue: TRALRESTDWObjectValue; AObjectDirection: TRALRESTDWObjectDirection;
  const ADefaultValue: StringRAL; ATypeObject: TRALRESTDWTypeObject): TRALRESTDWParamMethod;
begin
  Result := TRALRESTDWParamMethod(Add);
  Result.ParamName := AParamName;
  Result.ObjectValue := AObjectValue;
  Result.ObjectDirection := AObjectDirection;
  Result.DefaultValue := ADefaultValue;
  Result.TypeObject := ATypeObject;
end;

procedure TRALRESTDWParamsMethods.CreateParams(AParam: TRALRESTDWParams);
var
  vInt1: IntegerRAL;
begin
  for vInt1 := 0 to Pred(Count) do
    AParam.NewParam.Assign(TRALRESTDWParamMethod(inherited Items[vInt1]));
end;

function TRALRESTDWParamsMethods.Declared(const AName: StringRAL): boolean;
begin
  Result := GetParamByName(AName) <> nil;
end;

function TRALRESTDWParamsMethods.GetParam(AIndex: IntegerRAL): TRALRESTDWParamMethod;
begin
  Result := nil;
  if (AIndex >= 0) and (AIndex < Count) then
    Result := TRALRESTDWParamMethod(inherited Items[AIndex]);
end;

function TRALRESTDWParamsMethods.GetParamByName(AName: StringRAL): TRALRESTDWParamMethod;
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWParamMethod;
begin
  Result := nil;
  for vInt1 := 0 to Pred(Count) do
  begin
    vParam := TRALRESTDWParamMethod(inherited Items[vInt1]);
    if (SameText(vParam.ParamName, AName)) or
       ((vParam.Alias <> '') and (SameText(vParam.Alias, AName))) then
    begin
      Result := vParam;
      Break;
    end;
  end;
end;

{ TRALRESTDWParamMethod }

constructor TRALRESTDWParamMethod.Create(ACollection: TCollection);
begin
  inherited;
  FParamName := 'param' + IntToStr(Index);
  FTypeObject := toParam;
  FObjectDirection := odINOUT;
  FObjectValue := ovString;
  FDataMode := dmRAW;
end;

function TRALRESTDWParamMethod.GetDisplayName: string;
begin
  Result := FParamName;
  inherited;
end;

function TRALRESTDWParamMethod.GetNamePath: string;
var
  vName: StringRAL;
begin
  Result := '';
  if Self = nil then
    Exit;

  vName := Collection.GetNamePath;
  Result := vName + '_' + FParamName;
end;

procedure TRALRESTDWParamMethod.SetDisplayName(const AValue: string);
begin
  if Trim(AValue) <> '' then
    FParamName := AValue;
  inherited;
end;

procedure TRALRESTDWParamMethod.AssignTo(ADest: TPersistent);
begin
  if ADest.InheritsFrom(TRALRESTDWJSONParam) then
  begin
    with ADest as TRALRESTDWJSONParam do
    begin
      TypeObject := Self.TypeObject;
      ObjectDirection := Self.ObjectDirection;
      ObjectValue := Self.ObjectValue;
      DataMode := Self.DataMode;
      ParamName := Self.ParamName;
      Alias := Self.Alias;
      Encoded := Self.Encoded;
      { SetValue instead of AsString: every SetAs* stamps its own type, so the
        old code flattened the declared ObjectValue to ovString right here }
      SetValue(Self.DefaultValue);
    end;
  end
  else if ADest.InheritsFrom(TRALRESTDWParamMethod) then
  begin
    with ADest as TRALRESTDWParamMethod do
    begin
      TypeObject := Self.TypeObject;
      ObjectDirection := Self.ObjectDirection;
      ObjectValue := Self.ObjectValue;
      DataMode := Self.DataMode;
      ParamName := Self.ParamName;
      Alias := Self.Alias;
      DefaultValue := Self.DefaultValue;
      Encoded := Self.Encoded;
    end;
  end
  else
  begin
    inherited AssignTo(ADest);
  end;
end;

end.
