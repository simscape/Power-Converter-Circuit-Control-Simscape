% Copyright 2023 The MathWorks, Inc.


% Create test suite for MATLAB unit test and system level test
fprintf('*** Creating test suite ***')

topFolder = currentProject().RootFolder;

% MATLAB unit test for running all the example codes
% Unit test
suite1 = matlab.unittest.TestSuite.fromFile(fullfile(topFolder,"Tests", "GridFormingConverterUnit.m")); 
% System level verification test
suite2 = matlab.unittest.TestSuite.fromFile(fullfile(topFolder,"Tests", "GridFormingConverterSystem.m"));
suite = [suite1 suite2];

% Create test runner
runner = matlab.unittest.TestRunner.withTextOutput(...
    'OutputDetail',matlab.unittest.Verbosity.Detailed);

% Set up the report for results
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat('testResults.xml'));


%% MATLAB Code Coverage Report

coverageReportFolder = fullfile(topFolder, "coverage-GFMCodeCoverage");
if not(isfolder(coverageReportFolder))
    mkdir(coverageReportFolder)
end

coverageReport = matlab.unittest.plugins.codecoverage.CoverageReport( ...
    coverageReportFolder, ...
    MainFile = "GFMCoverageReport.html" );

plugin = matlab.unittest.plugins.CodeCoveragePlugin.forFile( ...
    [ ...
    fullfile(topFolder, "Script_Data", "PlotGridFormingConverter.m") ...
    fullfile(topFolder, "Script_Data", "PlotInertiaConstantEffects.m") ...
    fullfile(topFolder, "Script_Data", "PlotFaultCurrentVoltageEffects.m") ...
    fullfile(topFolder, "Script_Data", "PlotCompareFaultRideThroughMethod.m")], ...
    Producing = coverageReport );

addPlugin(runner, plugin)


% Run tests
results = run(runner, suite);
out = assertSuccess(results);
disp(out);

%disp(results.assertSuccess);
