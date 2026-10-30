classdef tCLLCPlantBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the CLLC Converter library
    % block in ConverterPlantLibrary. The harness model CLLCTestHarnessPlant
    % drives the plant open loop: a CLLC PWM Generator switches at the
    % resonant frequency (frequency 1 per unit), from a 380 V source into a
    % 90 Ohm load. The test passes when the model simulates without error.
    % It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "CLLCTestHarnessPlant";
        PlantBlockName = "CLLC Converter Power Circuit";
        LibraryBlock = "ConverterPlantLibrary/Soft-Switching Converters/CLLC Converter";
    end

    properties (TestParameter)
        PrimaryDeviceOption = {"Ideal Switch", "MOSFET (Ideal, Switching) with Thermal"};
        SecondaryDeviceOption = {"Ideal Switch", "MOSFET (Ideal, Switching) with Thermal"};
    end

    methods (Test)

        function RunSimplifiedModel(testCase)
            % Simulate the Simplified variant of the plant.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Simplified");
            sim(testCase.ModelName);
        end

        function RunDetailedModel(testCase, PrimaryDeviceOption, SecondaryDeviceOption)
            % Simulate the Detailed variant for every device combination.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Detailed");
            set_param(plantPath, "PrimaryDeviceOption", PrimaryDeviceOption);
            set_param(plantPath, "SecondaryDeviceOption", SecondaryDeviceOption);
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
