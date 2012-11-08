unit Nullpobug.UnitTest;

interface

uses
  System.SysUtils
  , System.StrUtils
  , System.Generics.Collections
  , System.Rtti
  ;

type
  EAssertionError = class(Exception);
  ESkipTest = class(Exception);

  TTestResultType = (rtOK, rtFail, rtError, rtSkip);

  TTestResult = class(TObject)
  private
    FResultType: TTestResultType;
    FError: Exception;
    FTestMethodName: String;
    FTestCaseName: String;
  public
    constructor Create;
    destructor Destroy; override;
    property ResultType: TTestResultType read FResultType write FResultType;
    property Error: Exception read FError write FError;
    property TestMethodName: String read FTestMethodName write FTestMethodName;
    property TestCaseName: String read FTestCaseName write FTestCaseName;
  end;

  TOnRanTestMethod = procedure(TestResult: TTestResult) of object;

  TTestCase = class(TObject)
  private
    FOnRanTestMethod: TOnRanTestMethod;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetUp; virtual;
    procedure TearDown; virtual;
    procedure AssertTrue(Value: Boolean);
    procedure AssertFalse(Value: Boolean);
    procedure AssertEquals(Value1, Value2: Integer); overload;
    procedure AssertEquals(Value1, Value2: String); overload;
    procedure Run(TestResultList: TObjectList<TTestResult>);
    property OnRanTestMethod: TOnRanTestMethod read FOnRanTestMethod write FOnRanTestMethod;
  end;

  TTestCaseClass = class of TTestCase;

  TTestRunner = class(TObject)
  private
    FTestCaseList: TObjectList<TTestCase>;
    FTestResultList: TObjectList<TTestResult>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddTestCase(TestCaseClass: TTestCaseClass);
    procedure Run(TestCase: TTestCase); virtual;
    procedure RunTests; virtual;
    property TestResultList: TObjectList<TTestResult> read FTestResultList;
  end;

  TTextTestRunner = class(TTestRunner)
  public
    procedure WriteHeader;
    procedure WriteTestResult(TestResult: TTestResult);
    procedure WriteFooter;
    procedure Run(TestCase: TTestCase); override;
    procedure RunTests; override;
  end;

procedure RunTest;
procedure RegisterTest(TestCaseClass: TTestCaseClass);

var
  TestRunner: TTestRunner;

implementation

{ TestCase }
constructor TTestCase.Create;
begin
  FOnRanTestMethod := nil;
end;

destructor TTestCase.Destroy;
begin
  FOnRanTestMethod := nil;
end;

procedure TTestCase.SetUp;
begin
end;

procedure TTestCase.TearDown;
begin
end;

procedure TTestCase.AssertTrue(Value: Boolean);
begin
  if not (Value = True) then
    raise EAssertionError.CreateFmt('%s != True', [BoolToStr(Value, True)]);
end;

procedure TTestCase.AssertFalse(Value: Boolean);
begin
  if not (Value = False) then
    raise EAssertionError.CreateFmt('%s != False', [BoolToStr(Value, True)]);
end;

procedure TTestCase.AssertEquals(Value1, Value2: Integer);
begin
  if not (Value1 = Value2) then
    raise EAssertionError.CreateFmt('%d != %d', [Value1, Value2]);
end;

procedure TTestCase.AssertEquals(Value1, Value2: String);
begin
  if not (Value1 = Value2) then
    raise EAssertionError.CreateFmt('%s != %s', [Value1, Value2]);
end;

procedure TTestCase.Run(TestResultList: TObjectList<TTestResult>);
var
  RttiContext: TRttiContext;
  RttiType: TRttiType;
  Method: TRttiMethod;
  TestResult: TTestResult;
begin
  RttiContext := TRttiContext.Create;
  try
    RttiType := RttiContext.GetType(ClassType);
    for Method in RttiType.GetMethods do
    begin
      if LeftStr(Method.Name, 4) = 'Test' then
      begin
        TestResult := TTestResult.Create;
        TestResult.ResultType := rtOk;
        TestResult.TestMethodName := Method.Name;
        TestResult.TestCaseName := ToString;
        try
          Method.Invoke(Self, []);
        except
          on E: EAssertionError do
          begin
            TestResult.ResultType := rtFail;
            TestResult.Error := E;
          end;
          on E: ESkipTest do
          begin
            TestResult.ResultType := rtSkip;
            TestResult.Error := E;
          end;
          on E: Exception do
          begin
            TestResult.ResultType := rtError;
            TestResult.Error := E;
          end;
        end;
        if Assigned(FOnRanTestMethod) then
          FOnRanTestMethod(TestResult);
        TestResultList.Add(TestResult);
      end;
    end;
  finally
    RttiContext.Free;
  end;
end;

{ TestResult }
constructor TTestResult.Create;
begin
  FResultType := rtSkip;
  FError := nil;
end;

destructor TTestResult.Destroy;
begin
  FError := nil;
  inherited Destroy;
end;

{ TestRunner }
constructor TTestRunner.Create;
begin
  FTestCaseList := TObjectList<TTestCase>.Create;
  FTestResultList := TObjectList<TTestResult>.Create;
end;

destructor TTestRunner.Destroy;
begin
  FreeAndNil(FTestCaseList);
  FreeAndNil(FTestResultList);
  inherited Destroy;
end;

procedure TTestRunner.AddTestCase(TestCaseClass: TTestCaseClass);
begin
  FTestCaseList.Add(TestCaseClass.Create);
end;

procedure TTestRunner.Run(TestCase: TTestCase);
begin
  TestCase.Run(TestResultList);
end;

procedure TTestRunner.RunTests;
var
  TestCase: TTestCase;
begin
  for TestCase in FTestCaseList do
    Run(TestCase);
end;

{ TTextTestRunner }
procedure TTextTestRunner.WriteHeader;
begin
end;

procedure TTextTestRunner.WriteTestResult(TestResult: TTestResult);
var
  ResultMark: String;
begin
  if TestResult.ResultType = rtOK then
    ResultMark := '.'
  else
    if TestResult.ResultType = rtFail then
      ResultMark := 'F'
    else
      if TestResult.ResultType = rtError then
        ResultMark := 'E'
      else
        if TestResult.ResultType = rtSkip then
          ResultMark := 'S'
        else
          ResultMark := '?';
  Write(ResultMark);
end;

procedure TTextTestRunner.WriteFooter;
begin
  WriteLn('');
  WriteLn(DupeString('-', 70));
  WriteLn(Format('Ran %d tests in 0.000s', [TestResultList.Count]));
  WriteLn('');
  WriteLn('OK');
end;

procedure TTextTestRunner.Run(TestCase: TTestCase);
begin
  TestCase.OnRanTestMethod := WriteTestResult;
  inherited Run(TestCase);
end;

procedure TTextTestRunner.RunTests;
begin
  inherited RunTests;
  WriteFooter;
end;

procedure RunTest;
begin
  TestRunner.RunTests;
end;

procedure RegisterTest(TestCaseClass: TTestCaseClass);
begin
  TestRunner.AddTestCase(TestCaseClass);
end;

initialization
  TestRunner := TTextTestRunner.Create;

finalization
  FreeAndNil(TestRunner);

end.
