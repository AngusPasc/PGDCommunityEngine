(******************************************************************************

  Pascal Game Development Community Engine (PGDCE)

  The contents of this file are subject to the license defined in the file
  'licence.md' which accompanies this file; you may not use this file except
  in compliance with the license.

  This file is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
  either express or implied.  See the license for the specific language governing
  rights and limitations under the license.

  The Original Code is CEImageResource.pas

  The Initial Developer of the Original Code is documented in the accompanying
  help file PGDCE.chm.  Portions created by these individuals are Copyright (C)
  2014 of these individuals.

******************************************************************************)

{
@abstract(PGDCE  image resource entity unit)

Base image resource entity, loader, converter classes and linker facility

@author(George Bakhtadze (avagames@gmail.com))
}

{$I PGDCE.inc}
unit CEImageResource;

interface

uses
  CEBaseTypes, CEEntity, CEResource, CEBaseImage;

type
  // Resource class for image data
  TCEImageResource = class(TCEResource)
  private
    // Image width
    FWidth,
    // Image height
    FHeight: Integer;
    // Number of mip levels required by user
    FRequestedLevels,
    // Suggested number of mip levels based on dimensions
    FSuggestedLevels,
    // Number of bits per pixel
    FBitsPerPixel: Integer;
    // Information about mip levels
    FLevels: PImageLevels;
    // Mip levels policy
    FMipPolicy: TMipPolicy;

    procedure SetMipPolicy(const Value: TMipPolicy);
    function GetActualLevels: Integer;
    // Images with generated mipmaps needs less space in storage stream
    function GetStoredDataSize: Integer; override;
    // Returns information about specified mip level
    function GetLevelInfo(Index: Integer): PImageLevel;
  public
    // Creates an empty image with the specified dimensions
    procedure CreateEmpty(AWidth, AHeight: Integer);
    // Sets width and height of the image. Data should be initialized. deprecated: @Link(MinFilter)/@Link(MagFilter) will be used to resize.
    procedure SetDimensions(AWidth, AHeight: Integer);
    // Generates mip data
    procedure GenerateMipLevels(ARect: CEBaseTypes.TRect);

    // Image width
    property Width: Integer read FWidth;
    // Image height
    property Height: Integer read FHeight;
    // Mip levels policy
    property MipPolicy: TMipPolicy read FMipPolicy write SetMipPolicy;
    // Suggested mip levels
    property SuggestedLevels: Integer read FSuggestedLevels;
    // Actual number of mip levels
    property ActualLevels: Integer read GetActualLevels;
    // Mip levels information
    property LevelInfo[Index: Integer]: PImageLevel read GetLevelInfo;
  end;

implementation

uses
  CECommon, CEImageResampler;

{ TCEImageResource }

procedure TCEImageResource.SetMipPolicy(const Value: TMipPolicy);
var
  NewSize, OldSize: Integer;
  NewData: Pointer;
  NeedGenerateMips: Boolean;
  PFormat: TCEPixelFormat;
begin
  if (Value = FMipPolicy) then Exit;
  Assert(ActualLevels > 0);

  PFormat := TCEPixelFormat(Format);

  NeedGenerateMips := (FMipPolicy <> mpGenerated) and (Value = mpGenerated);

  OldSize := FLevels^[ActualLevels-1].Offset + FLevels^[ActualLevels-1].Size;// Width * Height * GetBytesPerPixel(FFormat);

  FMipPolicy := Value; // May change the value of ActualLevels

  if (GetBitsPerPixel(PFormat) = 0) or
     (FWidth = 0) or (FHeight = 0) or
     not Assigned(DataHolder.Data) then Exit;

  NewSize := FLevels^[ActualLevels-1].Offset + FLevels^[ActualLevels-1].Size;

//  if Value =  mpNoMips then NewSize := OldSize;
//  if (Value <> mpNoMips) and  then
//    NewSize := FLevels[SuggestedLevels-1].Offset + FLevels[SuggestedLevels-1].Size;

  if (NewSize <> DataHolder.Size) then
  begin
    //{$IFDEF DEBUGMODE} Log('TImageResource.SetMipPolicy: Reallocating image "' + Name + '"'); {$ENDIF}
    GetMem(NewData, NewSize);
    if NewData = nil then begin
      //Log('TImageResource.SetMipPolicy: Not enough memory', lkError);
      Exit;
    end;

    Move(DataHolder.Data^, NewData^, Min(OldSize, NewSize));
    SetAllocated(NewSize, NewData);
  end;

  if NeedGenerateMips then GenerateMipLevels(GetRect(0, 0, Width, Height));
  //SendMessage(TResourceModifyMsg.Create(Self), Self, [mfCore, mfRecipient]);
end;

function TCEImageResource.GetActualLevels: Integer;
begin
  if MipPolicy = mpNoMips then
    Result := 1
  else if FRequestedLevels = 0 then
    Result := FSuggestedLevels
  else
    Result := FRequestedLevels;
end;

function TCEImageResource.GetStoredDataSize: Integer;
begin
  Result := DataHolder.Size;
  if MipPolicy = mpGenerated then Result := Width * Height * GetBitsPerPixel(TCEPixelFormat(Format)) * BITS_IN_BYTE;
end;

function TCEImageResource.GetLevelInfo(Index: Integer): PImageLevel;
begin
  Result := FLevels^[Index];
end;

