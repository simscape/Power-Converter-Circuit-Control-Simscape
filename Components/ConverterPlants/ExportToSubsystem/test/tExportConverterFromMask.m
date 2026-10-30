classdef tExportConverterFromMask < matlab.unittest.TestCase
%TEXPORTCONVERTERFROMMASK Unit tests for the Export button on each plant block mask.
%   For each converter plant, verifies that exportConverterModelFromMask:
%     1. Runs without error
%     2. Creates a .slx model file
%     3. Creates a _params.m parameter file

% Copyright 2025-2026 The MathWorks, Inc.

    properties (Constant)
        LibName = 'ConverterLibrary';
    end

    methods (TestClassSetup)
        function loadLibrary(testCase)
            load_system(testCase.LibName);
            set_param(testCase.LibName, 'Lock', 'off');
            testCase.addTeardown(@() close_system(testCase.LibName, 0));
        end
    end

    %% Export Button Presence Tests
    methods (Test)
        function testExportButtonExists(testCase)
            blkPaths = {
                'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Boost PFC'
                'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Interleaved Boost PFC'
                'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Totem-Pole Boost PFC'
                'ConverterLibrary/Power Converter Plant/Soft-Switching Converters/DAB Converter'
                'ConverterLibrary/Power Converter Plant/Soft-Switching Converters/  LLC Converter'
                'ConverterLibrary/Power Converter Plant/Non-Isolated DC-DC Converters/Non-Isolated DCDC'
            };

            for i = 1:numel(blkPaths)
                h = Simulink.Mask.get(blkPaths{i});
                ctrls = h.getDialogControls;

                hasExportPanel = false;
                for c = 1:numel(ctrls)
                    if strcmp(ctrls(c).Name, 'ExportPanel')
                        hasExportPanel = true;
                        panelCtrls = ctrls(c).DialogControls;
                        hasButton = false;
                        for b = 1:numel(panelCtrls)
                            if isa(panelCtrls(b), 'Simulink.dialog.Button') && ...
                                    strcmp(panelCtrls(b).Name, 'exportToModel')
                                hasButton = true;
                                testCase.verifyEqual(panelCtrls(b).Enabled, 'on', ...
                                    sprintf('%s: Export button should be enabled', blkPaths{i}));
                                testCase.verifyEqual(panelCtrls(b).Callback, ...
                                    'exportConverterModelFromMask(gcb);', ...
                                    sprintf('%s: Export button callback mismatch', blkPaths{i}));
                                break;
                            end
                        end
                        testCase.verifyTrue(hasButton, ...
                            sprintf('%s: ExportPanel should contain the Export button', blkPaths{i}));
                        break;
                    end
                end
                testCase.verifyTrue(hasExportPanel, ...
                    sprintf('%s: Mask should have an ExportPanel', blkPaths{i}));
            end
        end
    end

    %% Boost PFC
    methods (Test)
        function testExportBoostPFCSimplified(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Boost PFC';
            set_param(blkPath, 'modelOption', 'Simplified');
            testCase.verifyExport(blkPath);
        end

        function testExportBoostPFCDetailed(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Boost PFC';
            set_param(blkPath, 'modelOption', 'Detailed');
            set_param(blkPath, 'switchDeviceOption', 'Ideal Switch');
            set_param(blkPath, 'diodeDeviceOption', 'Ideal Diode');
            set_param(blkPath, 'rectDiodeDeviceOption', 'Ideal Diode');
            testCase.verifyExport(blkPath);
        end
    end

    %% Interleaved Boost PFC
    methods (Test)
        function testExportInterleavedBoostPFCSimplified(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Interleaved Boost PFC';
            set_param(blkPath, 'modelOption', 'Simplified');
            testCase.verifyExport(blkPath);
        end

        function testExportInterleavedBoostPFCDetailed(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Interleaved Boost PFC';
            set_param(blkPath, 'modelOption', 'Detailed');
            set_param(blkPath, 'switchDeviceOption', 'Ideal Switch');
            set_param(blkPath, 'diodeDeviceOption', 'Ideal Diode');
            set_param(blkPath, 'rectDiodeDeviceOption', 'Ideal Diode');
            testCase.verifyExport(blkPath);
        end
    end

    %% Totem-Pole Boost PFC
    methods (Test)
        function testExportTotemPolePFCSimplified(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Totem-Pole Boost PFC';
            set_param(blkPath, 'modelOption', 'Simplified');
            testCase.verifyExport(blkPath);
        end

        function testExportTotemPolePFCDetailed(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Power Factor Correction Converters/Totem-Pole Boost PFC';
            set_param(blkPath, 'modelOption', 'Detailed');
            set_param(blkPath, 'fastLegDeviceOption', 'Ideal Switch');
            set_param(blkPath, 'slowLegDeviceOption', 'Diode');
            set_param(blkPath, 'slowDiodeDeviceOption', 'Ideal Diode');
            testCase.verifyExport(blkPath);
        end
    end

    %% DAB Converter
    methods (Test)
        function testExportDABSimplified(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Soft-Switching Converters/DAB Converter';
            set_param(blkPath, 'modelOption', 'Simplified');
            testCase.verifyExport(blkPath);
        end

        function testExportDABDetailed(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Soft-Switching Converters/DAB Converter';
            set_param(blkPath, 'modelOption', 'Detailed');
            set_param(blkPath, 'switchDeviceOptionPri', 'Ideal Switch');
            set_param(blkPath, 'switchDeviceOptionSec', 'Ideal Switch');
            testCase.verifyExport(blkPath);
        end
    end

    %% LLC Converter
    methods (Test)
        function testExportLLCSimplified(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Soft-Switching Converters/  LLC Converter';
            set_param(blkPath, 'llcConverterModel', 'Simplified Half-Bridge');
            testCase.verifyExport(blkPath);
        end

        function testExportLLCDetailed(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Soft-Switching Converters/  LLC Converter';
            set_param(blkPath, 'llcConverterModel', 'Detailed Full-Bridge');
            set_param(blkPath, 'primaryDeviceOption', 'Ideal Semiconductor Switch');
            set_param(blkPath, 'secondaryDeviceOption', 'Ideal Diode');
            set_param(blkPath, 'rectifierOption', 'Full Bridge');
            testCase.verifyExport(blkPath);
        end
    end

    %% Non-Isolated DC-DC
    methods (Test)
        function testExportNonIsolatedDCDCBuck(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Non-Isolated DC-DC Converters/Non-Isolated DCDC';
            set_param(blkPath, 'modelOption', 'Buck');
            set_param(blkPath, 'switchDeviceOption', 'Ideal Switch');
            set_param(blkPath, 'diodeDeviceOption', 'Ideal Diode');
            testCase.verifyExport(blkPath);
        end

        function testExportNonIsolatedDCDCSyncBuck(testCase)
            blkPath = 'ConverterLibrary/Power Converter Plant/Non-Isolated DC-DC Converters/Non-Isolated DCDC';
            set_param(blkPath, 'modelOption', 'Synchronous Buck');
            set_param(blkPath, 'switchDeviceOption', 'Ideal Switch');
            set_param(blkPath, 'diodeDeviceOption', 'Ideal Diode');
            testCase.verifyExport(blkPath);
        end
    end

    methods (Access = private)
        function verifyExport(testCase, blkPath)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            exportDir = fixture.Folder;

            exportConverterModelFromMask(blkPath);

            slxFiles = dir(fullfile(exportDir, '*.slx'));
            testCase.verifyNotEmpty(slxFiles, ...
                'Export should create a .slx model file');

            paramFiles = dir(fullfile(exportDir, '*_params.m'));
            testCase.verifyNotEmpty(paramFiles, ...
                'Export should create a _params.m parameter file');

            if ~isempty(slxFiles)
                mdlName = erase(slxFiles(1).name, '.slx');
                load_system(fullfile(exportDir, slxFiles(1).name));
                testCase.addTeardown(@() close_system(mdlName, 0));
                testCase.verifyTrue(bdIsLoaded(mdlName), ...
                    'Exported model should be loadable');
            end
        end
    end
end
