{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Oracle Database Connectivity Classes        }
{                                                         }
{        Originally written by Sergey Seroukhov           }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcOracleResultSet;

interface

{$I ZDbc.inc}
{$IFNDEF ZEOS_DISABLE_ORACLE}

uses
{$IFDEF USE_SYNCOMMONS}
  SynCommons, SynTable,
{$ENDIF USE_SYNCOMMONS}
  {$IFNDEF NO_UNIT_CONTNRS}Contnrs,{$ENDIF}
  {$IFDEF WITH_TOBJECTLIST_REQUIRES_SYSTEM_TYPES}System.Types{$ELSE}Types{$ENDIF},
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, FmtBCD,
  {$IF defined(UNICODE) and not defined(WITH_UNICODEFROMLOCALECHARS)}Windows,{$IFEND}
  ZSysUtils, ZDbcIntfs, ZDbcOracle, ZDbcResultSet, ZPlainOracleDriver, ZDbcCache,
  ZDbcResultSetMetadata, ZDbcLogging, ZCompatibility, ZDbcOracleUtils, ZClasses,
  ZPlainOracleConstants, ZPlainDriver, ZDbcStatement, ZDbcCachedResultSet;

type
  { Oracle Error Class}
  EZOCIConvertError = class(EZSQLException);

  IZOracleResultSet = Interface(IInterface)
    ['{114B78EC-86F8-44E0-B0F5-127BAA78D335}']
    procedure AssignColumnsInfo(const Dest: TObjectList);
  End;

  TZOracleColumnInfo = class(TZColumnInfo)
  public
    dty: ub2;
    csid: ub2;
    CharsetForm: ub1;
  end;

  {** Implements Oracle ResultSet. }
  TZOracleAbstractResultSet_A = class(TZAbstractReadOnlyResultSet_A, IZOracleResultSet)
  private
    FStmtHandle: POCIStmt;
    FErrorHandle: POCIError;
    FConnectionHandle: POCIEnv;
    FOCISvcCtx: POCISvcCtx;
    FPlainDriver: TZOraclePlainDriver;
    FConnection: IZOracleConnection;
    FColumns: PZSQLVars;
    FChunkSize: Integer;
    FIteration: Integer; //Max count of rows which fit into BufferSize <= FZBufferSize
    FCurrentRowBufIndex: Cardinal; //The current row in buffer! NOT the current row of RS
    FZBufferSize: Integer; //max size for multiple rows. If Row > Value ignore it!
    FRowsBuffer: TByteDynArray; //Buffer for multiple rows if possible which is reallocated or freed by IDE -> mem leak save!
    FTempLob: IZBlob;
    FClientCP: Word;
    fStatus: Sword;
    FvnuInfo: TZvnuInfo;
    function GetFinalObject(Obj: POCIObject): POCIObject;
    function CreateOCIConvertError(ColumnIndex: Integer; DataType: ub2): EZOCIConvertError;
  public
    constructor Create(
      const Statement: IZStatement; const SQL: string;
      StmtHandle: POCIStmt; ErrorHandle: POCIError; const ZBufferSize: Integer);
    procedure BeforeClose; override;
    function IsNull(ColumnIndex: Integer): Boolean;
    function GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar; overload;
    function GetPWideChar(ColumnIndex: Integer; out Len: NativeUInt): PWideChar; overload;
    function GetBoolean(ColumnIndex: Integer): Boolean;
    function GetInt(ColumnIndex: Integer): Integer;
    function GetUInt(ColumnIndex: Integer): Cardinal;
    function GetLong(ColumnIndex: Integer): Int64;
    function GetULong(ColumnIndex: Integer): UInt64;
    function GetFloat(ColumnIndex: Integer): Single;
    function GetDouble(ColumnIndex: Integer): Double;
    function GetCurrency(ColumnIndex: Integer): Currency;
    procedure GetBigDecimal(ColumnIndex: Integer; var Result: TBCD);
    procedure GetGUID(ColumnIndex: Integer; var Result: TGUID);
    function GetBytes(ColumnIndex: Integer; out Len: NativeUInt): PByte; overload;
    procedure GetDate(ColumnIndex: Integer; var Result: TZDate); overload;
    procedure GetTime(ColumnIndex: Integer; var Result: TZTime); overload;
    procedure GetTimestamp(ColumnIndex: Integer; var Result: TZTimeStamp); overload;
    function GetDataSet(ColumnIndex: Integer): IZDataSet; override;
    function GetBlob(ColumnIndex: Integer; LobStreamMode: TZLobStreamMode = lsmRead): IZBlob;
    {$IFDEF USE_SYNCOMMONS}
    procedure ColumnsToJSON(JSONWriter: TJSONWriter; JSONComposeOptions: TZJSONComposeOptions); reintroduce;
    {$ENDIF USE_SYNCOMMONS}
  public //implement IZOracleResultSet
    procedure AssignColumnsInfo(const Dest: TObjectList);
  end;

  TZOracleResultSet_A = class(TZOracleAbstractResultSet_A, IZResultSet)
  private
    FMaxBufIndex: Integer;
  protected
    procedure Open; override;
  public
    procedure ResetCursor; override;
    procedure BeforeClose; override;
    function Next: Boolean; reintroduce;
  end;

  TZOracleCallableResultSet_A = Class(TZOracleAbstractResultSet_A, IZResultSet)
  private
    FFieldNames: TStringDynArray;
  public
    constructor Create(
      const Statement: IZStatement; const SQL: string; StmtHandle: POCIStmt;
      ErrorHandle: POCIError; OraVariables: PZOCIParamBinds;
      {$IFDEF AUTOREFCOUNT}const{$ENDIF}BindList: TZBindList);
  protected
    procedure Open; override;
  public
    function Next: Boolean; reintroduce;
  End;

  IZOracleLob = interface(IInterface)
    ['{98115C0C-143E-4457-8D17-D45C9FB82221}']
    function GetLobLocator: POCILobLocator;
    procedure CopyLocator;
  end;

  TZAbstracOracleLobStream = class; //forward
  {** implements an abstract oracle lob }
  TZAbstractOracleBlob = class(TZAbstractStreamedLob, IZLob, IZOracleLob)
  private
    FConnection: IZOracleConnection;
    FOCIError: POCIError;
    FOCIEnv: POCIEnv;
    FOCISvcCtx: POCISvcCtx;
    FLobLocator, FParentLocator: POCILobLocator;
    Fdty: ub2;
    FCharsetForm: ub1;
    Fcsid: ub2;
    FDescriptorType: ub4;
    FOwner: IImmediatelyReleasable;
    FHas64BitLobMethods: Boolean;
    FLobStream: TZAbstracOracleLobStream;
    FplainDriver: TZOraclePlainDriver;
    FLocatorAllocated: Boolean; //need to know if we destroy the stream if the locator should be freed too
    FIsCloned: Boolean;
  protected
    function CreateLobStream(CodePage: Word; LobStreamMode: TZLobStreamMode): TStream; override;
  public
    constructor Create(const Connection: IZOracleConnection;
      LobLocator: POCILobLocator; dty: ub2; const OpenLobStreams: TZSortedList);
    destructor Destroy; override;
  public
    function GetLobLocator: POCILobLocator;
    procedure CopyLocator;
  public //implement IZLob
    function IsEmpty: Boolean; override;
    procedure Clear; override;
  public
    function Clone(LobStreamMode: TZLobStreamMode = lsmRead): IZBlob;
  public //obsolete
    function Length: Integer; override;
  end;

  {** EH: Implements external (B/C)lob or (B/C)File Stream object for Oracle.}
  TZAbstracOracleLobStream = class(TZImmediatelyReleasableLobStream)
  private
    FPlainDriver: TZOraclePlainDriver;
    FOCISvcCtx: POCISvcCtx;
    FOCIError: POCIError;
    FOCIEnv: POCIEnv;
    fchunk_size: ub4;
    Flobtype: ub1;
    fcsid: ub2;
    FOwnerLob: TZAbstractOracleBlob;
    FPosition: Int64;
    FOpenLobStreams: TZSortedList;
    FConSettings: PZConSettings;
    procedure AllocLobLocator;
    procedure BeforeWrite;
  public
    procedure CreateTemporary;
    function IsOpen: LongBool;
    function IsTemporary: LongBool;
    procedure FreeTemporary;
    procedure CopyLocator;
    procedure FreeLocator;
    procedure Open;
    procedure Close;
    procedure CopyLob;
  public
    constructor Create(LobLocator: POCILobLocator; const OwnerLob: TZAbstractOracleBlob;
      const Owner: IImmediatelyReleasable; const OpenLobStreams: TZSortedList);
    Destructor Destroy; override;
  end;

  {** EH: implements a 32 bit stream for large objects }
  TZOracleLobStream32 = class(TZAbstracOracleLobStream)
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); overload; override;
    function ReadPoll(pBuff: PAnsiChar): ub4;
  public //TStream  overrides
    function Read(var Buffer; Count: Longint): Longint; overload; override;
    function Seek(Offset: Longint; Origin: Word): Longint; overload; override;
  end;

  {** EH: implements a 64 bit stream for large character objects and raw multibyte codepages
   this class loads all data to mem, using the polling mode.
   reason is, oracle returns amount of chars for clobs,
   but we have no possibility to find out the exact stream size in bytes}
  TZOracleRawMultibyteStream32 = class(TZCodePageConversionStream)
  private
    FBytesPerChar: Cardinal;
  protected
    procedure FlushMemToStream(Buf: Pointer; Len: NativeUInt; Stream: TStream); override;
    procedure ReadStreamToMem(var Buf: Pointer; var Len: NativeUint; Stream: TStream); override;
  public
    constructor Create(const Owner: TStream; SourceCodePage, DestCodePage: Word;
      ConSettings: PZConSettings; const OpenLobStreams: TZSortedList; BytesPerChar: Cardinal);
  end;

  {** EH: implements a 32 bit stream for large character objects and raw multibyte codepages
   this class loads all data to mem, using the polling mode.
   reason is, oracle returns amount of chars for clobs,
   but we have no possibility to find out the exact stream size in bytes}
  TZOracleRawMultibyteStream64 = class(TZOracleRawMultibyteStream32)
  protected
    procedure FlushMemToStream(Buf: Pointer; Len: NativeUInt; Stream: TStream); override;
    procedure ReadStreamToMem(var Buf: Pointer; var Len: NativeUint; Stream: TStream); override;
  end;

  {** EH: implements a 32 bit stream for internal binary or character large objects }
  TZOracleInternalLobStream32 = class(TZOracleLobStream32)
  protected
    procedure WritePoll(pBuff: PAnsiChar; Len: NativeUInt);
  public
    function Write(const Buffer; Count: Longint): Longint; overload; override;
  end;

  {** EH: implements a 32 bit stream for file large objects }
  TZOracleExternalLobStream32 = class(TZOracleLobStream32)
  public
    function Write(const Buffer; Count: Longint): Longint; overload; override;
  end;

  {** EH: implements a 64 bit stream for large objects }
  TZOracleLobStream64 = class(TZAbstracOracleLobStream)
  protected
    function GetSize: Int64; override;
    procedure SetSize(const NewSize: Int64); overload; override;
    function ReadPoll(pBuff: PAnsiChar): oraub8;
  public //TStream  overrides
    function Read(var Buffer; Count: Longint): Longint; overload; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;
  end;

  {** EH: implements a 64 bit stream for internal binary or character large objects }
  TZOracleInternalLobStream64 = class(TZOracleLobStream64)
  protected
    procedure WritePoll(pBuff: PAnsiChar; Len: NativeUInt);
  public
    function Write(const Buffer; Count: Longint): Longint; overload; override;
  end;

  {** EH: implements a 64 bit stream for external file large objects }
  TZOracleExternalLobStream64 = class(TZOracleLobStream64)
  public
    function Write(const Buffer; Count: Longint): Longint; overload; override;
  end;

  TZOrcacleFileLob = class(TZAbstractOracleBlob);

  TZOracleLob = class(TZAbstractOracleBlob);

  TZOracleBlob = class(TZOracleLob, IZBlob)
  public
    constructor CreateFromBlob(const Lob: IZBLob; LobLocator: POCILobLocator;
      const Connection: IZOracleConnection; const OpenLobStreams: TZSortedList);
  end;

  TZOracleClob = class(TZOracleLob, IZBlob, IZCLob)
  private
    FBytesPerChar: Byte;
  protected
    function CreateLobStream(CodePage: Word; LobStreamMode: TZLobStreamMode): TStream; override;
  public
    function GetPAnsiChar(CodePage: Word; var ConversionBuf: RawByteString; out Len: NativeUInt): PAnsiChar; reintroduce;
  public
    constructor Create(const Connection: IZOracleConnection;
      LobLocator: POCILobLocator; CharsetForm: ub1; csid: ub2;
      const OpenLobStreams: TZSortedList);
    constructor CreateFromClob(const Lob: IZCLob; LobLocator: POCILobLocator;
      CharsetForm: ub1; csid: ub2; const Connection: IZOracleConnection;
      const OpenLobStreams: TZSortedList); reintroduce;
  end;

  {**
    Implements Oracle cached ResultSet. This class should be extended
    with database specific logic to form SQL data manipulation statements.
  }
  TZOracleCachedResultSet = Class(TZCachedResultset)
  protected
    procedure FillColumnsInfo(const ColumnsInfo: TObjectList); override;
    class function GetRowAccessorClass: TZRowAccessorClass; override;
  public
    function CreateLob(ColumnIndex: Integer; LobStreamMode: TZLobStreamMode): IZBlob{IZLob}; override;
  End;

  { TZOracleRowAccessor }

  TZOracleRowAccessor = class(TZRowAccessor)
  public
    procedure FillFromFromResultSet(const ResultSet: IZResultSet;
        {$IFDEF AUTOREFCOUNT}const {$ENDIF}IndexPairList: TZIndexPairList); override;
  end;

{$ENDIF ZEOS_DISABLE_ORACLE}
implementation
{$IFNDEF ZEOS_DISABLE_ORACLE}

