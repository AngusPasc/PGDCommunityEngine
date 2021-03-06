(******************************************************************************

  Pascal Game Development Community Engine (PGDCE)

  The contents of this file are subject to the license defined in the file
  'licence.md' which accompanies this file; you may not use this file except
  in compliance with the license.

  This file is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
  either express or implied.  See the license for the specific language governing
  rights and limitations under the license.

  The Original Code is CEOpenGL.pas

  The Initial Developer of the Original Code is documented in the accompanying
  help file PGDCE.chm.  Portions created by these individuals are Copyright (C)
  2014 of these individuals.

******************************************************************************)

{
@abstract(PGDCE OpenGL common classes and utilities)

The unit contains OpenGL related classes and utilities which will be used in more specific renderers

@author(<INSERT YOUR NAME HERE> (<INSERT YOUR EMAIL ADDRESS OR WEBSITE HERE>))
}

{$Include PGDCE.inc}
unit CEOpenGL;

interface

uses
  CEBaseTypes, CEEntity, CEBaseApplication, CEBaseRenderer, CEMesh, CEMaterial,
  {$IFDEF GLES20}
    {$IFDEF OPENGLES_EMULATION}
    GLES20Regal,
    {$ELSE}
    gles20,
    {$ENDIF}
  {$ELSE}
    {$IFDEF XWINDOW}
   xlib,
    {$ENDIF}
    dglOpenGL,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  {!}CETemplate, CEIO, CEDataDecoder, CEUniformsManager;

type
  TGLSLIdentKind = (gliAttribute, gliUniform, gliVarying, gliSampler);

  TCEGLSLShader = class
  private
    procedure AddIdent(Kind: TCEShaderIdentKind; const Name: TCEShaderSource; const TypeName: TCEShaderSource);
    function Parse(const src: TCEShaderSource): Integer;
  public
    VertexShader, FragmentShader, ShaderProgram: Integer;
    Idents: array[TGLSLIdentKind] of PCEShaderIdentList;
    Capacities, Counts: array[TGLSLIdentKind] of Integer;
    constructor Create();
    destructor Destroy(); override;
    procedure SetVertexShader(ShaderId: Integer; const Source: TCEShaderSource);
    procedure SetFragmentShader(ShaderId: Integer; const Source: TCEShaderSource);
  end;

  TCEDataDecoderGLSL = class(TCEDataDecoder)
  protected
    function DoDecode(Stream: TCEInputStream; var Entity: TCEBaseEntity; const Target: TCELoadTarget;
                      MetadataOnly: Boolean): Boolean; override;
    procedure Init; override;
  end;

  _VectorValueType = TCEGLSLShader;
  {$MESSAGE 'Instantiating TGLSLShaderList interface'}
  {$I tpl_coll_vector.inc}
  // GLSL shader list
  TGLSLShaderList = _GenVector;

  // Abstract class containing common OpenGL based routines
  TCEBaseOpenGLRenderer = class(TCEBaseRenderer)
  private
  protected
    {$IFDEF WINDOWS}
    FOGLContext: HGLRC;                    // OpenGL rendering context
    FOGLDC: HDC;
    FRenderWindowHandle: HWND;
    {$ENDIF}
    {$IFDEF XWINDOW}
    FOGLContext: GLXContext;
    FDisplay: PXDisplay;
    FRenderWindowHandle: Cardinal;
    {$ENDIF}

    Shaders: TGLSLShaderList;
    CurShader: TCEGLSLShader;

    procedure DoInit; override;
    function DoInitGAPI(App: TCEBaseApplication): Boolean; override;
    procedure DoFinalizeGAPI(); override;
    function DoInitGAPIPlatform(App: TCEBaseApplication): Boolean; virtual; abstract;
    procedure DoFinalizeGAPIPlatform(); virtual; abstract;
    procedure DoNextFrame(); override;

    function InitShader(Pass: TCERenderPass): Integer;
  public
    procedure ApplyRenderPass(Pass: TCERenderPass); override;
    procedure RenderMesh(Mesh: TCEMesh); override;
    procedure Clear(Flags: TCEClearFlags; Color: TCEColor; Z: Single; Stencil: Cardinal); override;
  end;

  TCEOpenGLUniformsManager = class(TCEUniformsManager)
  public
    ShaderProgram: Integer;
    procedure SetInteger(const Name: PAPIChar; Value: Integer); override;
    procedure SetSingle(const Name: PAPIChar; Value: Single); override;
    procedure SetSingleVec2(const Name: PAPIChar; const Value: TCEVector2f); override;
    procedure SetSingleVec3(const Name: PAPIChar; const Value: TCEVector3f); override;
    procedure SetSingleVec4(const Name: PAPIChar; const Value: TCEVector4f); override;
  end;

  TCEOpenGLBufferManager = class(TCERenderBufferManager)
  private
    TmpData: array[Boolean] of Pointer;
  protected
    procedure ApiAddBuffer(Index: Integer); override;
    function ApiMapBuffer(const Status: TCEDataStatus; ElementsCount: Integer; Discard: Boolean): Pointer; override;
    procedure ApiUnmapBuffer(const Status: TCEDataStatus; ElementsCount: Integer; Data: Pointer); override;

    property Buffers: PCEDataBufferList read FBuffers;
  public
    constructor Create();
    destructor Destroy(); override;
  end;

  function CheckShaderInfoLog(Shader: TGLUint; const ShaderType: string): Boolean;
  function ReportGLErrorDebug(const ErrorLabel: string): Cardinal; {$I inline.inc}
  function ReportGLError(const ErrorLabel: string): Cardinal; {$I inline.inc}

  function GetGLType(Value: TAttributeDataType): GLenum;

