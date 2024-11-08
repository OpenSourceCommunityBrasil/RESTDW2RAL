unit RALDWModuleReg;

interface

uses
  Classes,
  ralrestdwmodule, ralrestdwserverevents;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RAL - RDWModule', [TRALRESTDWServerEvents]);
  RegisterComponents('RAL - Modules', [TRALRESTDWModule]);
end;

end.
