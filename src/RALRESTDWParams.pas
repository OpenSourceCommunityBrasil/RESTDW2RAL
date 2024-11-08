unit RALRESTDWParams;

interface

uses
  Classes, SysUtils;

type
  TRALRESTDWParams = class(TObject)
  private
    FParams : TList;
  protected
    procedure ClearParams;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TRALRESTDWParams }

procedure TRALRESTDWParams.ClearParams;
begin
  while FParams.Count > 0 do
  begin

  end;
end;

constructor TRALRESTDWParams.Create;
begin
  inherited;
  FParams := TList.Create;
end;

destructor TRALRESTDWParams.Destroy;
begin
  ClearParams;
  inherited;
end;

end.

