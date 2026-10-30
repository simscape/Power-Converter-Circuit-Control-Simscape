classdef tBoostPFCPlantBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the Boost PFC Converter
    % library block in ConverterPlantLibrary. The harness model
    % BoostPFCTestHarnessPlant drives the plant open loop: a Half Bridge PWM
    % Generator modulates the duty reference
    % 1 - 0.7528*|sin(2*pi*50*t + 1.76 deg)| into the boost switch gate, from
    % a 230 V rms, 50 Hz source into a 60 Ohm load. The amplitude and phase
    % set a 400 V output with the line current in phase with the line voltage. The test passes when the model simulates without error. It does
    % not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "BoostPFCTestHarnessPlant";
        PlantBlockName = "Boost PFC";
        LibraryBlock = "ConverterPlantLibrary/Power Factor Correction Converters/Boost PFC Converter";
    end

    properties (TestParameter)
        switchDeviceOption = {"Ideal Switch", "MOSFET (Ideal, Switching) with Thermal"};
        diodeDeviceOption = {"Ideal Diode", "Tabulated Diode"};
        rectDiodeDeviceOption = {"Ideal Diode", "Tabulated Diode"};
    end

    methods (Test)

        function RunSimplifiedModel(testCase)
            % Simulate the Simplified variant of the plant.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Simplified");
            sim(testCase.ModelName);
        end

        function RunDetailedModel(testCase, switchDeviceOption, diodeDeviceOption, rectDiodeDeviceOption)
            % Simulate the Detailed variant of the plant for every device combination.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Detailed");
            set_param(plantPath, "switchDeviceOption", switchDeviceOption);
            set_param(plantPath, "diodeDeviceOption", diodeDeviceOption);
            set_param(plantPath, "rectDiodeDeviceOption", rectDiodeDeviceOption);
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
