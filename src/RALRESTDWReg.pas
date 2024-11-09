unit RALRESTDWReg;

interface

uses
  Classes,
  RALRESTDWModule, RALRESTDWServerEvents, RALRESTDWClientEvents;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RAL - RDWModule', [TRALRESTDWServerEvents]);
  RegisterComponents('RAL - RDWModule', [TRALRESTDWClientEvents]);
  RegisterComponents('RAL - Modules', [TRALRESTDWModule]);
end;

end.