implementation

uses
  SysUtils, CEStrUtils, CEResource, CEBaseImage, CEImageResource, CELog, CECommon;

const
  SAMPLER_PREFIX = 'SAMPLER';
  GROW_STEP = 1;

  {$IF NOT DECLARED(PGLchar)}
type
  PGLchar = PAnsiChar;
  {$IFEND}

{$MESSAGE 'Instantiating TGLSLShaderList'}
{$I tpl_coll_vector.inc}

const
  LOGTAG = 'ce.render';

function CheckShaderInfoLog(Shader: TGLUint; const ShaderType: string): Boolean;
var
  len, Success: TGLint;
  Buffer: PGLchar;
begin
  Result := True;
  glGetShaderiv(Shader, GL_COMPILE_STATUS, @Success);
  if Success <> GL_TRUE then
  begin
    Result := False;
    glGetShaderiv(Shader, GL_INFO_LOG_LENGTH, @len);
    if len > 0 then
    begin
      GetMem(Buffer, len + 1);
      glGetShaderInfoLog(Shader, len, {$IFDEF GLES20}@{$ENDIF}len, Buffer);
      CELog.Error(ShaderType + ': ' + string(Buffer));
      FreeMem(Buffer);
    end;
  end;
end;

// Check and report to log OpenGL error only if debug mode is on
function ReportGLErrorDebug(const ErrorLabel: string): Cardinal; {$I inline.inc}
begin
  Result := GL_NO_ERROR;
  {$IFDEF CE_DEBUG}{$IFDEF OPENGL_ERROR_CHECK}
  Result := glGetError();
  if Result <> GL_NO_ERROR then
    CELog.Error(ErrorLabel + ' Error #: ' + IntToStr(Result) + '(' + string(gluErrorString(Result)) + ') at');//#13#10) + GetStackTraceStr(1));
  {$ENDIF}{$ENDIF}
end;

// Check and report to log OpenGL error
function ReportGLError(const ErrorLabel: string): Cardinal; {$I inline.inc}
begin
  {$IFDEF OPENGL_ERROR_CHECK}
  Result := glGetError();
  if Result <> GL_NO_ERROR then
    CELog.Error(ErrorLabel + ' Error #: ' + IntToStr(Result) + '(' + string(gluErrorString(Result)) + ')');
  {$ELSE}
  Result := GL_NO_ERROR;
  {$ENDIF}
end;

function GetIdentKind(const word: TCEShaderSource): TCEShaderIdentKind;
begin
  if word = 'UNIFORM' then
    Result := ikUNIFORM
  else if word = 'ATTRIBUTE' then
    Result := ikATTRIBUTE
  else if word = 'VARYING' then
    Result := ikVARYING
  else
    Result := ikINVALID;
end;

