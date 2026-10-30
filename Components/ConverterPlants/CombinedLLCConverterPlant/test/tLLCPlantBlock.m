classdef tLLCPlantBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the LLC Converter library
    % block in ConverterPlantLibrary. The harness model
    % LLCTestHarnessFullBridge drives the plant open loop: an LLC PWM
    % Generator switches at the resonant frequency (frequency 1 per unit),
    % from a 385 V source into a 20.48 Ohm load. The test passes when the
    % model simulates without error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "LLCTestHarnessFullBridge";
        PlantBlockName = "LLC Converter Power Circuit";
        LibraryBlock = "ConverterPlantLibrary/Soft-Switching Converters/LLC Converter";
    end

    properties (TestParameter)
        detailedModel = {"Detailed Half-Bridge", "Detailed Full-Bridge"};
        seriesInductorOption = {"Use external inductance", "Use transformer leakage inductance"};
        primaryDeviceOption = {"Ideal Semiconductor Switch", "MOSFET (Ideal, Switching) with Thermal"};
        rectifierOption = {"Centre-Tap", "Full Bridge"};
        secondaryDeviceOption = {"Ideal Diode", "Tabulated Diode"};
    end

    methods (Test)

        function RunSimplifiedModel(testCase, seriesInductorOption)
            % Simulate the Simplified Half-Bridge model with each series inductor option.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "llcConverterModel", "Simplified Half-Bridge");
            set_param(plantPath, "seriesInductorOption", seriesInductorOption);
            sim(testCase.ModelName);
        end

        function RunDetailedModel(testCase, detailedModel, seriesInductorOption, ...
                primaryDeviceOption, rectifierOption, secondaryDeviceOption)
            % Simulate both Detailed models for every inductor, device and rectifier option.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "llcConverterModel", detailedModel);
            set_param(plantPath, "seriesInductorOption", seriesInductorOption);
            set_param(plantPath, "primaryDeviceOption", primaryDeviceOption);
            set_param(plantPath, "rectifierOption", rectifierOption);
            set_param(plantPath, "secondaryDeviceOption", secondaryDeviceOption);
            sim(testCase.ModelName);
        end
    end

    methods (Access = private)

        function plantPath = loadHarnessWithLibraryPlant(testCase)
            % Load the harness, close it without saving at teardown, and replace
            % its plant with the current library block.
            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));
            plantPath = test.setupBlockForTesting(testCase.ModelName, testCase.PlantBlockName, ...
                testCase.LibraryBlock);
        end
    end
end
