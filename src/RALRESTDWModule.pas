unit RALRESTDWModule;

interface

uses
  Classes, SysUtils,
  RALServer, RALTypes, RALRoutes, RALRequest, RALResponse,
  RALRESTDWTypes, RALJSON;

type

  { TRALRESTDWModule }

  TRALRESTDWModule = class(TRALModuleRoutes)
  private
    FRDWRoutes : TRALRoutes;
    FClassName: StringRAL;
  protected
    procedure ReplyRoutes(ARequest: TRALRequest; AResponse: TRALResponse);

    procedure GetEvents(ARequest: TRALRequest; AResponse: TRALResponse);
    procedure GetServerEventsList(ARequest: TRALRequest; AResponse: TRALResponse);

    procedure CreateRoutes;
  public
    constructor Create(AOwner : TComponent); override;
    destructor Destroy; override;

    function CanAnswerRoute(ARequest: TRALRequest; AResponse: TRALResponse): TRALRoute; override;
  published
    property ClassName: StringRAL read FClassName write FClassName;
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
  vEvent: TRALRESTDWEvent;
begin
  vClass := TComponentClass(GetClass(FClassName));

  if vClass <> nil then begin
    vObj := vClass.Create(nil);
    try
      for vInt1 := 0 to Pred(vObj.ComponentCount) do begin
        if vObj.Components[vInt1].InheritsFrom(TRALRESTDWServerEvents) then begin
          vComp := vObj.Components[vInt1];
          vEvent := TRALRESTDWServerEvents(vComp).CanAnswerEvent(ARequest);
          if vEvent <> nil then
            vEvent.ReplyEvent(ARequest, AResponse);
        end;
      end;
    finally
      FreeAndNil(vObj);
    end;
  end;
end;

procedure TRALRESTDWModule.GetEvents(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vServerEventName: StringRAL;
  vClass: TComponentClass;
  vObj, vComp: TComponent;
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEvent;
begin
  vClass := TComponentClass(GetClass(FClassName));

  if vClass <> nil then begin
    vServerEventName := ARequest.ParamByName('dwservereventname').AsString;
    vObj := vClass.Create(nil);
    try
      for vInt1 := 0 to Pred(vObj.ComponentCount) do begin
        if vObj.Components[vInt1].InheritsFrom(TRALRESTDWServerEvents) then begin
          vComp := vObj.Components[vInt1];
//          if SameText(vComp.Name, vServerEventName) then
//            TRALRESTDWServerEvents(vComp).GetEvents
        end;
      end;
    finally
      FreeAndNil(vObj);
    end;
  end;
end;

procedure TRALRESTDWModule.GetServerEventsList(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vClass: TComponentClass;
  vObj, vComp: TComponent;
  vInt1: IntegerRAL;
  vEvent: TRALRESTDWEvent;
  vResult: StringRAL;
  vJSONParam: TRALRESTDWJSONParam;
  vJSON, vJSONObj: TRALJSONObject;
  vJSONArr: TRALJSONArray;
begin
  vClass := TComponentClass(GetClass(FClassName));

  if vClass <> nil then begin
    vObj := vClass.Create(nil);
    try
      vResult := '';
      for vInt1 := 0 to Pred(vObj.ComponentCount) do begin
        if vObj.Components[vInt1].InheritsFrom(TRALRESTDWServerEvents) then begin
          vComp := vObj.Components[vInt1];
          if vResult <> '' then
            vResult := vResult + '|';
          vResult := vResult + Format('%s.%s', [vClass.ClassName, vComp.Name]);
        end;
      end;

      vJSON := TRALJSONObject.Create;
      try
        vJSONArr := TRALJSONArray.Create;
        vJSONParam := TRALRESTDWJSONParam.Create;
        try
          vJSONParam.Value := vResult;
          vJSONParam.ObjectDirection := odOUT;
          vJSONParam.TypeObject := toParam;
          vJSONParam.Encoded := True;
          vJSONParam.ObjectValue := ovString;

          vJSONArr.Add(vJSONParam.ToJSONObject);
          vJSON.Add('PARAMS', vJSONArr)
        finally
          FreeAndNil(vJSONParam);
        end;

        vJSONArr := TRALJSONArray.Create;
        vJSONObj := TRALJSONObject.Create;
        vJSONObj.Add('MESSAGE', 'OK');
        vJSONObj.Add('RESULT', 'OK');
        vJSONArr.Add(vJSONObj);

        vJSON.Add('RESULT', vJSONArr)
      finally
        FreeAndNil(vJSON);
      end;
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

  vRoute := CreateRoute('/getevents', {$IFDEF FPC}@{$ENDIF}GetEvents);
  vRoute.AllowedMethods := [amGET];

  vRoute := CreateRoute('/getservereventslist', {$IFDEF FPC}@{$ENDIF}GetServerEventsList);
  vRoute.AllowedMethods := [amGET];
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

end.

