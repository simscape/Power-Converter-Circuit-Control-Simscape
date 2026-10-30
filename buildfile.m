function plan = buildfile
% buildfile - Defines the build plan for the Simscape library project
%
% This function creates a build plan with various tasks for building,
% checking, testing, reporting, and packaging a Simscape library that is
% generated from SPICE netlists.
%
% Returns:
%   plan - A buildplan object containing all defined tasks

% Copyright 2026  The MathWorks, Inc.

% Open project
prj = matlab.project.loadProject(pwd);

% In CI, give every job its own Simulink cache and code generation folder outside
% the build folder, so a MATLAB left running by an earlier job (or release) on the
% same runner cannot write into this job's cache.
if getenv("CI") == "true"
    jobCacheFolder = fullfile(tempdir, "simulink_cache_" + getenv("CI_JOB_ID"));
    if ~isfolder(jobCacheFolder)
        mkdir(jobCacheFolder);
    end
    Simulink.fileGenControl("set", "CacheFolder", jobCacheFolder, ...
        "CodeGenFolder", jobCacheFolder, "createDir", true);
    fprintf("Simulink cache folder for this CI job: %s\n", jobCacheFolder);
end

% Create an empty build plan
plan = buildplan;

% --- Test configurations ---
config_GFM = testConfig_GFM();
config_LLC = testConfig_LLC();
config_BoostPFC = testConfig_BoostPFC();
config_InterleavedBoostPFC = testConfig_InterleavedBoostPFC();
config_TotemPoleBoostPFC = testConfig_TotemPoleBoostPFC();
config_NonIsolatedDCDC = testConfig_NonIsolatedDCDC();
config_DAB = testConfig_DAB();
config_CLLC = testConfig_CLLC();
config_DeviceThermal = testConfig_DeviceThermal();

% Define individual tasks for the build plan
% Task to check code for issues in specified directories
plan("Check") = matlab.buildtool.TaskGroup(Description = "Static checks code related issues.");
plan("Check:CodeAnalyzerGFM") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "GridFormingConverter"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_GFM));
plan("Check:CodeAnalyzerLLC") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "LLCConverter"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_LLC));
plan("Check:CodeAnalyzerBoostPFC") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "BoostPFC"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_BoostPFC));
plan("Check:CodeAnalyzerInterleavedBoostPFC") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "InterleavedBoostPFC"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_InterleavedBoostPFC));
plan("Check:CodeAnalyzerTotemPoleBoostPFC") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "TotemPoleBoostPFC"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_TotemPoleBoostPFC));
plan("Check:CodeAnalyzerNonIsolatedDCDC") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "NonIsolatedDCDC"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_NonIsolatedDCDC));
plan("Check:CodeAnalyzerDAB") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "DAB"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_DAB));
plan("Check:CodeAnalyzerCLLC") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "CLLCConverter"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_CLLC));
plan("Check:CodeAnalyzerDeviceThermal") = matlab.buildtool.tasks.CodeIssuesTask( ...
    SourceFiles=fullfile(prj.RootFolder, "ScriptData", "DABThermalAnalysisWithCustomMOSFET"), ...
    IncludeSubfolders=true, ...
    Results=TestExecutor.getCodeAnalyzerPaths(config_DeviceThermal));

% Create external test task: GFM
plan("GFM:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for GFM.",...
    Actions=@(ctx)runAllSmokeTestsGFM(ctx,config_GFM));

plan("GFM:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for GFM.",...
    Actions=@(ctx)runModelSmokeTestsGFM(ctx,config_GFM));

plan("GFM:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for GFM.",...
    Actions=@(ctx)runWorkflowSmokeTestsGFM(ctx,config_GFM));

plan("GFM:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for GFM.",...
    Actions=@(ctx)runCustomTestsGFM(ctx,config_GFM));

% Create external test task: LLC
plan("LLC:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for LLC.",...
    Actions=@(ctx)runAllSmokeTestsLLC(ctx,config_LLC));

plan("LLC:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for LLC.",...
    Actions=@(ctx)runModelSmokeTestsLLC(ctx,config_LLC));

plan("LLC:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for LLC.",...
    Actions=@(ctx)runWorkflowSmokeTestsLLC(ctx,config_LLC));

plan("LLC:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for LLC.",...
    Actions=@(ctx)runCustomTestsLLC(ctx,config_LLC));

% Create external test task: BoostPFC
plan("BoostPFC:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for BoostPFC.",...
    Actions=@(ctx)runAllSmokeTestsBoostPFC(ctx,config_BoostPFC));

plan("BoostPFC:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for BoostPFC.",...
    Actions=@(ctx)runModelSmokeTestsBoostPFC(ctx,config_BoostPFC));

