classdef tNonIsolatedDCDCPlantBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the Non-Isolated DC-DC
    % Converter library block in ConverterPlantLibrary. The harness model
    % NonIsolatedDCDCTestHarnessPlant drives the plant open loop: a Half
    % Bridge PWM Generator applies a 0.5 duty, from a 200 V source into a
    % 106.667 Ohm load. A topology with a diode takes one gate (the
    % generator's first), a synchronous topology both. Every topology runs
    % with every device option that applies to it. The test passes when the
    % model simulates without error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "NonIsolatedDCDCTestHarnessPlant";
        PlantBlockName = "Non-Isolated DCDC";
        GateSelectBlock = "NonIsolatedDCDCTestHarnessPlant/Gate Select";
        LibraryBlock = "ConverterPlantLibrary/Non-Isolated DC-DC Converters/Non-Isolated DC-DC Converter";
    end

    properties (TestParameter)
        diodeTopology = {"Buck", "Boost", "Buck-Boost"};
        synchronousTopology = {"Synchronous Buck", "Synchronous Boost", "Synchronous Buck-Boost"};
        switchDeviceOption = {"Ideal Switch", "MOSFET (Ideal, Switching) with Thermal"};
        diodeDeviceOption = {"Ideal Diode", "Tabulated Diode"};
    end

    methods (Test)

        function RunDiodeTopology(testCase, diodeTopology, switchDeviceOption, diodeDeviceOption)
            % Simulate a topology with a switch and a diode, for every device combination.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(testCase.GateSelectBlock, "Indices", "1");
            set_param(plantPath, "modelOption", diodeTopology);
            set_param(plantPath, "switchDeviceOption", switchDeviceOption);
            set_param(plantPath, "diodeDeviceOption", diodeDeviceOption);
            sim(testCase.ModelName);
        end

        function RunSynchronousTopology(testCase, synchronousTopology, switchDeviceOption)
            % Simulate a synchronous topology, which has switches only, for each switch device.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(testCase.GateSelectBlock, "Indices", "[1 2]");
            set_param(plantPath, "modelOption", synchronousTopology);
            set_param(plantPath, "switchDeviceOption", switchDeviceOption);
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