function isPrecision(const word: TCEShaderSource): Boolean;
begin
  Result := (word = 'LOWP') or (word = 'MEDIUMP') or (word = 'HIGHP');
end;

procedure TCEGLSLShader.AddIdent(Kind: TCEShaderIdentKind; const Name: TCEShaderSource; const TypeName: TCEShaderSource);
var
  glKind: TGLSLIdentKind;
begin
  case Kind of
    ikUNIFORM:
      if StartsWith(UpperCase(TypeName), SAMPLER_PREFIX) then
        glKind := gliSampler
      else
        glKind := gliUniform;
    ikATTRIBUTE: glKind := gliAttribute;
    ikVARYING: glKind := gliVarying;
    else
      raise ECEInvalidArgument.Create('Invalid shader ident kind');
  end;
  if Capacities[glKind] <= Counts[glKind] then
  begin
    Inc(Capacities[glKind], GROW_STEP);
    ReallocMem(Idents[glKind], Capacities[glKind] * SizeOf(TCEShaderIdent));
    Initialize(Idents[glKind]^[Capacities[glKind] - GROW_STEP], GROW_STEP);
  end;
  Idents[glKind]^[Counts[glKind]].Kind    := Kind;
  Idents[glKind]^[Counts[glKind]].TypeStr := TypeName;
  Idents[glKind]^[Counts[glKind]].Name    := Name;
  Inc(Counts[glKind]);
end;

function TCEGLSLShader.Parse(const src: TCEShaderSource): Integer;
var
  i, j, LineCount, wc: Integer;
  Lines, Words: TStringArray;
  Kind: TCEShaderIdentKind;
begin
  Kind := ikINVALID;
  Result := 0;
  LineCount := Split(src, ';', Lines, False);
  for i := 0 to LineCount - 1 do
  begin
    wc := Split(Lines[i], ' ', Words, False);
    j := 0;
    while j < wc - 2 do
    begin
      Kind := GetIdentKind(UpperCase(Trim(Words[j])));
      if Kind <> ikINVALID then
        Break;
      Inc(j);
    end;
    if j < wc - 2 then
    begin
      if isPrecision(UpperCase(Trim(Words[j + 1]))) then
      begin
        Inc(j);
      end;
      if j < wc - 2 then
      begin
        AddIdent(Kind, Trim(Words[j + 2]), Trim(Words[j + 1]));
        Inc(Result);
      end;
    end;
  end;
end;

constructor TCEGLSLShader.Create;
begin
  VertexShader   := ID_NOT_INITIALIZED;
  FragmentShader := ID_NOT_INITIALIZED;
  ShaderProgram  := ID_NOT_INITIALIZED;
end;

destructor TCEGLSLShader.Destroy;
var
  i: TGLSLIdentKind;
begin
  for i := Low(TGLSLIdentKind) to High(TGLSLIdentKind) do
    if Counts[i] > 0 then begin
      Finalize(Idents[i]^[0], Capacities[i]);
      FreeMem(Idents[i]);
    end;
  inherited;
end;

procedure TCEGLSLShader.SetVertexShader(ShaderId: Integer; const Source: TCEShaderSource);
begin
  if VertexShader <> ID_NOT_INITIALIZED then Exit;
  VertexShader := ShaderId;
  Parse(Source);
end;

procedure TCEGLSLShader.SetFragmentShader(ShaderId: Integer; const Source: TCEShaderSource);
begin
  if FragmentShader <> ID_NOT_INITIALIZED then Exit;
  FragmentShader := ShaderId;
  Parse(Source);
end;

{ TCEDataDecoderGLSL }

function TCEDataDecoderGLSL.DoDecode(Stream: TCEInputStream; var Entity: TCEBaseEntity; const Target: TCELoadTarget;
    MetadataOnly: Boolean): Boolean;
const
  BufSize = 1024;
var
  Buf: array[0..BufSize - 1] of AnsiChar;
  Len: Integer;
  Res: TCETextResource;
  Str: UnicodeString;