plan("BoostPFC:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for BoostPFC.",...
    Actions=@(ctx)runWorkflowSmokeTestsBoostPFC(ctx,config_BoostPFC));

plan("BoostPFC:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for BoostPFC.",...
    Actions=@(ctx)runCustomTestsBoostPFC(ctx,config_BoostPFC));

% Create external test task: InterleavedBoostPFC
plan("InterleavedBoostPFC:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for InterleavedBoostPFC.",...
    Actions=@(ctx)runAllSmokeTestsInterleavedBoostPFC(ctx,config_InterleavedBoostPFC));

plan("InterleavedBoostPFC:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for InterleavedBoostPFC.",...
    Actions=@(ctx)runModelSmokeTestsInterleavedBoostPFC(ctx,config_InterleavedBoostPFC));

plan("InterleavedBoostPFC:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for InterleavedBoostPFC.",...
    Actions=@(ctx)runWorkflowSmokeTestsInterleavedBoostPFC(ctx,config_InterleavedBoostPFC));

plan("InterleavedBoostPFC:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for InterleavedBoostPFC.",...
    Actions=@(ctx)runCustomTestsInterleavedBoostPFC(ctx,config_InterleavedBoostPFC));

% Create external test task: TotemPoleBoostPFC
plan("TotemPoleBoostPFC:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for TotemPoleBoostPFC.",...
    Actions=@(ctx)runAllSmokeTestsTotemPoleBoostPFC(ctx,config_TotemPoleBoostPFC));

plan("TotemPoleBoostPFC:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for TotemPoleBoostPFC.",...
    Actions=@(ctx)runModelSmokeTestsTotemPoleBoostPFC(ctx,config_TotemPoleBoostPFC));

plan("TotemPoleBoostPFC:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for TotemPoleBoostPFC.",...
    Actions=@(ctx)runWorkflowSmokeTestsTotemPoleBoostPFC(ctx,config_TotemPoleBoostPFC));

plan("TotemPoleBoostPFC:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for TotemPoleBoostPFC.",...
    Actions=@(ctx)runCustomTestsTotemPoleBoostPFC(ctx,config_TotemPoleBoostPFC));

% Create external test task: NonIsolatedDCDC
plan("NonIsolatedDCDC:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for NonIsolatedDCDC.",...
    Actions=@(ctx)runAllSmokeTestsNonIsolatedDCDC(ctx,config_NonIsolatedDCDC));

plan("NonIsolatedDCDC:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for NonIsolatedDCDC.",...
    Actions=@(ctx)runModelSmokeTestsNonIsolatedDCDC(ctx,config_NonIsolatedDCDC));

plan("NonIsolatedDCDC:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for NonIsolatedDCDC.",...
    Actions=@(ctx)runWorkflowSmokeTestsNonIsolatedDCDC(ctx,config_NonIsolatedDCDC));

plan("NonIsolatedDCDC:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for NonIsolatedDCDC.",...
    Actions=@(ctx)runCustomTestsNonIsolatedDCDC(ctx,config_NonIsolatedDCDC));

% Create external test task: DAB
plan("DAB:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for DAB.",...
    Actions=@(ctx)runAllSmokeTestsDAB(ctx,config_DAB));

plan("DAB:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for DAB.",...
    Actions=@(ctx)runModelSmokeTestsDAB(ctx,config_DAB));

plan("DAB:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for DAB.",...
    Actions=@(ctx)runWorkflowSmokeTestsDAB(ctx,config_DAB));

plan("DAB:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for DAB.",...
    Actions=@(ctx)runCustomTestsDAB(ctx,config_DAB));

% Create external test task: CLLC
plan("CLLC:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for CLLC.",...
    Actions=@(ctx)runAllSmokeTestsCLLC(ctx,config_CLLC));

plan("CLLC:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for CLLC.",...
    Actions=@(ctx)runModelSmokeTestsCLLC(ctx,config_CLLC));

plan("CLLC:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for CLLC.",...
    Actions=@(ctx)runWorkflowSmokeTestsCLLC(ctx,config_CLLC));

plan("CLLC:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for CLLC.",...
    Actions=@(ctx)runCustomTestsCLLC(ctx,config_CLLC));

% Create external test task: DeviceThermal
plan("DeviceThermal:AllTest")= matlab.buildtool.Task(Description="Run all smoke tests for DeviceThermal.",...
    Actions=@(ctx)runAllSmokeTestsDeviceThermal(ctx,config_DeviceThermal));

plan("DeviceThermal:ModelTest")= matlab.buildtool.Task(Description="Run model smoke tests for DeviceThermal.",...
    Actions=@(ctx)runModelSmokeTestsDeviceThermal(ctx,config_DeviceThermal));

