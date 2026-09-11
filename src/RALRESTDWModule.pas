unit RALRESTDWModule;

interface

uses
  Classes, SysUtils,
  RALServer, RALTypes, RALRoutes, RALRequest, RALResponse,
  RALRESTDWTypes, RALConsts, RALRESTDWEvents, RALStream, RALMIMETypes;

type

  { TRALRESTDWModule }

  TRALRESTDWModule = class(TRALModuleRoutes)
  private
    FRDWRoutes : TRALRoutes;
    FClassModule: StringRAL;
    FFileExporter: StringRAL;
  protected
    procedure ReplyRoutes(ARequest: TRALRequest; AResponse: TRALResponse);

    procedure GetEvents(ARequest: TRALRequest; AResponse: TRALResponse);
    procedure GetServerEventsList(ARequest: TRALRequest; AResponse: TRALResponse);

    procedure CreateRoutes;
    procedure ImportFromStream(AStream : TStream);

    /// instancia a classe registrada em ClassModule; nil se nao estiver registrada
    function CreateModuleObject: TComponent;
    /// devolve o ServerEvents de AObject cujo nome completo e AccessTag conferem
    function FindServerEvents(AObject: TComponent;
                              const AName, AAccessTag: StringRAL): TComponent;
    /// liga ReplyRoutes nas rotas dos eventos, fora do caminho da requisicao
    procedure BindRoutes;

    procedure Loaded; override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    function GetListRoutes: TList; override;
    function CanAnswerRoute(ARequest: TRALRequest; AResponse: TRALResponse): TRALRoute; override;

    function ExportToStream : TStream; overload;
    procedure ExportToStream(AStream : TStream); overload;
    procedure ExportToFile(AFile : TFileName = ''); overload;

    procedure ImportFromFile(AFile : TFileName = ''); overload;
  published
    property ClassModule: StringRAL read FClassModule write FClassModule;
    property FileExporter: StringRAL read FFileExporter write FFileExporter;
    property Routes;
  end;

implementation

uses
  RALRESTDWServerEvents, RALRESTDWParams, RALParams;

/// ParamByName devolve nil quando o parametro nao veio na requisicao
function RequestParam(ARequest: TRALRequest; const AName: StringRAL): StringRAL;
var
  vParam: TRALParam;
begin
  Result := '';
  vParam := ARequest.ParamByName(AName);
  if vParam <> nil then
    Result := vParam.AsString;
end;

{ TRALRESTDWModule }

function TRALRESTDWModule.CreateModuleObject: TComponent;
var
  vClass: TComponentClass;
begin
  Result := nil;
  vClass := TComponentClass(GetClass(FClassModule));
  if vClass <> nil then
    { Owner nil de proposito: o servidor atende em varias threads e a lista de
      componentes do Owner nao tem protecao - dois requests simultaneos criando
      e destruindo filhos do modulo corrompiam a lista. O modulo chega ao
      desenvolvedor por TRALRESTDWParams.Module. }
    Result := vClass.Create(nil);
end;

function TRALRESTDWModule.FindServerEvents(AObject: TComponent;
  const AName, AAccessTag: StringRAL): TComponent;
var
  vInt1: IntegerRAL;
  vComp: TComponent;
begin
  Result := nil;
  if AObject = nil then
    Exit;

  for vInt1 := 0 to Pred(AObject.ComponentCount) do
  begin
    vComp := AObject.Components[vInt1];
    if (not vComp.InheritsFrom(TRALRESTDWServerEvents)) or
       (not SameText(Format('%s.%s', [AObject.ClassName, vComp.Name]), AName)) then
      Continue;

    // o nome e unico: achou o componente, so falta liberar ou nao pelo AccessTag
    if TRALRESTDWServerEvents(vComp).AccessTag = AAccessTag then
      Result := vComp;
    Break;
  end;
end;

