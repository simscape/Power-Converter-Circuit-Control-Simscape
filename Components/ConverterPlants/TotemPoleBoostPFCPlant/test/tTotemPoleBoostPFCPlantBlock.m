classdef tTotemPoleBoostPFCPlantBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the Totem-Pole Boost PFC
    % Converter library block in ConverterPlantLibrary. The harness model
    % TotemPoleBoostPFCTestHarnessPlant drives the plant open loop: the fast
    % leg takes the duty 1 - 0.8*|sin(2*pi*50*t + 0.44 deg)| from a Half Bridge
    % PWM Generator, the slow leg follows the line polarity through a
    % Complementary PWM Generator, from a 230 V rms, 50 Hz source into a
    % 400 Ohm load. The amplitude and phase set a 400 V output with the line
    % current in phase with the line voltage. The
    % test passes when the model simulates without error. It does not check
    % output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "TotemPoleBoostPFCTestHarnessPlant";
        PlantBlockName = "Totem-Pole Boost PFC";
        LibraryBlock = "ConverterPlantLibrary/Power Factor Correction Converters/Totem-Pole Boost PFC Converter";
    end

    properties (TestParameter)
        fastLegDeviceOption = {"Ideal Switch", "MOSFET (Ideal, Switching) with Thermal"};
        % Each slow-leg device with the device option that applies to it.
        slowLeg = struct( ...
            "IdealDiode", {{"slowLegDeviceOption", "Diode", "slowDiodeDeviceOption", "Ideal Diode"}}, ...
            "TabulatedDiode", {{"slowLegDeviceOption", "Diode", "slowDiodeDeviceOption", "Tabulated Diode"}}, ...
            "IdealSwitch", {{"slowLegDeviceOption", "MOSFET", "slowMOSFETDeviceOption", "Ideal Switch"}}, ...
            "ThermalMOSFET", {{"slowLegDeviceOption", "MOSFET", "slowMOSFETDeviceOption", ...
                "MOSFET (Ideal, Switching) with Thermal"}}, ...
            "Thyristor", {{"slowLegDeviceOption", "Thyristor"}});
    end

    methods (Test)

        function RunSimplifiedModel(testCase)
            % Simulate the Simplified variant of the plant.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Simplified");
            sim(testCase.ModelName);
        end

        function RunDetailedModel(testCase, fastLegDeviceOption, slowLeg)
            % Simulate the Detailed variant for every fast-leg and slow-leg device.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Detailed");
            set_param(plantPath, "fastLegDeviceOption", fastLegDeviceOption);
            set_param(plantPath, slowLeg{:});
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