plan("DeviceThermal:WorkflowTest")= matlab.buildtool.Task(Description="Run workflow smoke tests for DeviceThermal.",...
    Actions=@(ctx)runWorkflowSmokeTestsDeviceThermal(ctx,config_DeviceThermal));

plan("DeviceThermal:CustomTest")= matlab.buildtool.Task(Description="Run custom tests for DeviceThermal.",...
    Actions=@(ctx)runCustomTestsDeviceThermal(ctx,config_DeviceThermal));

% Create component test tasks: library blocks in the Components folder
plan("Components:AllTest")= matlab.buildtool.Task(Description="Run every component smoke test.",...
    Actions=@(ctx)runComponentTests(ctx,testConfig_Components("All")));

plan("Components:PlantTest")= matlab.buildtool.Task(Description="Run the converter plant smoke tests (ConverterPlantLibrary).",...
    Actions=@(ctx)runComponentTests(ctx,testConfig_Components("Plant")));

plan("Components:ControllerTest")= matlab.buildtool.Task(Description="Run the converter controller smoke tests (ConverterLibrary).",...
    Actions=@(ctx)runComponentTests(ctx,testConfig_Components("Controller")));

plan("Components:PWMGeneratorTest")= matlab.buildtool.Task(Description="Run the PWM generator smoke tests (ConverterLibrary).",...
    Actions=@(ctx)runComponentTests(ctx,testConfig_Components("PWMGenerator")));

plan("Components:PowerComponentTest")= matlab.buildtool.Task(Description="Run the MOSFET, IGBT and diode model tests (ConverterLibrary).",...
    Actions=@(ctx)runComponentTests(ctx,testConfig_Components("PowerComponent")));

% Default task: what "buildtool" with no task name, and the Run Build button on the
% toolstrip, runs. The code checks are quick; run the tests by task name.
plan.DefaultTasks = "Check";

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GET TASKS FROM "OTHER" BUILDFILES AND ADD THEM TO THE MAIN PLAN
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
buildfileList = dir(fullfile(prj.RootFolder, "*", "buildfile_internal.m"));
% Loop through the buildfile list and add tasks from each buildfile
for iFile = 1:length(buildfileList)
    [~,name,~] = fileparts(buildfileList(iFile).name);
    filePlan = feval(name);
    nTasks = numel(filePlan.Tasks);
    for taskIdx = 1:nTasks
        if ~ismember(filePlan.Tasks(taskIdx).Name,cellstr({plan.Tasks.Name}))
            plan(filePlan.Tasks(taskIdx).Name) = filePlan.Tasks(taskIdx);
        else
            fprintf("THERE ALREADY EXIST A TASK OF NAME: ""%s"" IN THE MAIN BUILD FILE. IGNORING TASK FROM OTHER BUILDFILES.", filePlan.Tasks(taskIdx).Name);
        end
    end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsGFM(~, config_GFM)