procedure TCEImageResource.CreateEmpty(AWidth, AHeight: Integer);
var PFormat: TCEPixelFormat;
begin
  PFormat := TCEPixelFormat(Format);
  if (AWidth <> 0) and (AHeight <> 0) then
  begin
    FSuggestedLevels := GetSuggestedMipLevelsInfo(AWidth, AHeight, PFormat, FLevels);
    if (GetBitsPerPixel(PFormat) <> 0) then
      Allocate(FLevels^[ActualLevels-1].Offset + FLevels^[ActualLevels-1].Size);
  end;

  FWidth  := AWidth;
  FHeight := AHeight;

  FSuggestedLevels := GetSuggestedMipLevelsInfo(FWidth, FHeight, PFormat, FLevels);

  //SendMessage(TResourceModifyMsg.Create(Self), nil, [mfCore]);
end;

procedure TCEImageResource.SetDimensions(AWidth, AHeight: Integer);
var
  NewData: Pointer;
  NewSize: Integer;
  PFormat: TCEPixelFormat;
begin
  if (FWidth = AWidth) and (FHeight = AHeight) then Exit;
  PFormat := TCEPixelFormat(Format);

  if (AWidth <> 0) and (AHeight <> 0) then
  begin
    FSuggestedLevels := GetSuggestedMipLevelsInfo(AWidth, AHeight, PFormat, FLevels);
    NewSize := FLevels^[ActualLevels-1].Offset + FLevels^[ActualLevels-1].Size;

    if Assigned(DataHolder.Data) and (DataHolder.Size <> NewSize) and (GetBitsPerPixel(PFormat) <> 0) then
    begin
      GetMem(NewData, NewSize);
      Move(DataHolder.Data^, NewData^, Min(DataHolder.Size, NewSize));
//      ResizeImage(GetRect(0, 0, Width, Height), GetRect(0, 0, AWidth, AHeight), AWidth, NewData);
      SetAllocated(NewSize, NewData);
      //{$IFDEF DEBUGMODE} Log(SysUtils.Format('%S("%S").%S: Image dimensions changed', [ClassName, Name, 'SetDimensions']), lkWarning); {$ENDIF}
    end;
  end;

  FWidth  := AWidth;
  FHeight := AHeight;

  FSuggestedLevels := GetSuggestedMipLevelsInfo(FWidth, FHeight, PFormat, FLevels);

  //SendMessage(TResourceModifyMsg.Create(Self), Self, [mfCore, mfRecipient]);
end;

procedure TCEImageResource.GenerateMipLevels(ARect: CEBaseTypes.TRect);

  procedure CorrectRect(var LRect: CEBaseTypes.TRect; Level: Integer);
  begin
    LRect.Left   := LRect.Left - Ord(Odd(LRect.Left));
    LRect.Top    := LRect.Top  - Ord(Odd(LRect.Top));
    LRect.Right  := Min(LevelInfo[Level].Width,  LRect.Right  + Ord(Odd(LRect.Right)));
    LRect.Bottom := Min(LevelInfo[Level].Height, LRect.Bottom + Ord(Odd(LRect.Bottom)));
  end;

var
  k, w, h: Integer;
  ORect, LRect, LastRect: CEBaseTypes.TRect;
  r: TCEImageResample;
  Resampler: TCEImageResampler;
begin
  if not Assigned(Data) or (FMipPolicy = mpNoMips) then Exit;

  ARect.Left   := Clamp(ARect.Left,   0, Width);
  ARect.Top    := Clamp(ARect.Top,    0, Height);
  ARect.Right  := Clamp(ARect.Right,  0, Width);
  ARect.Bottom := Clamp(ARect.Bottom, 0, Height);

  ORect := ARect;
  CorrectRect(ORect, 0);
  LRect := ARect;

  r.Format := TCEPixelFormat(Format);
  r.Filter := rfSimple2X; // TODO: create property
  r.Options := [roAllowFilterFallback];

  for k := 0 to ActualLevels-2 do begin
    CorrectRect(LRect, k);
    LastRect := LRect;
    LRect.Left   := LRect.Left   div 2;
    LRect.Top    := LRect.Top    div 2;
    LRect.Right  := LRect.Right  div 2;
    LRect.Bottom := LRect.Bottom div 2;

    r.SrcWidth := LevelInfo[k].Width;
    r.SrcHeight := LevelInfo[k].Height;
    r.DestWidth := LevelInfo[k+1].Width;
    r.DestHeight := LevelInfo[k+1].Height;
    r.Area := @LRect;


    w := LRect.Right  - LRect.Left;
    h := LRect.Bottom - LRect.Top;

    if (w = 0) and (h = 0) then Break;
    w := Max(1, w);
    h := Max(1, h);

    Resampler := GetImageResampler(r);
    if not Assigned(Resampler) and (roAllowFilterFallback in r.Options) then
    begin
      Include(r.Options, roIgnoreFilter);
      Resampler := GetImageResampler(r);
      Exclude(r.Options, roIgnoreFilter);
    end;

    if Assigned(Resampler) then
      Resampler.Resample(r, PtrOffs(Data, LevelInfo[k].Offset), PtrOffs(Data, LevelInfo[k+1].Offset))
    else
      ;//TODO log
  end;

//  {$IFDEF DEBUGMODE} Log('TImageResource.GenerateMipLevels: Image "' + Name + '"'); {$ENDIF}

//  SendMessage(TResourceModifyMsg.Create(Self), Self, [mfCore, mfRecipient]);
end;

end.
