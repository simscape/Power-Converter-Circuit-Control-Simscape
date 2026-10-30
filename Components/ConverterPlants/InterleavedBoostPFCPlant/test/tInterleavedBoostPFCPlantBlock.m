classdef tInterleavedBoostPFCPlantBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the Interleaved Boost PFC
    % Converter library block in ConverterPlantLibrary. The harness model
    % InterleavedBoostPFCTestHarnessPlant drives the plant open loop: the
    % interleaved PWM generator modulates the duty reference
    % 1 - 0.7936*|sin(2*pi*50*t + 1.14 deg)| into both boost legs, from a
    % 230 V rms, 50 Hz source into an 80 Ohm load. The amplitude and phase
    % set a 400 V output with the line current in phase with the line voltage. The test passes when the model simulates
    % without error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "InterleavedBoostPFCTestHarnessPlant";
        PlantBlockName = "Interleaved Boost PFC";
        LibraryBlock = "ConverterPlantLibrary/Power Factor Correction Converters/Interleaved Boost PFC Converter";
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