uses
  Math, {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings,{$ENDIF} SysConst,
  ZFastCode, ZMessages, ZEncoding, ZDbcUtils;

{ TZOracleAbstractResultSet_A }

{$IFDEF USE_SYNCOMMONS}
procedure TZOracleAbstractResultSet_A.ColumnsToJSON(JSONWriter: TJSONWriter;
  JSONComposeOptions: TZJSONComposeOptions);
var P: PAnsiChar;
  C, H, I: SmallInt;
  Month, Day: Byte;
  Hour, Minute, Second: Byte;
  Year: SmallInt;
  L: NativeUInt;
  Millis: Cardinal absolute L;
  procedure AddJSONEscapeA(P: PAnsichar; Len: LengthInt);
  begin
    JSONWriter.Add('"');
    if FClientCP = zCP_UTF8 then
      JSONWriter.AddJSONEscape(P, Len)
    else begin
      FUniTemp := PRawToUnicode(P, Len, FClientCP);
      JSONWriter.AddJSONEscapeW(Pointer(FUniTemp), System.Length(FUniTemp));
    end;
    JSONWriter.Add('"');
  end;
  procedure AddJSONEscapeW(P: PWideChar; Len: LengthInt);
  begin
    JSONWriter.Add('"');
    JSONWriter.AddJSONEscapeW(Pointer(P), Len);
    JSONWriter.Add('"');
  end;
begin
  //init
  if JSONWriter.Expand then
    JSONWriter.Add('{');
  if Assigned(JSONWriter.Fields) then
    H := High(JSONWriter.Fields) else
    H := High(JSONWriter.ColNames);
  for I := 0 to H do begin
    if Pointer(JSONWriter.Fields) = nil then
      C := I else
      C := JSONWriter.Fields[i];
    {$R-}
    with FColumns^.Variables[C] do
    if (valuep = nil) or (indp^[FCurrentRowBufIndex] < 0) then begin
      if not (jcsSkipNulls in JSONComposeOptions) then begin
        if JSONWriter.Expand then
          JSONWriter.AddString(JSONWriter.ColNames[I]);
        JSONWriter.AddShort('null,')
      end;
    end else begin
      if JSONWriter.Expand then
        JSONWriter.AddString(JSONWriter.ColNames[I]);
      P := valuep+(FCurrentRowBufIndex*value_sz);
      case dty of
        { the ordinals we support }
        SQLT_INT        : case value_sz of
                            SizeOf(Int64): JSONWriter.Add(PInt64(P)^);
                            SizeOf(Integer): JSONWriter.Add(PInteger(P)^);
                            SizeOf(SmallInt): JSONWriter.Add(PSmallInt(P)^);
                            else JSONWriter.Add(PShortInt(P)^);
                          end;
        SQLT_UIN        : case value_sz of
                            SizeOf(UInt64): JSONWriter.Add(PUInt64(P)^);
                            SizeOf(Cardinal): JSONWriter.Add(PCardinal(P)^);
                            SizeOf(Word): JSONWriter.Add(PWord(P)^);
                            else JSONWriter.Add(PByte(P)^);
                          end;
        { the FPU floting values we support }
        SQLT_FLT        : if value_sz = SizeOf(Double)
                          then JSONWriter.AddDouble(PDouble(P)^)
                          else JSONWriter.AddSingle(PSingle(P)^);
        SQLT_BDOUBLE    : JSONWriter.AddDouble(PDouble(P)^);
        SQLT_BFLOAT     : JSONWriter.AddSingle(PSingle(P)^);
        { the oracle soft decimal }
        SQLT_VNU        : case ZDbcOracleUtils.nvuKind(POCINumber(P), FvnuInfo) of
                            nvu0: JSONWriter.Add('0');
                            vnuNegInt: JSONWriter.AddNoJSONEscape(@FTinyBuffer[0], NegOrdNVU2Raw(POCINumber(P), FvnuInfo, @FTinyBuffer[0]));
                            vnuPosInt: JSONWriter.AddNoJSONEscape(@FTinyBuffer[0], PosOrdNVU2Raw(POCINumber(P), FvnuInfo, @FTinyBuffer[0]));
                            vnuPosCurr: JSONWriter.AddCurr64(PosNvu2Curr(POCINumber(P), FvnuInfo));
                            //vnuPosCurr: JSONWriter.AddNoJSONEscape(@FTinyBuffer[0], PosNVUCurr2Raw(POCINumber(P), FvnuInfo, @FTinyBuffer[0]));
                            vnuNegCurr: JSONWriter.AddCurr64(NegNvu2Curr(POCINumber(P), FvnuInfo));
                            //vnuNegCurr: JSONWriter.AddNoJSONEscape(@FTinyBuffer[0], NegNVUCurr2Raw(POCINumber(P), FvnuInfo, @FTinyBuffer[0]));
                            nvuNegInf: JSONWriter.AddShort('"-Infinity"');
                            nvuPosInf: JSONWriter.AddShort('"Infinity"');
                            else begin
                              FStatus:= FPlainDriver.OCINumberToReal(FErrorHandle, POCINumber(P), SizeOf(Double), @FTinyBuffer[0]);
                              if FStatus = OCI_Success
                              then JSONWriter.AddDouble(PDouble(@FTinyBuffer[0])^)
                              else CheckOracleError(FPLainDriver, FErrorHandle, FStatus, lcOther, 'OCINumberToReal', ConSettings);
                            end;
                          end;
        { the charter types we support }
        SQLT_VCS        : if ColType = stUnicodeString
                          then AddJSONEscapeW(@POCIVary(P).Data[0], POCIVary(P).Len shr 1)
                          else AddJSONEscapeA(@POCIVary(P).Data[0], POCIVary(P).Len);
        SQLT_LVC        : if ColType = stUnicodeString
                          then AddJSONEscapeW(@POCILong(P).Data[0], POCILong(P).Len shr 1)
                          else AddJSONEscapeA(@POCILong(P).Data[0], POCILong(P).Len);
        SQLT_VST        : if ColType = stUnicodeString
                          then AddJSONEscapeW(@PPOCILong(P)^.data[0], PPOCILong(P)^.Len shr 1)
                          else AddJSONEscapeA(@PPOCILong(P)^.data[0], PPOCILong(P)^.Len);
        { fixed char right ' ' padded }
        SQLT_AFC        : if ColType = stUnicodeString
                          then AddJSONEscapeW(PWideChar(P), GetAbsorbedTrailingSpacesLen(PWideChar(P), Value_sz))
                          else AddJSONEscapeA(P, GetAbsorbedTrailingSpacesLen(P, Value_sz));
        { the binary raw we support }
        SQLT_LVB        : JSONWriter.WrBase64(@POCILong(P).data[0], POCILong(P).Len, True);
        SQLT_BIN        : JSONWriter.WrBase64(P, value_sz, True);
        SQLT_VBI        : JSONWriter.WrBase64(@POCIVary(P).data[0], POCIVary(P).Len, True);
        { date /+ time we do support }
        SQLT_DAT        : begin
                            if jcoMongoISODate in JSONComposeOptions then
                              JSONWriter.AddShort('ISODate("')
                            else if jcoDATETIME_MAGIC in JSONComposeOptions then
                              JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                            else
                              JSONWriter.Add('"');
                            if POraDate(P)^.Cent < 100 then
                              JSONWriter.Add('-');
                            if ColType <> stTime then begin
                              DateToIso8601PChar(@FTinyBuffer[0], True, (POraDate(P)^.Cent-100)*100+POraDate(P)^.Year-100,
                                POraDate(P)^.month, POraDate(P)^.day);
                              JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],10);
                            end else if jcoMongoISODate in JSONComposeOptions then
                              JSONWriter.AddShort('0000-00-00');
                            if (ColType <> stDate) then begin
                              TimeToIso8601PChar(@FTinyBuffer[0], True, POraDate(P)^.Hour-1,
                                POraDate(P)^.Min-1,POraDate(P)^.Sec-1, 0, 'T', jcoMilliseconds in JSONComposeOptions);
                              JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],8 + (4*Ord(jcoMilliseconds in JSONComposeOptions)));
                            end;
                            if jcoMongoISODate in JSONComposeOptions
                            then JSONWriter.AddShort('Z)"')
                            else JSONWriter.Add('"');
                          end;
        SQLT_TIMESTAMP: begin
                          if jcoMongoISODate in JSONComposeOptions then
                            JSONWriter.AddShort('ISODate("')
                          else if jcoDATETIME_MAGIC in JSONComposeOptions then
                            JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                          else
                            JSONWriter.Add('"');
                          if (ColType <> stTime) and (FPlainDriver.OCIDateTimeGetDate(FConnectionHandle,
                             FErrorHandle, PPOCIDescriptor(P)^, Year{%H-}, Month{%H-}, Day{%H-}) = OCI_SUCCESS) and
                             (not ((Year=1) and (Month=1) and (Day=1))) then begin
                          // attention : this code handles all timestamps on 01/01/0001 as a pure time value
                          // reason : oracle doesn't have a pure time datatype so all time comparisons compare
                          //          TDateTime values on 30 Dec 1899 against oracle timestamps on 01 januari 0001 (negative TDateTime)
                            DateToIso8601PChar(@FTinyBuffer[0], True, Abs(Year), Month, Day);
                            JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],10);
                          end else if jcoMongoISODate in JSONComposeOptions then
                            JSONWriter.AddShort('0000-00-00');
                          if (ColType <> stDate) and (FPlainDriver.OCIDateTimeGetTime(FConnectionHandle,
                             FErrorHandle, {%H-}PPOCIDescriptor(P)^, Hour{%H-}, Minute{%H-}, Second{%H-}, Millis{%H-}) = OCI_SUCCESS) then begin
                            TimeToIso8601PChar(@FTinyBuffer[0], True, Hour, Minute, Second,
                              Millis div 1000000, 'T', jcoMilliseconds in JSONComposeOptions);
                            JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],8 + (4*Ord(jcoMilliseconds in JSONComposeOptions)));
                          end;
                          if jcoMongoISODate in JSONComposeOptions
                          then JSONWriter.AddShort('Z)"')
                          else JSONWriter.Add('"');
                        end;
        SQLT_INTERVAL_DS,
        SQLT_INTERVAL_YM: begin
                            JSONWriter.Add('"');
                            JSONWriter.AddDateTime(GetTimeStamp(C{$IFNDEF GENERIC_INDEX}+1{$ENDIF}));
                            JSONWriter.Add('"');
                          end;
        { large object support }
        SQLT_BLOB,
        SQLT_BFILEE,
        SQLT_CFILEE     : begin
                            FTempLob := GetBlob(C+{$IFNDEF GENERIC_INDEX}+1{$ENDIF});
                            P := FTempLob.GetBuffer(fRawTemp, L);
                            JSONWriter.WrBase64(P, L, True);
                            FTempLob := nil;
                          end;
        SQLT_CLOB       : begin
                            JSONWriter.Add('"');
                            FTempLob := GetBlob(C{$IFNDEF GENERIC_INDEX}+1{$ENDIF});
                            P := FTempLob.GetPAnsiChar(zCP_UTF8, fRawTemp, L);
                            JSONWriter.AddJSONEscape(P, L);
                            FTempLob := nil;
                            JSONWriter.Add('"');
                          end;
        else
          raise Exception.Create('Missing OCI Type: '+IntToStr(dty));
      end;
      JSONWriter.Add(',');
    end;
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
  end;
  if jcoEndJSONObject in JSONComposeOptions then begin
    JSONWriter.CancelLastComma; // cancel last ','
    if JSONWriter.Expand then
      JSONWriter.Add('}');
  end;
end;
{$ENDIF USE_SYNCOMMONS}

{**
  Constructs this object, assignes main properties and
  opens the record set.
  @param PlainDriver a Oracle plain driver.
  @param Statement a related SQL statement object.
  @param SQL a SQL statement.
  @param Handle a Oracle specific query handle.
}
procedure TZOracleAbstractResultSet_A.AssignColumnsInfo(
  const Dest: TObjectList);
var
  I: Integer;
  Current: TZOracleColumnInfo;
  ColumnInfo: TZOracleColumnInfo;
begin
  for I := 0 to ColumnsInfo.Count - 1 do
  begin
    Current := TZOracleColumnInfo(ColumnsInfo[I]);
    ColumnInfo := TZOracleColumnInfo.Create;

    ColumnInfo.AutoIncrement := Current.AutoIncrement;
    ColumnInfo.CaseSensitive := Current.CaseSensitive;
    ColumnInfo.Searchable := Current.Searchable;
    ColumnInfo.Currency := Current.Currency;
    ColumnInfo.Nullable := Current.Nullable;
    ColumnInfo.Signed := Current.Signed;
    ColumnInfo.ColumnLabel := Current.ColumnLabel;
    ColumnInfo.ColumnName := Current.ColumnName;
    ColumnInfo.SchemaName := Current.SchemaName;
    ColumnInfo.Precision := Current.Precision;
    ColumnInfo.Scale := Current.Scale;
    ColumnInfo.TableName := Current.TableName;
    ColumnInfo.CatalogName := Current.CatalogName;
    if (Current.dty = SQLT_CLOB) then
      if (Current.ColumnCodePage = zCP_UTF16) or IsMBCSCodePage(Current.ColumnCodePage)
      then ColumnInfo.ColumnType := stUnicodeStream
      else ColumnInfo.ColumnType := stAsciiStream
    else if Current.ColumnType in [stString, stUnicodeString] then
      if (Current.ColumnCodePage = zCP_UTF16)
      then ColumnInfo.ColumnType := stUnicodeString
      else ColumnInfo.ColumnType := stString
    else ColumnInfo.ColumnType := Current.ColumnType;
    ColumnInfo.ReadOnly := Current.ReadOnly;
    ColumnInfo.Writable := Current.Writable;
    ColumnInfo.DefinitelyWritable := Current.DefinitelyWritable;
    ColumnInfo.ColumnCodePage := Current.ColumnCodePage;

    ColumnInfo.dty := Current.dty;
    ColumnInfo.csid := Current.csid;
    ColumnInfo.CharsetForm := Current.CharsetForm;

    Dest.Add(ColumnInfo);
  end;
end;

procedure TZOracleAbstractResultSet_A.BeforeClose;
begin
  FreeOracleSQLVars(FPlainDriver, FColumns, FIteration, FConnectionHandle,
    FErrorHandle, ConSettings);
  inherited BeforeClose;
end;

constructor TZOracleAbstractResultSet_A.Create(
  const Statement: IZStatement; const SQL: string; StmtHandle: POCIStmt;
  ErrorHandle: POCIError; const ZBufferSize: Integer);
begin
  inherited Create(Statement, SQL, nil, Statement.GetConnection.GetConSettings);
  FConnection := Statement.GetConnection as IZOracleConnection;
  FStmtHandle := StmtHandle;
  FErrorHandle := ErrorHandle;
  FPlainDriver := FConnection.GetPlainDriver;
  ResultSetConcurrency := rcReadOnly;
  FConnectionHandle := FConnection.GetConnectionHandle;
  FOCISvcCtx := FConnection.GetServiceContextHandle;
  FChunkSize := Statement.GetChunkSize;
  FIteration := 1;
  FCurrentRowBufIndex := 0;
  FZBufferSize := ZBufferSize;
  FClientCP := ConSettings^.ClientCodePage^.CP;
  Open;
end;

function TZOracleAbstractResultSet_A.CreateOCIConvertError(ColumnIndex: Integer;
  DataType: ub2): EZOCIConvertError;
begin
  Result := EZOCIConvertError.Create(Format(SErrorConvertionField,
        [TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]).ColumnLabel,
        IntToStr(DataType)]));
end;

{**
  Indicates if the value of the designated column in the current row
  of this <code>ResultSet</code> object is Null.

  @param columnIndex the first column is 1, the second is 2, ...
  @return if the value is SQL <code>NULL</code>, the
    value returned is <code>true</code>. <code>false</code> otherwise.
}
function TZOracleAbstractResultSet_A.IsNull(ColumnIndex: Integer): Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckClosed;
  if (RowNo < 1) or (RowNo > LastRowNo) then
    raise EZSQLException.Create(SRowDataIsNotAvailable);
  if (ColumnIndex < FirstDbcIndex) or (ColumnIndex > Integer(FColumns^.AllocNum{$IFDEF GENERIC_INDEX}-1{$ENDIF})) then
    raise EZSQLException.Create(
      Format(SColumnIsNotAccessable, [ColumnIndex]));
{$ENDIF}
  {$R-}
  Result := (FColumns^.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}].valuep = nil) or
            (FColumns^.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}].indp^[FCurrentRowBufIndex] < 0);
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PAnsiChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len the Length of the PAnsiChar String
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
const rInfinity: RawbyteString = 'Infinity';
const rNegInfinity: RawbyteString = '-Infinity';
function TZOracleAbstractResultSet_A.GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUint): PAnsiChar;
var TS: TZTimeStamp;
  SQLVarHolder: PZSQLVar absolute TS;
label dbl, sin, set_Result, jmpW2A, jmpTestN;
  procedure RawFromNVU;
  begin
    Nvu2BCD(POCINumber(Result), PBCD(@FTinyBuffer[0])^);
    FRawTemp := BcdToSQLRaw(PBCD(@FTinyBuffer[0])^);
  end;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := nil;
    Len := 0;
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    Result := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC: if ColumnCodePage = zCP_UTF16 then begin
                  Len := GetAbsorbedTrailingSpacesLen(PWideChar(Result), SQLVarHolder.Value_sz shr 1);
                  goto jmpW2A;
                end else Len := GetAbsorbedTrailingSpacesLen(Result, SQLVarHolder.Value_sz);
      SQLT_VST: begin
                  Len := PPOCILong(Result)^.Len;
                  Result := @PPOCILong(Result)^.data[0];
                  goto jmpTestN;
                end;
      SQLT_VCS: begin
                  Len := POCIVary(Result).Len;
                  Result := PAnsiChar(@POCIVary(Result).data[0]);
                  goto jmpTestN;
                end;
      SQLT_LVC: begin
                  Len := POCILong(Result).Len;
                  Result := PAnsiChar(@POCILong(Result).data[0]);
jmpTestN:         if ColumnCodePage = zCP_UTF16 then begin
                    Len := Len shr 1;
jmpW2A:             fRawTemp := PUnicodeToRaw(PWideChar(Result), Len, ConSettings.CTRL_CP);
                    Len := Length(fRawTemp);
                    if Len = 0
                    then Result := pEmptyAnsiString
                    else Result := Pointer(fRawTemp);
                  end;
                end;
      { the oracle soft decimal }
      SQLT_VNU:
        case nvuKind(POCINumber(Result), FvnuInfo) of
          nvu0: begin
              FTinyBuffer[0] := Ord('0');
              Len := 1;
              Result := @FTinyBuffer[0];
            end;
          nvuNegInf: begin
              Result := Pointer(rNegInfinity);
              Len := 9;
            end;
          nvuPosInf: begin
              Result := Pointer(rInfinity);
              Len := 8;
            end;
          vnuNegInt: begin
              Len := NegOrdNVU2Raw(POCINumber(Result), FvnuInfo, @FTinyBuffer[0]);
              Result := @FTinyBuffer[0];
            end;
          vnuPosInt: begin
              Len := PosOrdNVU2Raw(POCINumber(Result), FvnuInfo, @FTinyBuffer[0]);
              Result := @FTinyBuffer[0];
            end;
          vnuPosCurr: begin
              CurrToRaw(PosNvu2Curr(POCINumber(Result), FvnuInfo), @FTinyBuffer[0], @Result);
              goto set_Result;
            end;
          vnuNegCurr: begin
              CurrToRaw(NegNvu2Curr(POCINumber(Result), FvnuInfo), @FTinyBuffer[0], @Result);
              goto set_Result;
            end;
          else begin
              RawFromNVU;
              Result := Pointer(FRawTemp);
              Len := Length(FRawTemp);
            end;
        end;
      { the ordinals we yet do support }
      SQLT_INT: begin
                  case SQLVarHolder.value_sz of
                    SizeOf(Int64): IntToRaw(PInt64(Result)^, @FTinyBuffer[0], @Result);
                    SizeOf(Integer): IntToRaw(PInteger(Result)^, @FTinyBuffer[0], @Result);
                    SizeOf(SmallInt): IntToRaw(PSmallInt(Result)^, @FTinyBuffer[0], @Result);
                    else IntToRaw(PShortInt(Result)^, @FTinyBuffer, @Result[0]);
                  end;
                  goto set_Result;
                end;
      SQLT_UIN: begin
                  case SQLVarHolder.value_sz of
                    SizeOf(UInt64): IntToRaw(PUInt64(Result)^, @FTinyBuffer[0], @Result);
                    SizeOf(Cardinal): IntToRaw(PCardinal(Result)^, @FTinyBuffer[0], @Result);
                    SizeOf(SmallInt): IntToRaw(Cardinal(PWord(Result)^), @FTinyBuffer[0], @Result);
                    else IntToRaw(Cardinal(PByte(Result)^), @FTinyBuffer, @Result[0]);
                  end;
