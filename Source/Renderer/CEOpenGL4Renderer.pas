(******************************************************************************

  Pascal Game Development Community Engine (PGDCE)

  The contents of this file are subject to the license defined in the file
  'licence.md' which accompanies this file; you may not use this file except
  in compliance with the license.

  This file is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
  either express or implied.  See the license for the specific language governing
  rights and limitations under the license.

  The Original Code is CEOpenGL4Renderer.pas

  The Initial Developer of the Original Code is documented in the accompanying
  help file PGDCE.chm.  Portions created by these individuals are Copyright (C)
  2014 of these individuals.

******************************************************************************)

{
@abstract(PGDCE OpenGL Renderer)

Definition for the PGDCE OpenGL 4.x renderer class

@author(<INSERT YOUR NAME HERE> (<INSERT YOUR EMAIL ADDRESS OR WEBSITE HERE>))
}

{$Include PGDCE.inc}
unit CEOpenGL4Renderer;

interface

uses
  CEBaseTypes, CEBaseRenderer, CEBaseApplication, CEMesh, CEMaterial,
  dglOpenGL
  {$IFDEF WINDOWS}
  , Windows
  {$ENDIF}
  ;

type
  TCEOpenGL4Renderer = class(TCEBaseRenderer)
  private
    {$IFDEF WINDOWS}
      FOGLContext: HGLRC;                    // OpenGL rendering context
      FOGLDC: HDC;
      FRenderWindowHandle: HWND;
    {$ENDIF}
    VertexData: Pointer;
    VBO: GLUInt;
  protected
    procedure DoInit(); override;
    function DoInitGAPI(App: TCEBaseApplication): Boolean; override;
    function DoInitGAPIWin(App: TCEBaseApplication): Boolean;
    procedure DoFinalizeGAPI(); override;
    procedure DoFinalizeGAPIWin();
  public
    procedure ApplyRenderPass(Pass: TCERenderPass); override;
    procedure RenderMesh(Mesh: TCEMesh); override;
    procedure Clear(Flags: TCEClearFlags; Color: TCEColor; Z: Single; Stencil: Cardinal); override;
    procedure NextFrame(); override;
  end;

implementation

uses
  CECommon, CEVectors, CEImageResource;

{ TCEOpenGL4Renderer }

procedure TCEOpenGL4Renderer.DoInit;
begin
  dglOpenGL.InitOpenGL();
  dglOpenGL.ReadExtensions();
end;

function TCEOpenGL4Renderer.DoInitGAPI(App: TCEBaseApplication): Boolean;
begin
  Result := False;
  {$IFDEF WINDOWS}
  if not DoInitGAPIWin(App) then Exit;
  {$ELSE}
  raise Exception.Create('Not implemented for this platform');
  {$ENDIF}
  Writeln('Context succesfully created');

  // Init projection matrix
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  gluPerspective(45, 800/600, 0.1, 1000);

  // Init modelview matrix
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  // Init GL settings
  glClearColor(0, 0, 0, 0);
  glEnable(GL_TEXTURE_2D);
  glCullFace(GL_NONE);
  glDepthFunc(GL_LEQUAL);
  glEnable(GL_DEPTH_TEST);
  glEnable(GL_NORMALIZE);
  glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);

  GetMem(VertexData, 1000);

  Result := True;
end;

function TCEOpenGL4Renderer.DoInitGAPIWin(App: TCEBaseApplication): Boolean;
var
  Dummy: LongWord;
begin
  Result := False;

  Dummy  := 0;
  FRenderWindowHandle := App.Cfg.GetInt64(CFG_WINDOW_HANDLE);

  FOGLDC := GetDC(FRenderWindowHandle);
  if (FOGLDC = 0) then begin
    Writeln(ClassName + '.DoInitGAPI: Unable to get a device context');
    Exit;
  end;

  FOGLContext := CreateRenderingContext(FOGLDC, [opDoubleBuffered], 24, 16, 0, 0, 0, Dummy);

  if FOGLContext = 0 then begin
    Writeln(ClassName + '.DoInitGAPI: Error creating rendering context');
    Exit;
  end;

  ActivateRenderingContext(FOGLDC, FOGLContext);

  Result := True;
