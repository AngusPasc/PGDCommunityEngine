(******************************************************************************

  Pascal Game Development Community Engine (PGDCE)

  The contents of this file are subject to the license defined in the file
  'licence.md' which accompanies this file; you may not use this file except
  in compliance with the license.

  This file is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
  either express or implied.  See the license for the specific language governing
  rights and limitations under the license.

  The Original Code is CEMesh.pas

  The Initial Developer of the Original Code is documented in the accompanying
  help file PGDCE.chm.  Portions created by these individuals are Copyright (C)
  2014 of these individuals.

******************************************************************************)

{
@abstract(PGDCE mesh entity unit)

The unit contains mesh entity class

@author(George Bakhtadze (avagames@gmail.com))
}

{$I PGDCE.inc}
unit CEMesh;

interface

uses
  CEBaseTypes, CEEntity, CEVectors, CEUniformsManager;

type
  // Primitive types
  TPrimitiveType = (ptPointList, ptLineList, ptLineStrip, ptTriangleList, ptTriangleStrip, ptTriangleFan, ptQuads);

  // Vertex attribute data types
  TAttributeDataType = (adtShortint, adtByte, adtSmallint, adtWord, adtSingle);
  // Vertex attribute data information
  TAttributeData = record
    DataType: TAttributeDataType;
    Size: Integer;
    Name: PAPIChar;
  end;
  TAttributeDataArray = array[0..$FFFF] of TAttributeData;
  PAttributeDataArray = ^TAttributeDataArray;

  {
  Encapsulates vertex data needed to render a visible entity
  }
  TCEMesh = class(TCEBaseEntity)
  protected
    VertexBuffer, IndexBuffer: TCEDataStatus;
    FVerticesCount: Integer;
    FVertexSize: Integer;
    FPrimitiveType: TPrimitiveType;
    FPrimitiveCount: Integer;                            // TODO: remove?
    FVertexAttribsCount: Integer;
    FVertexAttribs: PAttributeDataArray;
    procedure SetVertexAttribsCount(Count: Integer);
  public
    destructor Destroy; override;
    procedure DoInit(); override;
    // Fill vertex buffer
    procedure FillVertexBuffer(Dest: Pointer); virtual;
    // Fill index buffer
    procedure FillIndexBuffer(Dest: Pointer); virtual;
    // Called by renderer when uniforms for the mesh need to be set
    procedure SetUniforms(Manager: TCEUniformsManager); virtual;
    // Number of vertices in mesh
    property VerticesCount: Integer read FVerticesCount;
    // Size of each vertex in bytes
    property VertexSize: Integer read FVertexSize;
    // Primitive type
    property PrimitiveType: TPrimitiveType read FPrimitiveType;
    // Number of primitives (points, lines, triangles etc depending on PrimitiveType) in mesh
    property PrimitiveCount: Integer read FPrimitiveCount;
    // Number of vertex attributes
    property VertexAttribCount: Integer read FVertexAttribsCount;
    // Vertex attributes info
    property VertexAttribs: PAttributeDataArray read FVertexAttribs;
  end;

  // Used by renderer
  function GetVB(const Mesh: TCEMesh): PCEDataStatus; {$I inline.inc}
  // Used by renderer
  function GetIB(const Mesh: TCEMesh): PCEDataStatus; {$I inline.inc}
  procedure InitTesselationStatus(Status: PCEDataStatus); {$I inline.inc}

implementation

function GetVB(const Mesh: TCEMesh): PCEDataStatus; {$I inline.inc}
begin
  Result := @Mesh.VertexBuffer;
end;

function GetIB(const Mesh: TCEMesh): PCEDataStatus; {$I inline.inc}
begin
  Result := @Mesh.IndexBuffer;
end;

procedure InitTesselationStatus(Status: PCEDataStatus); {$I inline.inc}
begin
  Status.BufferIndex := -1;
  Status.Offset := 0;
  Status.Status := dsSizeChanged;
  Status.DataType := dtStatic;
end;

{ TCEMesh }

procedure TCEMesh.SetVertexAttribsCount(Count: Integer);
begin
  FVertexAttribsCount := Count;
  ReallocMem(FVertexAttribs, FVertexAttribsCount * SizeOf(TAttributeData));
end;

destructor TCEMesh.Destroy;
begin
  FreeMem(FVertexAttribs, FVertexAttribsCount * SizeOf(TAttributeData));
  inherited;
end;

procedure TCEMesh.DoInit();
begin
  FVerticesCount := 1;
  FVertexSize := SizeOf(TCEVector3f);
  FPrimitiveType := ptTriangleList;
  FPrimitiveCount := 1;
  InitTesselationStatus(@VertexBuffer);
  InitTesselationStatus(@IndexBuffer);
end;

procedure TCEMesh.FillVertexBuffer(Dest: Pointer);
begin
  VertexBuffer.Status := dsValid;
end;

procedure TCEMesh.FillIndexBuffer(Dest: Pointer);
begin
  IndexBuffer.Status := dsValid;
end;

procedure TCEMesh.SetUniforms(Manager: TCEUniformsManager);
begin
// do nothing
end;

end.