begin
  Result := False;
  if not Assigned(Entity) then
    Entity := TCETextResource.Create();
  if not (Entity is TCETextResource) then
    raise ECEInvalidArgument.Create('Entity must be TCETextResource descendant');

  Res := TCETextResource(Entity);
  Res.Text := '';
  Len := Stream.Read(Buf, BufSize);
  while Len > 0 do
  begin
    if Res.Text = '' then
      Res.SetBuffer(PAnsiChar(@Buf[0]), Len)
    else begin
      SetString(Str, PAnsiChar(@Buf[0]), Len div SizeOf(Buf[0]));
      Res.Text := Res.Text + AnsiString(Str);
    end;
    Len := Stream.Read(Buf, BufSize);
  end;
  Result := true;
end;

procedure TCEDataDecoderGLSL.Init;
begin
  SetLength(FLoadingTypes, 1);
  FLoadingTypes[0] := GetDataTypeFromExt('glsl');
end;

function CompileShader(Handle: TGLuint; const Source: PAnsiChar; const ErrorTitle: string): Boolean;
begin
  glShaderSource(Handle, 1, @Source, nil);
  glCompileShader(Handle);
  Result := CheckShaderInfoLog(Handle, ErrorTitle);
end;

const
  ShaderErrorTitle: array[Boolean] of String = ('fragment shader', 'vertex shader');

function CreateShader(ShaderType: TGLenum; const Source: PAnsiChar): TGLuint;
begin
  Result := glCreateShader(ShaderType);
  if not CompileShader(Result, Source, ShaderErrorTitle[ShaderType = GL_VERTEX_SHADER]) then
    Result := 0;
end;

procedure LinkShader(const Shader: TCEGLSLShader);
begin
  glAttachShader(Shader.ShaderProgram, Shader.VertexShader);
  glAttachShader(Shader.ShaderProgram, Shader.FragmentShader);
  glLinkProgram(Shader.ShaderProgram);
end;

procedure UpdateShader(Pass: TCERenderPass; const Shader: TCEGLSLShader);
var Updated: Boolean;
begin
  Updated := true;
  if (ufVertexShader in Pass.UpdateFlags) and (Shader.VertexShader > 0) then
  begin
    CELog.Info(Pass.Name + ': updating ' + ShaderErrorTitle[true]);
    Updated := Updated and CompileShader(Shader.VertexShader, PAnsiChar(Pass.VertexShader.Text), ShaderErrorTitle[true]);
  end;
  if (ufFragmentShader in Pass.UpdateFlags) and (Shader.FragmentShader > 0) then
  begin
    CELog.Info(Pass.Name + ': updating ' + ShaderErrorTitle[false]);
    Updated := Updated and CompileShader(Shader.FragmentShader, PAnsiChar(Pass.FragmentShader.Text), ShaderErrorTitle[false]);
  end;
  Pass.ResetUpdateFlags();
  if Updated then LinkShader(Shader);
  ReportGLErrorDebug('Update shader');
end;

{ TCEBaseOpenGLRenderer }

procedure TCEBaseOpenGLRenderer.DoInit;
type
  TLib = PWideChar;
begin
  {$IFDEF GLES20}
    {$IFDEF WINDOWS}
    LoadGLESv2(TLib(GetPathRelativeToFile(ParamStr(0), '../Library/regal/regal32.dll')));
    {$ELSE}
    {$ENDIF}
  {$ELSE}
    dglOpenGL.InitOpenGL();
    dglOpenGL.ReadExtensions();
  {$ENDIF}
end;

function TCEBaseOpenGLRenderer.DoInitGAPI(App: TCEBaseApplication): Boolean;
begin
  Result := False;
  Shaders := TGLSLShaderList.Create();
  if not DoInitGAPIPlatform(App) then Exit;
  CELog.Log(LOGTAG, 'Graphics API succesfully initialized');

  FUniformsManager := TCEOpenGLUniformsManager.Create();
  FBufferManager := TCEOpenGLBufferManager.Create();

  // Init GL settings
  glClearColor(0, 0, 0, 0);
  glEnable(GL_TEXTURE_2D);
  glCullFace(GL_BACK);
  glEnable(GL_CULL_FACE);
  glDepthFunc(GL_LEQUAL);
  glEnable(GL_DEPTH_TEST);
  glDisable(GL_STENCIL_TEST);

  Result := True;
end;

function FreeCallback(const e: TCEGLSLShader; Data: Pointer): Boolean;
begin
  if Assigned(e) then e.Free();
  Result := True;
