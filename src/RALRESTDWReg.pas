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

  { TRALRESTDWClientEventsMenu }

  TRALRESTDWClientEventsMenu = Class(TComponentEditor)
  protected
    /// marca o form como alterado; sem isso o trabalho do verbo se perde
    procedure MarkModified;
  public
    function GetVerbCount: Integer; override;
    function GetVerb(AIndex : Integer): string; override;
    procedure ExecuteVerb(AIndex : Integer); override;
  end;

  { TRALRESTDWModulesMenu }

  TRALRESTDWModulesMenu = Class(TComponentEditor)
  protected
    /// marca o form como alterado; sem isso o trabalho do verbo se perde
    procedure MarkModified;
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

  RegisterComponentEditor(TRALRESTDWModule, TRALRESTDWModulesMenu);
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
  if vClient = nil then
    Exit;

  vList := TStringList.Create;
  try
    vList.LineBreak := '|';
    try
      vList.Text := vClient.GetServerEvents;
    except
      // servidor fora do ar nao pode virar dialogo de excecao dentro da IDE:
      // a lista fica vazia e o nome continua editavel na mao
      Exit;
    end;

    for vInt1 := 0 to Pred(vList.Count) do
      Proc(vList.Strings[vInt1]);
  finally
    FreeAndNil(vList);
  end;
end;

{ TRALRESTDWClientEventsMenu }

procedure TRALRESTDWClientEventsMenu.MarkModified;
begin
  {$IFDEF FPC}
    Modified;
  {$ELSE}
    if Designer <> nil then
      Designer.Modified;
  {$ENDIF}
end;

function TRALRESTDWClientEventsMenu.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TRALRESTDWClientEventsMenu.GetVerb(AIndex: Integer): string;
begin
  Result := '';
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
      vClient := TRALRESTDWClientEvents(GetComponent);
      if vClient <> nil then
      begin
        vStream := vClient.GetEvents;
        try
          vClient.SetEvents(vStream);
          MarkModified;
        finally
          FreeAndNil(vStream);
        end;
      end;
    end;
  end;
end;

{ TRALRESTDWModulesMenu }

procedure TRALRESTDWModulesMenu.MarkModified;
begin
  {$IFDEF FPC}
    Modified;
  {$ELSE}
    if Designer <> nil then
      Designer.Modified;
  {$ENDIF}
end;

function TRALRESTDWModulesMenu.GetVerbCount: Integer;
begin
  Result := 1;
end;

function TRALRESTDWModulesMenu.GetVerb(AIndex: Integer): string;
begin
  Result := '';
  case AIndex of
    0 : Result := 'Import Events';
  end;
end;

procedure TRALRESTDWModulesMenu.ExecuteVerb(AIndex: Integer);
var
  vModule: TRALRESTDWModule;
begin
  case AIndex of
    0 : begin
      vModule := TRALRESTDWModule(GetComponent);
      if vModule <> nil then
      begin
        if not FileExists(vModule.FileExporter) then
          raise Exception.CreateFmt('Arquivo de eventos nao encontrado: "%s"',
                                    [vModule.FileExporter]);

        vModule.ImportFromFile(vModule.FileExporter);
        MarkModified;
      end;
    end;
  end;
end;

{$IFDEF FPC}
initialization
{$I RALRESTDW.lrs}
{$ENDIF}

end.
