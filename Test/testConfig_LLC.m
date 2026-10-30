function config = testConfig_LLC()
% testConfig_LLC - Test configuration for the LLC resonant converter
%
% Links the three test levels of the LLC converter:
%   Models     - every model in Models\LLCConverter loads and simulates
%                (LLCResonantConverterFullBridge, GainCurveLLCConverter,
%                EstimateFrequencyResponse; each loads its default input
%                parameters in its PreLoadFcn)
%   Workflows  - every workflow script in ScriptData\LLCConverter\Workflow runs,
%                except TuneLLCResonantConverter (its frequency response sweep runs for over half an hour;
%                run it by hand)
%   Custom     - the component smoke tests of the LLC plant (from
%                ConverterPlantLibrary) and the LLC voltage controller (from
%                ConverterLibrary), and the LLC system tests in
%                Test\Custom\LLCConverter

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
config.Models.IncludeDirectories = ["Models\LLCConverter"]; %#ok<*NBRAK2>
config.Models.IncludeFiles = string.empty;
config.Models.FileTypes = ["SLX-file"; "MDL-file"];
config.Models.ExcludeDirectories = string.empty;
config.Models.ExcludeFiles = string.empty;

%% Workflow Discovery
config.Workflows.IncludeDirectories = ["ScriptData\LLCConverter\Workflow"];
config.Workflows.IncludeFiles = string.empty;
config.Workflows.FileTypes = ["MLX-file"; "M-file"];
config.Workflows.ExcludeDirectories = string.empty;
config.Workflows.ExcludeFiles = ["ScriptData\LLCConverter\Workflow\TuneLLCResonantConverter.m"];   % too long for a routine run

%% Custom Tests
% Component smoke tests (plant and controller library blocks) and the system tests
config.CustomTests.Files = string.empty;
config.CustomTests.Directories = [  fullfile("Components", "ConverterPlants", "CombinedLLCConverterPlant", "test"),...
                                    fullfile("Components", "Controllers", "LLCConverterController", "test")];

%% Code Coverage
config.CodeCoverage.IncludeDirectories = ["ScriptData\LLCConverter"];
config.CodeCoverage.IncludeFiles = string.empty;
config.CodeCoverage.FileTypes = ["M-file"; "MLX-file"];
config.CodeCoverage.ExcludeDirectories = "Test";
config.CodeCoverage.ExcludeFiles = string.empty;

%% Reporting
config.Reports.FolderName = "LLCConverter";
config.Reports.GenerateJUnitXML = true;
config.Reports.GenerateHTMLReport = true;
config.Reports.GenerateCodeCoverage = true;
config.Reports.OpenInBrowser = false;

%% Warning Suppression
% A machine without graphics hardware (a batch or CI run) warns on the first figure;
% R2026a issues MATLAB:graphics:HardwareUnavailable, earlier releases MATLAB:hg:AutoSoftwareOpenGL.
config.SuppressedWarnings = ["MATLAB:hg:AutoSoftwareOpenGL", "MATLAB:graphics:HardwareUnavailable"];

end