set_Result:       Len := Result - @FTinyBuffer[0];
                  Result := @FTinyBuffer[0];
                end;
      { the FPU floats we do support }
      SQLT_BFLOAT:  goto sin;
      SQLT_BDOUBLE: goto dbl;
      SQLT_FLT: begin
                  if SQLVarHolder^.value_sz = SizeOf(Double) then
      dbl:          Len := FloatToSQLRaw(PDouble(Result)^, @FTinyBuffer)
                  else
      sin:          Len := FloatToSQLRaw(PSingle(Result)^, @FTinyBuffer);
                  Result := @FTinyBuffer[0];
                end;
      { the binary raw we support }
      SQLT_VBI: begin
                  Len := POCIVary(Result)^.Len;
                  Result := @POCIVary(Result)^.data[0];
                end;
      SQLT_LVB: begin
                  Len := POCILong(Result)^.Len;
                  Result := @POCILong(Result)^.data[0];
                end;
      { the date/time types we support }
      SQLT_DAT,
      SQLT_INTERVAL_DS,
      SQLT_INTERVAL_YM,
      SQLT_TIMESTAMP_TZ,
      SQLT_TIMESTAMP_LTZ,
      SQLT_TIMESTAMP: begin
                  GetTimeStamp(ColumnIndex, TS);
                  Result := @fTinyBuffer[0];
                  Len := DateTimeToRaw(TS.Year, TS.Month, TS.Day,
                    TS.Hour, TS.Minute, TS.Second, TS.Fractions,
                    Result, ConSettings^.ReadFormatSettings.DateTimeFormat,
                    False, TS.IsNegative);
                end;
      SQLT_BLOB, SQLT_BFILEE, SQLT_CFILEE:
        begin
          FTempLob  := GetBlob(ColumnIndex);
          Result    := FTempLob.GetBuffer(FRawTemp, Len);
          FTempLob  := nil;
        end;
      SQLT_CLOB:
        begin
          FTempLob  := GetBlob(ColumnIndex);
          Result    := FTempLob.GetPAnsiChar(FClientCP, FRawTemp, Len);
          FTempLob  := nil;
        end;
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PWideChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len the length of UCS2 string in codepoints
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
const
  wNegInfinity: ZWideString = '-Infinity';
  wInfinity: ZWideString = 'Infinity';

function TZOracleAbstractResultSet_A.GetPWideChar(ColumnIndex: Integer;
  out Len: NativeUInt): PWideChar;
var TS: TZTimeStamp;
  SQLVarHolder: PZSQLVar absolute TS;
  P: PAnsiChar;
label dbl, sin, set_from_tmp, set_Result, jmpA2W;
  procedure UniFromNVU;
  begin
    Nvu2BCD(POCINumber(P), PBCD(@FTinyBuffer[0])^);
    FUniTemp := ZSysUtils.BcdToSQLUni(PBCD(@FTinyBuffer[0])^);
  end;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stString);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := nil;
    Len := 0;
  end else with TZOracleColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC: if ColumnCodePage = zCP_UTF16 then begin
                  Result := PWideChar(P);
                  Len := GetAbsorbedTrailingSpacesLen(Result, SQLVarHolder.Value_sz shr 1)
                end else begin
                  Len := GetAbsorbedTrailingSpacesLen(P, SQLVarHolder.Value_sz);
                  goto jmpA2W;
                end;
      SQLT_VST: if ColumnCodePage = zCP_UTF16 then begin
                  Result := @PPOCILong(P)^.data[0];
                  Len := PPOCILong(P)^.Len shr 1;
                end else begin
                  Len := PPOCILong(P)^.Len;
                  P := @PPOCILong(P)^.data[0];
                  goto jmpA2W;
                end;
      SQLT_VCS: if ColumnCodePage = zCP_UTF16 then begin
                  Result := @POCIVary(P)^.data[0];
                  Len := POCIVary(P)^.Len shr 1;
                end else begin
                  Len := POCIVary(P)^.Len;
                  P := @POCIVary(P)^.data[0];
                  goto jmpA2W;
                end;
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  Result := @POCILong(P)^.data[0];
                  Len := POCILong(P)^.Len shr 1;
                end else begin
                  Len := POCILong(P)^.Len;
                  P := @POCILong(P)^.data[0];
jmpA2W:           FUniTemp := PRawToUnicode(P, Len, FClientCP);
                  goto set_from_tmp;
                end;
      { the oracle soft decimal }
      SQLT_VNU:
        case nvuKind(POCINumber(P), FvnuInfo) of
          nvu0: begin
              PWord(@FTinyBuffer[0])^ := Ord('0');
              Len := 1;
              Result := @FTinyBuffer[0];
            end;
          nvuNegInf: begin
              Result := Pointer(wNegInfinity);
              Len := 9;
            end;
          nvuPosInf: begin
              Result := Pointer(wInfinity);
              Len := 8;
            end;
          vnuNegInt: begin
              IntToUnicode(NegNvu2Int(POCINumber(P), FvnuInfo), @FTinyBuffer[0], @Result);
              goto set_Result;
            end;
          vnuPosInt: begin
              IntToUnicode(PosNvu2Int(POCINumber(P), FvnuInfo), @FTinyBuffer[0], @Result);
              goto set_Result;
            end;
          vnuPosCurr: begin
              CurrToUnicode(PosNvu2Curr(POCINumber(P), FvnuInfo), @FTinyBuffer[0], @Result);
              goto set_Result;
            end;
          vnuNegCurr: begin
              CurrToUnicode(NegNvu2Curr(POCINumber(P), FvnuInfo), @FTinyBuffer[0], @Result);
              goto set_Result;
            end;
          else begin
              UniFromNVU;
              Result := Pointer(FUniTemp);
              Len := Length(FUniTemp);
            end;
        end;
      { the ordinals we yet do support }
      SQLT_INT: begin
                  case SQLVarHolder.value_sz of
                    SizeOf(Int64): IntToUnicode(PInt64(P)^, @FTinyBuffer[0], @Result);
                    SizeOf(Integer): IntToUnicode(PInteger(P)^, @FTinyBuffer[0], @Result);
                    SizeOf(SmallInt): IntToUnicode(PSmallInt(P)^, @FTinyBuffer[0], @Result);
                    else IntToUnicode(PShortInt(P)^, @FTinyBuffer, @Result[0]);
                  end;
                  goto set_Result;
                end;
      SQLT_UIN: begin
                  case SQLVarHolder.value_sz of
                    SizeOf(UInt64): IntToUnicode(PUInt64(P)^, @FTinyBuffer[0], @Result);
                    SizeOf(Cardinal): IntToUnicode(PCardinal(P)^, @FTinyBuffer[0], @Result);
                    SizeOf(Word): IntToUnicode(Cardinal(PWord(P)^), @FTinyBuffer[0], @Result);
                    else IntToUnicode(Cardinal(PByte(P)^), @FTinyBuffer, @Result[0]);
                  end;
set_Result:       Len := Result - PWideChar(@FTinyBuffer[0]);
                  Result := @FTinyBuffer[0];
                end;
      { the FPU floats we du support }
      SQLT_BFLOAT:  goto sin;
      SQLT_BDOUBLE: goto dbl;
      SQLT_FLT: begin
                  if SQLVarHolder^.value_sz = SizeOf(Double) then
      dbl:          Len := FloatToSQLUnicode(PDouble(P)^, @FTinyBuffer)
                  else
      sin:          Len := FloatToSQLUnicode(PSingle(P)^, @FTinyBuffer);
                  Result := @FTinyBuffer
                end;
      { the binary raw we support }
      SQLT_VBI: begin
                  Len := POCIVary(P)^.Len;
                  Result := @POCIVary(P)^.data[0];
                end;
      SQLT_LVB: begin
                  Len := POCILong(P)^.Len;
                  Result := @POCILong(P)^.data[0];
                end;
      { the date/time types we support }
      SQLT_DAT,
      SQLT_INTERVAL_DS,
      SQLT_INTERVAL_YM,
      SQLT_TIMESTAMP_TZ,
      SQLT_TIMESTAMP_LTZ,
      SQLT_TIMESTAMP: begin
                  GetTimeStamp(ColumnIndex, TS);
                  Result := @fTinyBuffer[0];
                  Len := DateTimeToUni(TS.Year, TS.Month, TS.Day,
                    TS.Hour, TS.Minute, TS.Second, TS.Fractions,
                    Result, ConSettings^.ReadFormatSettings.DateTimeFormat,
                    False, TS.IsNegative);
                end;
      SQLT_BLOB, SQLT_BFILEE, SQLT_CFILEE:
        begin
          FTempLob  := GetBlob(ColumnIndex);
          Result := FTempLob.GetBuffer(FRawTemp, Len);
          FUniTemp := Ascii7ToUnicodeString(PAnsiChar(Result), Len);
          FTempLob := nil;
set_from_tmp:
          Len := Length(FUniTemp);
          if Len = 0
          then Result := PEmptyUnicodeString
          else Result := Pointer(FUniTemp);
        end;
      SQLT_CLOB:
        begin
          FTempLob  := GetBlob(ColumnIndex); //localize
          Result    := FTempLob.GetPWideChar(FUniTemp, Len);
          FTempLob  := nil;
        end;
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the final object of a type/named-collection/nested-table,array

  @param obj the parent-object
  @return the Object which contains the final object descriptor
}
function TZOracleAbstractResultSet_A.GetFinalObject(Obj: POCIObject): POCIObject;
begin
  if Obj.is_final_type = 1 then
    Result := Obj
  else
    Result := GetFinalObject(Obj.next_subtype); //recursive call
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>boolean</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>false</code>
}
function TZOracleAbstractResultSet_A.GetBoolean(ColumnIndex: Integer): Boolean;
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
  Len: NativeUInt;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBoolean);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := False
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS,
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, Len));
                  Result := StrToBoolEx(PWideChar(P), PWideChar(P)+Len, True, False);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, Len);
                  Result := StrToBoolEx(P, P+Len, True, False);
                end;
      { the oracle soft decimal }
      SQLT_VNU: Result := nvuKind(POCINumber(P), FvnuInfo) <> nvu0;
      { the ordinals we yet do support }
      SQLT_INT: case SQLVarHolder.value_sz of
                  SizeOf(Int64):    Result := PInt64(P)^ <> 0;
                  SizeOf(Integer):  Result := PInteger(P)^ <> 0;
                  SizeOf(SmallInt): Result := PSmallInt(P)^ <> 0;
                  else              Result := PShortInt(P)^ <> 0;
                end;
      SQLT_UIN: case SQLVarHolder.value_sz of
                  SizeOf(UInt64):   Result := PUInt64(P)^ <> 0;
                  SizeOf(Cardinal): Result := PCardinal(P)^ <> 0;
                  SizeOf(Word):     Result := PWord(P)^ <> 0;
                  else              Result := PByte(P)^ <> 0;
                end;
      { the FPU floats we do support }
      SQLT_FLT: if SQLVarHolder^.value_sz = SizeOf(Double)
                then Result := PDouble(P)^ <> 0
                else Result := PSingle(P)^ <> 0;
      SQLT_BFLOAT:  Result := PSingle(P)^ <> 0;
      SQLT_BDOUBLE: Result := PDouble(P)^ <> 0;
      { the binary raw we support }
      //SQLT_VBI, SQLT_LVB:
      { the date/time types we support }
      SQLT_DAT, SQLT_TIMESTAMP:
        Result := GetTimeStamp(ColumnIndex) <> 0;
      //SQLT_BLOB, SQLT_BFILEE, SQLT_CFILEE:
      SQLT_CLOB: begin
          P := GetBlob(ColumnIndex).GetPAnsiChar(FClientCP, fRawTemp, Len);
          Result := StrToBoolEx(P, P+Len);
        end;
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the address of value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>byte</code> array in the Java programming language.
  The bytes represent the raw values returned by the driver.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len return the length of the addressed buffer
  @return the adressed column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZOracleAbstractResultSet_A.GetBytes(ColumnIndex: Integer;
  out Len: NativeUInt): PByte;
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBytes);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := nil;
    Len := 0;
  end else begin
    P := SQLVarHolder^.valuep+(FCurrentRowBufIndex*SQLVarHolder^.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported character/raw binary types we use }
      SQLT_VST: begin
                  Result := @PPOCILong(P)^.data[0];
                  Len := PPOCILong(P)^.Len;
                end;
      SQLT_VCS, SQLT_VBI: begin
                  Result := @POCIVary(P).data[0];
                  Len := POCIVary(P).Len;
                end;
      SQLT_LVC, SQLT_LVB: begin
                  Result := @POCILong(P).data[0];
                  Len := POCILong(P).Len;
                end;
      { the supported large object types types we use }
      SQLT_BLOB, SQLT_BFILEE, SQLT_CFILEE, SQLT_CLOB: begin
        FRawTemp := GetBlob(ColumnIndex).GetString;
        Result := Pointer(FRawTemp);
        Len := Length(FRawTemp);
      end else begin
        Result := PByte(P);
        Len := SQLVarHolder.value_sz;
      end;
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>int</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZOracleAbstractResultSet_A.GetInt(ColumnIndex: Integer): Integer;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stInteger);
{$ENDIF}
  Result := GetLong(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZOracleAbstractResultSet_A.GetLong(ColumnIndex: Integer): Int64;
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
  L: NativeUInt;
  Status: sword;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLong);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := 0
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS,
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, L));
                  Result := UnicodeToInt64Def(PWideChar(P), PWideChar(P)+L, 0);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, L);
                  Result := RawToInt64Def(P, P+L, 0);
                end;
      { the oracle soft decimal }
      SQLT_VNU: case nvuKind(POCINumber(P), FvnuInfo) of
                  nvu0,
                  nvuNegInf,
                  nvuPosInf:  Result := 0;
                  vnuNegInt:  Result := NegNvu2Int(POCINumber(P), FvnuInfo);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
                  vnuPosInt:  Result := PosNvu2Int(POCINumber(P), FvnuInfo);
                  vnuPosCurr: Result := PosNvu2Int(POCINumber(P), FvnuInfo);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
                  vnuNegCurr: Result := NegNvu2Int(POCINumber(P), FvnuInfo);
                  else begin
                      Status := FplainDriver.OCINumberToReal(FErrorHandle, POCINumber(P),
                        SizeOf(Double), @FTinyBuffer[0]);
                      if Status <> OCI_SUCCESS then
                        CheckOracleError(FPlainDriver, FErrorHandle, Status, lcOther,
                              'OCINumberToReal', ConSettings);
                      Result := Trunc(PDouble(@FTinyBuffer[0])^);
                    end;
                end;
      { the ordinals we yet do support }
      SQLT_INT:
        case SQLVarHolder.value_sz of
          SizeOf(Int64):    Result := PInt64(P)^;
          SizeOf(Integer):  Result := PInteger(P)^;
          SizeOf(SmallInt): Result := PSmallInt(P)^;
          else              Result := PShortInt(P)^;
        end;
      SQLT_UIN:
        case SQLVarHolder.value_sz of
          SizeOf(UInt64):   Result := Int64(PUInt64(P)^);
          SizeOf(Cardinal): Result := PCardinal(P)^;
          SizeOf(Word):     Result := PSmallInt(P)^;
          else              Result := PByte(P)^;
        end;
      { the FPU floats we do support }
      SQLT_FLT:     if SQLVarHolder.value_sz = SizeOf(Double)
                    then Result := Trunc(PDouble(P)^)
                    else Result := Trunc(PSingle(P)^);
      SQLT_BFLOAT:  Result := Trunc(PSingle(P)^);
      SQLT_BDOUBLE: Result := Trunc(PDouble(P)^);
      { the binary raw we support }
      //SQLT_VBI, SQLT_LVB:
      { the date/time types we support }
      SQLT_DAT, SQLT_TIMESTAMP:
        Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(GetTimeStamp(ColumnIndex));
      SQLT_CLOB: begin
          FTempLob := GetBlob(ColumnIndex);
          P := FTempLob.GetBuffer(fRawTemp, L);
          Result := RawToInt64Def(P, P+L, 0);
          fRawTemp := '';
        end;
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>uint</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZOracleAbstractResultSet_A.GetUInt(ColumnIndex: Integer): Cardinal;
begin
  Result := GetLong(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>UInt64</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
function TZOracleAbstractResultSet_A.GetULong(ColumnIndex: Integer): UInt64;
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
  Status: sword;
  L: NativeUInt;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stULong);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
{$IF defined (RangeCheckEnabled) and not defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
    LastWasNull := True;
    Result := 0
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS,
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, L));
                  Result := UnicodeToUInt64Def(PWideChar(P), PWideChar(P)+L, 0);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, L);
                  Result := RawToUInt64Def(P, P+L, 0);
                end;
      { the oracle soft decimal }
      SQLT_VNU: case nvuKind(POCINumber(P), FvnuInfo) of
                  nvu0,
                  nvuNegInf,
                  nvuPosInf:  Result := 0;
                  vnuNegInt:  Result := NegNvu2Int(POCINumber(P), FvnuInfo);
                  vnuPosInt:  Result := PosNvu2Int(POCINumber(P), FvnuInfo);
                  vnuPosCurr: Result := PosNvu2Int(POCINumber(P), FvnuInfo);
                  vnuNegCurr: Result := NegNvu2Int(POCINumber(P), FvnuInfo);
                  else begin
                      Status := FplainDriver.OCINumberToReal(FErrorHandle, POCINumber(P),
                        SizeOf(Double), @FTinyBuffer[0]);
                      if Status <> OCI_SUCCESS then
                        CheckOracleError(FPlainDriver, FErrorHandle, Status, lcOther,
                              'OCINumberToReal', ConSettings);
                      if PDouble(@FTinyBuffer[0])^ < 0
                      then Result := 0
                      else Result := Trunc(PDouble(@FTinyBuffer[0])^);
                    end;
                end;
      { the ordinals we yet do support }
      SQLT_INT:
        case SQLVarHolder.value_sz of
          SizeOf(Int64):    Result := PInt64(P)^;
          SizeOf(Integer):  Result := PInteger(P)^;
          SizeOf(SmallInt): Result := PSmallInt(P)^;
          else              Result := PShortInt(P)^;
        end;
      SQLT_UIN:
        case SQLVarHolder.value_sz of
          SizeOf(UInt64):   Result := PUInt64(P)^;
          SizeOf(Cardinal): Result := PCardinal(P)^;
          SizeOf(Word):     Result := PWord(P)^;
          else              Result := PByte(P)^;
        end;
      { the FPU floats we do support }
      SQLT_FLT:     if SQLVarHolder.value_sz = SizeOf(Double)
                    then Result := Trunc(PDouble(P)^)
                    else Result := Trunc(PSingle(P)^);
      SQLT_BFLOAT:  Result := Trunc(PSingle(P)^);
      SQLT_BDOUBLE: Result := Trunc(PDouble(P)^);
      { the binary raw we support }
      //SQLT_VBI, SQLT_LVB:
      { the date/time types we support }
      SQLT_DAT, SQLT_TIMESTAMP:
        Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(GetTimeStamp(ColumnIndex));
      SQLT_CLOB: begin
        FTempLob := GetBlob(ColumnIndex);
        P := FTempLob.GetBuffer(fRawTemp, L);
        Result := RawToUInt64Def(P, P+L, 0);
        fRawTemp := '';
      end
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>float</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZOracleAbstractResultSet_A.GetFloat(ColumnIndex: Integer): Single;
begin
  Result := GetDouble(ColumnIndex);
