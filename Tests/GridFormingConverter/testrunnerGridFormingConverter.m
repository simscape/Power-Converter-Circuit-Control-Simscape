%% Script to run unit tests
% This script runs tests for component-level and system-level tests.
% Note that tests for detailed model applications are not run
% to avoid long-running tests.

% Copyright 2023-2026 The MathWorks, Inc.

relStr = matlabRelease().Release;
disp("This is MATLAB " + relStr + ".");

topFolder = currentProject().RootFolder;

%% Create test suite
% Test suite for unit test
%suite = matlab.unittest.TestSuite.fromFile(fullfile(topFolder,"Tests", "GridFormingConverterUnit.m")); 
fprintf('*** Creating test suite ***')
import matlab.unittest.TestSuite;
suite = [testsuite('Tests/GridFormingConverterMainLiveScriptTest.m'),...
    testsuite('Tests/GridFormingConverterSystem.m'),...
    testsuite('Tests/GridFormingConverterUnit.m'),...
    ];
%% Create test runner
runner = matlab.unittest.TestRunner.withTextOutput(...
    'OutputDetail',matlab.unittest.Verbosity.Detailed);

%% Set up test results
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat(...
    fullfile(topFolder, "GFM_TestResults.xml")));

%% MATLAB Code Coverage Report
coverageReportFolder = fullfile(topFolder, "coverage-GFMCodeCoverage" + relStr);
if ~isfolder(coverageReportFolder)
    mkdir(coverageReportFolder)
end

coverageReport = matlab.unittest.plugins.codecoverage.CoverageReport( ...
    coverageReportFolder, MainFile = "GFMCoverageReport" + relStr + ".html" );

plugin = matlab.unittest.plugins.CodeCoveragePlugin.forFile( ...
    [ ...
    fullfile(topFolder, "ScriptData","SupportingFiles", "PlotGridFormingConverter.m") ...
    fullfile(topFolder, "ScriptData","SupportingFiles", "PlotInertiaConstantEffects.m") ...
    fullfile(topFolder, "ScriptData","SupportingFiles", "PlotFaultCurrentVoltageEffects.m") ...
    fullfile(topFolder, "ScriptData","SupportingFiles", "PlotCompareFaultRideThroughMethod.m")], ...
    Producing = coverageReport );

addPlugin(runner, plugin)

%% Run tests
results = run(runner, suite);
out = assertSuccess(results);
disp(out);