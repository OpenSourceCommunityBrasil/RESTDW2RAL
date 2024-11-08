unit RALRESTDWModule;

interface

uses
  Classes, SysUtils,
  RALServer, RALTypes, RALRoutes, RALRequest, RALResponse;

type

  { TRALRESTDWModule }

  TRALRESTDWModule = class(TRALModuleRoutes)
  private
    FClassName: StringRAL;
  protected
    procedure ReplyRoutes(ARequest: TRALRequest; AResponse: TRALResponse);
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
  RALRESTDWServerEvents;

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

constructor TRALRESTDWModule.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

destructor TRALRESTDWModule.Destroy;
begin
  inherited Destroy;
end;

function TRALRESTDWModule.CanAnswerRoute(ARequest: TRALRequest;
  AResponse: TRALResponse): TRALRoute;
begin
  Result := inherited CanAnswerRoute(ARequest, AResponse);
  if Result <> nil then
    Result.OnReply := {$IFDEF FPC}@{$ENDIF}ReplyRoutes;
end;

end.

