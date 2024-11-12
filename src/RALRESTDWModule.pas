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
  RALRESTDWServerEvents, RALRESTDWParams;

{ TRALRESTDWModule }

procedure TRALRESTDWModule.ReplyRoutes(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vClass: TComponentClass;
  vObj, vComp: TComponent;
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEventServer;
  vServerEventName, vServer, vAccessTag, vAccess: StringRAL;
  vBlock: boolean;
begin
  vClass := TComponentClass(GetClass(FClassModule));
  AResponse.Answer(403);

  if vClass <> nil then begin
    vServerEventName := ARequest.ParamByName('servereventname').AsString;
    vAccessTag := ARequest.ParamByName('accesstag').AsString;

    vObj := vClass.Create(Self);
    try
      for vInt1 := 0 to Pred(vObj.ComponentCount) do begin
        if vObj.Components[vInt1].InheritsFrom(TRALRESTDWServerEvents) then begin
          vComp := vObj.Components[vInt1];
          vServer := Format('%s.%s', [vClass.ClassName, vComp.Name]);
          vAccess := TRALRESTDWServerEvents(vComp).AccessTag;
          if SameText(vServer, vServerEventName) then
          begin
            vBlock := ((vAccess <> '') and (vAccess <> vAccessTag)) or
                      ((vAccessTag <> '') and (vAccess <> vAccessTag));

            if not vBlock then begin
              vEvent := TRALRESTDWServerEvents(vComp).CanAnswerEvent(ARequest);
              if vEvent <> nil then
                vEvent.ReplyEvent(ARequest, AResponse)
            end;
          end;
        end;
      end;
    finally
      FreeAndNil(vObj);
    end;
  end;
end;

procedure TRALRESTDWModule.GetEvents(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vServerEventName, vServer, vAccessTag, vAccess: StringRAL;
  vClass: TComponentClass;
  vObj, vComp: TComponent;
  vInt1: IntegerRAL;
  vStream: TStream;
  vBlock: boolean;
begin
  vClass := TComponentClass(GetClass(FClassModule));
  AResponse.Answer(403);

  if vClass <> nil then begin
    vServerEventName := ARequest.ParamByName('servereventname').AsString;
    vAccessTag := ARequest.ParamByName('accesstag').AsString;

    vObj := vClass.Create(Self);
    try
      for vInt1 := 0 to Pred(vObj.ComponentCount) do begin
        if vObj.Components[vInt1].InheritsFrom(TRALRESTDWServerEvents) then begin
          vComp := vObj.Components[vInt1];
          vServer := Format('%s.%s', [vClass.ClassName, vComp.Name]);
          vAccess := TRALRESTDWServerEvents(vComp).AccessTag;
          if SameText(vServer, vServerEventName) then
          begin
            vBlock := ((vAccess <> '') and (vAccess <> vAccessTag)) or
                      ((vAccessTag <> '') and (vAccess <> vAccessTag));

            if not vBlock then
            begin
              AResponse.Clear;
              vStream := TRALRESTDWServerEvents(vComp).GetEvents;
              try
                AResponse.Answer(HTTP_OK, vStream, rctAPPLICATIONOCTETSTREAM);
              finally
                FreeAndNil(vStream);
              end;
            end;
          end;
        end;
      end;
    finally
      FreeAndNil(vObj);
    end;
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

procedure TRALRESTDWModule.GetServerEventsList(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vClass: TComponentClass;
  vObj, vComp: TComponent;
  vInt1: IntegerRAL;
  vResult: StringRAL;
  vAccessTag, vAccess: StringRAL;
  vBlock: boolean;
begin
  vClass := TComponentClass(GetClass(FClassModule));
  AResponse.Answer(403);

  if vClass <> nil then begin
    vAccessTag := ARequest.ParamByName('accesstag').AsString;

    vObj := vClass.Create(Self);
    try
      vResult := '';
      for vInt1 := 0 to Pred(vObj.ComponentCount) do begin
        if vObj.Components[vInt1].InheritsFrom(TRALRESTDWServerEvents) then begin
          vComp := vObj.Components[vInt1];
          vAccess := TRALRESTDWServerEvents(vComp).AccessTag;

          vBlock := ((vAccess <> '') and (vAccess <> vAccessTag)) or
                    ((vAccessTag <> '') and (vAccess <> vAccessTag));
          if not vBlock then
          begin
            if vResult <> '' then
              vResult := vResult + '|';
            vResult := vResult + Format('%s.%s', [vClass.ClassName, vComp.Name]);
          end;
        end;
      end;

      AResponse.Clear;
      AResponse.Answer(200, vResult, rctTEXTPLAIN);
    finally
      FreeAndNil(vObj);
    end;
  end;
end;

procedure TRALRESTDWModule.CreateRoutes;
var
  vRoute: TRALRoute;
begin
  FRDWRoutes.Clear;

  vRoute := TRALRoute(FRDWRoutes.Add);
  vRoute.Name := 'getevents';
  vRoute.Route := Domain + '/getevents';
  vRoute.OnReply := {$IFDEF FPC}@{$ENDIF}GetEvents;
  vRoute.AllowedMethods := [amPOST, amOPTIONS];

  vRoute := TRALRoute(FRDWRoutes.Add);
  vRoute.Name := 'getservereventslist';
  vRoute.Route := Domain + '/getservereventslist';
  vRoute.OnReply := {$IFDEF FPC}@{$ENDIF}GetServerEventsList;
  vRoute.AllowedMethods := [amPOST, amOPTIONS];
end;

procedure TRALRESTDWModule.ImportFromStream(AStream: TStream);
var
  vWriter: TRALBinaryWriter;
  vTotServer, vTotParam, vTotEvent, vInt1, vInt2, vInt3: IntegerRAL;
  vObjRoute : TRALRoute;
  vRoute, vRouteName, vDescription: StringRAL;
  vParamRoute: TRALRouteParam;
begin
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

        vObjRoute := CreateRoute(vRoute, nil, vDescription);
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
    Result.OnReply := {$IFDEF FPC}@{$ENDIF}ReplyRoutes
  else
    Result := FRDWRoutes.CanAnswerRoute(ARequest);
end;

function TRALRESTDWModule.ExportToStream: TStream;
begin
  Result := TMemoryStream.Create;
  ExportToStream(Result);
end;

procedure TRALRESTDWModule.ExportToStream(AStream: TStream);
var
  vWriter : TRALBinaryWriter;
  vClass: TComponentClass;
  vObj, vComp: TComponent;
  vTotal, vInt1: IntegerRAL;
begin
  vWriter := TRALBinaryWriter.Create(AStream);
  try
    vClass := TComponentClass(GetClass(FClassModule));
    if vClass <> nil then begin
      vObj := vClass.Create(nil);
      try
        vTotal := 0;
        vWriter.WriteInteger(vTotal);
        for vInt1 := 0 to Pred(vObj.ComponentCount) do begin
          if vObj.Components[vInt1].InheritsFrom(TRALRESTDWServerEvents) then begin
            vComp := vObj.Components[vInt1];
            TRALRESTDWServerEvents(vComp).ExportEvents(vWriter);
            vTotal := vTotal + 1;
          end;
        end;
        AStream.Position := 0;
        vWriter.WriteInteger(vTotal);
        AStream.Position := 0;
      finally
        FreeAndNil(vObj);
      end;
    end;
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
  begin
    raise Exception.Create('FileName not assigned');
    Exit;
  end;

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
  begin
    raise Exception.Create('FileName not assigned');
    Exit;
  end;

  vStream := TFileStream.Create(AFile, fmOpenRead);
  try
    ImportFromStream(vStream);
  finally
    FreeAndNil(vStream);
  end;
end;

end.