end;

procedure TCEBaseOpenGLRenderer.DoFinalizeGAPI();
begin
  DoFinalizeGAPIPlatform();

  Shaders.ForEach(FreeCallback, nil);
  Shaders.Free();
  Shaders := nil;
end;

procedure TCEBaseOpenGLRenderer.DoNextFrame();
begin
  {$IFDEF WINDOWS}
  SwapBuffers(FOGLDC);                  // Display the scene
  {$ENDIF}
  {$IFDEF XWINDOW}
  glXSwapBuffers(FDisplay, FRenderWindowHandle);
  {$ENDIF}
end;

function TCEBaseOpenGLRenderer.InitShader(Pass: TCERenderPass): Integer;
var
  Sh: TCEGLSLShader;
begin
  Sh := TCEGLSLShader.Create();
  Sh.ShaderProgram  := glCreateProgram();
  Sh.VertexShader   := CreateShader(GL_VERTEX_SHADER,   PAnsiChar(Pass.VertexShader.Text));
  Sh.FragmentShader := CreateShader(GL_FRAGMENT_SHADER, PAnsiChar(Pass.FragmentShader.Text));
  if (sh.VertexShader = 0) or (sh.FragmentShader = 0) then
  begin
    Warning('Error initializing shader');
    Sh.Free();
    Result := ID_NOT_INITIALIZED;
    Exit;
  end;
  LinkShader(Sh);
  Shaders.Add(Sh);
  Result := Shaders.Count - 1;
  Log('Shader successfully initialized');
end;

procedure UpdateTexture(Image: TCEImageResource; TexId: glUint);
var
  GLFormat: GLenum;
  BpP: Integer;
begin
  if (TexId > 0) then
  begin
    GLFormat := GL_RGBA;
    BpP := GetBitsPerPixel(TCEPixelFormat(Image.Format));
    if BpP >= 8 then begin
      glBindTexture(GL_TEXTURE_2D, TexId);
      case TCEPixelFormat(Image.Format) of
        pfR8G8B8: GLFormat := GL_RGB;
        pfA8R8G8B8: GLFormat := GL_RGBA;
        pfR5G6B5: GLFormat := GL_RGB565;
        pfR5G5B5: GLFormat := GL_RGB5;
        pfA1R5G5B5: GLFormat := GL_RGB5_A1;
        pfA4R4G4B4: GLFormat := GL_RGBA4;
        pfB8G8R8: GLFormat := GL_BGR;
        pfB8G8R8A8: GLFormat := GL_BGRA;
        pfA1B5G5R5: GLFormat := GL_RGBA4;
        else CELog.Error('UpdateTexture: Unsupported image format: ' + IntToStr(Image.Format));
      end;
      glTexImage2D(GL_TEXTURE_2D, 0, BpP div 8, Image.Width, Image.Height, 0, GLFormat, GL_UNSIGNED_BYTE, Image.Data);
    end;
  end;
end;

function InitTexture(Image: TCEImageResource): glUint;
begin
  Result := 0;
  if not Assigned(Image) then Exit;
  glGenTextures(1, @Result);
  UpdateTexture(Image, Result);
end;

procedure TCEBaseOpenGLRenderer.ApplyRenderPass(Pass: TCERenderPass);
var
  TexId, PrId: Integer;
  Sh: TCEGLSLShader;

