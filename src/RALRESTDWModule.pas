/// Publishes the events of a DataModule as routes on a TRALServer.
unit RALRESTDWModule;

interface

uses
  Classes, SysUtils,
  RALServer, RALTypes, RALRoutes, RALRequest, RALResponse, RALTools,
  RALRESTDWTypes, RALConsts, RALRESTDWEvents, RALStream, RALMIMETypes;

var
  { Gancho que a metade de banco preenche ao ser linkada.

    Quem tem a instancia do DataModule em maos e este modulo, na hora de
    descobrir as rotas dos eventos - e e ali que o TRALDBModule do RAL precisa
    nascer, porque o TRESTDWPoolerDB do RDW mora dentro do DataModule e o
    TRALDBModule tem de viver enquanto o servidor estiver no ar.

    E um gancho, e nao uma chamada direta, porque RALRESTDWPoolerDB esta no
    pacote RALRESTDWDB: o pacote de eventos nao pode arrastar o link de banco
    do RAL para quem so publica eventos. Nulo quando o pacote de banco nao
    esta instalado, e ai nao ha o que montar. }
  RALRESTDWMontarBanco: procedure(AServer: TRALServer;
                                  AInstancia: TComponent) = nil;

type

  { TRALRESTDWModule }

  TRALRESTDWModule = class(TRALModuleRoutes)
  private
    FRDWRoutes : TRALRoutes;
    FClassModule: StringRAL;
    FFileExporter: StringRAL;
    FAutoRoutes: boolean;
    FRoutesBuilt: boolean;
  protected
    procedure ReplyRoutes(ARequest: TRALRequest; AResponse: TRALResponse);

    procedure GetEvents(ARequest: TRALRequest; AResponse: TRALResponse);
    procedure GetServerEventsList(ARequest: TRALRequest; AResponse: TRALResponse);

    procedure CreateRoutes;
    procedure ImportFromStream(AStream : TStream);

    /// Instantiates the class registered under ClassModule; nil when unregistered
    function CreateModuleObject: TComponent;
    function RouteExists(const ARoute: StringRAL): boolean;
    /// Publishes one route for an event, skipping a path already published
    procedure AddEventRoute(AEvent: TRALRESTDWEventBase);
    /// Wires ReplyRoutes into the routes, away from the request path
    procedure BindRoutes;
    /// Builds the routes from ClassModule when AutoRoutes is on and none exist
    procedure AutoBuildRoutes;

    procedure SetServer(AValue: TRALServer); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    function GetListRoutes: TList; override;
    function CanAnswerRoute(ARequest: TRALRequest; AResponse: TRALResponse): TRALRoute; override;

    { Rebuilds Routes from the current ClassModule.

      Runs on its own at Loaded and when Server is assigned; call it by hand if
      ClassModule only becomes known later. }
    procedure RefreshRoutes;

    function ExportToStream : TStream; overload;
    procedure ExportToStream(AStream : TStream); overload;
    procedure ExportToFile(AFile : TFileName = ''); overload;

    procedure ImportFromFile(AFile : TFileName = ''); overload;
  published
    property ClassModule: StringRAL read FClassModule write FClassModule;
    property FileExporter: StringRAL read FFileExporter write FFileExporter;
    { Discovers the events of ClassModule and publishes their routes by itself.

      This is what removes the export/import step: with it on, dropping a
      TRALRESTDWServerEvents on the DataModule is all it takes, exactly like
      REST Dataware. Turn it off to curate Routes by hand. }
    property AutoRoutes: boolean read FAutoRoutes write FAutoRoutes default True;
    property Routes;
  end;

implementation

uses
  RALRESTDWServerEvents, RALRESTDWParams, RALRESTDWParamsMethods, RALParams;

const
  cExportSignature = 'RALRDWEX';
  cExportVersion = 2;

{ ParamByName devolve nil quando o parametro nao veio na requisicao. E quando a
  requisicao carrega um unico param de body, o RAL manda o valor cru e o nome
  nao chega do outro lado - ver "A lone body param travels without its name" no
  CLAUDE.md do PascalRAL. Dai a leitura em dois passos, por nome e depois pelo
  Body, que e o que o proprio RAL faz nos modulos dele. }
