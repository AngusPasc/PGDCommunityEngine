(******************************************************************************

  Pascal Game Development Community Engine (PGDCE)

  The contents of this file are subject to the license defined in the file
  'licence.md' which accompanies this file; you may not use this file except
  in compliance with the license.

  This file is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
  either express or implied.  See the license for the specific language governing
  rights and limitations under the license.

  The Original Code is CECore.pas

  The Initial Developer of the Original Code is documented in the accompanying
  help file PGDCE.chm.  Portions created by these individuals are Copyright (C)
  2014 of these individuals.

******************************************************************************)

{
@abstract(Template collections test)

This is test for template collections

@author(George Bakhtadze (avagames@gmail.com))
}

{$Include PGDCE.inc}
program EntityTest;

{$APPTYPE CONSOLE}

uses
  SysUtils, CEEntity, CECommon, Tester;

type
  // Base class for all template classes tests
  TEntityTest = class(TTestSuite)
  published
    procedure TestEntity();
  end;

{ TEntityTest }

procedure TEntityTest.TestEntity;
begin

end;

begin
  RegisterSuites([TEntityTest]);
  Tester.RunTests();
  Readln;
end.
