unit RALRESTDWReg;

interface

uses
  Classes,
  RALRESTDWModule, RALRESTDWServerEvents;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RAL - RDWModule', [TRALRESTDWServerEvents]);
  RegisterComponents('RAL - Modules', [TRALRESTDWModule]);
end;

end.
