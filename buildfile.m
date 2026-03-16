function plan = buildfile
% buildfile - Defines the build plan for the Simscape library project
%
% This function creates a build plan with various tasks for building,
% checking, testing, reporting, and packaging a Simscape library that is
% generated from SPICE netlists.
%
% Returns:
%   plan - A buildplan object containing all defined tasks
%
% Copyright 2026 The MathWorks, Inc.

% Open project
project = matlab.project.loadProject(pwd);
projectRoot = project.RootFolder;

% Create an empty build plan
plan = buildplan;

% Define individual tasks for the build plan

% Task to check code for issues in specified directories
plan("check") = matlab.buildtool.TaskGroup("Description","Check code realted issue and issues specific to Simscape.");
plan("check:code") = matlab.buildtool.tasks.CodeIssuesTask(...
    SourceFiles=currentProject().RootFolder,...
    IncludeSubfolders=true,...
    Results= "code_issues_results.mat");

% Create external test task
plan("Test")= matlab.buildtool.Task(Description="Run Customer Visible tests.",...
    Actions=@(ctx, input)lRunTests(ctx, input));
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = lRunTests(~, input)
% lRunTests Creates test suite and runs tests with XML output
%
% This function creates a test suite from the Test directory at the
% project root and runs all tests with JUnit XML output.
%
% Returns:
%   results - TestResult object containing test execution results

status = 1;

% Get the project root directory
projectRoot = currentProject().RootFolder;

% Code coverage plugin
coverageReportFolder = fullfile(projectRoot, "CodeCoverageReports");
coverageReport = matlab.unittest.plugins.codecoverage.CoverageReport( ...
    coverageReportFolder, MainFile = input + "CoverageReport"  + ".html" );

switch input
    case 'GFM'
        testDir = [ fullfile(projectRoot, 'Tests','GridFormingConverter'),...
                    fullfile(projectRoot, 'Components', 'GridFormingConverter', 'test')];

        % Code coverage plugin
        ccplugin = matlab.unittest.plugins.CodeCoveragePlugin.forFile( ...
            [ ...
            fullfile(projectRoot, "ScriptData","GridFormingConverter","SupportingFiles", "plotGridFormingConverter.m") ...
            fullfile(projectRoot, "ScriptData","GridFormingConverter","SupportingFiles", "plotInertiaConstantEffects.m") ...
            fullfile(projectRoot, "ScriptData","GridFormingConverter","SupportingFiles", "plotFaultCurrentVoltageEffects.m") ...
            fullfile(projectRoot, "ScriptData","GridFormingConverter","SupportingFiles", "plotCompareFaultRideThroughMethod.m")], ...
            Producing = coverageReport );

    case 'LLC'
        testDir = [ fullfile(projectRoot,'Tests','LLCConverter'),...
                    fullfile(projectRoot, 'Components', 'LLCConverter', 'test')];

        ccplugin = matlab.unittest.plugins.CodeCoveragePlugin.forFolder(...
            fullfile(projectRoot, "ScriptData","LLCConverter","SupportingFiles"),...
            Producing = coverageReport);

    otherwise
        fprintf('Did not find correct input\n');
end

% Create test suite from the Test directory
import matlab.unittest.selectors.HasSuperclass
suite = testsuite(testDir,IncludeSubfolders=true);
suite = suite.selectIf(HasSuperclass("matlab.unittest.TestCase"));

% TESTS TO EXCLUDE
testsToExclude = {  'LLCResonantConverterUnit/LLCResonantConvertersControllerDesignLivescript',...
                    'GridFormingConverterMainLiveScriptTest'};
suite = suite(~contains({suite.Name}, testsToExclude));

% Create test runner
runner = testrunner('textoutput');

% Add XML plugin to generate JUnit format output
xmlFile = fullfile(projectRoot, ['test_results','_',input,'.xml']);
xmlPlugin = matlab.unittest.plugins.XMLPlugin.producingJUnitFormat(xmlFile);
runner.addPlugin(xmlPlugin);

% Code coverage plugin
addPlugin(runner, ccplugin)

% Run the test suite
result = runner.run(suite);
% Save to |.mat| file
save(['test_results','_',input,'.mat'], "result");

% Check if all test passed:
if ~any([result.Failed])
    fprintf("\nAll tests passed!\n");
    status = 0;
end
end
%--------------------------------------------------------------------------