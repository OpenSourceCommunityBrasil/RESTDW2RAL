/// Design-time registration of the database half.
unit RALRESTDWDBReg;

interface

uses
  {$IFDEF FPC}
    LResources,
  {$ENDIF}
  Classes,
  RALRESTDWClientSQL, RALRESTDWDatabase, RALRESTDWPoolerDB;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RAL - RDWModule', [TRALRESTDWClientSQL]);
  RegisterComponents('RAL - RDWModule', [TRALRESTDWDatabase]);
  RegisterComponents('RAL - RDWModule', [TRALRESTDWPoolerDB]);
  RegisterComponents('RAL - RDWModule', [TRALRESTDWFireDACDriver]);
end;

end.
