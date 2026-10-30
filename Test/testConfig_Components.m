function config = testConfig_Components(family)
% testConfig_Components - Test configuration for the component smoke tests
%
% config = testConfig_Components(family) returns the configuration that runs
% the smoke tests of one family of library blocks in the Components folder:
%   "Plant"          - the converter plants, from ConverterPlantLibrary
%   "Controller"     - the converter controllers, from ConverterLibrary
%   "PWMGenerator"   - the PWM generator blocks, from ConverterLibrary
%   "PowerComponent" - the MOSFET, IGBT and diode models, from ConverterLibrary
%   "All"            - every family (default)
% Each test passes when its harness simulates without error.

% Copyright 2026 The MathWorks, Inc.

arguments
    family (1,1) string {mustBeMember(family, ["All", "Plant", "Controller", "PWMGenerator", "PowerComponent"])} = "All"
end

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
config.Models.IncludeDirectories = string.empty;
config.Models.IncludeFiles = string.empty;
config.Models.FileTypes = ["SLX-file"; "MDL-file"];
config.Models.ExcludeDirectories = string.empty;
config.Models.ExcludeFiles = string.empty;

%% Workflow Discovery
config.Workflows.IncludeDirectories = string.empty;
config.Workflows.IncludeFiles = string.empty;
config.Workflows.FileTypes = ["MLX-file"; "M-file"];
config.Workflows.ExcludeDirectories = string.empty;
config.Workflows.ExcludeFiles = string.empty;

%% Custom Tests - one test folder per library block family member
plantFolders = fullfile("Components", "ConverterPlants", ["BoostPFCPlant", "InterleavedBoostPFCPlant", ...
    "TotemPoleBoostPFCPlant", "NonIsolatedDCDCPlant", "DABConverterPlant", "CLLCConverterPlant", ...
    "CombinedLLCConverterPlant"], "test");
controllerFolders = fullfile("Components", "Controllers", ["BoostPFCController", "InterleavedBoostPFCController", ...
    "TotemPoleBoostPFCController", "NonIsolatedDCDCController", "DABConverterController", ...
    "CLLCConverterController", "LLCConverterController", "GridFormingConverterController"], "test");
pwmGeneratorFolders = fullfile("Components", "Controllers", "PWMGenerators", "test");
powerComponentFolders = fullfile("Components", "PowerComponents", ["MOSFETThermalBlock", "IGBTThermalBlock", ...
    "DiodeThermalBlock"], "test");
switch family
    case "Plant"
        folders = plantFolders;
    case "Controller"
        folders = controllerFolders;
    case "PWMGenerator"
        folders = pwmGeneratorFolders;
    case "PowerComponent"
        folders = powerComponentFolders;
    otherwise
        folders = [plantFolders, controllerFolders, pwmGeneratorFolders, powerComponentFolders];
end
config.CustomTests.Files = string.empty;
config.CustomTests.Directories = folders;

%% Code Coverage
config.CodeCoverage.IncludeDirectories = string.empty;
config.CodeCoverage.IncludeFiles = string.empty;
config.CodeCoverage.FileTypes = ["M-file"; "MLX-file"];
config.CodeCoverage.ExcludeDirectories = "Test";
config.CodeCoverage.ExcludeFiles = string.empty;

%% Reporting
config.Reports.FolderName = "Components" + family;
config.Reports.GenerateJUnitXML = true;
config.Reports.GenerateHTMLReport = true;
config.Reports.GenerateCodeCoverage = false;
config.Reports.OpenInBrowser = false;

%% Warning Suppression
config.SuppressedWarnings = ["MATLAB:hg:AutoSoftwareOpenGL"];

end