begin
  PrId := CEMaterial._GetProgramId(Pass);
  if PrId = ID_NOT_INITIALIZED then
  begin
    PrId := InitShader(Pass);
    CEMaterial._SetProgramId(Pass, PrId);
  end;
  if PrId >= 0 then
  begin
    Sh := Shaders.Get(PrId);
    if Pass.UpdateFlags * [ufVertexShader, ufFragmentShader] <> [] then
      UpdateShader(Pass, Sh);
    glUseProgram(Sh.ShaderProgram);
    {PhaseLocation := glGetUniformLocation(Sh.ShaderProgram, 'phase');
    if PhaseLocation < 0 then begin
      CELog.Error('Error: Cannot get phase shader uniform location');
    end;}
    //glUniform1i(glGetUniformLocation(Sh.ShaderProgram, 's_texture0'), 0);
    CurShader := Sh;
  end;

  TexId := CEMaterial._GetTextureId(Pass, 0);
  if TexId <> ID_NOT_INITIALIZED then
  begin
    if Pass.UpdateFlags * [ufTexture0] <> [] then
      UpdateTexture(Pass.Texture0, TexId);
    glBindTexture(GL_TEXTURE_2D, TexId)
  end else begin
    TexId := InitTexture(Pass.Texture0);
    CEMaterial._SetTextureId(Pass, 0, TexId);
  end;

  {$IFNDEF GLES20}
  glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
  if Assigned(Pass.Texture0) then
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, Pass.Texture0.ActualLevels);
  {$ENDIF}
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glActiveTexture(GL_TEXTURE0);
  glEnable(GL_TEXTURE_2D);

  if Pass.AlphaBlending then
  begin
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  end;

  ReportGLErrorDebug('Pass');
end;

procedure TCEBaseOpenGLRenderer.RenderMesh(Mesh: TCEMesh);
var
  i: Integer;
  VertexData, IndexData: PCEMeshData;
  Destinations: TDataDestinations;
  VBOffset: Cardinal;

function GetAttributeDataSize(const Attribute: TAttributeData): Cardinal; {$I inline.inc}
begin
  Result := Attribute.Count;
  case Attribute.DataType of
    //adtShortint, adtByte: Result := Attribute.Count;
    adtSmallint, adtWord: Result := Attribute.Count * 2;
    adtSingle: Result := Attribute.Count * 4;
  end;
end;

begin
  Assert(Assigned(Mesh));
  if not Active then Exit;

  IndexData := nil;
  if Mesh.IndicesCount > 0 then
  begin
    IndexData := CEMesh.GetBuffer(Mesh, dbtIndex);
    Destinations[dbtIndex] := FBufferManager.MapBuffer(Mesh.IndicesCount, IndexData^.Size, IndexData^.Status);
  end;

  VertexData := CEMesh.GetBuffer(Mesh, dbtVertex1);
  Destinations[dbtVertex1] := FBufferManager.MapBuffer(Mesh.VerticesCount, VertexData^.Size, VertexData^.Status);
  if not Assigned(Destinations[dbtVertex1]) then
    Exit;

  Mesh.WriteMeshData(@Destinations);
  FBufferManager.UnMapBuffer(VertexData^.Status, Mesh.VerticesCount, Destinations[dbtVertex1]);
  Assert(Mesh.VerticesCount >= Mesh.PrimitiveCount, 'Inconsistent state of mesh: ' + Mesh.Name);

  if Assigned(CurShader) then
  begin
    // glDrawElements() doesn't allow to specify starting vertex so adding offset here. May be glDrawElementsBaseVertex() is better option.
    VBOffset := VertexData^.Status.Offset * VertexData^.Size;
    for i := 0 to VertexData^.VertexAttribsCount - 1 do
    begin
      Assert(glGetAttribLocation(CurShader.ShaderProgram, VertexData^.VertexAttribs^[i].Name) = i, 'Attribute index mismatch: ' + IntToStr(i));
      glEnableVertexAttribArray(i);
      glVertexAttribPointer(i, VertexData^.VertexAttribs^[i].Count, GetGLType(VertexData^.VertexAttribs^[i].DataType),
                            {$IFDEF GLES20}GL_FALSE{$ELSE}false{$ENDIF},
                            VertexData^.Size, PtrOffs(nil, VBOffset));
      Inc(VBOffset, GetAttributeDataSize(VertexData^.VertexAttribs^[i]));
    end;

    TCEOpenGLUniformsManager(FUniformsManager).ShaderProgram := CurShader.ShaderProgram;
    Mesh.SetUniforms(FUniformsManager);

    if Mesh.IndicesCount > 0 then
    begin
      FBufferManager.UnMapBuffer(IndexData^.Status, Mesh.IndicesCount, Destinations[dbtIndex]);
      case Mesh.PrimitiveType of
        ptPointList: glDrawElements(GL_POINTS, Mesh.PrimitiveCount, GL_UNSIGNED_SHORT, PtrOffs(nil, IndexData^.Status.Offset));
        ptLineList: glDrawElements(GL_LINES, Mesh.PrimitiveCount * 2, GL_UNSIGNED_SHORT, PtrOffs(nil, IndexData^.Status.Offset));
        ptLineStrip: glDrawElements(GL_LINE_STRIP, Mesh.PrimitiveCount + 1, GL_UNSIGNED_SHORT, PtrOffs(nil, IndexData^.Status.Offset));
        ptTriangleList: glDrawElements(GL_TRIANGLES, Mesh.PrimitiveCount * 3, GL_UNSIGNED_SHORT, PtrOffs(nil, IndexData^.Status.Offset));
        ptTriangleStrip: glDrawElements(GL_TRIANGLE_STRIP, Mesh.PrimitiveCount + 2, GL_UNSIGNED_SHORT, PtrOffs(nil, IndexData^.Status.Offset));
        ptTriangleFan: glDrawElements(GL_TRIANGLE_FAN, Mesh.VerticesCount, GL_UNSIGNED_SHORT, PtrOffs(nil, IndexData^.Status.Offset));
        ptQuads:;
      end
    end else
      case Mesh.PrimitiveType of
        ptPointList: glDrawArrays(GL_POINTS, 0, Mesh.PrimitiveCount);
        ptLineList: glDrawArrays(GL_LINES, 0, Mesh.PrimitiveCount * 2);
        ptLineStrip: glDrawArrays(GL_LINE_STRIP, 0, Mesh.PrimitiveCount + 1);
        ptTriangleList: glDrawArrays(GL_TRIANGLES, 0, Mesh.PrimitiveCount * 3);
        ptTriangleStrip: begin
          glDrawArrays(GL_TRIANGLE_STRIP, 0, Mesh.PrimitiveCount + 2);
          //glPointSize(4);
          //glDrawArrays(GL_POINTS, VertexData^.Status.Offset, Mesh.PrimitiveCount + 2);
        end;
        ptTriangleFan: glDrawArrays(GL_TRIANGLE_FAN, 0, Mesh.VerticesCount);
        ptQuads:;
      end;
  end;
