{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           Test Case for Master-Detail Links             }
{                                                         }
{         Originally written by Sergey Seroukhov          }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2006 Zeos Development Group       }
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
{   http://zeosbugs.firmos.at (BUGTRACKER)                }
{   svn://zeos.firmos.at/zeos/trunk (SVN Repository)      }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZTestMasterDetail;

interface
{$I ZComponent.inc}

uses
  {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF}, Db, ZSqlStrings, SysUtils, ZTokenizer, ZGenericSqlToken,
  ZConnection, ZDataset, ZTestDefinitions, ZDbcMySql, ZDbcPostgreSql, ZDbcDbLib;

type

  {** Implements a test case for class TZReadOnlyQuery. }
  TZTestMasterDetailCase = class(TZComponentPortableSQLTestCase)
  private
    Connection: TZConnection;
    MasterDataSource: TDataSource;
    MasterQuery: TZQuery;
    DetailQuery: TZQuery;
    DetailQuery2: TZQuery;
    DetailQuery3: TZQuery;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestDataSource;
    procedure TestMasterFields;
    procedure TestClientDataset;
    procedure TestClientDatasetWithForeignKey;
  end;

implementation

uses Classes, ZDbcUtils, ZTestConsts, ZDbcIntfs, ZSqlMonitor, ZdbcLogging;

const TestRowID = 1000;

{ TZTestMasterDetailCase }

{**
  Prepares initial data before each test.
}
procedure TZTestMasterDetailCase.SetUp;
begin
  Connection := CreateDatasetConnection;

  MasterQuery := TZQuery.Create(nil);
  MasterQuery.Connection := Connection;

  MasterDataSource := TDataSource.Create(nil);
  MasterDataSource.DataSet := MasterQuery;

  DetailQuery := TZQuery.Create(nil);
  DetailQuery.Connection := Connection;

  DetailQuery2 := TZQuery.Create(nil);
  DetailQuery2.Connection := Connection;

  DetailQuery3 := TZQuery.Create(nil);
  DetailQuery3.Connection := Connection;
end;

{**
  Removes data after each test.
}
procedure TZTestMasterDetailCase.TearDown;
begin
  DetailQuery.Close;
  DetailQuery.Free;

  DetailQuery2.Close;
  DetailQuery2.Free;

  DetailQuery3.Close;
  DetailQuery3.Free;

  MasterQuery.Close;
  MasterQuery.Free;

  MasterDataSource.Free;

  Connection.Disconnect;
  Connection.Free;
end;

{**
  Runs a test for SQL parameters.
}
procedure TZTestMasterDetailCase.TestDataSource;
begin
  MasterQuery.SQL.Text := 'SELECT * FROM department ORDER BY dep_id';
  MasterQuery.Open;

  DetailQuery.SQL.Text := 'SELECT * FROM people WHERE p_dep_id=:dep_id';
  DetailQuery.DataSource := MasterDataSource;
  DetailQuery.Open;

  MasterQuery.First;
  CheckEquals(1, MasterQuery.FieldByName('dep_id').AsInteger);
  CheckEquals(2, DetailQuery.RecordCount);
  CheckEquals(1, DetailQuery.FieldByName('p_dep_id').AsInteger);

  MasterQuery.Next;
  CheckEquals(2, MasterQuery.FieldByName('dep_id').AsInteger);
  CheckEquals(2, DetailQuery.RecordCount);
  CheckEquals(2, DetailQuery.FieldByName('p_dep_id').AsInteger);
end;

{**
  Runs a test for master-detail links.
}
procedure TZTestMasterDetailCase.TestMasterFields;
begin
  MasterQuery.SQL.Text := 'SELECT * FROM department ORDER BY dep_id';
  MasterQuery.Open;

  DetailQuery.SQL.Text := 'SELECT * FROM people';
  DetailQuery.MasterSource := MasterDataSource;
  DetailQuery.MasterFields := 'dep_id';
  DetailQuery.LinkedFields := 'p_dep_id';
  DetailQuery.Open;

  MasterQuery.First;
  CheckEquals(1, MasterQuery.FieldByName('dep_id').AsInteger);
  CheckEquals(2, DetailQuery.RecordCount);
  CheckEquals(1, DetailQuery.FieldByName('p_dep_id').AsInteger);

  MasterQuery.Next;
  CheckEquals(2, MasterQuery.FieldByName('dep_id').AsInteger);
  CheckEquals(2, DetailQuery.RecordCount);
  CheckEquals(2, DetailQuery.FieldByName('p_dep_id').AsInteger);
end;

{**
  Runs a test for in clientdatset rules
  All detail-queries should be updated in a single transaction.
}
procedure TZTestMasterDetailCase.TestClientDataset;
var
  SQLMonitor: TZSQLMonitor;
  CommitCount, I: Integer;
begin
  SQLMonitor := TZSQLMonitor.Create(nil);
  SQLMonitor.Active := True;
  MasterQuery.SQL.Text := 'SELECT * FROM default_values ORDER BY d_id';
  MasterQuery.Open;

  DetailQuery.SQL.Text := 'SELECT * FROM date_values';
  DetailQuery.MasterSource := MasterDataSource;
  DetailQuery.MasterFields := 'd_id';
  DetailQuery.LinkedFields := 'd_id';
  DetailQuery.Open;

  DetailQuery2.SQL.Text := 'SELECT * FROM date_values';
  DetailQuery2.MasterSource := MasterDataSource;
  DetailQuery2.MasterFields := 'd_id';
  DetailQuery2.LinkedFields := 'd_id';
  DetailQuery2.Open;

  DetailQuery3.SQL.Text := 'SELECT * FROM date_values';
  DetailQuery3.MasterSource := MasterDataSource;
  DetailQuery3.MasterFields := 'd_id';
  DetailQuery3.LinkedFields := 'd_id';
  DetailQuery3.Open;

  CommitCount := 0;
  try
    MasterQuery.Append;
    MasterQuery.FieldByName('d_id').AsInteger := TestRowID;
    CheckEquals(True, (MasterQuery.State = dsInsert), 'MasterQuery Insert-State');

    DetailQuery.Append;
    DetailQuery.FieldByName('d_id').AsInteger := TestRowID;
    DetailQuery.FieldByName('d_date').AsDateTime := Date;
    DetailQuery.FieldByName('d_time').AsDateTime := Time;
    CheckEquals(True, (DetailQuery.State = dsInsert), 'MasterQuery Insert-State');

    DetailQuery2.Append;
    DetailQuery2.FieldByName('d_id').AsInteger := TestRowID+1;
    DetailQuery2.FieldByName('d_date').AsDateTime := Date;
    DetailQuery2.FieldByName('d_time').AsDateTime := Time;
    CheckEquals(True, (DetailQuery2.State = dsInsert), 'MasterQuery Insert-State');

    DetailQuery3.Append;
    DetailQuery3.FieldByName('d_id').AsInteger := TestRowID+2;
    DetailQuery3.FieldByName('d_date').AsDateTime := Date;
    DetailQuery3.FieldByName('d_time').AsDateTime := Time;
    CheckEquals(True, (DetailQuery3.State = dsInsert), 'MasterQuery Insert-State');

    MasterQuery.Post;

    CheckEquals(True, (MasterQuery.State = dsBrowse), 'MasterQuery Browse-State');
    CheckEquals(True, (DetailQuery.State = dsBrowse), 'DetailQuery Browse-State');
    CheckEquals(True, (DetailQuery2.State = dsBrowse), 'DetailQuery Browse-State');
    CheckEquals(True, (DetailQuery3.State = dsBrowse), 'DetailQuery Browse-State');

    for i := 0 to SQLMonitor.TraceCount -1 do
      if SQLMonitor.TraceList[i].Category = lcTransaction then
        if Pos('COMMIT', SQLMonitor.TraceList[i].Message) > 0 then
          Inc(CommitCount);
    CheckEquals(1, CommitCount, 'CommitCount');
  finally
    MasterQuery.SQL.Text := 'delete from default_values where d_id = '+IntToStr(TestRowID);
    MasterQuery.ExecSQL;
    MasterQuery.SQL.Text := 'delete from date_values where d_id = '+IntToStr(TestRowID);
    MasterQuery.ExecSQL;
    MasterQuery.SQL.Text := 'delete from date_values where d_id = '+IntToStr(TestRowID+1);
    MasterQuery.ExecSQL;
    MasterQuery.SQL.Text := 'delete from date_values where d_id = '+IntToStr(TestRowID+1);
    MasterQuery.ExecSQL;
    SQLMonitor.Free;
  end;
end;

{**
  Runs a test for in extendet clientdatset rules
  All detail-queries should be updated in a single transaction.
  But now the MasterTable should be updated first for an valid ForegnKey.
  Then all DetailTables should have been updated.
  Very tricky and has to deal with MetaData informations.
}
procedure TZTestMasterDetailCase.TestClientDatasetWithForeignKey;
var
  SQLMonitor: TZSQLMonitor;
  CommitCount, I: Integer;

begin
  SQLMonitor := TZSQLMonitor.Create(nil);
  SQLMonitor.Active := True;
  MasterQuery.SQL.Text := 'SELECT * FROM department ORDER BY dep_id';
  MasterQuery.Open;

  DetailQuery.SQL.Text := 'SELECT * FROM people';
  DetailQuery.MasterSource := MasterDataSource;
  DetailQuery.MasterFields := 'dep_id';
  DetailQuery.LinkedFields := 'p_dep_id';
  DetailQuery.Open;
  try
    MasterQuery.Append;
    MasterQuery.FieldByName('dep_id').AsInteger := TestRowID;
    MasterQuery.FieldByName('dep_name').AsString := '������';
    MasterQuery.FieldByName('dep_shname').AsString := 'abcdef';
    MasterQuery.FieldByName('dep_address').AsString := 'A adress of ������';
    CheckEquals(True, (MasterQuery.State = dsInsert), 'MasterQuery Insert-State');

    DetailQuery.Append;
    DetailQuery.FieldByName('p_id').AsInteger := TestRowID;
    DetailQuery.FieldByName('p_dep_id').AsInteger := TestRowID;
    DetailQuery.FieldByName('p_name').AsString := '������';
    DetailQuery.FieldByName('p_begin_work').AsDateTime := now;
    DetailQuery.FieldByName('p_end_work').AsDateTime := now;
    DetailQuery.FieldByName('p_picture').AsString := '';
    DetailQuery.FieldByName('p_resume').AsString := '';
    DetailQuery.FieldByName('p_redundant').AsInteger := 5;
    CheckEquals(True, (DetailQuery.State = dsInsert), 'MasterQuery Insert-State');

    MasterQuery.Post;

    CheckEquals(True, (MasterQuery.State = dsBrowse), 'MasterQuery Browse-State');
    CheckEquals(True, (DetailQuery.State = dsBrowse), 'DetailQuery Browse-State');

    for i := 0 to SQLMonitor.TraceCount -1 do
      if SQLMonitor.TraceList[i].Category = lcTransaction then
        if Pos('COMMIT', SQLMonitor.TraceList[i].Message) > 0 then
          Inc(CommitCount);
    CheckEquals(1, CommitCount, 'CommitCount');
  finally
    MasterQuery.SQL.Text := 'delete from department where dep_id = '+IntToStr(TestRowID);
    MasterQuery.ExecSQL;
    MasterQuery.SQL.Text := 'delete from people where p_id = '+IntToStr(TestRowID);
    MasterQuery.ExecSQL;
    SQLMonitor.Free;
  end;
end;

initialization
  RegisterTest('component',TZTestMasterDetailCase.Suite);
end.
