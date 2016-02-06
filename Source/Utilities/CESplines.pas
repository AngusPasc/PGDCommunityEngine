(******************************************************************************

  Pascal Game Development Community Engine (PGDCE)

  The contents of this file are subject to the license defined in the file
  'licence.md' which accompanies this file; you may not use this file except
  in compliance with the license.

  This file is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
  either express or implied.  See the license for the specific language governing
  rights and limitations under the license.

  The Original Code is CEMaterial.pas

  The Initial Developer of the Original Code is documented in the accompanying
  help file PGDCE.chm.  Portions created by these individuals are Copyright (C)
  2014 of these individuals.

******************************************************************************)

{
@abstract(PGDCE spline calculation unit)

The unit contains spline calculation routines

@author(George Bakhtadze (avagames@gmail.com))
}

{$I PGDCE.inc}
unit CESplines;

interface

uses
  CEBaseTypes;

type
  TSingleBuffer = array[0..MaxInt div SizeOf(Single)-1] of Single;
  PSingleBuffer = ^TSingleBuffer;
  procedure CalcCatmullRom1D(PointsCount, Resolution: Integer; ControlPoints, Curve: PSingleBuffer; CurveStride: Integer = 1);
  procedure CalcCatmullRom2D(PointsCount, Resolution: Integer; ControlPoints, Curve: P2DPointArray);
  procedure CalcCatmullRomND(PointsCount, Resolution, N: Integer; ControlPoints, FinalCurve: Pointer; ControlStride, CurveStride: Integer);

implementation

uses
  CECommon;

procedure CalcCatmullRom1D(PointsCount, Resolution: Integer; ControlPoints, Curve: PSingleBuffer; CurveStride: Integer = 1);
var
  i, j, CI: Integer;
  Ap, Bp, Cp, Dp: Single;
  OverR, T: Single;
begin
  CI := 0;
  OverR := 1 / Resolution;
  ControlPoints^[0] := ControlPoints^[1];
  ControlPoints^[PointsCount] := ControlPoints^[PointsCount-1];
  for i := 1 to PointsCount-1 do
  begin
//Coeffs
    Ap :=  -ControlPoints^[i-1] + 3*ControlPoints^[i] - 3*ControlPoints^[i+1] + ControlPoints^[i+2];
    Bp := 2*ControlPoints^[i-1] - 5*ControlPoints^[i] + 4*ControlPoints^[i+1] - ControlPoints^[i+2];
    Cp :=  -ControlPoints^[i-1] + ControlPoints^[i+1];
    Dp := 2*ControlPoints^[i];
//Calc
    Curve^[CI] := ControlPoints^[i];
    Inc(CI, CurveStride);
    T := OverR;
    for j := 1 to Resolution-1 do
    begin
      Curve^[CI] := ((Ap * T * T * T) + (Bp * T * T) + (Cp * T) + Dp) * 0.5;  { Calc x value }
      T := T + OverR;
      Inc(CI, CurveStride);
    end;
  end;
//  Curve^[CI] := CtrlPt^[PointsCount];
end;

procedure CalcCatmullRom2D(PointsCount, Resolution: Integer; ControlPoints, Curve: P2DPointArray);
var
  i0, i1, i2, i3, j, CI: Integer;
  Ap, Bp, Cp, Dp: record X, Y: Single end;
  OverR, T, T2, T3: Single;