end;

function GetGLType(Value: TAttributeDataType): GLenum;
begin
  Result := GL_FLOAT;
  case Value of
    adtShortint: Result := GL_BYTE;
    adtByte: Result := GL_UNSIGNED_BYTE;
    adtSmallint: Result := GL_SHORT;
    adtWord: Result := GL_UNSIGNED_SHORT;
    adtSingle: Result := GL_FLOAT;
  end;
end;

procedure TCEBaseOpenGLRenderer.Clear(Flags: TCEClearFlags; Color: TCEColor; Z: Single; Stencil: Cardinal);
begin
  if (Flags = []) or not Active then Exit;

  {$IFDEF GLES20}
  glDepthMask(GL_TRUE);
  glClearDepthf(Z);
  {$ELSE}
  glDepthMask(True);
  glClearDepth(Z);
  {$ENDIF}
  glClearColor(Color.R * ONE_OVER_255, Color.G * ONE_OVER_255, Color.B * ONE_OVER_255, Color.A * ONE_OVER_255);
  glClearStencil(Stencil);

  glClear(GL_COLOR_BUFFER_BIT * Ord(cfColor in Flags) or GL_DEPTH_BUFFER_BIT * Ord(cfDepth in Flags) or
          GL_STENCIL_BITS * Ord(cfStencil in Flags));
end;

{ TCEOpenGLES2UniformsManager }

function GetUniformLocation(ShaderProgram: Integer; const Name: PAPIChar): Integer;
begin
  Result := glGetUniformLocation(ShaderProgram, Name);
  if Result < 0 then
    CELog.Warning(LOGTAG, 'Can''t find uniform location for name: ' + Name);
end;

procedure TCEOpenGLUniformsManager.SetInteger(const Name: PAPIChar; Value: Integer);
begin
  glUniform1i(GetUniformLocation(ShaderProgram, Name), Value);
end;

procedure TCEOpenGLUniformsManager.SetSingle(const Name: PAPIChar; Value: Single);
begin
  glUniform1f(GetUniformLocation(ShaderProgram, Name), Value);
end;

procedure TCEOpenGLUniformsManager.SetSingleVec2(const Name: PAPIChar; const Value: TCEVector2f);
begin
  glUniform2f(GetUniformLocation(ShaderProgram, Name), Value.x, Value.y);