status = 1; %#ok<*NASGU>
results = TestExecutor.runAll(config_GFM);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "GFM all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsLLC(~, config_LLC)
status = 1;
results = TestExecutor.runAll(config_LLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "LLC all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsGFM(~, config_GFM)
status = 1;
results = TestExecutor.runModelsOnly(config_GFM);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "GFM model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsLLC(~, config_LLC)
status = 1;
results = TestExecutor.runModelsOnly(config_LLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "LLC model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsGFM(~, config_GFM)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_GFM);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "GFM workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsLLC(~, config_LLC)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_LLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "LLC workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsGFM(~, config_GFM)
status = 1;
results = TestExecutor.runCustomOnly(config_GFM);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "GFM custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsLLC(~, config_LLC)
status = 1;
results = TestExecutor.runCustomOnly(config_LLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "LLC custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsBoostPFC(~, config_BoostPFC)
status = 1;
results = TestExecutor.runAll(config_BoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "BoostPFC all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsInterleavedBoostPFC(~, config_InterleavedBoostPFC)
status = 1;
results = TestExecutor.runAll(config_InterleavedBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "InterleavedBoostPFC all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsTotemPoleBoostPFC(~, config_TotemPoleBoostPFC)
status = 1;
results = TestExecutor.runAll(config_TotemPoleBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "TotemPoleBoostPFC all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsNonIsolatedDCDC(~, config_NonIsolatedDCDC)
status = 1;
results = TestExecutor.runAll(config_NonIsolatedDCDC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "NonIsolatedDCDC all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsDAB(~, config_DAB)
status = 1;
results = TestExecutor.runAll(config_DAB);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DAB all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsCLLC(~, config_CLLC)
status = 1;
results = TestExecutor.runAll(config_CLLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "CLLC all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runAllSmokeTestsDeviceThermal(~, config_DeviceThermal)
status = 1;
results = TestExecutor.runAll(config_DeviceThermal);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DeviceThermal all smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsBoostPFC(~, config_BoostPFC)
status = 1;
results = TestExecutor.runModelsOnly(config_BoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "BoostPFC model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsInterleavedBoostPFC(~, config_InterleavedBoostPFC)
status = 1;
results = TestExecutor.runModelsOnly(config_InterleavedBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "InterleavedBoostPFC model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsTotemPoleBoostPFC(~, config_TotemPoleBoostPFC)
status = 1;
results = TestExecutor.runModelsOnly(config_TotemPoleBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "TotemPoleBoostPFC model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsNonIsolatedDCDC(~, config_NonIsolatedDCDC)
status = 1;
results = TestExecutor.runModelsOnly(config_NonIsolatedDCDC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "NonIsolatedDCDC model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsDAB(~, config_DAB)
status = 1;
results = TestExecutor.runModelsOnly(config_DAB);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DAB model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsCLLC(~, config_CLLC)
status = 1;
results = TestExecutor.runModelsOnly(config_CLLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "CLLC model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runModelSmokeTestsDeviceThermal(~, config_DeviceThermal)
status = 1;
results = TestExecutor.runModelsOnly(config_DeviceThermal);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DeviceThermal model smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsBoostPFC(~, config_BoostPFC)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_BoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "BoostPFC workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsInterleavedBoostPFC(~, config_InterleavedBoostPFC)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_InterleavedBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "InterleavedBoostPFC workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsTotemPoleBoostPFC(~, config_TotemPoleBoostPFC)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_TotemPoleBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "TotemPoleBoostPFC workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsNonIsolatedDCDC(~, config_NonIsolatedDCDC)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_NonIsolatedDCDC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "NonIsolatedDCDC workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsDAB(~, config_DAB)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_DAB);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DAB workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsCLLC(~, config_CLLC)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_CLLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "CLLC workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runWorkflowSmokeTestsDeviceThermal(~, config_DeviceThermal)
status = 1;
results = TestExecutor.runWorkflowsOnly(config_DeviceThermal);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DeviceThermal workflow smoke tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsBoostPFC(~, config_BoostPFC)
status = 1;
results = TestExecutor.runCustomOnly(config_BoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "BoostPFC custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsInterleavedBoostPFC(~, config_InterleavedBoostPFC)
status = 1;
results = TestExecutor.runCustomOnly(config_InterleavedBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "InterleavedBoostPFC custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsTotemPoleBoostPFC(~, config_TotemPoleBoostPFC)
status = 1;
results = TestExecutor.runCustomOnly(config_TotemPoleBoostPFC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "TotemPoleBoostPFC custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsNonIsolatedDCDC(~, config_NonIsolatedDCDC)
status = 1;
results = TestExecutor.runCustomOnly(config_NonIsolatedDCDC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "NonIsolatedDCDC custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsDAB(~, config_DAB)
status = 1;
results = TestExecutor.runCustomOnly(config_DAB);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DAB custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsCLLC(~, config_CLLC)
status = 1;
results = TestExecutor.runCustomOnly(config_CLLC);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "CLLC custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function status = runCustomTestsDeviceThermal(~, config_DeviceThermal)
status = 1;
results = TestExecutor.runCustomOnly(config_DeviceThermal);
if ~any([results.Failed] | [results.Incomplete])
    fprintf("\nAll tests passed!\n");
    status = 0;
else
    % Fail the buildtool task (and the CI job) when a test failed or is
    % incomplete (for example, filtered by an assumption).
    failed = results([results.Failed] | [results.Incomplete]);
    error("buildfile:TestsFailed", "DeviceThermal custom tests: %d of %d tests failed or are incomplete:%s", ...
        numel(failed), numel(results), join(newline + "  " + string({failed.Name}), ""));
end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function runComponentTests(~, config)
% Run the component smoke tests listed in a test configuration. A failed
% test fails the task: buildtool reports a task as failed only when its
% action errors, not from a returned status.
results = TestExecutor.runCustomOnly(config);
if isempty(results) || any([results.Failed]) || any([results.Incomplete])
    error("buildfile:ComponentTestFailed", "%d of %d component tests did not pass.", ...
        sum([results.Failed] | [results.Incomplete]), numel(results));
end
fprintf("\nAll %d component tests passed!\n", numel(results));
% The CI success pattern
fprintf("\nAll tests passed!\n");
end
%--------------------------------------------------------------------------