function RequestParam(ARequest: TRALRequest; const AName: StringRAL;
  AFallbackBody: boolean = False): StringRAL;
var
  vParam: TRALParam;
begin
  Result := '';

  vParam := ARequest.ParamByName(AName);
  if (vParam = nil) and AFallbackBody then
    vParam := ARequest.Body;

  if vParam <> nil then
    Result := vParam.AsString;
end;

function ServerEventsName(AObject, AComponent: TComponent): StringRAL;
begin
  Result := StringRAL(Format('%s.%s', [AObject.ClassName, AComponent.Name]));
end;

{ TRALRESTDWModule }

constructor TRALRESTDWModule.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRDWRoutes := TRALRoutes.Create(Self);
  FAutoRoutes := True;
  FRoutesBuilt := False;
  CreateRoutes;
end;

destructor TRALRESTDWModule.Destroy;
begin
  FreeAndNil(FRDWRoutes);
  inherited Destroy;
end;

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

procedure TRALRESTDWModule.ReplyRoutes(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vObj, vComp: TComponent;
  vSE: TRALRESTDWServerEvents;
  vInt1: IntegerRAL;
  vName, vTag: StringRAL;
  vMatched: boolean;
begin
  AResponse.Answer(HTTP_Forbidden);

  vObj := CreateModuleObject;
  if vObj = nil then
    Exit;

  try
    vName := RequestParam(ARequest, 'servereventname');
    vTag := RequestParam(ARequest, 'accesstag');

    { Sem o nome por nome: ou a requisicao levou um unico param de body (e o RAL
      tirou o nome no caminho), ou quem chamou nem sabe que existe um - um curl,
      um cliente de outra linguagem. O body so vale como palpite: se nao casar
      com nenhum componente, atende-se pela rota, que e o que um cliente REST
      comum espera. }
    if vName = '' then
    begin
      vName := RequestParam(ARequest, 'servereventname', True);
      vMatched := False;
      for vInt1 := 0 to Pred(vObj.ComponentCount) do
      begin
        vComp := vObj.Components[vInt1];
        if vComp.InheritsFrom(TRALRESTDWServerEvents) and
           SameText(ServerEventsName(vObj, vComp), vName) then
        begin
          vMatched := True;
          Break;
        end;
      end;
      if not vMatched then
        vName := '';
    end;

    for vInt1 := 0 to Pred(vObj.ComponentCount) do
    begin
      vComp := vObj.Components[vInt1];
      if not vComp.InheritsFrom(TRALRESTDWServerEvents) then
        Continue;

      vSE := TRALRESTDWServerEvents(vComp);

      if (vName <> '') and (not SameText(ServerEventsName(vObj, vComp), vName)) then
        Continue;

      if vSE.AccessTag <> vTag then
        Continue;

      vSE.DoCreate;
      if vSE.ExecuteEvent(ARequest, AResponse, Self, Domain) then
        Break;
    end;
  finally
    FreeAndNil(vObj);
  end;
end;

procedure TRALRESTDWModule.GetEvents(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vObj, vComp, vFound: TComponent;
  vInt1, vTotal: IntegerRAL;
  vName, vTag: StringRAL;
  vStream: TStream;
begin
  AResponse.Answer(HTTP_Forbidden);

  vObj := CreateModuleObject;
  if vObj = nil then
    Exit;

  try
    { aqui servereventname viaja sozinho sempre que o AccessTag esta vazio,
      entao o fallback pelo body e o caminho normal, nao a excecao }
    vName := RequestParam(ARequest, 'servereventname', True);
    vTag := RequestParam(ARequest, 'accesstag');

    vFound := nil;
    vTotal := 0;
    for vInt1 := 0 to Pred(vObj.ComponentCount) do
    begin
      vComp := vObj.Components[vInt1];
      if (not vComp.InheritsFrom(TRALRESTDWServerEvents)) or
         (TRALRESTDWServerEvents(vComp).AccessTag <> vTag) then
        Continue;

      vTotal := vTotal + 1;
      if SameText(ServerEventsName(vObj, vComp), vName) then
      begin
        vFound := vComp;
        Break;
      end;

      // sem nome e com um unico componente liberado nao ha ambiguidade
      if (vTotal = 1) and (vName = '') then
        vFound := vComp;
    end;

    if vFound <> nil then
    begin
      AResponse.Clear;
      vStream := TRALRESTDWServerEvents(vFound).GetEvents;
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
  AResponse.Answer(HTTP_Forbidden);

  vObj := CreateModuleObject;
  if vObj = nil then
    Exit;

  try
    // aqui o accesstag e o unico param da requisicao, entao chega sem nome
    vAccessTag := RequestParam(ARequest, 'accesstag', True);
    vResult := '';

    for vInt1 := 0 to Pred(vObj.ComponentCount) do
    begin
      vComp := vObj.Components[vInt1];
      if vComp.InheritsFrom(TRALRESTDWServerEvents) and
         (TRALRESTDWServerEvents(vComp).AccessTag = vAccessTag) then
      begin
        if vResult <> '' then
          vResult := vResult + '|';
        vResult := vResult + ServerEventsName(vObj, vComp);
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

function TRALRESTDWModule.RouteExists(const ARoute: StringRAL): boolean;
var
  vInt1: IntegerRAL;
begin
  Result := False;
  for vInt1 := 0 to Pred(Routes.Count) do
  begin
    if SameText(TRALRoute(Routes.Items[vInt1]).Route, ARoute) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

procedure TRALRESTDWModule.AddEventRoute(AEvent: TRALRESTDWEventBase);
var
  vRoute: TRALRoute;
  vParam: TRALRESTDWParamMethod;
  vRouteParam: TRALRouteParam;
  vInt1: IntegerRAL;
begin
  // dois componentes podem declarar a mesma rota; o primeiro e quem vale
  if RouteExists(AEvent.GetRoute) then
    Exit;

  vRoute := CreateRoute(AEvent.GetRoute, {$IFDEF FPC}@{$ENDIF}ReplyRoutes,
                        AEvent.Description.Text);
  vRoute.Name := AEvent.EventName;
  vRoute.AllowedMethods := AEvent.Routes.AllowedMethods;
  vRoute.SkipAuthMethods := AEvent.Routes.SkipAuthMethods;
  vRoute.Callback := AEvent.CallbackEvent;

  for vInt1 := 0 to Pred(AEvent.Params.Count) do
  begin
    vParam := AEvent.Params.Items[vInt1];
    if not (vParam.ObjectDirection in [odIN, odINOUT]) then
      Continue;

    vRouteParam := TRALRouteParam(vRoute.InputParams.Add);
    vRouteParam.ParamName := vParam.ParamName;
    vRouteParam.ParamType := ObjectValueToRouteParamType(vParam.ObjectValue);
  end;
end;

procedure TRALRESTDWModule.RefreshRoutes;
var
  vObj, vComp: TComponent;
  vSE: TRALRESTDWServerEvents;
  vInt1, vInt2: IntegerRAL;
begin
  FRoutesBuilt := True;

  vObj := CreateModuleObject;
  if vObj = nil then
    Exit;

  try
    { o banco antes das rotas: o TRALDBModule responde numa rota propria e nao
      tem nada a ver com a colecao de eventos }
    if Assigned(RALRESTDWMontarBanco) and (Server <> nil) then
      RALRESTDWMontarBanco(Server, vObj);

    Routes.Clear;
    for vInt1 := 0 to Pred(vObj.ComponentCount) do
    begin
      vComp := vObj.Components[vInt1];
      if not vComp.InheritsFrom(TRALRESTDWServerEvents) then
        Continue;

      vSE := TRALRESTDWServerEvents(vComp);
      for vInt2 := 0 to Pred(vSE.Events.Count) do
        AddEventRoute(vSE.Events.Items[vInt2]);
    end;
  finally
    FreeAndNil(vObj);
  end;
end;

procedure TRALRESTDWModule.AutoBuildRoutes;
begin
  { rotas montadas a mao (ou importadas do arquivo) mandam: descobrir por cima
    delas apagaria o que o desenvolvedor escreveu }
  if (not FAutoRoutes) or FRoutesBuilt or (Routes.Count > 0) or
     (Trim(FClassModule) = '') then
    Exit;

  RefreshRoutes;
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
  AutoBuildRoutes;
  // rotas montadas a mao no design chegam sem handler
  BindRoutes;
end;

procedure TRALRESTDWModule.SetServer(AValue: TRALServer);
begin
  inherited SetServer(AValue);

  // modulo criado por codigo nao passa por Loaded
  if (AValue <> nil) and (not (csLoading in ComponentState)) then
  begin
    AutoBuildRoutes;
    BindRoutes;
  end;
end;

procedure TRALRESTDWModule.ImportFromStream(AStream: TStream);
var
  vWriter: TRALBinaryWriter;
  vTotServer, vTotParam, vTotEvent, vInt1, vInt2, vInt3: IntegerRAL;
  vObjRoute : TRALRoute;
  vRoute, vRouteName, vDescription: StringRAL;
  vParamRoute: TRALRouteParam;
  vMethods: TRALMethods;
  vCallback, vAll: boolean;
  vDirection: TRALRESTDWObjectDirection;

  function ReadVerb(AMethod: TRALMethod): TRALMethods;
  begin
    Result := [];
    if vWriter.ReadBoolean then
      Result := [AMethod];
  end;

begin
  // arquivo vazio nao pode derrubar as rotas que ja estao publicadas
  if (AStream = nil) or (AStream.Size < SizeOf(IntegerRAL)) then
    Exit;

  vWriter := TRALBinaryWriter.Create(AStream);
  try
    if vWriter.ReadString <> cExportSignature then
      raise Exception.Create('Not a RESTDW2RAL event export file');
    if vWriter.ReadInteger <> cExportVersion then
      raise Exception.Create('Event export file written by another version');

    Routes.Clear;
    FRoutesBuilt := True;

    vTotServer := vWriter.ReadInteger;
    for vInt1 := 1 to vTotServer do
    begin
      vTotEvent := vWriter.ReadInteger;
      for vInt2 := 1 to vTotEvent do
      begin
        vRouteName := vWriter.ReadString;
        vRoute := vWriter.ReadString;
        vDescription := vWriter.ReadString;
        vCallback := vWriter.ReadBoolean;

        vAll := vWriter.ReadBoolean;
        vMethods := ReadVerb(amGET) + ReadVerb(amPOST) + ReadVerb(amPUT) +
                    ReadVerb(amPATCH) + ReadVerb(amDELETE) + ReadVerb(amOPTIONS);
        if vAll then
          vMethods := [amALL]
        else
          vMethods := vMethods + [amOPTIONS];

        vObjRoute := CreateRoute(vRoute, {$IFDEF FPC}@{$ENDIF}ReplyRoutes, vDescription);
        vObjRoute.Name := vRouteName;
        vObjRoute.AllowedMethods := vMethods;
        vObjRoute.Callback := vCallback;

        vTotParam := vWriter.ReadInteger;
        for vInt3 := 1 to vTotParam do
        begin
          vParamRoute := TRALRouteParam(vObjRoute.InputParams.Add);
          vParamRoute.ParamName := vWriter.ReadString;
          vParamRoute.ParamType := ObjectValueToRouteParamType(TRALRESTDWObjectValue(vWriter.ReadByte));
          vDirection := TRALRESTDWObjectDirection(vWriter.ReadByte);
          // so os de entrada descrevem a rota
          if not (vDirection in [odIN, odINOUT]) then
            vObjRoute.InputParams.Delete(vParamRoute.Index);
        end;
      end;
    end;
  finally
    FreeAndNil(vWriter);
  end;
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
  vCountPos: Int64;
begin
  vWriter := TRALBinaryWriter.Create(AStream);
  try
    vWriter.WriteString(cExportSignature);
    vWriter.WriteInteger(cExportVersion);

    // o total e reservado agora e reescrito no fim, de volta nesta posicao
    vCountPos := AStream.Position;
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

      AStream.Position := vCountPos;
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
