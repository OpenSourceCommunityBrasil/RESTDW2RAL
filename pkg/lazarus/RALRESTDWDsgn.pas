{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit RALRESTDWDsgn;

{$warn 5023 off : no warning about unused units}
interface

uses
  RALRESTDWReg, RALRESTDWDBReg, RALRESTDWIndyReg, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('RALRESTDWReg', @RALRESTDWReg.Register);
  RegisterUnit('RALRESTDWDBReg', @RALRESTDWDBReg.Register);
  RegisterUnit('RALRESTDWIndyReg', @RALRESTDWIndyReg.Register);
end;

initialization
  RegisterPackage('RALRESTDWDsgn', @Register);
end.