end;

procedure TZOracleAbstractResultSet_A.GetGUID(ColumnIndex: Integer;
  var Result: TGUID);
var SQLVarHolder: PZSQLVar;
  L: NativeUint;
  P: PAnsiChar;
label Fail;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stGUID);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Fillchar(Result, SizeOf(TGUID), #0);
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported character/binary types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS,
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, L));
                  if (L = 36) or (L = 38)
                  then ValidGUIDToBinary(PWideChar(P), @Result.D1)
                  else goto Fail;
                end else begin
                  P := GetPAnsiChar(ColumnIndex, L);
                  if (L = 36) or (L = 38)
                  then ValidGUIDToBinary(P, @Result.D1)
                  else goto Fail;
                end;
      SQLT_VBI: if POCIVary(P).Len = SizeOf(TGUID)
                then Move(POCIVary(P).data[0], Result.D1, SizeOf(TGUID))
                else goto Fail;
      SQLT_LVB: if POCILong(P).Len = SizeOf(TGUID)
                then Move(POCILong(P).data[0], Result.D1, SizeOf(TGUID))
                else goto Fail;
      else
Fail:     raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>double</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZOracleAbstractResultSet_A.GetDouble(ColumnIndex: Integer): Double;
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
  PW: PWideChar absolute P;
  L: NativeUint;
  Status: sword;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDouble);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := 0
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder^.valuep+(FCurrentRowBufIndex*SQLVarHolder^.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS,
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, L));
                  SqlStrToFloatDef(PWideChar(P), 0, Result, L);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, L);
                  SqlStrToFloatDef(P,0,Result, L)
                end;
      { the oracle soft decimal }
      SQLT_VNU: begin
          Result := 0;
          Status:= FPlainDriver.OCINumberToReal(FErrorHandle, POCINumber(P), SizeOf(Double), @Result);
          if Status <> OCI_Success then
            CheckOracleError(FPLainDriver, FErrorHandle, Status, lcOther, 'OCINumberToReal', ConSettings);
        end;
      { the ordinals we yet do support }
      SQLT_INT:
        case SQLVarHolder.value_sz of
          SizeOf(Int64):    Result := PInt64(P)^;
          SizeOf(Integer):  Result := PInteger(P)^;
          SizeOf(SmallInt): Result := PSmallInt(P)^;
          else              Result := PShortInt(P)^;
        end;
      SQLT_UIN:
          case SQLVarHolder.value_sz of
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
            SizeOf(UInt64):   Result := Int64(PUInt64(P)^);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
            SizeOf(Cardinal): Result := PCardinal(P)^;
            SizeOf(Word):     Result := PSmallInt(P)^;
            else              Result := PByte(P)^;
          end;
      { the FPU floats we do support }
      SQLT_FLT:     if SQLVarHolder.value_sz = SizeOf(Double)
                    then Result := PDouble(P)^
                    else Result := PSingle(P)^;
      SQLT_BFLOAT:  Result := PSingle(P)^;
      SQLT_BDOUBLE: Result := PDouble(P)^;
      { the binary raw we support }
      //SQLT_VBI, SQLT_LVB:
      { the date/time types we support }
      SQLT_DAT, SQLT_TIMESTAMP:
        Result := GetTimeStamp(ColumnIndex);
      SQLT_CLOB: if (ColumnCodePage = zCP_UTF16) then begin
          PW := GetPWideChar(ColumnIndex, L);
          SqlStrToFloatDef(PW, 0, Result, L);
        end else begin
          P := GetPAnsiChar(ColumnIndex, L);
          SqlStrToFloatDef(P, 0, Result, L);
        end
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.BigDecimal</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param scale the number of digits to the right of the decimal point
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZOracleAbstractResultSet_A.GetBigDecimal(ColumnIndex: Integer; var Result: TBCD);
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
  PW: PWideChar absolute P;
  Len: NativeUInt;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBigDecimal);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := NullBcd;
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC,
      SQLT_VST,
      SQLT_VCS,
      SQLT_LVC,
      SQLT_CLOB: if ColumnCodePage = zCP_UTF16 then begin
                  PW := GetPWideChar(ColumnIndex, Len);
                  LastWasNull := not TryUniToBcd(PW, Len, Result, '.');
                end else begin
                  P := GetPAnsiChar(ColumnIndex, Len);
                  LastWasNull := not TryRawToBcd(P, Len, Result, '.');
                end;
      { the oracle soft decimal }
      SQLT_VNU: Nvu2BCD(POCINumber(P), Result);
      { the ordinals we yet do support }
      SQLT_INT: case SQLVarHolder.value_sz of
          SizeOf(Int64):    ScaledOrdinal2Bcd(PInt64(P)^, 0, Result);
          SizeOf(Integer):  ScaledOrdinal2Bcd(PInteger(P)^, 0, Result);
          SizeOf(SmallInt): ScaledOrdinal2Bcd(PSmallInt(P)^, 0, Result);
          else              ScaledOrdinal2Bcd(SmallInt(PShortInt(P)^), 0, Result);
        end;
      SQLT_UIN: case SQLVarHolder.value_sz of
            SizeOf(UInt64):   ScaledOrdinal2Bcd(PUInt64(P)^, 0, Result, False);
            SizeOf(Cardinal): ScaledOrdinal2Bcd(PCardinal(P)^, 0, Result, False);
            SizeOf(Word):     ScaledOrdinal2Bcd(PWord(P)^, 0, Result, False);
            else              ScaledOrdinal2Bcd(Word(PByte(P)^), 0, Result, False);
          end;
      { the FPU floats we do support }
      SQLT_FLT:     if SQLVarHolder.value_sz = SizeOf(Double)
                    then Double2BCD(PDouble(P)^, Result)
                    else Double2BCD(PSingle(P)^, Result);
      SQLT_BFLOAT:  Double2BCD(PSingle(P)^, Result);
      SQLT_BDOUBLE: Double2BCD(PDouble(P)^, Result);
      { the binary raw we support }
      //SQLT_VBI, SQLT_LVB:
      { the date/time types we support }
      SQLT_DAT, SQLT_TIMESTAMP:
        Double2BCD(GetTimeStamp(ColumnIndex), Result);
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>currency</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZOracleAbstractResultSet_A.GetCurrency(ColumnIndex: Integer): Currency;
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
  PW: PWideChar absolute P;
  L: NativeUint;
  Status: sword;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stCurrency);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := 0
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      SQLT_AFC, SQLT_VST, SQLT_VCS,
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, L));
                  SqlStrToFloatDef(PWideChar(P), 0, Result, L);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, L);
                  SqlStrToFloatDef(P,0,Result, L)
                end;
      { the oracle soft decimal }
      SQLT_VNU:
          case nvuKind(POCINumber(P), FvnuInfo) of
            nvu0, nvuNegInf, nvuPosInf: Result := 0;
            vnuNegInt: Result := NegNvu2Int(POCINumber(P), FvnuInfo);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
            vnuPosInt: Result := PosNvu2Int(POCINumber(P), FvnuInfo);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
            vnuPosCurr: Result := PosNvu2Curr(POCINumber(P), FvnuInfo);
            vnuNegCurr: Result := NegNvu2Curr(POCINumber(P), FvnuInfo);
            else begin
                Status := FplainDriver.OCINumberToReal(FErrorHandle, POCINumber(P),
                  SizeOf(Double), @FTinyBuffer[0]);
                if Status <> OCI_SUCCESS then
                  CheckOracleError(FPlainDriver, FErrorHandle, Status, lcOther,
                        'OCINumberToReal', ConSettings);
                Result := PDouble(@FTinyBuffer[0])^;
              end;
        end;
      { the ordinals we yet do support }
      SQLT_INT:
        case SQLVarHolder.value_sz of
          SizeOf(Int64):    Result := PInt64(P)^;
          SizeOf(Integer):  Result := PInteger(P)^;
          SizeOf(SmallInt): Result := PSmallInt(P)^;
          else              Result := PShortInt(P)^;
        end;
      SQLT_UIN:
          case SQLVarHolder.value_sz of
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
            SizeOf(UInt64):   Result := Int64(PUInt64(P)^);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
            SizeOf(Cardinal): Result := PCardinal(P)^;
            SizeOf(Word):     Result := PSmallInt(P)^;
            else              Result := PByte(P)^;
          end;
      { the FPU floats we do support }
      SQLT_FLT:     if SQLVarHolder.value_sz = SizeOf(Double)
                    then Result := PDouble(P)^
                    else Result := PSingle(P)^;
      SQLT_BFLOAT:  Result := PSingle(P)^;
      SQLT_BDOUBLE: Result := PDouble(P)^;
      { the binary raw we support }
      //SQLT_VBI, SQLT_LVB:
      { the date/time types we support }
      SQLT_DAT, SQLT_TIMESTAMP:
        Result := GetTimeStamp(ColumnIndex);
      SQLT_CLOB: if (ColumnCodePage = zCP_UTF16) then begin
          PW := GetPWideChar(ColumnIndex, L);
          SqlStrToFloatDef(PW, 0, Result, L);
        end else begin
          P := GetPAnsiChar(ColumnIndex, L);
          SqlStrToFloatDef(P, 0, Result, L);
        end
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Date</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZOracleAbstractResultSet_A.GetDate(ColumnIndex: Integer;
  var Result: TZDate);
var
  SQLVarHolder: PZSQLVar;
  DT: TDateTime;
  P: PAnsiChar absolute DT;
  Len: NativeUInt;
  Status: sword absolute Len;
  yr, mnth, dy, hr, mm, ss, fsec: sb4;
  Year: SmallInt absolute yr;
  Month: Byte absolute mnth;
  Day: Byte absolute dy;
  Ptr: POraDate absolute P;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDate);
{$ENDIF}
  PInt64(@Result.Year)^ := 0;
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True
  else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS, SQLT_LVC,
      SQLT_CLOB: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, Len));
                  LastWasNull := not TryPCharToDate(PWideChar(P), Len, ConSettings^.ReadFormatSettings, Result);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, Len);
                  LastWasNull := not TryPCharToDate(P, Len, ConSettings^.ReadFormatSettings, Result);
                end;
      SQLT_INT,
      SQLT_UIN,
      SQLT_FLT,
      SQLT_BFLOAT,
      SQLT_BDOUBLE,
      SQLT_VNU: begin
                  DT := GetDouble(ColumnIndex);
                  DecodeDateTimeToDate(DT, Result);
                end;
      SQLT_DAT: begin
                  if Ptr^.Cent <= 100 then begin
                    Result.IsNegative := True;
                    Result.Year := Ptr^.Cent*100+Ptr^.Year-100;
                  end else begin
                    Result.IsNegative := False;
                    Result.Year := (Ptr^.Cent-100)*100+Ptr^.Year-100;
                  end;
                  Result.Month := Ptr^.Month;
                  Result.Day := Ptr^.Day;
                end;
      SQLT_INTERVAL_DS:
        begin
          Status := FPlainDriver.OCIIntervalGetDaySecond(FOCISvcCtx, FErrorHandle,
            @dy, @hr, @mm, @ss, @fsec, PPOCIDescriptor(P)^);
          if (Status = OCI_SUCCESS) then
            Result.Day := dy;
        end;
      SQLT_INTERVAL_YM: begin
          Status := FPlainDriver.OCIIntervalGetYearMonth(FOCISvcCtx, FErrorHandle, @yr, @mnth, PPOCIDescriptor(P)^);
          if (Status = OCI_SUCCESS) then begin
            Result.Year := yr;
            Result.Month := mnth;
          end;
        end;
      SQLT_TIMESTAMP_TZ,
      SQLT_TIMESTAMP_LTZ,
      SQLT_TIMESTAMP: begin
          Status := FPlainDriver.OCIDateTimeGetDate(FConnectionHandle, FErrorHandle,
            PPOCIDescriptor(P)^, Year{%H-}, Month{%H-}, Day{%H-});
          if (Status = OCI_SUCCESS) then begin
            Result.Year :=  Abs(Year);
            Result.Month := Month;
            Result.Day := Day;
            Result.IsNegative := Year < 0;
          end;
        end;
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Time</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZOracleAbstractResultSet_A.GetTime(ColumnIndex: Integer; Var Result: TZTime);
var
  SQLVarHolder: PZSQLVar;
  DT: TDateTime;
  P: PAnsiChar absolute DT;
  Len: NativeUInt;
  Status: sword absolute Len;
  dy, hr, mm, ss, fsec: sb4;
  Hour: Byte absolute hr;
  Minute: Byte absolute mm;
  Second: Byte absolute ss;
  Millis: ub4 absolute fsec;
  Ptr: POraDate absolute P;
label Fill;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTime);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
Fill: PCardinal(@Result.Hour)^ := 0;
    PInt64(@Result.Second)^ := 0;
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS, SQLT_LVC,
      SQLT_CLOB: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, Len));
                  LastWasNull := not TryPCharToTime(PWideChar(P), Len, ConSettings^.ReadFormatSettings, Result);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, Len);
                  LastWasNull := not TryPCharToTime(P, Len, ConSettings^.ReadFormatSettings, Result);
                end;
      SQLT_INT,
      SQLT_UIN,
      SQLT_FLT,
      SQLT_BFLOAT,
      SQLT_BDOUBLE,
      SQLT_VNU: begin
                  DT := GetDouble(ColumnIndex);
                  DecodeDateTimeToTime(DT, Result);
                end;
      SQLT_DAT: begin
              Result.Hour := Ptr^.Hour-1;
              Result.Minute := Ptr^.Min-1;
              PInt64(@Result.Second)^ := 0;
              Result.Second := Ptr^.Sec-1;
              Result.IsNegative := False;
          end;
      SQLT_INTERVAL_DS:
        begin
          Status := FPlainDriver.OCIIntervalGetDaySecond(FOCISvcCtx, FErrorHandle,
            @dy, @hr, @mm, @ss, @fsec, PPOCIDescriptor(P)^);
          if (Status = OCI_SUCCESS) then begin
            Result.Hour := hr;
            Result.Minute := mm;
            Result.Second := ss;
            Result.Fractions := fsec*10;
            Result.IsNegative := False;
          end else goto Fill;
        end;
      SQLT_INTERVAL_YM: goto Fill;
      SQLT_TIMESTAMP_TZ,
      SQLT_TIMESTAMP_LTZ,
      SQLT_TIMESTAMP: begin
          Status := FPlainDriver.OCIDateTimeGetTime(FConnectionHandle, FErrorHandle,
            PPOCIDescriptor(P)^, Hour{%H-}, Minute{%H-}, Second{%H-}, Millis{%H-});
          if Status = OCI_SUCCESS then begin
            Result.Hour := Hour;
            Result.Minute := Minute;
            Result.Second := Second;
            Result.Fractions := Millis;
            Result.IsNegative := False;
          end else
            goto Fill;
        end;
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Timestamp</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
  value returned is <code>null</code>
  @exception SQLException if a database access error occurs
}
procedure TZOracleAbstractResultSet_A.GetTimestamp(ColumnIndex: Integer;
  var Result: TZTimeStamp);
var
  SQLVarHolder: PZSQLVar;
  DT: TDateTime;
  P: PAnsiChar absolute DT;
  PW: PWideChar absolute DT;
  Len: NativeUInt;
  Status: sword absolute Len;
  yr, mnth, dy, hr, mm, ss, fsec: sb4;
  Year: SmallInt absolute yr;
  Month: Byte absolute mnth;
  Day: Byte absolute dy;
  Hour: Byte absolute hr;
  Minute: Byte absolute mm;
  Second: Byte absolute ss;
  Millis: ub4 absolute fsec;
  Ptr: POraDate absolute P;