begin
  Assert(PointsCount > 1);
  Assert(Resolution > 0);
  Assert(Assigned(ControlPoints) and Assigned(Curve));
  CI := 0;
  //ControlPoints^[0] := ControlPoints^[1];
  //ControlPoints^[PointsCount + 1] := ControlPoints^[PointsCount];
  OverR := 1 / Resolution;
  for i1 := 0 to PointsCount-1 do
  begin                        // TODO: optimize
    i0 := MaxI(0, i1 - 1);
    i2 := MinI(PointsCount - 1, i1 + 1);
    i3 := MinI(PointsCount - 1, i1 + 2);
    Ap.X :=  -ControlPoints^[i0].X + 3*ControlPoints^[i1].X - 3*ControlPoints^[i2].X + ControlPoints^[i3].X;
    Bp.X := 2*ControlPoints^[i0].X - 5*ControlPoints^[i1].X + 4*ControlPoints^[i2].X - ControlPoints^[i3].X;
    Cp.X :=  -ControlPoints^[i0].X + ControlPoints^[i2].X;
    Dp.X := 2*ControlPoints^[i1].X;
    Ap.Y :=  -ControlPoints^[i0].Y + 3*ControlPoints^[i1].Y - 3*ControlPoints^[i2].Y + ControlPoints^[i3].Y;
    Bp.Y := 2*ControlPoints^[i0].Y - 5*ControlPoints^[i1].Y + 4*ControlPoints^[i2].Y - ControlPoints^[i3].Y;
    Cp.Y :=  -ControlPoints^[i0].Y + ControlPoints^[i2].Y;
    Dp.Y := 2*ControlPoints^[i1].Y;
//Calc
    Curve^[CI].X := Dp.X * 0.5;  { Calc x value }
    Curve^[CI].Y := Dp.Y * 0.5;  { Calc y value }
    Inc(CI);
    T := OverR;
    for j := 1 to Resolution-1 do
    begin
      T2 := T * T;
      T3 := T2 * T;
      Curve^[CI].X := ((Ap.X * T3) + (Bp.X * T2) + (Cp.X * T) + Dp.X) * 0.5;  { Calc x value }
      Curve^[CI].Y := ((Ap.Y * T3) + (Bp.Y * T2) + (Cp.Y * T) + Dp.Y) * 0.5;  { Calc y value }
      T := T + OverR;
      Inc(CI);
    end;
  end;
  Curve^[CI] := ControlPoints^[PointsCount-1];
end;

procedure CalcCatmullRomND(PointsCount, Resolution, N: Integer; ControlPoints, FinalCurve: Pointer; ControlStride, CurveStride: Integer);
var
  i, j, k, CI: Integer;
  Ap, Bp, Cp, Dp: array of Single;
  OverR, T, T2, T3: Single;
  CtrlPt, Curve: PSingleBuffer;
begin
  CtrlPt := ControlPoints;
  Curve := FinalCurve;
  CI := 0;
  for j := 0 to N - 1 do begin
    CtrlPt^[0 + j] := CtrlPt^[1 * ControlStride + j];
    CtrlPt^[(PointsCount + 1) * ControlStride + j] := CtrlPt^[PointsCount * ControlStride + j];
  end;
  OverR := 1 / Resolution;
  SetLength(Ap, N);
  SetLength(Bp, N);
  SetLength(Cp, N);
  SetLength(Dp, N);

  for i := 1 to PointsCount - 1 do begin
//Coeffs
    for j := 0 to N - 1 do begin
      Ap[j] :=    -CtrlPt^[(i - 1) * ControlStride + j] + 3 * CtrlPt^[i * ControlStride + j] - 3 * CtrlPt^[(i + 1) * ControlStride + j] + CtrlPt^[(i + 2) * ControlStride + j];
      Bp[j] := 2 * CtrlPt^[(i - 1) * ControlStride + j] - 5 * CtrlPt^[i * ControlStride + j] + 4 * CtrlPt^[(i + 1) * ControlStride + j] - CtrlPt^[(i + 2) * ControlStride + j];
      Cp[j] :=    -CtrlPt^[(i - 1) * ControlStride + j] + CtrlPt^[(i + 1) * ControlStride + j];
      Dp[j] := 2 * CtrlPt^[i * ControlStride + j];
      Curve^[CI * CurveStride + j] := Dp[j] * 0.5;  { Calc x value }
    end;
//Calc
    Inc(CI);
    T := OverR;
    for k := 1 to Resolution - 1 do
    begin
      T2 := T * T;
      T3 := T2 * T;
      for j := 0 to N - 1 do
        Curve^[CI * CurveStride + j] := ((Ap[j] * T3) + (Bp[j] * T2) + (Cp[j] * T) + Dp[j]) * 0.5;
      { Calc x value }
      T := T + OverR;
      Inc(CI);
    end;
  end;
  for j := 0 to N - 1 do
    Curve^[CI * CurveStride + j] := CtrlPt^[PointsCount * ControlStride + j];
end;

end.
