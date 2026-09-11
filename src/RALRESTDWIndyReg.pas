/// Design-time registration of the Indy service pooler.
///
/// It lives apart from RALRESTDWReg because this one drags Indy in: a project
/// that only talks to a server, or that runs on another engine, has no reason
/// to carry it.
unit RALRESTDWIndyReg;

interface

uses
  Classes,
  RALRESTDWIndyPooler;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('RAL - RDWModule', [TRALRESTDWIndyServicePooler]);
end;

end.