label Fill;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stTimeStamp);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
Fill: PInt64(@Result.Year)^ := 0;
    PInt64(@Result.Minute)^ := 0;
    PInt64(PAnsiChar(@Result.Fractions)-2)^ := 0;
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS, SQLT_LVC,
      SQLT_CLOB: if ColumnCodePage = zCP_UTF16 then begin
                  PW := GetPWideChar(ColumnIndex, Len);
                  LastWasNull := not TryPCharToTimeStamp(PW, Len, ConSettings^.ReadFormatSettings, Result);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, Len);
                  LastWasNull := not TryPCharToTimeStamp(P, Len, ConSettings^.ReadFormatSettings, Result);
                end;
      SQLT_INT,
      SQLT_UIN,
      SQLT_FLT,
      SQLT_BFLOAT,
      SQLT_BDOUBLE,
      SQLT_VNU: begin
                  DT := GetDouble(ColumnIndex);
                  DecodeDateTimeToTimeStamp(DT, Result);
                end;
      SQLT_DAT: begin
                  if Ptr^.Cent <= 100 then begin
                    Result.IsNegative := True;
                    Result.Year := Ptr^.Cent*100+Ptr^.Year-100;
                  end else begin
                    Result.IsNegative := False;
                    Result.Year := (Ptr^.Cent-100)*100+Ptr^.Year-100;
                  end;
                  Result.Month := Ptr^.Month;
                  Result.Day := Ptr^.Day;
                  PInt64(@Result.Minute)^ := 0;
                  if (Ptr^.Hour <> 0) and (Ptr^.Min <> 0) and (Ptr^.Sec <> 0) then begin
                    Result.Hour := Ptr^.Hour-1;
                    Result.Minute := Ptr^.Min-1;
                    Result.Second := Ptr^.Sec-1;
                  end else
                    Result.Hour := 0;
                  PCardinal(@Result.TimeZoneHour)^ := 0;
                end;
      SQLT_INTERVAL_DS:
        begin
          Status := FPlainDriver.OCIIntervalGetDaySecond(FOCISvcCtx, FErrorHandle,
            @dy, @hr, @mm, @ss, @fsec, PPOCIDescriptor(P)^);
          if (Status = OCI_SUCCESS) then begin
            PCardinal(@Result.Year)^ := 0;
            PCardinal(@Result.TimeZoneHour)^ := 0;
            Result.IsNegative := dy < 0;
            Result.Day := Abs(dy);
            Result.Hour := hr;
            Result.Minute := mm;
            Result.Second := ss;
            Result.Fractions := fSec * 10;
          end else goto Fill;
        end;
      SQLT_INTERVAL_YM:
        begin
          Status := FPlainDriver.OCIIntervalGetYearMonth(FOCISvcCtx, FErrorHandle, @yr, @mnth, PPOCIDescriptor(P)^);
          if (Status = OCI_SUCCESS) then begin
            PInt64(@Result.Hour)^ := 0;
            PInt64(@Result.Second)^ := 0;
            Result.Year := Abs(yr);
            Result.IsNegative := yr < 0;
            Result.Month := mnth;
          end else goto Fill;
        end;
      SQLT_TIMESTAMP_TZ,
      SQLT_TIMESTAMP_LTZ,
      SQLT_TIMESTAMP: if (FPlainDriver.OCIDateTimeGetDate(FConnectionHandle, FErrorHandle,
              PPOCIDescriptor(P)^, Year{%H-}, Month{%H-}, Day{%H-}) = OCI_SUCCESS) and
              (FPlainDriver.OCIDateTimeGetTime(FConnectionHandle, FErrorHandle,
               PPOCIDescriptor(P)^, Hour{%H-}, Minute{%H-}, Second{%H-}, Millis{%H-}) = OCI_SUCCESS) then begin
            Result.Year :=  Abs(Year);
            Result.Month := Month;
            Result.Day := Day;
            Result.IsNegative := Year < 0;
            Result.Hour := Hour;
            Result.Minute := Minute;
            Result.Second := Second;
            Result.Fractions := Millis;
          end else
            goto Fill;
      else raise CreateOCIConvertError(ColumnIndex, SQLVarHolder^.dty);
    end;
  end;
end;

{**
  Returns the value of the designated column in the current row
  of this <code>ResultSet</code> object as a <code>IZResultSet</code> object
  in the Java programming language.

  @param ColumnIndex the first column is 1, the second is 2, ...
  @return a <code>IZResultSet</code> object representing the SQL
    <code>IZResultSet</code> value in the specified column
}
function TZOracleAbstractResultSet_A.GetDataSet(ColumnIndex: Integer): IZDataSet;
var
  SQLVarHolder: PZSQLVar;
  type_Ref: POCIRef;
  //tdo: POCIType;
begin
  Result := nil ;
{$IFNDEF DISABLE_CHECKING}
  CheckBlobColumn(ColumnIndex);
{$ENDIF}
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stCurrency);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := nil
  end else begin
    LastWasNull := False;
    Result := nil;
    if SQLVarHolder.dty = SQLT_NTY then
      {$R-}
      if SQLVarHolder.indp[FCurrentRowBufIndex] >= 0 then begin
      {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
        if SQLVarHolder._Obj.is_final_type = 1 then
          // here we've the final object lets's read it to test it
          // later we only need the reference-pointers to create a new dataset
        else
        begin
           //http://cpansearch.perl.org/src/TIMB/DBD-Oracle-1.26/oci8.c

          //create a temporary object
          type_ref := nil;
          CheckOracleError(FPlainDriver, FErrorHandle,
            FPlainDriver.OCIObjectNew(FConnectionHandle,
              FConnection.GetErrorHandle, FOCISvcCtx, OCI_TYPECODE_REF,
                nil, nil, OCI_DURATION_DEFAULT, TRUE, @type_ref),
            lcOther, 'OCITypeByRef from OCI_ATTR_REF_TDO', ConSettings);
          //Get the type reference
          CheckOracleError(FPlainDriver, FErrorHandle,
            FPlainDriver.OCIObjectGetTypeRef(FConnectionHandle,
              FConnection.GetErrorHandle, SQLVarHolder._Obj.obj_value, type_Ref),
            lcOther, 'OCIObjectGetTypeRef(obj_value)', ConSettings);

          //Now let's get the new tdo
          //Excptions????????
          {CheckOracleError(FPlainDriver, FErrorHandle,
            FPlainDriver.TypeByRef(FConnectionHandle,
              FConnection.GetErrorHandle, type_ref, OCI_DURATION_DEFAULT,
              OCI_TYPEGET_ALL, @tdo),
            lcOther, 'OCITypeByRef from OCI_ATTR_REF_TDO', ConSettings);}
          //free the temporary object
          CheckOracleError(FPlainDriver, FErrorHandle,
            FPlainDriver.OCIObjectFree(FConnectionHandle,
              FConnection.GetErrorHandle, type_ref, ub2(0)),
            lcOther, 'ObjectFree()', ConSettings);
        end;


        {CheckOracleError(FPlainDriver, FErrorHandle,
          FPlainDriver.ResultSetToStmt(SQLVarHolder^._Obj.obj_ind,
            FErrorHandle), lcOther, 'Nested Table to Stmt handle', ConSettings);
        Result := CreateOracleResultSet(FPlainDriver, GetStatement,
          'Fetch Nested Table', SQLVarHolder^._Obj.obj_ref, FErrorHandle)};
      end;
  end;
end;

{**
  Returns the value of the designated column in the current row
  of this <code>ResultSet</code> object as a <code>Blob</code> object
  in the Java programming language.

  @param ColumnIndex the first column is 1, the second is 2, ...
  @return a <code>Blob</code> object representing the SQL <code>BLOB</code> value in
    the specified column
}
function TZOracleAbstractResultSet_A.GetBlob(ColumnIndex: Integer;
  LobStreamMode: TZLobStreamMode = lsmRead): IZBlob;
var
  SQLVarHolder: PZSQLVar;
  P: PAnsiChar;
  L: NativeUint;
begin
  Result := nil ;
  if LobStreamMode <> lsmRead then
    raise CreateReadOnlyException;
{$IFNDEF DISABLE_CHECKING}
  CheckBlobColumn(ColumnIndex);
{$ENDIF}
  {$R-}
  SQLVarHolder := @FColumns.Variables[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  if (SQLVarHolder.valuep = nil) or (SQLVarHolder.indp[FCurrentRowBufIndex] < 0) then begin
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    LastWasNull := True;
    Result := nil
  end else with TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do begin
    P := SQLVarHolder.valuep+(FCurrentRowBufIndex*SQLVarHolder.value_sz);
    LastWasNull := False;
    case SQLVarHolder.dty of
      { the binary raw we support }
      SQLT_VBI, SQLT_LVB: begin
                  P := Pointer(GetBytes(ColumnIndex, L));
                  Result := TZMemoryReferencedBLob.CreateWithData(P, L, FOpenLobStreams);
                end;
      { the supported String types we use }
      SQLT_AFC, SQLT_VST, SQLT_VCS,
      SQLT_LVC: if ColumnCodePage = zCP_UTF16 then begin
                  P := Pointer(GetPWideChar(ColumnIndex, L));
                  Result := TZMemoryReferencedCLob.CreateWithData(PWideChar(P), L, zCP_UTF16, ConSettings, FOpenLobStreams);
                end else begin
                  P := GetPAnsiChar(ColumnIndex, L);
                  Result := TZMemoryReferencedCLob.CreateWithData(P, L, FClientCP, ConSettings, FOpenLobStreams);
                end;
      SQLT_BLOB,
      SQLT_BFILEE,
      SQLT_CFILEE: Result := TZOracleBlob.Create(FConnection, PPOCIDescriptor(P)^, SQLVarHolder.dty, FOpenLobStreams);
      SQLT_CLOB: with TZOracleColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]) do
          Result := TZOracleClob.Create(FConnection, PPOCIDescriptor(P)^, CharSetForm, csid, FOpenLobStreams);
      SQLT_NTY: ;
      else raise CreateCanNotAccessBlobRecordException(ColumnIndex, TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]).ColumnType);
    end;
  end;
end;

{ TZOracleResultSet_A }

{**
  Opens this recordset.
}
procedure TZOracleResultSet_A.Open;
var
//  char_semantics: ub1;
  I, J: Integer;
  ColumnInfo: TZOracleColumnInfo;
  CurrentVar: PZSQLVar;
  ColumnCount: ub4;
  TempColumnNameLen: Integer;
  P: PAnsiChar;
  DescriptorColumnCount,SubObjectColumnCount: Integer;
  paramdpp: Pointer;
  RowSize: Integer;
  defn_or_bindpp: POCIHandle;
  acsid: ub2;
  function AttributeToString(var P: PAnsiChar; Len: Integer):
    {$IF DEFINED(WITH_RAWBYTESTRING) and not DEFINED(UNICODE)}RawByteString{$ELSE}String{$IFEND};
  begin
    if P <> nil then
      if FClientCP = zCP_UTF16 then begin
        Len := Len shr 1;
        {$IFDEF UNICODE}
        System.SetString(Result, PWideChar(P), Len)
        {$ELSE}
        Result := PUnicodeToRaw(PWideChar(P), Len, ConSettings^.CTRL_CP)
        {$ENDIF}
      end else
      {$IFDEF UNICODE}
      Result := ZEncoding.PRawToUnicode(P, Len, FClientCP)
      {$ELSE}
      if (not ConSettings^.AutoEncode) or (FClientCP = ConSettings^.CTRL_CP) then
        Result := BufferToStr(P, Len)
      else begin
        Result := '';
        PRawToRawConvert(P, Len, FClientCP, ConSettings^.CTRL_CP, Result);
      end
      {$ENDIF}
    else
      Result := '';
    P := nil;
  end;
