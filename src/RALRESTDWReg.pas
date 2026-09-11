/// Design-time registration: palette, component editors and property editors.
unit RALRESTDWReg;

interface

uses
  {$IFDEF FPC}
    LResources, PropEdits, ComponentEditors,
  {$ELSE}
    DesignEditors, DesignIntf,
  {$ENDIF}
  Classes, SysUtils,
  RALRESTDWModule, RALRESTDWServerEvents, RALRESTDWClientEvents,
  RALRESTDWClient, RALTypes;

type
  { TRALRESTDWServerEventsList }

  /// Fills ServerEventName by asking the server which components it exposes
  TRALRESTDWServerEventsList = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

  { TRALRESTDWMenu }

  /// Shared base: marks the form as modified, which neither editor used to do
  TRALRESTDWMenu = Class(TComponentEditor)
  protected
    procedure MarkModified;
  end;

  { TRALRESTDWClientEventsMenu }

  TRALRESTDWClientEventsMenu = Class(TRALRESTDWMenu)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(AIndex : Integer): string; override;
    procedure ExecuteVerb(AIndex : Integer); override;
  end;

  { TRALRESTDWModulesMenu }

  TRALRESTDWModulesMenu = Class(TRALRESTDWMenu)
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
  RegisterComponents('RAL - RDWModule', [TRALRESTDWClient]);
  RegisterComponents('RAL - Modules', [TRALRESTDWModule]);

  RegisterComponentEditor(TRALRESTDWModule, TRALRESTDWModulesMenu);
  RegisterComponentEditor(TRALRESTDWClientEvents, TRALRESTDWClientEventsMenu);
  RegisterPropertyEditor(TypeInfo(StringRAL), TRALRESTDWClientEvents,
                         'ServerEventName', TRALRESTDWServerEventsList);
end;

{ TRALRESTDWServerEventsList }

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

{ TRALRESTDWMenu }

procedure TRALRESTDWMenu.MarkModified;
begin
  {$IFDEF FPC}
    Modified;
  {$ELSE}
    if Designer <> nil then
      Designer.Modified;
  {$ENDIF}
end;

{ TRALRESTDWClientEventsMenu }

function TRALRESTDWClientEventsMenu.GetVerbCount: Integer;
begin
  Result := 2;
end;

function TRALRESTDWClientEventsMenu.GetVerb(AIndex: Integer): string;
begin
  Result := '';
  case AIndex of
    0 : Result := 'Get Events';
    1 : Result := 'Clear Events';
  end;
end;

procedure TRALRESTDWClientEventsMenu.ExecuteVerb(AIndex: Integer);
var
  vClient: TRALRESTDWClientEvents;
begin
  vClient := TRALRESTDWClientEvents(GetComponent);
  if vClient = nil then
    Exit;

  case AIndex of
    0 : begin
          vClient.FetchEvents;
          MarkModified;
        end;
    1 : begin
          vClient.ClearEvents;
          MarkModified;
        end;
  end;
end;

{ TRALRESTDWModulesMenu }

function TRALRESTDWModulesMenu.GetVerbCount: Integer;
begin
  Result := 3;
end;

function TRALRESTDWModulesMenu.GetVerb(AIndex: Integer): string;
begin
  Result := '';
  case AIndex of
    0 : Result := 'Refresh Routes';
    1 : Result := 'Export Events';
    2 : Result := 'Import Events';
  end;
end;

procedure TRALRESTDWModulesMenu.ExecuteVerb(AIndex: Integer);
var
  vModule: TRALRESTDWModule;
begin
  vModule := TRALRESTDWModule(GetComponent);
  if vModule = nil then
    Exit;

  case AIndex of
    0 : begin
          { le a classe de ClassModule e republica as rotas. E o mesmo que o
            modulo faz sozinho com AutoRoutes ligado - o verbo existe para
            conferir o resultado sem rodar o servidor }
          if Trim(vModule.ClassModule) = '' then
            raise Exception.Create('ClassModule nao informado');

          vModule.RefreshRoutes;
          if vModule.Routes.Count = 0 then
            raise Exception.CreateFmt(
              'Nenhum evento encontrado em "%s". A classe esta registrada com ' +
              'RegisterClass e a unit dela esta no uses do projeto?',
              [vModule.ClassModule]);

          MarkModified;
        end;
    1 : begin
          if Trim(vModule.FileExporter) = '' then
            raise Exception.Create('FileExporter nao informado');

          vModule.ExportToFile;
        end;
    2 : begin
          if not FileExists(vModule.FileExporter) then
            raise Exception.CreateFmt('Arquivo de eventos nao encontrado: "%s"',
                                      [vModule.FileExporter]);

          vModule.ImportFromFile;
          MarkModified;
        end;
  end;
end;

{$IFDEF FPC}
initialization
{$I RALRESTDW.lrs}
{$ENDIF}

end.
