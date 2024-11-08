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
  published
    property TypeObject: TRALRESTDWTypeObject read FTypeObject write FTypeObject;
    property ObjectDirection: TRALRESTDWObjectDirection read FObjectDirection write FObjectDirection;
    property ObjectValue: TRALRESTDWObjectValue read FObjectValue write FObjectValue;
    property Alias: StringRAL read FAlias write FAlias;
    property DefaultValue: StringRAL read FDefaultValue write FDefaultValue;
    property ParamName: StringRAL read FParamName write FParamName;
    property Encoded: Boolean read FEncoded write FEncoded;
  end;

  { TRALRESTDWParamsMethods }

  TRALRESTDWParamsMethods = class(TOwnedCollection)
  private
    function GetParamByName(AName: StringRAL): TRALRESTDWParamMethod;
  public
    constructor Create(AOwner: TPersistent);

    procedure CreateParams(AParam : TRALRESTDWParams);

    property ParamByName[AName: StringRAL]: TRALRESTDWParamMethod Read GetParamByName;
  end;

implementation

{ TRALRESTDWParamsMethods }

constructor TRALRESTDWParamsMethods.Create(AOwner: TPersistent);
begin
  inherited Create(AOwner, TRALRESTDWParamMethod);
end;

procedure TRALRESTDWParamsMethods.CreateParams(AParam: TRALRESTDWParams);
var
  vInt1: IntegerRAL;
  vParamMethod: TRALRESTDWParamMethod;
begin
  for vInt1 := 0 to Pred(Count) do
  begin
    vParamMethod := TRALRESTDWParamMethod(Items[vInt1]);
    AParam.NewParam.Assign(vParamMethod);
  end;
end;

function TRALRESTDWParamsMethods.GetParamByName(AName: StringRAL): TRALRESTDWParamMethod;
var
  vInt1: IntegerRAL;
  vParam: TRALRESTDWParamMethod;
begin
  Result := nil;
  for vInt1 := 0 to Pred(Count) do
  begin
    vParam := TRALRESTDWParamMethod(Items[vInt1]);
    if SameText(vParam.ParamName, AName) then
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
end;

function TRALRESTDWParamMethod.GetDisplayName: string;
begin
  Result := FParamName;
  inherited;
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
      ParamName := Self.ParamName;
      Alias := Self.Alias;
      Value := Self.DefaultValue;
    end;
  end
  else if ADest.InheritsFrom(TRALRESTDWParamMethod) then
  begin
    with ADest as TRALRESTDWParamMethod do
    begin
      TypeObject := Self.TypeObject;
      ObjectDirection := Self.ObjectDirection;
      ObjectValue := Self.ObjectValue;
      ParamName := Self.ParamName;
      Alias := Self.Alias;
      DefaultValue := Self.DefaultValue;
    end;
  end;
end;

end.

