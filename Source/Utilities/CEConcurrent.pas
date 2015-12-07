(******************************************************************************

  Pascal Game Development Community Engine (PGDCE)

  The contents of this file are subject to the license defined in the file
  'licence.md' which accompanies this file; you may not use this file except
  in compliance with the license.

  This file is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND,
  either express or implied.  See the license for the specific language governing
  rights and limitations under the license.

  The Original Code is CEConcurrent.pas

  The Initial Developer of the Original Code is documented in the accompanying
  help file PGDCE.chm.  Portions created by these individuals are Copyright (C)
  2014 of these individuals.

******************************************************************************)

{
@abstract(PGDCE concurrent utilities)

The unit contains concurrency related routines. Platform specific.

@author(George Bakhtadze (avagames@gmail.com))
}

{$I PGDCE.inc}
unit CEConcurrent;

interface

uses
  {$IFDEF WINDOWS}
    Windows,
    {$IFDEF NAMESPACED_UNITS} System.SyncObjs, {$ELSE} SyncObjs, {$ENDIF}
  {$ENDIF}
  {$IFDEF UNIX}
    unix, cthreads,
  {$ENDIF}
  SysUtils;

  {$IFDEF FPC}
type
  TCEMutex = TRTLCriticalSection;
  {$ENDIF}
  {$IFDEF DELPHI}
type
  TCEMutex = TCriticalSection;
  {$ENDIF}

// Thread-safe increment of the value
function AtomicIncrement(var Addend: LongInt): LongInt;
// Thread-safe decrement of the value
function AtomicDecrement(var Addend: LongInt): LongInt;
// Store Source in Target and returns the old value of Target in a thread-safe way
function AtomicExchange(var Target: LongInt; Source: LongInt): LongInt;
// Thread-safe add and exchange of values
function AtomicAddExchange(var Target: LongInt; Source: LongInt): LongInt;
// Exchanges Target with NewValue if Target and Comparand are equal. It returns the old value of Target.
function AtomicCompareExchange(var Target: LongInt; NewValue: LongInt; Comparand: LongInt): LongInt;

  procedure MutexCreate(out Mutex: TCEMutex);
  procedure MutexDelete(var Mutex: TCEMutex);
  procedure MutexEnter(var Mutex: TCEMutex);
  function MutexTryEnter(var Mutex: TCEMutex): Boolean;
  procedure MutexLeave(var Mutex: TCEMutex);

implementation

{$IFDEF FPC}

function AtomicIncrement(var Addend: LongInt): LongInt;
begin
  Result := InterlockedIncrement(Addend);
end;

function AtomicDecrement(var Addend: LongInt): LongInt;
begin
  Result := InterlockedDecrement(Addend);
end;

function AtomicExchange(var Target: LongInt; Source: LongInt): LongInt;
begin
  Result := InterLockedExchange(Target, Source);
end;

function AtomicAddExchange(var Target: LongInt; Source: LongInt): LongInt;
begin
  Result := InterLockedExchangeAdd(Target, Source);
end;

function AtomicCompareExchange(var Target: LongInt; NewValue: LongInt; Comparand: LongInt): LongInt;
begin
  Result := InterlockedCompareExchange(Target, NewValue, Comparand);
end;

procedure MutexCreate(out Mutex: TCEMutex);
begin
  InitCriticalSection(Mutex);
end;

procedure MutexDelete(var Mutex: TCEMutex);
begin
  DoneCriticalsection(Mutex);
end;

procedure MutexEnter(var Mutex: TCEMutex);
begin
  EnterCriticalsection(Mutex);
end;

function MutexTryEnter(var Mutex: TCEMutex): Boolean;
begin
  Result := TryEnterCriticalsection(Mutex) <> 0;
end;

procedure MutexLeave(var Mutex: TCEMutex);
begin
  LeaveCriticalsection(Mutex);
end;

{$ELSE}{$IFDEF WINDOWS}

function AtomicIncrement(var Addend: LongInt): LongInt;
begin
  Result := Windows.InterlockedIncrement(Addend);
end;

function AtomicDecrement(var Addend: LongInt): LongInt;
begin
  Result := Windows.InterlockedDecrement(Addend);
end;

function AtomicExchange(var Target: LongInt; Source: LongInt): LongInt;
begin
  Result := Windows.InterLockedExchange(Target, Source);
end;

function AtomicAddExchange(var Target: LongInt; Source: LongInt): LongInt;
begin
  Result := Windows.InterlockedExchangeAdd(Target, Source);
end;

function AtomicCompareExchange(var Target: LongInt; NewValue: LongInt; Comparand: LongInt): LongInt;
begin
  Result := Windows.InterlockedCompareExchange(Target, NewValue, Comparand);
end;

procedure MutexCreate(out Mutex: TCEMutex);
begin
  Mutex := TCEMutex.Create();
end;

procedure MutexDelete(var Mutex: TCEMutex);
begin
  if Assigned(Mutex) then
    Mutex.Free();
  Mutex := nil;
end;

procedure MutexEnter(var Mutex: TCEMutex);
begin
  Mutex.Enter();
end;

function MutexTryEnter(var Mutex: TCEMutex): Boolean;
begin
  Result := Mutex.TryEnter();
end;

procedure MutexLeave(var Mutex: TCEMutex);
begin
  Mutex.Leave();
end;

{$ENDIF}{$ENDIF}

end.