begin
  //CanBindInt64 := FConnection.GetClientVersion >= 11002000;
  if ResultSetConcurrency = rcUpdatable then
    raise EZSQLException.Create(SLiveResultSetsAreNotSupported);

  if not Assigned(FStmtHandle) or not Assigned(FErrorHandle) then
    raise EZSQLException.Create(SCanNotRetrieveResultSetData);

  CheckOracleError(FPlainDriver, FErrorHandle,
    FPlainDriver.OCIStmtExecute(FOCISvcCtx, FStmtHandle, FErrorHandle, 1, 0,
      nil, nil, OCI_DESCRIBE_ONLY),
      lcExecute, 'OCIStmtExecute', ConSettings);

  { Resize SQLVARS structure if needed }
  CheckOracleError(FPlainDriver, FErrorHandle,
    FPlainDriver.OCIAttrGet(FStmtHandle, OCI_HTYPE_STMT, @ColumnCount, nil,
      OCI_ATTR_PARAM_COUNT, FErrorHandle),
      lcExecute, 'OCIStmtExecute', ConSettings);

  AllocateOracleSQLVars(FColumns, ColumnCount);
  DescriptorColumnCount := 0; SubObjectColumnCount := 0;
  ColumnsInfo.Clear;
  ColumnsInfo.Capacity := ColumnCount; //alloc space once
  RowSize := 0;
  { collect informations for result set columns }
  for I := 1 to ColumnCount do begin
    {$R-}
    CurrentVar := @FColumns.Variables[I-1];
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}

    ColumnInfo := TZOracleColumnInfo.Create;
    ColumnsInfo.Add(ColumnInfo);

    paramdpp := nil; //init
    FPlainDriver.OCIParamGet(FStmtHandle, OCI_HTYPE_STMT, FErrorHandle, paramdpp, I);
    (*CheckOracleError(FPlainDriver, FErrorHandle,
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @char_semantics, nil, OCI_ATTR_CHAR_USED, FErrorHandle),
      lcExecute, 'OCI_ATTR_CHAR_USED', ConSettings);
    if Boolean(char_semantics) then
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @CurrentVar^.value_sz, nil, OCI_ATTR_MAXCHAR_SIZE, FErrorHandle)
    else*)
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @CurrentVar^.value_sz, nil, OCI_ATTR_DATA_SIZE, FErrorHandle);
    CurrentVar^.value_sz := PUB2(@CurrentVar^.value_sz)^; //full init of all 4 Bytes -> is a ub2
    FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
      @CurrentVar^.dty, nil, OCI_ATTR_DATA_TYPE, FErrorHandle);
    if CurrentVar^.dty in [SQLT_NUM, SQLT_VNU] then begin //unsigned char[21](binary) see: http://docs.oracle.com/cd/B19306_01/appdev.102/b14250/oci03typ.htm
      {11g bug: returns Precision 38 for Ordinal values }
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @CurrentVar^.Precision, nil, OCI_ATTR_PRECISION, FErrorHandle);
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @CurrentVar^.Scale, nil, OCI_ATTR_SCALE, FErrorHandle);
      ColumnInfo.Precision := CurrentVar.Precision;
      if CurrentVar.Scale > 0 then
        ColumnInfo.Scale := CurrentVar.Scale;
    end else if CurrentVar^.dty in [SQLT_DATE..SQLT_TIMESTAMP_LTZ] then begin
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @CurrentVar^.Precision, nil, OCI_ATTR_LFPRECISION, FErrorHandle);
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @CurrentVar^.Scale, nil, OCI_ATTR_FSPRECISION, FErrorHandle);
      ColumnInfo.Precision := CurrentVar.Precision;
      if CurrentVar.Scale > 0 then
        ColumnInfo.Scale := CurrentVar.Scale;
    end else begin
      CurrentVar^.Scale := 0;
      CurrentVar^.Precision := 0;
    end;
    ColumnInfo.dty := CurrentVar^.dty;
    P := nil; //init
    CheckOracleError(FPlainDriver, FErrorHandle,
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
      @P, @TempColumnNameLen, OCI_ATTR_NAME, FErrorHandle),
      lcExecute, 'OCI_ATTR_NAME', ConSettings);
    ColumnInfo.ColumnLabel := AttributeToString(P, TempColumnNameLen);

    CheckOracleError(FPlainDriver, FErrorHandle,
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
      @P, @TempColumnNameLen, OCI_ATTR_SCHEMA_NAME, FErrorHandle),
      lcExecute, 'OCI_ATTR_SCHEMA_NAME', ConSettings);
    ColumnInfo.SchemaName := AttributeToString(P, TempColumnNameLen);
    ColumnInfo.CharOctedLength := CurrentVar^.value_sz;

    CurrentVar^.ColType := NormalizeOracleTypeToSQLType(CurrentVar.dty,
      CurrentVar.value_sz, CurrentVar^.DescriptorType,
      CurrentVar.Precision, CurrentVar.Scale, ConSettings, OCI_TYPEPARAM_IN);
    inc(DescriptorColumnCount, Ord(CurrentVar^.DescriptorType > 0));
    ColumnInfo.Signed := True;
    ColumnInfo.Nullable := ntNullable;

    ColumnInfo.ColumnType := CurrentVar^.ColType;
    ColumnInfo.Scale := CurrentVar^.Scale;
    if (ColumnInfo.ColumnType in [stString, stAsciiStream]) then begin
      {EH: Oracle does not calculate true data size if the attachment charset is a multibyte one
        and is different to the native db charset
        so we'll increase the buffers to avoid truncation errors
        and we use 8 byte aligned buffers. Here we go:}
      FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
        @ColumnInfo.CharsetForm, nil, OCI_ATTR_CHARSET_FORM, FErrorHandle);
      if ColumnInfo.ColumnType = stString then begin
          FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
            @ColumnInfo.Precision, nil, OCI_ATTR_DISP_SIZE, FErrorHandle);
        if ColumnInfo.CharsetForm = SQLCS_NCHAR then begin
          CurrentVar^.value_sz := ColumnInfo.Precision;
          ColumnInfo.Precision := ColumnInfo.Precision shr 1;
          CurrentVar.ColType := stUnicodeString;
          ColumnInfo.ColumnCodePage := zCP_UTF16;
          ColumnInfo.csid := OCI_UTF16ID;
        end else begin
          if Consettings.ClientCodePage.Encoding <> ceUTF16 then begin
            CurrentVar^.value_sz := ColumnInfo.Precision * ConSettings.ClientCodePage.CharWidth;
            ColumnInfo.ColumnCodePage := FClientCP;
          end else begin
            CurrentVar^.value_sz := ColumnInfo.Precision shl 1;
            ColumnInfo.ColumnCodePage := zCP_UTF16;
            CurrentVar.ColType := stUnicodeString;
          end;
          FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
            @ColumnInfo.csid, nil, OCI_ATTR_CHARSET_ID, FErrorHandle);
        end;
        CurrentVar^.value_sz := ((CurrentVar^.value_sz shr 3)+1) shl 3;
        ColumnInfo.CharOctedLength := CurrentVar^.value_sz;
      end else begin
        if (ColumnInfo.CharsetForm = SQLCS_NCHAR) or (Consettings.ClientCodePage.Encoding = ceUTF16) then begin
          CurrentVar.ColType := stUnicodeStream;
          ColumnInfo.ColumnCodePage := zCP_UTF16
        end else ColumnInfo.ColumnCodePage := FClientCP;
        FPlainDriver.OCIAttrGet(paramdpp, OCI_DTYPE_PARAM,
          @ColumnInfo.csid, nil, OCI_ATTR_CHARSET_ID, FErrorHandle);
      end;
      ColumnInfo.ColumnType := CurrentVar^.ColType;
    end else if (ColumnInfo.ColumnType = stBytes ) then begin
      ColumnInfo.Precision := CurrentVar^.value_sz;
      ColumnInfo.ColumnCodePage := zCP_Binary
    end else
      ColumnInfo.Precision := CurrentVar^.Precision;
    if CurrentVar.dty = SQLT_NTY  then begin
      Inc(SubObjectColumnCount);
      CurrentVar^.value_sz := SizeOf(PPOCIDescriptor);
      CurrentVar^.ColType := stDataSet;

      CurrentVar^._Obj := DescribeObject(FplainDriver, FConnection,
        paramdpp, FStmtHandle, 0);
      if CurrentVar^._Obj.col_typecode = OCI_TYPECODE_TABLE then
        CurrentVar^.ColType := stDataSet
      else if CurrentVar^._Obj.col_typecode = OCI_TYPECODE_VARRAY then
        CurrentVar^.ColType := stArray
      else //more possible types
        CurrentVar^.ColType := stBinaryStream;
    end;
    {calc required size of field}

    if CurrentVar^.value_sz > 0 then
      if (CurrentVar^.dty = SQLT_VST) or (CurrentVar^.DescriptorType > 0)
      then Inc(RowSize, SizeOf(Pointer)+SizeOf(sb2){NullIndicator})
      else Inc(RowSize, Integer(CurrentVar^.value_sz+SizeOf(sb2)){NullIndicator});
  end;
  {in case all cols are null we need min 1 defined col-variable to exec the stmt }
  if (RowSize = 0 ) then begin
    FIteration := 1;
    FColumns.Variables[0].value_sz := 8;
    RowSize := 8 +SizeOf(sb2);
  end else if (RowSize > FZBufferSize) { now let's calc the iters we can use }
    then FIteration := 1
    else FIteration := FZBufferSize div RowSize;
  if ( DescriptorColumnCount > 0 ) and (DescriptorColumnCount * FIteration > 1000) then //take care we do not create too much descriptors
    FIteration := 1000 div DescriptorColumnCount;
  if (SubObjectColumnCount > 0) then
    FIteration := 1; //EH: current code isn't prepared -> Bugfix required

  SetLength(FRowsBuffer, RowSize * FIteration); //Alloc mem we need for multiple rows
  {give our Vars it's addressation in RowsBuffer}
  P := Pointer(FRowsBuffer);
  { Bind handle and Fills the column info. }
  for I := 1 to FColumns.AllocNum do begin
    {$R-}
    CurrentVar := @FColumns.Variables[I-1];
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    if (CurrentVar^.value_sz = 0) then
      continue;
    CurrentVar.indp := Pointer(P);
    Inc(P, SizeOf(sb2)*FIteration);
    CurrentVar.valuep := P;
    if CurrentVar^.ColType = stUnknown then
      continue;
    if CurrentVar^.DescriptorType <> NO_DTYPE then
      for J := 0 to FIteration -1 do begin
        FStatus := FPlainDriver.OCIDescriptorAlloc(FConnectionHandle, PPOCIDescriptor(P)^, CurrentVar^.DescriptorType, 0, nil);
        if FStatus <> OCI_SUCCESS then
          CheckOracleError(FPlainDriver, FErrorHandle, Fstatus, lcOther, 'OCIDescriptorAlloc', ConSettings);
        Inc(P, SizeOf(PPOCIDescriptor));
      end
    else if CurrentVar^.dty = SQLT_VST then
      for J := 0 to FIteration -1 do begin
        FStatus := FPlainDriver.OCIStringResize(FConnectionHandle, FErrorHandle, CurrentVar^.value_sz, PPOCIString(P));
        if FStatus <> OCI_SUCCESS then
          CheckOracleError(FPlainDriver, FErrorHandle, Fstatus, lcOther, 'OCIStringResize', ConSettings);
        Inc(P, SizeOf(PPOCIString));
      end
    else
      Inc(P, CurrentVar^.value_sz*Cardinal(FIteration));
    defn_or_bindpp := nil;
    FStatus := FPlainDriver.OCIDefineByPos(FStmtHandle, defn_or_bindpp,
      FErrorHandle, I, CurrentVar^.valuep, CurrentVar^.value_sz, CurrentVar^.dty,
      CurrentVar^.indp, CurrentVar^.alenp, nil, OCI_DEFAULT);
    if FStatus <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FErrorHandle, FStatus, lcExecute, 'OCIDefineByPos', ConSettings);
    if (CurrentVar^.ColType in [stUnicodeString, stUnicodeStream]) and (ConSettings.ClientCodePage.ID <> OCI_UTF16ID) then begin
      acsid := OCI_UTF16ID;
      FStatus := FplainDriver.OCIAttrSet(defn_or_bindpp, OCI_HTYPE_DEFINE, @acsid,
           0, OCI_ATTR_CHARSET_ID, FErrorHandle);
      if FStatus <> OCI_SUCCESS then
        CheckOracleError(FPlainDriver, FErrorHandle, FStatus, lcExecute, 'OCIAttrSet(OCI_ATTR_CHARSET_ID)', ConSettings);
    end else if CurrentVar^.dty=SQLT_NTY then
      //second step: http://www.csee.umbc.edu/portal/help/oracle8/server.815/a67846/obj_bind.htm
      CheckOracleError(FPlainDriver, FErrorHandle,
        FPlainDriver.OCIDefineObject(defn_or_bindpp, FErrorHandle, CurrentVar^._Obj.tdo,
           @CurrentVar^._Obj.obj_value, nil, nil, nil),
        lcExecute, 'OCIDefineObject', ConSettings);
  end;

  inherited Open;
end;

procedure TZOracleResultSet_A.ResetCursor;
begin
  FCurrentRowBufIndex := 0;
  fTempLob := nil;
  inherited;

end;

{**
  Releases this <code>ResultSet</code> object's database and
  JDBC resources immediately instead of waiting for
  this to happen when it is automatically closed.

  <P><B>Note:</B> A <code>ResultSet</code> object
  is automatically closed by the
  <code>Statement</code> object that generated it when
  that <code>Statement</code> object is closed,
  re-executed, or is used to retrieve the next result from a
  sequence of multiple results. A <code>ResultSet</code> object
  is also automatically closed when it is garbage collected.
}
procedure TZOracleResultSet_A.BeforeClose;
begin
  inherited BeforeClose;
  SetLength(Self.FRowsBuffer, 0);
  { prepared statement own handles, so dont free them }
  FStmtHandle := nil;
end;

{**
  Moves the cursor down one row from its current position.
  A <code>ResultSet</code> cursor is initially positioned
  before the first row; the first call to the method
  <code>next</code> makes the first row the current row; the
  second call makes the second row the current row, and so on.

  <P>If an input stream is open for the current row, a call
  to the method <code>next</code> will
  implicitly close it. A <code>ResultSet</code> object's
  warning chain is cleared when a new row is read.

  @return <code>true</code> if the new current row is valid;
    <code>false</code> if there are no more rows
}
function TZOracleResultSet_A.Next: Boolean;
var
  Status: Integer;
  FetchedRows: LongWord;
label Success;  //ugly but faster and no double code
begin
  { Checks for maximum row. }
  Result := False;
  if (RowNo > LastRowNo) or ((MaxRows > 0) and (RowNo >= MaxRows)) or (FStmtHandle = nil) then
    Exit;

  if RowNo = 0 then begin//fetch Iteration count of rows
    Status := FPlainDriver.OCIStmtExecute(FOCISvcCtx, FStmtHandle,
      FErrorHandle, FIteration, 0, nil, nil, OCI_DEFAULT);
    if Status = OCI_SUCCESS then begin
      FMaxBufIndex := FIteration -1; //FFetchedRows is an index [0...?] / FIteration is Count 1...?
      goto success; //skip next if's
    end;
  end else if Integer(FCurrentRowBufIndex) < FMaxBufIndex then begin
    Inc(FCurrentRowBufIndex);
    goto Success; //skip next if's
  end else if FMaxBufIndex+1 < FIteration then begin
    RowNo := RowNo + 1;
    Exit;
  end else begin //fetch Iteration count of rows
    Status := FPlainDriver.OCIStmtFetch2(FStmtHandle, FErrorHandle,
      FIteration, OCI_FETCH_NEXT, 0, OCI_DEFAULT);
    FCurrentRowBufIndex := 0; //reset
    if Status = OCI_SUCCESS then begin
      FMaxBufIndex := FIteration -1;
      goto success;
    end;
  end;

  if Status = OCI_NO_DATA then begin
    FPlainDriver.OCIAttrGet(FStmtHandle,OCI_HTYPE_STMT,@FetchedRows,nil,OCI_ATTR_ROWS_FETCHED,FErrorHandle);
    LastRowNo := RowNo+Integer(FetchedRows);  //this makes Exit out in first check on next fetch
    FMaxBufIndex := Integer(FetchedRows)-1;
    RowNo := RowNo + 1;
    //did we retrieve a row or is table empty?
    if FetchedRows > 0 then
      Result := True;
    Exit;
  end;

  CheckOracleError(FPlainDriver, FErrorHandle, Status, lcOther, 'FETCH ROW', ConSettings);

  if Status in [OCI_SUCCESS, OCI_SUCCESS_WITH_INFO] then begin
Success:
    RowNo := RowNo + 1;
    if FMaxBufIndex+1 = FIteration then
      LastRowNo := RowNo;
    Result := True;
  end;
end;

{ TZOracleCallableResultSet_A }

constructor TZOracleCallableResultSet_A.Create(const Statement: IZStatement;
  const SQL: string; StmtHandle: POCIStmt; ErrorHandle: POCIError;
  OraVariables: PZOCIParamBinds; {$IFDEF AUTOREFCOUNT}const{$ENDIF} BindList: TZBindList);
var I, N: Integer;
  BindValue: PZBindValue;
  ParamValue: PZOCIParamBind;
  CurrentVar: PZSQLVar;
begin
  N := 0;
  for I := 0 to BindList.Count -1 do
    if Ord(BindList[i].ParamType) > ord(pctIn) then
      Inc(N);
  AllocateOracleSQLVars(FColumns, N);
  SetLength(FFieldNames, N);

  N := 0;
  for I := 0 to BindList.Count -1 do begin
    {$R-}
    BindValue := BindList[i];
    if Ord(BindValue.ParamType) <= ord(pctIn) then
      Continue;
    ParamValue := @OraVariables[i];
    CurrentVar := @FColumns.Variables[N];
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    CurrentVar.valuep := ParamValue.valuep;
    CurrentVar.dty := ParamValue.dty;
    CurrentVar.value_sz := ParamValue.value_sz;
    CurrentVar.indp := ParamValue.indp;
    CurrentVar.DescriptorType := ParamValue.DescriptorType;
    CurrentVar.ColType := BindValue.SQLType;
    FFieldNames[N] := ParamValue.ParamName;
    Inc(N);
  end;
  inherited Create(Statement, SQL, StmtHandle, ErrorHandle, 0);
  LastRowNo := 1;
end;

function TZOracleCallableResultSet_A.Next: Boolean;
begin
  { Checks for maximum row. }
  Result := False;
  if (RowNo = 1) then
    Exit;
  RowNo := 1;
  Result := True;
end;

procedure TZOracleCallableResultSet_A.Open;
var
  I: Integer;
  ColumnInfo: TZOracleColumnInfo;
  CurrentVar: PZSQLVar;
begin
  { Fills the column info. }
  ColumnsInfo.Clear;
  for I := 0 to FColumns.AllocNum -1 do
  begin
    {$R-}
    CurrentVar := @FColumns.Variables[I];
    {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
    ColumnInfo := TZOracleColumnInfo.Create;

    with ColumnInfo do begin
      ColumnName := '';
      TableName := '';

      ColumnLabel := FFieldNames[i];
      AutoIncrement := False;
      Signed := True;
      Nullable := ntNullable;

      ColumnType := CurrentVar^.ColType;
      Scale := CurrentVar^.Scale;
      ColumnInfo.dty := CurrentVar^.dty;
      {Reset the column type which can be changed by user before}
      if CurrentVar^.ColType in [stString, stUnicodeString, stAsciiStream, stUnicodeStream] then
      begin
        ColumnInfo.ColumnCodePage := FClientCP;
      end else
        ColumnInfo.ColumnCodePage := High(Word);

      Precision := CurrentVar.Precision;
    end;
    ColumnsInfo.Add(ColumnInfo);
  end;

  inherited Open;
end;

{ TZAbstracOracleLobStream }

procedure TZAbstracOracleLobStream.BeforeWrite;
begin
  if (FOwnerLob.FLobStreamMode = lsmRead) or (FOwnerLob.FDescriptorType = OCI_DTYPE_FILE) then
    raise CreateReadOnlyException;
  if FOwnerLob.FIsCloned or (FOwnerLob.FLobLocator = nil) then begin
    CreateTemporary;
    FOwnerLob.FIsCloned := False;
    Open;
  end else if not IsOpen then
    Open;
  FOwnerLob.FIsUpdated := True;
end;

procedure TZAbstracOracleLobStream.Close;
var Status: sword;
begin
  if IsOpen then begin
    Status := FPlainDriver.OCILobClose(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobClose', FConSettings);
  end;
end;

procedure TZAbstracOracleLobStream.CopyLob;
var Status: sword;
    size8: oraub8;
    size4: ub4 absolute size8;
begin
  BeforeWrite;
  { copy the whole lob on server side }
  if FOwnerLob.FIsCloned and (FOwnerLob.FLobStreamMode = lsmReadWrite) then begin
    try
      if Assigned(FPLainDriver.OCILobCopy2) then begin
        Status := FPlainDriver.OCILobGetLength2(FOCISvcCtx, FOCIError, FOwnerlob.FParentLocator, size8);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
        if Status <> OCI_SUCCESS then
          CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobGetLength2', FConSettings);
        Status := FPLainDriver.OCILobCopy2(FOCISvcCtx, FOCIError, FOwnerlob.FLobLocator, FOwnerlob.FParentLocator, size8, 1, 1);
        if Status <> OCI_SUCCESS then
          CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobCopy2', GetConSettings);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      end else begin
        Status := FPlainDriver.OCILobGetLength(FOCISvcCtx, FOCIError, FOwnerlob.FParentLocator, size4);
        if Status <> OCI_SUCCESS then
          CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobGetLength', FConSettings);
        Status := FPLainDriver.OCILobCopy(FOCISvcCtx, FOCIError, FOwnerlob.FLobLocator, FOwnerlob.FParentLocator, size4, 1, 1);
        if Status <> OCI_SUCCESS then
          CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobCopy', GetConSettings);
      end;
    finally
      { notify the current locator does no longer point to copy of Parent locator }
      FOwnerlob.FParentLocator := nil;
      FOwnerLob.FIsCloned := False;
    end;
  end;
end;

procedure TZAbstracOracleLobStream.CopyLocator;
var Status: sword;
begin
  { create a local descriptor }
  if (FOwnerLob.FLobLocator <> nil) then begin
    FOwnerLob.FParentLocator := FOwnerLob.FLobLocator; //local copy
    AllocLobLocator;
    { copy locator next fetch may fill the org locator with next lob infos }
    Status := FPlainDriver.OCILobLocatorAssign(FOCISvcCtx, FOCIError, FOwnerLob.FParentLocator, @FOwnerLob.FLobLocator);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobLocatorAssign', FConSettings);
  end;
end;

constructor TZAbstracOracleLobStream.Create(LobLocator: POCILobLocator;
  const OwnerLob: TZAbstractOracleBlob; const Owner: IImmediatelyReleasable;
  const OpenLobStreams: TZSortedList);
begin
  inherited Create(OwnerLob, Owner, OpenLobStreams);
  FPlainDriver := OwnerLob.FplainDriver;
  FOCIEnv := OwnerLob.FOCIEnv;
  FOCISvcCtx := OwnerLob.FOCISvcCtx;
  FOCIError := OwnerLob.FOCIError;
  FOwnerLob := OwnerLob;
  FOpenLobStreams := OpenLobStreams;
  FConSettings := GetConSettings;
  if FOwnerLob.Fdty = SQLT_CLOB
  then {if (FOwnerLob.Fcsid >= OCI_UTF16ID) or (FOwnerlob.FCharsetForm = SQLCS_NCHAR)
    then flobType := OCI_TEMP_NCLOB
    else} Flobtype := OCI_TEMP_CLOB
  else Flobtype := OCI_TEMP_BLOB;
end;

procedure TZAbstracOracleLobStream.AllocLobLocator;
var Status: sword;
begin
  FOwnerLob.FLobLocator := nil;
  Status := FPlainDriver.OCIDescriptorAlloc(FOCIEnv,
    FOwnerLob.FLobLocator, FOwnerLob.FDescriptorType, 0, nil);
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCIDescriptorAlloc', FConSettings);
  FOwnerLob.FLocatorAllocated := True;
end;

procedure TZAbstracOracleLobStream.CreateTemporary;
var Status: sword;
begin
  if not FReleased then begin
    if FOwnerLob.FLobLocator = nil then
      AllocLobLocator;
    Status := FPlainDriver.OCILobCreateTemporary(FOCISvcCtx, FOCIError,
        FOwnerLob.FLobLocator, FOwnerLob.Fcsid, FOwnerLob.FCharsetForm, Flobtype,
        False, OCI_DURATION_DEFAULT);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobCreateTemporary', FConSettings);
  end;
end;

destructor TZAbstracOracleLobStream.Destroy;
begin
  FOwnerLob.FLobStream := nil;
  if (FOwnerLob.FLobLocator <> nil) then
    Close;
  inherited;
end;

procedure TZAbstracOracleLobStream.FreeLocator;
var Status: sword;
begin
  Status := FPlainDriver.OCIDescriptorFree(FOwnerLob.FLobLocator, FOwnerLob.FDescriptorType);
  FOwnerLob.FLobLocator := nil;
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCIDescriptorFree', FConSettings);
end;

procedure TZAbstracOracleLobStream.FreeTemporary;
var Status: sword;
begin
  if not FReleased then begin
    Status := FPlainDriver.OCILobFreeTemporary(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobFreeTemporary', FConSettings);
  end;
end;

{$IFDEF FPC} {$PUSH} {$WARN 5060 off : Function result variable does not seem to be set} {$ENDIF}
function TZAbstracOracleLobStream.IsOpen: LongBool;
var Status: sword;
begin
  if not FReleased then begin
    Status := FPlainDriver.OCILobIsOpen(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator, Result);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobIsOpen', FConSettings);
  end else Result := False;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{$IFDEF FPC} {$PUSH} {$WARN 5060 off : Function result variable does not seem to be set} {$ENDIF}
function TZAbstracOracleLobStream.IsTemporary: LongBool;
var Status: sword;
begin
  if not FReleased then begin
    Status := FPlainDriver.OCILobIsTemporary(FOCIEnv, FOCIError, FOwnerLob.FLobLocator, Result);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobIsTemporary', FConSettings);
  end else Result := False;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

const OCIOpenModes: array[TZLobStreamMode] of ub1 = (OCI_LOB_READONLY, OCI_LOB_READWRITE, OCI_LOB_READWRITE);
procedure TZAbstracOracleLobStream.Open;
var Status: sword;
    mode: ub1;
begin
  if not FReleased then begin
    mode := OCIOpenModes[fOwnerLob.FLobStreamMode];
    Status := FPlainDriver.OCILobOpen(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator, mode);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobOpen', FConSettings);
    Status := FplainDriver.OCILobCharSetId(FOCIEnv, FOCIError,
      FOwnerLob.FLobLocator, @Fcsid);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobCharSetId', FConSettings);
    Status := FplainDriver.OCILobCharSetForm(FOCIEnv, FOCIError,
      FOwnerLob.FLobLocator, @FOwnerLob.FCharsetForm);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobCharSetForm', FConSettings);
    if FOwnerLob.FDescriptorType <> OCI_DTYPE_FILE then begin
      Status := FplainDriver.OCILobGetChunkSize(FOCISvcCtx, FOCIError,
        FOwnerLob.FLobLocator, FChunk_Size);
      if Status <> OCI_SUCCESS then
        CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobGetChunkSize', FConSettings);
    end;
  end;
end;

{ TZOracleLobStream32 }

function TZOracleLobStream32.GetSize: Int64;
var Status: sword;
  lenp: ub4;
begin
  if FReleased
  then Result := 0
  else begin
    if Not IsOpen then
      Open;
    Status := FplainDriver.OCILobGetLength(FOCISvcCtx, FOCIError, FOwnerLob.FlobLocator, lenp);
    Result := lenp;
    if (Flobtype = OCI_TEMP_CLOB) and (FOwnerLob.Fcsid = OCI_UTF16ID) then
      Result := Result shl 1;
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobGetLength', FConSettings);
  end;
end;

function TZOracleLobStream32.Read(var Buffer; Count: Longint): Longint;
var
  bufl: ub4;
  Status: sword;
  pBuff: PAnsiChar;
  Offset, amtp, amtpBytes: ub4;
begin
  if (Count < 0) then
    raise ERangeError.CreateRes(@SRangeError);
  if not IsOpen then
    Open;
  Result := 0;
  if Count = 0 then
    Exit;
  if FOwnerLob.Fcsid = OCI_UTF16ID then begin
    Offset := (FPosition shr 1) + 1;
    amtp := Count shr 1;
    Count := amtp shl 1;
    bufl := count;
  end else begin
    Offset := FPosition +1;
    amtp := Count;
    bufl := count;
  end;
  Status := OCI_SUCCESS;
  pBuff := @Buffer;
  while Result < Count do begin
    Status := FPlainDriver.OCILobRead(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
      amtp, offset, pBuff, bufl, nil, nil, FOwnerLob.Fcsid, FOwnerLob.FCharsetForm);
    if (Status <> OCI_SUCCESS) then
      Break;
    amtpBytes := amtp;
    Offset := Offset + amtp;
    if FOwnerLob.Fcsid = OCI_UTF16ID then
      amtpBytes := amtpBytes shl 1;
    Inc(pBuff, amtpBytes);
    Dec(bufl, amtpBytes);
    Inc(Result, Longint(amtpBytes));
  end;
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobRead', FConSettings);
  FPosition := FPosition + Result;
end;

function TZOracleLobStream32.ReadPoll(pBuff: PAnsiChar): ub4;
var
  Status: sword;
  Offset, amtp, bufl: ub4;
  pStart: PAnsiChar;
begin
  OffSet := 1;
  if fchunk_size = 0
  then bufl := 8*1024
  else bufl := fchunk_size;
  PStart := pBuff;
  Status := OCI_NEED_DATA;
  while Status = OCI_NEED_DATA do begin
    amtp := 0; //enter polling mode without callback
    Status := FPlainDriver.OCILobRead(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
      amtp, offset, pBuff, bufl, nil, nil, Fcsid, FOwnerLob.FCharsetForm);
    { amtp returns amount of byte filled in the buffer }
    Inc(pBuff, amtp);
  end;
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobRead', FConSettings);
  Result := pBuff - pStart;
  FPosition := Result;
  Close;
end;

function TZOracleLobStream32.Seek(Offset: Longint; Origin: Word): Longint;
begin
  if Origin = soFromEnd then
    Result := FPosition - OffSet
  else if Origin = soFromCurrent then
    Result := FPosition + OffSet
  else
    Result := OffSet;
  if Result <> FPosition then
    FPosition := Result;
end;

procedure TZOracleLobStream32.SetSize(const NewSize: Int64);
var Status: sword;
    newlen: ub4;
    ASize: Int64;
begin
  if (NewSize < Low(ub4)) or (NewSize > High(ub4)) then
    raise ERangeError.CreateRes(@SRangeError);
  BeforeWrite;
  ASize := GetSize;
  if not FReleased and (NewSize <> ASize) then begin
    if NewSize < ASize then begin
      newlen := ub4(NewSize);
      if FOwnerLob.Fcsid = OCI_UTF16ID then
        newlen := newlen shr 1;
      Status := FPlainDriver.OCILobTrim(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator, newlen);
      if Status <> OCI_SUCCESS then
        CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobTrim', FConSettings);
      if FPosition > NewSize then
        FPosition := NewSize;
    end else if NewSize > ASize then
      raise EZSQLException.Create(SOperationIsNotAllowed1);
  end;
end;

{ TZOracleInternalLobStream32 }

function TZOracleInternalLobStream32.Write(const Buffer; Count: LongInt): Longint;
var
  Status: sword;
  Offset, amtpBytes, amtp: ub4;
  pBuff: PAnsiChar;
begin
  if (Count < 0) then
    raise ERangeError.CreateRes(@SRangeError);
  BeforeWrite;
  if Count = 0 then begin
    Result := 0;
    Exit;
  end;
  if FOwnerLob.Fcsid = OCI_UTF16ID then begin
    Count := Count shr 1;
    amtp := Count;
    amtpBytes := Count shl 1; //round to two words no half word excepted
    Offset := (FPosition shr 1) +1;
  end else begin
    amtpBytes := Count;
    amtp := Count;
    Offset := FPosition +1;
  end;
  pBuff := @Buffer;
  Status := FPLainDriver.OCILobWrite(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
    amtp, offset, pBuff, amtpBytes, OCI_ONE_PIECE, nil, nil, FOwnerLob.Fcsid, FOwnerLob.FCharsetForm);
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobWrite', FConSettings);
  Result := amtpBytes;
  FPosition := FPosition + Result;
end;

procedure TZOracleInternalLobStream32.WritePoll(pBuff: PAnsiChar;
  Len: NativeUInt);
var
  Status: sword;
  Offset, amtp, bufl: ub4;
  pEnd: PAnsiChar;
  piece: ub1;
begin
  BeforeWrite;
  if Len = 0 then
    Exit;
  pEnd := pBuff+Len;
  if FChunk_Size = 0
  then bufl := 8*1024
  else bufl := FChunk_Size;
  if (Len < bufl) then begin
    piece := OCI_LAST_PIECE;
    bufl := len;
  end else piece := OCI_FIRST_PIECE;
  Status := OCI_NEED_DATA;
  Offset := 1;
  while Status = OCI_NEED_DATA do begin
    amtp := 0;
    Status := FPLainDriver.OCILobWrite(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
      amtp, offset, pBuff, bufl, Piece, nil, nil, Fcsid, FOwnerLob.FCharsetForm);
    Inc(pBuff, amtp);
    if (pBuff + bufl) < pEnd
    then piece := OCI_NEXT_PIECE
    else piece := OCI_LAST_PIECE
 end;
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobWrite', FConSettings);
end;

{ TZAbstractOracleBlob }

procedure TZAbstractOracleBlob.Clear;
var Stream: TStream;
begin
  if FLobLocator <> nil then begin
    if FlobStream = nil
    then Stream := CreateLobStream(FcolumnCodePage, lsmWrite)
    else Stream := FLobStream;
    if FLobStream.IsTemporary
    then FLobStream.FreeTemporary
    else Stream.Size := 0; //trim the lob
    if FLocatorAllocated then
      FlobStream.FreeLocator;
    FreeAndNil(FlobStream);
  end;
end;

function TZAbstractOracleBlob.Clone(LobStreamMode: TZLobStreamMode): IZBlob;
var AbstractOracleBlob: TZAbstractOracleBlob;
begin
  Result := nil;
  case Fdty of
    SQLT_BFILEE,
    SQLT_CFILEE,
    SQLT_BLOB:  begin
                  AbstractOracleBlob := TZOracleBlob.Create(FConnection, FLobLocator, Fdty, FOpenLobStreams);
                  Result := TZOracleBlob(AbstractOracleBlob);
                end;
    SQLT_CLOB:  begin
                  AbstractOracleBlob := TZOracleClob.Create(FConnection, FLobLocator, Fcharsetform, fcsid, FOpenLobStreams);
                  Result := TZOracleClob(AbstractOracleBlob);
                end;
    else raise EZSQLException.Create(SUnsupportedOperation);
  end;
  AbstractOracleBlob.CopyLocator;
  AbstractOracleBlob.FLobStreamMode := LobStreamMode;
  AbstractOracleBlob.FIsCloned := True;
end;

procedure TZAbstractOracleBlob.CopyLocator;
var Status: sword;
begin
  { create a local descriptor }
  Assert(FLobLocator <> nil);
  FParentLocator := FLobLocator; //local copy
  FLobLocator := nil;
  Status := FPlainDriver.OCIDescriptorAlloc(FOCIEnv, FLobLocator, FDescriptorType, 0, nil);
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCIDescriptorAlloc', FConSettings);
  FLocatorAllocated := True;
  { copy locator next fetch may fill the org locator with next lob infos }
  Status := FPlainDriver.OCILobLocatorAssign(FOCISvcCtx, FOCIError, FParentLocator, @FLobLocator);
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobLocatorAssign', FConSettings);
end;

constructor TZAbstractOracleBlob.Create(const Connection: IZOracleConnection;
  LobLocator: POCILobLocator; dty: ub2; const OpenLobStreams: TZSortedList);
begin
  inherited Create(zCP_Binary, OpenLobStreams);
  FConnection := Connection;
  FOCIEnv := Connection.GetConnectionHandle;
  FOCISvcCtx := Connection.GetServiceContextHandle;
  FLobLocator := LobLocator;
  FOCIError := Connection.GetErrorHandle;
  Fdty := dty;
  FOwner := Connection;
  FPlainDriver := Connection.GetPlainDriver;
  FHas64BitLobMethods := Assigned(FPlainDriver.OCILobRead2);
  FConSettings := Connection.GetConSettings;
  if (Fdty = SQLT_CLOB) or (Fdty = SQLT_BLOB)
  then FDescriptorType := OCI_DTYPE_LOB
  else if (Fdty = SQLT_BFILEE) or (Fdty = OCI_DTYPE_FILE)
    then FDescriptorType := OCI_DTYPE_FILE
    else FDescriptorType := 0; //will raise an error by oci
end;

function TZAbstractOracleBlob.CreateLobStream(CodePage: Word;
  LobStreamMode: TZLobStreamMode): TStream;
begin
  FLobStreamMode := LobStreamMode;
  if FlobStream = nil then
    case Fdty of
      SQLT_BFILEE,
      SQLT_CFILEE,
      SQLT_BLOB:  if FHas64BitLobMethods
                  then FlobStream := TZOracleInternalLobStream64.Create(FLobLocator, Self, FOwner, FOpenLobStreams)
                  else FlobStream := TZOracleInternalLobStream32.Create(FLobLocator, Self, FOwner, FOpenLobStreams);
      SQLT_CLOB:  begin
                    if FHas64BitLobMethods
                    then FlobStream := TZOracleInternalLobStream64.Create(FLobLocator, Self, FOwner, FOpenLobStreams)
                    else FlobStream := TZOracleInternalLobStream32.Create(FLobLocator, Self, FOwner, FOpenLobStreams);
                    if (Fcsid =  OCI_UTF16ID) then begin { we do not overwrite FColumnCodePage but for all MBCS we can seek/read/write safely only if we use UTF16 }
                      if (CodePage <> zCP_UTF16) then begin
                        Result := TZCodePageConversionStream.Create(FlobStream, zCP_UTF16, CodePage, FConSettings, FOpenLobStreams);
                        Exit;
                      end;
                    end else if (CodePage <> FColumnCodePage) then begin
                      Result := TZCodePageConversionStream.Create(FlobStream, FColumnCodePage, CodePage, FConSettings, FOpenLobStreams);
                      Exit;
                    end else if True then

                  end;

      else raise EZSQLException.Create(SUnsupportedOperation);
    end;
  Result := FlobStream;
end;

{$IFDEF FPC} {$PUSH} {$WARN 5057 off : Local variable "B" does not seem to be initialized} {$ENDIF}
destructor TZAbstractOracleBlob.Destroy;
var Status: sword;
  B: LongBool;
begin
  if (FLobLocator <> nil) and FLocatorAllocated then try
    Status := FPlainDriver.OCILobIsOpen(FOCISvcCtx, FOCIError, FLobLocator, B);
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobIsOpen', FConSettings);
    if B then begin
      Status := FPlainDriver.OCILobClose(FOCISvcCtx, FOCIError, FLobLocator);
      if Status <> OCI_SUCCESS then
        CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobClose', FConSettings);
    end;
  finally
    Status := FPlainDriver.OCIDescriptorFree(FLobLocator, FDescriptorType);
    FLobLocator := nil;
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCIDescriptorFree', FConSettings);
  end;
  inherited;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

function TZAbstractOracleBlob.GetLobLocator: POCILobLocator;
begin
  Result := FLobLocator;
end;

function TZAbstractOracleBlob.IsEmpty: Boolean;
begin
  Result := (FLobLocator = nil);
end;

function TZAbstractOracleBlob.Length: Integer;
var Stream: TStream;
begin
  Result := -1;
  if (FLobLocator <> nil) then begin
    Stream := CreateLobStream(FColumnCodePage, lsmRead);
    try
      Result := Stream.Size;
    finally
      Stream.Free;
    end;
  end;
end;

{ TZOracleBlob }

constructor TZOracleBlob.CreateFromBlob(const Lob: IZBLob; LobLocator: POCILobLocator;
  const Connection: IZOracleConnection; const OpenLobStreams: TZSortedList);
var P: Pointer;
  L: NativeUint;
  R: RawByteString;
  Stream: TZAbstracOracleLobStream;
begin
  Create(Connection, LobLocator, SQLT_BLOB, OpenLobStreams);
  R := '';
  Fdty := SQLT_BLOB;
  FLobStreamMode := lsmWrite;
  if not Lob.IsEmpty then begin
    P := Lob.GetBuffer(R, L);
    if FHas64BitLobMethods
    then Stream := TZOracleInternalLobStream64.Create(nil, Self, FOwner, OpenLobStreams)
    else Stream := TZOracleInternalLobStream32.Create(nil, Self, FOwner, OpenLobStreams);
    try
      Stream.CreateTemporary;
      if P <> nil then
        Assert(Stream.Write(P^, L) = NativeInt(L));
    finally
      Stream.Free;
    end;
  end;
end;

{ TZOracleClob }

constructor TZOracleClob.Create(const Connection: IZOracleConnection;
      LobLocator: POCILobLocator; CharsetForm: ub1; csid: ub2;
      const OpenLobStreams: TZSortedList);
var CodePage: PZCodePage;
begin
  inherited Create(Connection, Loblocator, SQLT_CLOB, OpenLobStreams);
  Fcsid := csid;
  FCharsetForm := CharsetForm;
  if (FCharsetForm = SQLCS_NCHAR) or (csid >= OCI_UTF16ID) then begin
    FColumnCodePage := zCP_UTF16;
    Fcsid := OCI_UTF16ID;
    FBytesPerChar := 2;
  end else if csid = 0 {binary}
  then FColumnCodePage := zCP_Binary
  else begin
    CodePage := FPlainDriver.ValidateCharEncoding(csid);
    if CodePage.ID = 0
    then FColumnCodePage := FconSettings.ClientCodePage.CP
    else if ZEncoding.IsMBCSCodePage(CodePage.CP) then
      Fcsid := OCI_UTF16ID; //oracle is vinny nilly reading chunks for mbcs's only ut16 works savely
    FBytesPerChar := CodePage.CharWidth;
    FColumnCodePage := CodePage.CP;
  end;
end;

constructor TZOracleClob.CreateFromClob(const Lob: IZCLob; LobLocator: POCILobLocator;
  CharsetForm: ub1; csid: ub2; const Connection: IZOracleConnection;
  const OpenLobStreams: TZSortedList);
var P: Pointer;
  L: NativeUint;
  R: RawByteString;
  U: UnicodeString;
  Stream: TZAbstracOracleLobStream;
begin
  Create(Connection, LobLocator, CharsetForm, csid, OpenLobStreams);
  FLobStreamMode := lsmWrite;
  if Fcsid = OCI_UTF16ID then begin
    U := '';
    P := Lob.GetPWideChar(U, L);
    L := L shl 1;
  end else begin
    R := '';
    P := Lob.GetBuffer(R, L);
  end;
  if P <> nil then begin
    if FHas64BitLobMethods
    then Stream := TZOracleInternalLobStream64.Create(nil, Self, FOwner, OpenLobStreams)
    else Stream := TZOracleInternalLobStream32.Create(nil, Self, FOwner, OpenLobStreams);
    try
      Stream.CreateTemporary;
      Assert(Stream.Write(P^, L) = NativeInt(L));
    finally
      Stream.Free;
    end;
  end;
end;

function TZOracleClob.CreateLobStream(CodePage: Word;
  LobStreamMode: TZLobStreamMode): TStream;
begin
  if (CodePage = FColumnCodePage) and (CodePage <> zCP_UTF16) and IsMBCSCodePage(CodePage) then begin
    FLobStreamMode := LobStreamMode;
    if FHas64BitLobMethods then begin
      FlobStream := TZOracleInternalLobStream64.Create(FLobLocator, Self, FOwner, FOpenLobStreams);
      Result := TZOracleRawMultibyteStream64.Create(FlobStream, CodePage, CodePage, FconSettings, FOpenLobStreams, FBytesPerChar);
    end else begin
      FlobStream := TZOracleInternalLobStream32.Create(FLobLocator, Self, FOwner, FOpenLobStreams);
      Result := TZOracleRawMultibyteStream32.Create(FlobStream, CodePage, CodePage, FconSettings, FOpenLobStreams, FBytesPerChar);
    end
  end else Result := inherited CreateLobStream(CodePage, LobStreamMode);
end;

function TZOracleClob.GetPAnsiChar(CodePage: Word;
  var ConversionBuf: RawByteString; out Len: NativeUInt): PAnsiChar;
var
  OCIStream32: TZOracleInternalLobStream32;
  OCIStream64: TZOracleInternalLobStream64;
  Size: Int64;
  pBuf: PAnsiChar;
begin
  if FlobLocator = nil then begin
    Result := nil;
    Len := 0;
    Exit;
  end;
  {EH: this is a optimization to prevent A2W+W2A conversion for Multibyte char sets.
   Oci does NOT return the amount of chars NOT bytes. The streams are made to work
   with bytes so we have no clue how many bytes we can fetch for UTF8 f.e. using
   chunked Stream.Read(), but here we read full size. and we can calc
   the bufl param by chars*BytesPerChar ... And of cours we can perform poll reads }
  if (CodePage = FColumnCodePage) and (FBytesPerChar > 1) then begin
    if FHas64BitLobMethods then begin
      OCIStream64 := TZOracleInternalLobStream64.Create(FLobLocator, Self, FConnection, FOpenLobStreams);
      Size := OCIStream64.Size;
      OCIStream32 := nil
    end else begin
      OCIStream32 := TZOracleInternalLobStream32.Create(FLobLocator, Self, FConnection, FOpenLobStreams);
      Size := OCIStream32.Size;
      OCIStream64 := nil;
    end;
    try
      if Size = 0 then begin
        Result := pEmptyAnsiString;
        Len := 0;
        Exit;
      end;
      Size := Size shr 1;
      ConversionBuf := EmptyRaw;
      ZSetString(nil, Size*FBytesPerChar, ConversionBuf{$IFDEF WITH_RAWBYTESTRING}, CodePage{$ENDIF}); //reserve full mem
      pBuf := Pointer(ConversionBuf);
      if FHas64BitLobMethods
      then Len := OCIStream64.ReadPoll(pBuf)
      else Len := OCIStream32.ReadPoll(pBuf);
      SetLength(ConversionBuf, len);
      Result := Pointer(ConversionBuf);
    finally
      FreeAndNil(OCIStream32);
      FreeAndNil(OCIStream64);
    end;
  end else
    Result := inherited GetPAnsiChar(CodePage, ConversionBuf, Len);
end;

{ TZOracleLobStream64 }

function TZOracleLobStream64.GetSize: Int64;
var Status: sword;
  lenp: oraub8;
begin
  if FReleased or (FOwnerLob.FlobLocator = nil)
  then Result := 0
  else begin
    if Not IsOpen then
      Open;
    Status := FplainDriver.OCILobGetLength2(FOCISvcCtx, FOCIError, FOwnerLob.FlobLocator, lenp);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
    Result := lenp;
    if Status <> OCI_SUCCESS then
      CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobGetLength2', FConSettings);
    if (FOwnerLob.Fcsid = OCI_UTF16ID) then
      Result := Result shl 1;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  end;
end;

function TZOracleLobStream64.Read(var Buffer; Count: LongInt): Longint;
var
  Status: sword;
  pBuff: PAnsiChar;
  asize, byte_amtp, char_amtp, bufl, Offset: oraub8;
begin
  if (Count < 0) then
    raise ERangeError.CreateRes(@SRangeError);
  if not IsOpen then
    Open;
  Result := 0; //init
  if Count = 0 then Exit;

  { get bytes/(single-byte)character count of lob }
  Status := FplainDriver.OCILobGetLength2(FOCISvcCtx, FOCIError, FOwnerLob.FlobLocator, asize);
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobGetLength2', FConSettings);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
  if FOwnerLob.Fcsid = OCI_UTF16ID then begin
    Offset := (FPosition shr 1) +1; //align to char position
    char_amtp := Count shr 1;
    byte_amtp := char_amtp shl 1; //no odd bytes allowed
  end else begin
    Offset := FPosition +1;
    char_amtp := Count;
    byte_amtp := char_amtp;
  end;

  pBuff := @Buffer;
  bufl := byte_amtp;
  Status := FPlainDriver.OCILobRead2(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
    @byte_amtp, @char_amtp, Offset, pBuff, bufl, OCI_ONE_PIECE, nil, nil, FOwnerLob.Fcsid, FOwnerLob.FCharsetForm);
  Result := byte_amtp;
  if (Status <> OCI_SUCCESS) then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobRead2', FConSettings);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  FPosition := FPosition + Result;
end;

function TZOracleLobStream64.ReadPoll(pBuff: PAnsiChar): oraub8;
var byte_amtp, char_amtp, bufl, OffSet: oraub8;
  piece: ub1;
  Status: Sword;
  pStart: pAnsiChar;
begin
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
  if FChunk_Size = 0
  then bufl := 8*1024
  else bufl := FChunk_Size; //usually 8k/chunk
  OffSet := 1;
  pStart := pBuff;
  Status := OCI_NEED_DATA;
  { these parameters need to be set to initialize the poilling mode
    without using a callback function:
    piece must be OCI_FIRST_PIECE
    byte_amtp and char_amtp must be zero
    bufl must be greater than zero
    Offset is ignored
  }
  piece := OCI_FIRST_PIECE;
  while (Status = OCI_NEED_DATA) do begin
    byte_amtp := 0;
    char_amtp := 0;
    Status := FPlainDriver.OCILobRead2(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
      @byte_amtp, @char_amtp, Offset, pBuff, bufl, piece, nil, nil, Fcsid, FOwnerLob.FCharsetForm);
    Inc(pBuff, byte_amtp);
    piece := OCI_NEXT_PIECE;
  end;
  if (Status <> OCI_SUCCESS) then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobRead2', FConSettings);
  Result := pBuff - pStart;
  FPosition := Result;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  Close;
end;

function TZOracleLobStream64.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  if Origin = soEnd then
    Result := FPosition - OffSet
  else if Origin = soCurrent then
    Result := FPosition + OffSet
  else
    Result := OffSet;
  if Result <> FPosition then
    FPosition := Result;
end;

procedure TZOracleLobStream64.SetSize(const NewSize: Int64);
var Status: sword;
    newlen: oraub8;
    ASize: Int64;
begin
  if (NewSize < 0) then
    raise ERangeError.CreateRes(@SRangeError);
  BeforeWrite;
  ASize := GetSize;
  if not FReleased and (NewSize <> ASize) then begin
    if NewSize < ASize then begin
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      newlen := oraub8(NewSize);
      if (FOwnerLob.Fcsid = OCI_UTF16ID) then
        newlen := newlen shr 1; //need size in chars not bytes
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      Status := FPlainDriver.OCILobTrim2(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator, newlen);
      if Status <> OCI_SUCCESS then
        CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobTrim2', FConSettings);
      if FPosition > NewSize then
        FPosition := NewSize;
      {$IFDEF DEBUG}
      Assert(GetSize = NewSize);
      {$ENDIF}
    end else if NewSize > ASize then
      raise EZSQLException.Create(SOperationIsNotAllowed1);
  end;
end;

{ TZOracleInternalLobStream64 }

function TZOracleInternalLobStream64.Write(const Buffer;
  Count: LongInt): Longint;
var
  Status: sword;
  byte_amtp, char_amtp, Offset: oraub8;
  pBuff: PAnsiChar;
begin
  if (Count < 0) then
    raise ERangeError.CreateRes(@SRangeError);
  BeforeWrite;
  if Count = 0 then begin
    Result := 0;
    Exit;
  end;

{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
  if FOwnerLob.Fcsid = OCI_UTF16ID then begin//UTF16
    Offset := (FPosition shr 1) +1;
    char_amtp := Count shr 1;
    byte_amtp := char_amtp shl 1;
  end else begin
    Offset := Position +1;
    char_amtp := Count;
    byte_amtp := char_amtp;
  end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  pBuff := @Buffer;
  Status := FPLainDriver.OCILobWrite2(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
    byte_amtp, char_amtp, offset, pBuff, byte_amtp, OCI_ONE_PIECE, nil, nil, FOwnerLob.Fcsid, FOwnerLob.FCharsetForm);
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobWrite2', FConSettings);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
  Result := byte_amtp;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  FPosition := FPosition + Result;
end;

{ TZOracleExternalLobStream64 }

{$IFDEF FPC} {$PUSH} {$WARN 5033 off : Function result variable does not seem to be set} {$ENDIF}
function TZOracleExternalLobStream64.Write(const Buffer;
  Count: LongInt): Longint;
begin
  raise CreateReadOnlyException;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{ TZOracleExternalLobStream32 }

{$IFDEF FPC} {$PUSH} {$WARN 5033 off : Function result variable does not seem to be set} {$ENDIF}
function TZOracleExternalLobStream32.Write(const Buffer;
  Count: LongInt): Longint;
begin
  raise CreateReadOnlyException;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

procedure TZOracleInternalLobStream64.WritePoll(pBuff: PAnsiChar;
  Len: NativeUInt);
var
  Status: sword;
  Offset, byte_amtp, char_amtp, bufl: oraub8;
  pEnd: PAnsiChar;
  piece: ub1;
begin
  BeforeWrite;
  if Len = 0 then
    Exit;
  pEnd := pBuff+Len;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
  if FChunk_Size = 0
  then bufl := 8*1024
  else bufl := FChunk_Size;
  if (Len < bufl) then
    bufl := len;
  piece := OCI_FIRST_PIECE;
  Status := OCI_NEED_DATA;
  Offset := 1;
  while Status = OCI_NEED_DATA do begin
    char_amtp := 0;
    byte_amtp := 0;
    Status := FPLainDriver.OCILobWrite2(FOCISvcCtx, FOCIError, FOwnerLob.FLobLocator,
      byte_amtp, char_amtp, offset, pBuff, bufl, piece, nil, nil, Fcsid, FOwnerLob.FCharsetForm);
    Inc(pBuff, byte_amtp);
    if (pBuff + bufl) < pEnd
    then piece := OCI_NEXT_PIECE
    else begin
      piece := OCI_LAST_PIECE;
      bufl := pEnd - pBuff;
    end;
 end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  if Status <> OCI_SUCCESS then
    CheckOracleError(FPlainDriver, FOCIError, Status, lcOther, 'OCILobWrite', FConSettings);
end;

{ TZOracleCachedResultSet }

function TZOracleCachedResultSet.CreateLob(ColumnIndex: Integer;
  LobStreamMode: TZLobStreamMode): IZBlob;
var ColumnInfo: TZOracleColumnInfo;
  Connection: IZOracleConnection;
  OracleLob: TZOracleLob;
begin
  Result := nil;
  ColumnInfo := TZOracleColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]);
  Connection := GetStatement.GetConnection as IZOracleConnection;
  case ColumnInfo.dty of
    SQLT_BLOB,
    SQLT_BFILEE,
    SQLT_CFILEE: begin
                  OracleLob := TZOracleBlob.Create(Connection, nil, ColumnInfo.dty, FOpenLobStreams);
                  OracleLob.FLobStreamMode := LobStreamMode;
                  Result := TZOracleBLob(OracleLob);
                end;
    SQLT_CLOB:  begin
                  OracleLob := TZOracleClob.Create(Connection, nil, ColumnInfo.CharsetForm,
                    ColumnInfo.csid, FOpenLobStreams);
                  OracleLob.FLobStreamMode := LobStreamMode;
                  Result := TZOracleClob(OracleLob);
                end;
    else Result := inherited CreateLob(ColumnIndex, LobStreamMode);
  end;
  UpdateLob(ColumnIndex, Result);
end;

procedure TZOracleCachedResultSet.FillColumnsInfo(
  const ColumnsInfo: TObjectList);
var OracleResultSet: IZOracleResultSet;
begin
  if Supports(ResultSet, IZOracleResultSet, OracleResultSet)
  then OracleResultSet.AssignColumnsInfo(ColumnsInfo)
  else inherited FillColumnsInfo(ColumnsInfo);
end;

class function TZOracleCachedResultSet.GetRowAccessorClass: TZRowAccessorClass;
begin
  Result := TZOracleRowAccessor;
end;

{ TZOracleRowAccessor }

procedure TZOracleRowAccessor.FillFromFromResultSet(const ResultSet: IZResultSet;
  {$IFDEF AUTOREFCOUNT}const {$ENDIF}IndexPairList: TZIndexPairList);
var
  ColumnIndex, i: Integer;
  IndexPair: PZIndexPair;
  SQLType: TZSQLType;

  procedure CopyLobLocator;
  var Lob: IZBlob;
      OCILob: IZOracleLob;
      IsNull: Boolean;
  begin
    Lob := GetBlob(ColumnIndex, IsNull);
    if (Lob <> nil) and (Lob.QueryInterface(IZOracleLob, OCILob) = S_OK) then
      OCILob.CopyLocator;
  end;
begin
  inherited FillFromFromResultSet(ResultSet, IndexPairList);
  if (FHighLobCols > -1) and not FCachedLobs then
    for i := 0 to IndexPairList.Count -1 do begin
      IndexPair := IndexPairList[i];
      ColumnIndex := IndexPair.ColumnIndex;
      SQLType := FColumnTypes[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
      if (SQLType in [stAsciiStream..stBinaryStream]) then
        CopyLobLocator;
    end;
end;

{ TZOracleRawMultibyteStream32 }

constructor TZOracleRawMultibyteStream32.Create(const Owner: TStream;
  SourceCodePage, DestCodePage: Word; ConSettings: PZConSettings;
  const OpenLobStreams: TZSortedList; BytesPerChar: Cardinal);
begin
  FBytesPerChar := BytesPerChar;
  inherited Create(Owner, SourceCodePage, DestCodePage, ConSettings,
    OpenLobStreams);
end;

procedure TZOracleRawMultibyteStream32.FlushMemToStream(Buf: Pointer;
  Len: NativeUInt; Stream: TStream);
begin
  TZOracleInternalLobStream32(Stream).WritePoll(Buf, Len);
end;

procedure TZOracleRawMultibyteStream32.ReadStreamToMem(var Buf: Pointer;
  var Len: NativeUint; Stream: TStream);
var BytesTotal: NativeUint;
begin
  Len := Len shr 1;
  BytesTotal := Len * FBytesPerChar;
  GetMem(Buf, BytesTotal);
  Len := TZOracleInternalLobStream32(Stream).ReadPoll(Buf);
  if Len <> BytesTotal then
    ReallocMem(Buf, Len);
end;

{ TZOracleRawMultibyteStream64 }

procedure TZOracleRawMultibyteStream64.FlushMemToStream(Buf: Pointer;
  Len: NativeUInt; Stream: TStream);
begin
  TZOracleInternalLobStream64(Stream).WritePoll(Buf, Len);
end;

procedure TZOracleRawMultibyteStream64.ReadStreamToMem(var Buf: Pointer;
  var Len: NativeUint; Stream: TStream);
var BytesTotal: NativeUint;
begin
  Len := Len shr 1;
  BytesTotal := Len * FBytesPerChar;
  GetMem(Buf, BytesTotal);
  Len := TZOracleInternalLobStream64(Stream).ReadPoll(Buf);
  if Len <> BytesTotal then
    ReallocMem(Buf, Len);
end;

initialization
{$ENDIF ZEOS_DISABLE_ORACLE}
end.