end;

procedure TCEOpenGLUniformsManager.SetSingleVec3(const Name: PAPIChar; const Value: TCEVector3f);
begin
  glUniform3f(GetUniformLocation(ShaderProgram, Name), Value.x, Value.y, Value.z);
end;

procedure TCEOpenGLUniformsManager.SetSingleVec4(const Name: PAPIChar; const Value: TCEVector4f);
begin
  glUniform4f(GetUniformLocation(ShaderProgram, Name), Value.x, Value.y, Value.z, Value.w);
end;

{ TCEOpenGLBufferManager }

function IsIndexBuffer(Usage: TCEDataUsage): Boolean; {$I inline.inc}
begin
  Result := (Usage = duStaticIndices) or (Usage = duStreamingIndices);
end;

function GetBufferType(Usage: TCEDataUsage): Cardinal; {$I inline.inc}
const
  BUFFER_TYPE: array[Boolean] of Cardinal = (GL_ARRAY_BUFFER, GL_ELEMENT_ARRAY_BUFFER);
begin
  Result := BUFFER_TYPE[IsIndexBuffer(Usage)];
end;

const
  BUFFER_USAGE: array[Boolean] of Cardinal = (GL_STATIC_DRAW, GL_STREAM_DRAW);

procedure TCEOpenGLBufferManager.ApiAddBuffer(Index: Integer);
begin
  Assert((Index >= 0) and (Index < Count), 'Invalid index');
  glGenBuffers(1, @FBuffers^[Index].Id);
  glBindBuffer(GetBufferType(FBuffers^[Index].DataUsage), FBuffers^[Index].Id);
  glBufferData(GetBufferType(FBuffers^[Index].DataUsage), DATA_BUFFER_SIZE_DYNAMIC * FBuffers^[Index].ElementSize, nil,
    BUFFER_USAGE[FBuffers^[Index].DataUsage >= duStreamingIndices]);
  ReportGLError('AddBuffer');
end;

function TCEOpenGLBufferManager.ApiMapBuffer(const Status: TCEDataStatus; ElementsCount: Integer; Discard: Boolean): Pointer;
begin
  glBindBuffer(GetBufferType(FBuffers^[Status.BufferIndex].DataUsage), FBuffers^[Status.BufferIndex].Id);
  if Discard then
  begin
    glBufferData(GetBufferType(FBuffers^[Status.BufferIndex].DataUsage), FBuffers^[Status.BufferIndex].Size * FBuffers^[Status.BufferIndex].ElementSize,
      nil, BUFFER_USAGE[FBuffers^[Status.BufferIndex].DataUsage >= duStreamingIndices]);
    CELog.Debug('Discarding buffer #' + IntToStr(Status.BufferIndex));
  end;
  Result := TmpData[IsIndexBuffer(FBuffers^[Status.BufferIndex].DataUsage)];
end;

procedure TCEOpenGLBufferManager.ApiUnmapBuffer(const Status: TCEDataStatus; ElementsCount: Integer; Data: Pointer);
begin
  glBufferSubData(GetBufferType(FBuffers^[Status.BufferIndex].DataUsage), Status.Offset * FBuffers^[Status.BufferIndex].ElementSize,
    ElementsCount * FBuffers^[Status.BufferIndex].ElementSize, Data);
  ReportGLError('SubData');
end;

constructor TCEOpenGLBufferManager.Create();
begin
  GetMem(TmpData[false], DATA_BUFFER_SIZE_DYNAMIC * DATA_VERTEX_BUFFER_ELEMENT_MAX_SIZE);
  GetMem(TmpData[true], DATA_BUFFER_SIZE_DYNAMIC * DATA_INDEX_BUFFER_ELEMENT_MAX_SIZE);
end;

destructor TCEOpenGLBufferManager.Destroy();
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    glDeleteBuffers(1, @FBuffers^[i].Id);
  if Assigned(TmpData[false]) then
    FreeMem(TmpData[false]);
  if Assigned(TmpData[true]) then
    FreeMem(TmpData[true]);
  inherited;
end;

initialization
  CEDataDecoder.RegisterDataDecoder(TCEDataDecoderGLSL.Create());
end.