end;

procedure TCEOpenGL4Renderer.DoFinalizeGAPI();
begin
  if Assigned(VertexData) then
    FreeMem(VertexData);
  {$IFDEF WINDOWS}
  DoFinalizeGAPIWin();
  {$ELSE}
  raise Exception.Create('Not implemented for this platform');
  {$ENDIF}
end;

procedure TCEOpenGL4Renderer.DoFinalizeGAPIWin();
begin
  DeactivateRenderingContext();
  DestroyRenderingContext(FOGLContext);
  FOGLContext := 0;
  ReleaseDC(FRenderWindowHandle, FOGLDC);
  FOGLDC := 0;
end;

procedure TCEOpenGL4Renderer.Clear(Flags: TCEClearFlags; Color: TCEColor; Z: Single; Stencil: Cardinal);
begin
  if (Flags = []) or not Active then Exit;

  glDepthMask(True);
  glClearColor(Color.R * ONE_OVER_255, Color.G * ONE_OVER_255, Color.B * ONE_OVER_255, Color.A * ONE_OVER_255);
  glClearDepth(Z);
  glClearStencil(Stencil);

  glClear(GL_COLOR_BUFFER_BIT * Ord(cfColor in Flags) or GL_DEPTH_BUFFER_BIT * Ord(cfDepth in Flags) or GL_STENCIL_BITS * Ord(cfStencil in Flags));
end;

function InitTexture(Image: TCEImageResource): glUint;
begin
  glGenTextures(1, @Result);
  glBindTexture(GL_TEXTURE_2D, Result);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, Image.ActualLevels);
  glTexImage2D(GL_TEXTURE_2D, 0, 3, Image.Width, Image.Height, 0, GL_BGR, GL_UNSIGNED_BYTE, Image.Data);
end;

procedure TCEOpenGL4Renderer.ApplyRenderPass(Pass: TCERenderPass);
var TexId: Integer;
begin
  TexId := CEMaterial._GetTextureId(Pass, 0);
  if TexId = -1 then
  begin
    TexId := InitTexture(Pass.Texture0);
    CEMaterial._SetTextureId(Pass, 0, TexId);
  end;
  glBindTexture(GL_TEXTURE_2D, TexId);
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glActiveTexture(GL_TEXTURE0);
  glEnable(GL_TEXTURE_2D);
end;

procedure TCEOpenGL4Renderer.RenderMesh(Mesh: TCEMesh);
var
  ts: PTesselationStatus;
begin
  if not Active then Exit;
  ts := CEMesh.GetVB(Mesh);

  {if ts^.BufferIndex = -1 then begin  // Create buffer
    glGenBuffers(1, @VBO);
    ts^.BufferIndex := VBO;
    ts^.Status := tsMaxSizeChanged;   // Not tesselated yet as vertex buffer is just created
  end;

  glBindBuffer(GL_ARRAY_BUFFER, ts^.BufferIndex);}
  if ts^.Status <> tsTesselated then begin
    Mesh.FillVertexBuffer(VertexData);
    //glBufferData(GL_ARRAY_BUFFER, Mesh.VerticesCount * Mesh.VertexSize, VertexData, GL_STATIC_DRAW);
  end;

  {glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 3, GL_FLOAT, False, Mesh.VertexSize, nil);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 2, GL_FLOAT, False, Mesh.VertexSize, pointer(3));}

  glEnableClientState(GL_VERTEX_ARRAY);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  glTexCoordPointer(2, GL_FLOAT, Mesh.VertexSize,  ptroffs(VertexData, SizeOf(TCEVector3f)));
  glVertexPointer(3, GL_FLOAT, Mesh.VertexSize, VertexData);
  glDrawArrays(GL_TRIANGLES, 0, Mesh.VerticesCount);
end;

procedure TCEOpenGL4Renderer.NextFrame;
begin
  if not Active then Exit;
  {$IFDEF WINDOWS}
  SwapBuffers(FOGLDC);                  // Display the scene
  {$ENDIF}
end;

end.
