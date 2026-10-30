function config = testConfig_BoostPFC()
% testConfig_BoostPFC - Test configuration for the boost PFC converter
%
% Links the three test levels of the boost PFC converter:
%   Models     - every model in Models\BoostPFC loads and simulates
%                (BoostPFCConverter)
%   Workflows  - every workflow script in ScriptData\BoostPFC\Workflow runs
%   Custom     - the component smoke tests of the boost PFC plant (from ConverterPlantLibrary) and the boost PFC controller (from ConverterLibrary)

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
config.Models.IncludeDirectories = ["Models\BoostPFC"]; %#ok<*NBRAK2>
config.Models.IncludeFiles = string.empty;
config.Models.FileTypes = ["SLX-file"; "MDL-file"];
config.Models.ExcludeDirectories = string.empty;
config.Models.ExcludeFiles = string.empty;

%% Workflow Discovery
config.Workflows.IncludeDirectories = ["ScriptData\BoostPFC\Workflow"];
config.Workflows.IncludeFiles = string.empty;
config.Workflows.FileTypes = ["MLX-file"; "M-file"];
config.Workflows.ExcludeDirectories = string.empty;
config.Workflows.ExcludeFiles = string.empty;

%% Custom Tests
% Component smoke tests (plant and controller library blocks)
config.CustomTests.Files = string.empty;
config.CustomTests.Directories = [  fullfile("Components", "ConverterPlants", "BoostPFCPlant", "test"),...
                                    fullfile("Components", "Controllers", "BoostPFCController", "test")];

%% Code Coverage
config.CodeCoverage.IncludeDirectories = ["ScriptData\BoostPFC"];
config.CodeCoverage.IncludeFiles = string.empty;
config.CodeCoverage.FileTypes = ["M-file"; "MLX-file"];
config.CodeCoverage.ExcludeDirectories = "Test";
config.CodeCoverage.ExcludeFiles = string.empty;

%% Reporting
config.Reports.FolderName = "BoostPFC";
config.Reports.GenerateJUnitXML = true;
config.Reports.GenerateHTMLReport = true;
config.Reports.GenerateCodeCoverage = true;
config.Reports.OpenInBrowser = false;

%% Warning Suppression
% A machine without graphics hardware (a batch or CI run) warns on the first figure;
% R2026a issues MATLAB:graphics:HardwareUnavailable, earlier releases MATLAB:hg:AutoSoftwareOpenGL.
% BoostPFCMain runs the accelerator-mode model with its own Solver and MaxStep, so Simulink
% rebuilds the accelerator target and removes the previous build folder from the path.
config.SuppressedWarnings = ["MATLAB:hg:AutoSoftwareOpenGL", "MATLAB:graphics:HardwareUnavailable", ...
                             "MATLAB:RMDIR:RemovedFromPath"];

end
