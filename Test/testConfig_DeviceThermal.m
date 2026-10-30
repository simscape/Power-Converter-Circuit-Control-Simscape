function config = testConfig_DeviceThermal()
% testConfig_DeviceThermal - Test configuration for the custom Simulink device thermal solution
%
% Links the three test levels of the device thermal models (the MOSFET,
% IGBT and diode models in ConverterLibrary, and the DAB thermal workflow
% that uses the custom MOSFET):
%   Models     - DABThermalAnalysisWithCustomMOSFET in
%                Models\DABThermalAnalysisWithCustomMOSFET loads and simulates.
%                The two device files beside it are subsystem references the
%                model uses, not models, so they are not listed.
%   Workflows  - the scripts in
%                ScriptData\DABThermalAnalysisWithCustomMOSFET\Workflow run
%   Custom     - the buck tests of the MOSFET, IGBT and diode models, each
%                against the matching Simscape device

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
config.Models.IncludeDirectories = string.empty;
config.Models.IncludeFiles = ["Models\DABThermalAnalysisWithCustomMOSFET\DABThermalAnalysisWithCustomMOSFET.slx"];
config.Models.FileTypes = ["SLX-file"; "MDL-file"];
config.Models.ExcludeDirectories = string.empty;
config.Models.ExcludeFiles = string.empty;

%% Workflow Discovery
config.Workflows.IncludeDirectories = ["ScriptData\DABThermalAnalysisWithCustomMOSFET\Workflow"];
config.Workflows.IncludeFiles = string.empty;
config.Workflows.FileTypes = ["MLX-file"; "M-file"];
config.Workflows.ExcludeDirectories = string.empty;
config.Workflows.ExcludeFiles = string.empty;

%% Custom Tests
% Buck tests of the three device models (Simscape device against Simulink device)
config.CustomTests.Files = string.empty;
config.CustomTests.Directories = [  fullfile("Components", "PowerComponents", "MOSFETThermalBlock", "test"),...
                                    fullfile("Components", "PowerComponents", "IGBTThermalBlock", "test"),...
                                    fullfile("Components", "PowerComponents", "DiodeThermalBlock", "test")];

%% Code Coverage
config.CodeCoverage.IncludeDirectories = ["ScriptData\DABThermalAnalysisWithCustomMOSFET"];
config.CodeCoverage.IncludeFiles = string.empty;
config.CodeCoverage.FileTypes = ["M-file"; "MLX-file"];
config.CodeCoverage.ExcludeDirectories = "Test";
config.CodeCoverage.ExcludeFiles = string.empty;

%% Reporting
config.Reports.FolderName = "DeviceThermal";
config.Reports.GenerateJUnitXML = true;
config.Reports.GenerateHTMLReport = true;
config.Reports.GenerateCodeCoverage = true;
config.Reports.OpenInBrowser = false;

%% Warning Suppression
% A machine without graphics hardware (a batch or CI run) warns on the first figure;
% R2026a issues MATLAB:graphics:HardwareUnavailable, earlier releases MATLAB:hg:AutoSoftwareOpenGL.
config.SuppressedWarnings = ["MATLAB:hg:AutoSoftwareOpenGL", "MATLAB:graphics:HardwareUnavailable"];

end
