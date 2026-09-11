/// Design-time registration of the database half.
unit RALRESTDWDBReg;

interface

uses
  {$IFDEF FPC}
    LResources,
  {$ENDIF}
  Classes,
  RALRESTDWClientSQL;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RAL - RDWModule', [TRALRESTDWClientSQL]);
end;

end.
