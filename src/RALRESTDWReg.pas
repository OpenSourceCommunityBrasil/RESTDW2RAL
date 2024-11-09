unit RALRESTDWReg;

interface

uses
  {$IFDEF FPC}
    LResources, PropEdits, ComponentEditors,
  {$ELSE}
    DesignEditors, DesignIntf,
  {$ENDIF}
  Classes, SysUtils,
  RALRESTDWModule, RALRESTDWServerEvents, RALRESTDWClientEvents, RALTypes;

type
  { TRALRESTDWServerEventsList }

  TRALRESTDWServerEventsList = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  { TRALDBZMemTableEditor }

  TRALRESTDWClientEventsMenu = Class(TComponentEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(AIndex : Integer): string; override;
    procedure ExecuteVerb(AIndex : Integer); override;
  end;


procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RAL - RDWModule', [TRALRESTDWServerEvents]);
  RegisterComponents('RAL - RDWModule', [TRALRESTDWClientEvents]);
  RegisterComponents('RAL - Modules', [TRALRESTDWModule]);

  RegisterComponentEditor(TRALRESTDWClientEvents, TRALRESTDWClientEventsMenu);
  RegisterPropertyEditor(TypeInfo(StringRAL), TRALRESTDWClientEvents, 'ServerEventName', TRALRESTDWServerEventsList);
end;



{ TRALRESTServerEventsList }

function TRALRESTDWServerEventsList.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList];
end;

procedure TRALRESTDWServerEventsList.GetValues(Proc: TGetStrProc);
var
  vClient: TRALRESTDWClientEvents;
  vList: TStringList;
  vInt1: IntegerRAL;
begin
  vClient := TRALRESTDWClientEvents(GetComponent(0));
  if vClient <> nil then begin
    vList := TStringList.Create;
    try
      vList.LineBreak := '|';
      vList.Text := vClient.GetServerEvents;

      for vInt1 := 0 to Pred(vList.Count) do
        Proc(vList.Strings[vInt1]);
    finally
      FreeAndNil(vList);
    end;
  end;
end;

{ TRALRESTDWClientEventsMenu }

function TRALRESTDWClientEventsMenu.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TRALRESTDWClientEventsMenu.GetVerb(AIndex: Integer): string;
begin
  case AIndex of
    0 : Result := 'Get Events';
  end;
end;

procedure TRALRESTDWClientEventsMenu.ExecuteVerb(AIndex: Integer);
var
  vClient: TRALRESTDWClientEvents;
  vStream: TStream;
begin
  case AIndex of
    0 : begin
      vClient := TRALRESTDWClientEvents(GetComponent{$IFNDEF FPC}(0){$ENDIF});
      if vClient <> nil then
      begin
        vStream := vClient.GetEvents;
        try
          vClient.SetEvents(vStream);
        finally
          FreeAndNil(vStream);
        end;
      end;
    end;
  end;
end;

{$IFDEF FPC}
initialization
{$I RALRESTDW.lrs}
{$ENDIF}

end.
