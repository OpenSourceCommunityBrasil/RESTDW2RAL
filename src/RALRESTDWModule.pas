unit RALRESTDWModule;

interface

uses
  Classes, SysUtils,
  RALServer, RALTypes, RALRoutes, RALRequest, RALResponse,
  RALRESTDWTypes, RALConsts, RALRESTDWEvents;

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
  vServerEventName, vServer, vAccessTag, vAccess: StringRAL;
  vBlock: boolean;
begin
  vClass := TComponentClass(GetClass(FClassName));

  if vClass <> nil then begin
    vServerEventName := ARequest.ParamByName('servereventname').AsString;
    vAccessTag := ARequest.ParamByName('accesstag').AsString;

    vObj := vClass.Create(nil);
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
              else
                AResponse.Answer(403);
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
  vClass := TComponentClass(GetClass(FClassName));
  AResponse.Clear;
  AResponse.StatusCode := HTTP_Forbidden;

  if vClass <> nil then begin
    vServerEventName := ARequest.ParamByName('servereventname').AsString;
    vAccessTag := ARequest.ParamByName('accesstag').AsString;
    vObj := vClass.Create(nil);

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
              AResponse.StatusCode := HTTP_OK;
              vStream := TRALRESTDWServerEvents(vComp).GetEvents;
              try
                AResponse.ResponseStream := vStream;
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

procedure TRALRESTDWModule.GetServerEventsList(ARequest: TRALRequest; AResponse: TRALResponse);
var
  vClass: TComponentClass;
  vObj, vComp: TComponent;
  vInt1: IntegerRAL;
  vResult: StringRAL;
  vAccessTag, vAccess: StringRAL;
  vBlock: boolean;
begin
  vClass := TComponentClass(GetClass(FClassName));
  AResponse.Clear;
  AResponse.StatusCode := HTTP_Forbidden;

  if vClass <> nil then begin
    vAccessTag := ARequest.ParamByName('accesstag').AsString;

    vObj := vClass.Create(nil);
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
      AResponse.Answer(200, vResult);
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

