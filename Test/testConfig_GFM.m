function config = testConfig_GFM()
% testConfig_GFM - Test configuration for the grid-forming converter (GFM)
%
% Links the three test levels of the grid-forming converter:
%   Models     - every model in Models\GridFormingConverter loads and simulates
%                (GridFormingConverter)
%   Workflows  - every workflow script in ScriptData\GridFormingConverter\Workflow runs
%   Custom     - the component smoke tests of the grid-forming converter
%                controller (from ConverterLibrary), with the average and the
%                switching power circuit

% Copyright 2026 The MathWorks, Inc.

%% Get project Root
try
    projectRoot = string(currentProject().RootFolder);
catch
    try
        prj = matlab.project.loadProject(pwd);
        projectRoot = string(prj.RootFolder);
    catch
        error("testConfig:NoProject", ...
            "Could not resolve ProjectRoot. Open the MATLAB project or run from the project root.");
    end
end

%% Project Root
config.ProjectRoot = projectRoot;

%% Model Discovery
config.Models.IncludeDirectories = ["Models\GridFormingConverter"]; %#ok<*NBRAK2>
config.Models.IncludeFiles = string.empty;
config.Models.FileTypes = ["SLX-file"; "MDL-file"];
config.Models.ExcludeDirectories = string.empty;
config.Models.ExcludeFiles = string.empty;

%% Workflow Discovery
config.Workflows.IncludeDirectories = ["ScriptData\GridFormingConverter\Workflow"];
config.Workflows.IncludeFiles = string.empty;
config.Workflows.FileTypes = ["MLX-file"; "M-file"];
config.Workflows.ExcludeDirectories = string.empty;
config.Workflows.ExcludeFiles = string.empty;

%% Custom Tests
% Component smoke tests (controller library block), and the system test of
% Test\Custom\GridFormingConverter. That folder is listed by file because its
% GridFormingConverterUnit and tGridFormingConverterScript tests are skipped.
config.CustomTests.Files = fullfile("Test", "Custom", "GridFormingConverter", "GridFormingConverterSystem.m");
config.CustomTests.Directories = fullfile("Components", "Controllers", "GridFormingConverterController", "test");

%% Code Coverage
config.CodeCoverage.IncludeDirectories = ["ScriptData\GridFormingConverter"];
config.CodeCoverage.IncludeFiles = string.empty;
config.CodeCoverage.FileTypes = ["M-file"; "MLX-file"];
config.CodeCoverage.ExcludeDirectories = "Test";
config.CodeCoverage.ExcludeFiles = string.empty;

%% Reporting
config.Reports.FolderName = "GridFormingConverter";
config.Reports.GenerateJUnitXML = true;
config.Reports.GenerateHTMLReport = true;
config.Reports.GenerateCodeCoverage = true;
config.Reports.OpenInBrowser = false;

%% Warning Suppression
% A machine without graphics hardware (a batch or CI run) warns on the first figure;
% R2026a issues MATLAB:graphics:HardwareUnavailable, earlier releases MATLAB:hg:AutoSoftwareOpenGL.
config.SuppressedWarnings = ["MATLAB:hg:AutoSoftwareOpenGL", "MATLAB:graphics:HardwareUnavailable"];

end