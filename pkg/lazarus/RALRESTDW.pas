{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit RALRESTDW;

{$warn 5023 off : no warning about unused units}
interface

uses
  RALRESTDWReg, RALRESTDWModule, RALRESTDWParams, RALRESTDWParamsMethods, 
  RALRESTDWServerEvents, RALRESTDWTypes, RALRESTDWClientEvents, 
  RALRESTDWEvents, RALRESTDWCompat, RALRESTDWOptions, RALRESTDWDataModule,
  RALRESTDWClient, RALRESTDWMassive, RALRESTDWServerContext,
  LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('RALRESTDWReg', @RALRESTDWReg.Register);
end;

initialization
  RegisterPackage('RALRESTDW', @Register);
end.
