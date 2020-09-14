{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit mungo.textfile.maki;

{$warn 5023 off : no warning about unused units}
interface

uses
  mungo.textfile.maki.sourceeditor, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('mungo.textfile.maki', @Register);
end.