procedure TRALRESTDWModule.ReplyRoutes(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vObj, vComp: TComponent;
  vEvent: TRALRESTDWEventServer;
begin
  AResponse.Answer(403);

  vObj := CreateModuleObject;
  if vObj = nil then
    Exit;

  try
    vComp := FindServerEvents(vObj, RequestParam(ARequest, 'servereventname'),
                                    RequestParam(ARequest, 'accesstag'));
    if vComp <> nil then
    begin
      vEvent := TRALRESTDWServerEvents(vComp).CanAnswerEvent(ARequest, Domain);
      if vEvent <> nil then
        vEvent.ReplyEvent(ARequest, AResponse, Self);
    end;
  finally
    FreeAndNil(vObj);
  end;
end;

procedure TRALRESTDWModule.GetEvents(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vObj, vComp: TComponent;
  vStream: TStream;
begin
  AResponse.Answer(403);

  vObj := CreateModuleObject;
  if vObj = nil then
    Exit;

  try
    vComp := FindServerEvents(vObj, RequestParam(ARequest, 'servereventname'),
                                    RequestParam(ARequest, 'accesstag'));
    if vComp <> nil then
    begin
      AResponse.Clear;
      vStream := TRALRESTDWServerEvents(vComp).GetEvents;
      try
        AResponse.Answer(HTTP_OK, vStream, rctAPPLICATIONOCTETSTREAM);
      finally
        FreeAndNil(vStream);
      end;
    end;
  finally
    FreeAndNil(vObj);
  end;
end;

procedure TRALRESTDWModule.GetServerEventsList(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vObj, vComp: TComponent;
  vInt1: IntegerRAL;
  vResult, vAccessTag: StringRAL;
begin
  AResponse.Answer(403);

  vObj := CreateModuleObject;
  if vObj = nil then
    Exit;

  try
    vAccessTag := RequestParam(ARequest, 'accesstag');
    vResult := '';

    for vInt1 := 0 to Pred(vObj.ComponentCount) do
    begin
      vComp := vObj.Components[vInt1];
      if vComp.InheritsFrom(TRALRESTDWServerEvents) and
         (TRALRESTDWServerEvents(vComp).AccessTag = vAccessTag) then
      begin
        if vResult <> '' then
          vResult := vResult + '|';
        vResult := vResult + Format('%s.%s', [vObj.ClassName, vComp.Name]);
      end;
    end;

    AResponse.Clear;
    AResponse.Answer(HTTP_OK, vResult, rctTEXTPLAIN);
  finally
    FreeAndNil(vObj);
  end;
end;

function TRALRESTDWModule.GetListRoutes: TList;
var
  vInt: IntegerRAL;
begin
  Result := inherited GetListRoutes;

  for vInt := 0 to Pred(FRDWRoutes.Count) do
    Result.Add(FRDWRoutes.Items[vInt]);
end;

procedure TRALRESTDWModule.CreateRoutes;
var
  vRoute: TRALRoute;
begin
  FRDWRoutes.Clear;

  // o Domain e aplicado por TRALBaseRoute.GetFullRoute; repeti-lo aqui duplicava o prefixo
  vRoute := TRALRoute(FRDWRoutes.Add);
  vRoute.Name := 'getevents';
  vRoute.Route := '/getevents';
  vRoute.OnReply := {$IFDEF FPC}@{$ENDIF}GetEvents;
  vRoute.AllowedMethods := [amPOST, amOPTIONS];

  vRoute := TRALRoute(FRDWRoutes.Add);
  vRoute.Name := 'getservereventslist';
  vRoute.Route := '/getservereventslist';
  vRoute.OnReply := {$IFDEF FPC}@{$ENDIF}GetServerEventsList;
  vRoute.AllowedMethods := [amPOST, amOPTIONS];
end;

procedure TRALRESTDWModule.BindRoutes;
var
  vInt1: IntegerRAL;
begin
  for vInt1 := 0 to Pred(Routes.Count) do
    TRALRoute(Routes.Items[vInt1]).OnReply := {$IFDEF FPC}@{$ENDIF}ReplyRoutes;
end;

procedure TRALRESTDWModule.Loaded;
begin
  inherited Loaded;
  // rotas montadas a mao no design chegam sem handler
  BindRoutes;
end;

procedure TRALRESTDWModule.ImportFromStream(AStream: TStream);
var
  vWriter: TRALBinaryWriter;
  vTotServer, vTotParam, vTotEvent, vInt1, vInt2, vInt3: IntegerRAL;
  vObjRoute : TRALRoute;
  vRoute, vRouteName, vDescription: StringRAL;
  vParamRoute: TRALRouteParam;
begin
  // arquivo vazio nao pode derrubar as rotas que ja estao publicadas
  if (AStream = nil) or (AStream.Size < SizeOf(IntegerRAL)) then
    Exit;

  Routes.Clear;

  vWriter := TRALBinaryWriter.Create(AStream);
  try
    vTotServer := vWriter.ReadInteger;
    for vInt1 := 1 to vTotServer do
    begin
      vTotEvent := vWriter.ReadInteger;
      for vInt2 := 1 to vTotEvent do
      begin
        vRouteName := vWriter.ReadString;
        vRoute := vWriter.ReadString;
        vDescription := vWriter.ReadString;

        vObjRoute := CreateRoute(vRoute, {$IFDEF FPC}@{$ENDIF}ReplyRoutes, vDescription);
        vObjRoute.Name := vRouteName;

        vTotParam := vWriter.ReadInteger;
        for vInt3 := 1 to vTotParam do
        begin
          vParamRoute := TRALRouteParam(vObjRoute.InputParams.Add);
          vParamRoute.ParamName := vWriter.ReadString;
          vParamRoute.ParamType := ObjectValueToRouteParamType(TRALRESTDWObjectValue(vWriter.ReadByte));
        end;
      end;
    end;
  finally
    FreeAndNil(vWriter);
  end;
end;

constructor TRALRESTDWModule.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRDWRoutes := TRALRoutes.Create(Self);
  CreateRoutes;
end;

destructor TRALRESTDWModule.Destroy;
begin
  FreeAndNil(FRDWRoutes);
  inherited Destroy;
end;

function TRALRESTDWModule.CanAnswerRoute(ARequest: TRALRequest;
  AResponse: TRALResponse): TRALRoute;
begin
  Result := inherited CanAnswerRoute(ARequest, AResponse);
  if Result <> nil then
  begin
    // cobre a rota criada em runtime, depois do Loaded
    if not Assigned(Result.OnReply) then
      Result.OnReply := {$IFDEF FPC}@{$ENDIF}ReplyRoutes;
  end
  else
  begin
    Result := FRDWRoutes.CanAnswerRoute(ARequest);
  end;
end;

function TRALRESTDWModule.ExportToStream: TStream;
begin
  Result := TMemoryStream.Create;
  ExportToStream(Result);
end;

procedure TRALRESTDWModule.ExportToStream(AStream: TStream);
var
  vWriter : TRALBinaryWriter;
  vObj, vComp: TComponent;
  vTotal, vInt1: IntegerRAL;
begin
  vWriter := TRALBinaryWriter.Create(AStream);
  try
    // o total e reservado agora e reescrito no fim, com o stream de volta no zero
    vTotal := 0;
    vWriter.WriteInteger(vTotal);

    vObj := CreateModuleObject;
    if vObj <> nil then
    begin
      try
        for vInt1 := 0 to Pred(vObj.ComponentCount) do
        begin
          vComp := vObj.Components[vInt1];
          if vComp.InheritsFrom(TRALRESTDWServerEvents) then
          begin
            TRALRESTDWServerEvents(vComp).ExportEvents(vWriter);
            vTotal := vTotal + 1;
          end;
        end;
      finally
        FreeAndNil(vObj);
      end;

      AStream.Position := 0;
      vWriter.WriteInteger(vTotal);
    end;

    AStream.Position := 0;
  finally
    FreeAndNil(vWriter);
  end;
end;

procedure TRALRESTDWModule.ExportToFile(AFile: TFileName);
var
  vStream : TRALBufFileStream;
begin
  if Trim(AFile) = '' then
    AFile := FFileExporter;

  if Trim(AFile) = '' then
    raise Exception.Create('FileName not assigned');

  vStream := TRALBufFileStream.Create(AFile, fmCreate);
  try
    ExportToStream(vStream);
  finally
    FreeAndNil(vStream);
  end;
end;

procedure TRALRESTDWModule.ImportFromFile(AFile: TFileName);
var
  vStream : TFileStream;
begin
  if Trim(AFile) = '' then
    AFile := FFileExporter;

  if Trim(AFile) = '' then
    raise Exception.Create('FileName not assigned');

  vStream := TFileStream.Create(AFile, fmOpenRead);
  try
    ImportFromStream(vStream);
  finally
    FreeAndNil(vStream);
  end;
end;

end.
