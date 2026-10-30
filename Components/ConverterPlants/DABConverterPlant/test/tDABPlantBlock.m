classdef tDABPlantBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the DAB Converter library
    % block in ConverterPlantLibrary. The harness model DABTestHarnessPlant
    % drives the plant open loop: a DAB PWM Generator applies a 0.7042 rad
    % phase shift at 50 % pulse width, from a 750 V source into a
    % 27.5625 Ohm load. The test passes when the model simulates without
    % error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "DABTestHarnessPlant";
        PlantBlockName = "DAB Converter";
        LibraryBlock = "ConverterPlantLibrary/Soft-Switching Converters/DAB Converter";
    end

    properties (TestParameter)
        seriesInductorOption = {"Use external inductance", "Use transformer leakage inductance"};
        switchDeviceOptionPri = {"Ideal Switch", "MOSFET (Ideal, Switching) with Thermal"};
        switchDeviceOptionSec = {"Ideal Switch", "MOSFET (Ideal, Switching) with Thermal"};
    end

    methods (Test)

        function RunSimplifiedModel(testCase, seriesInductorOption)
            % Simulate the Simplified variant with each series inductor option.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Simplified");
            testCase.setSeriesInductance(plantPath, seriesInductorOption);
            sim(testCase.ModelName);
        end

        function RunDetailedModel(testCase, seriesInductorOption, switchDeviceOptionPri, switchDeviceOptionSec)
            % Simulate the Detailed variant for every device combination.
            plantPath = testCase.loadHarnessWithLibraryPlant();
            set_param(plantPath, "modelOption", "Detailed");
            testCase.setSeriesInductance(plantPath, seriesInductorOption);
            set_param(plantPath, "switchDeviceOptionPri", switchDeviceOptionPri);
            set_param(plantPath, "switchDeviceOptionSec", switchDeviceOptionSec);
            sim(testCase.ModelName);
        end
    end

    methods (Access = private)

        function setSeriesInductance(~, plantPath, seriesInductorOption)
            % Write the design inductances for the option, then select it. An
            % external inductor needs the external design: the library default is
            % the transformer-leakage design, whose external inductance is zero.
            % DABDefaultInputParameters sets DABSpec.
            DABSpec = struct();
            DABDefaultInputParameters;
            [~, DABDesign] = designDABConverter(DABSpec, Realization=seriesInductorOption, ...
                DisplayTableFlag=false);
            set_param(plantPath, "Lr", num2str(DABDesign.Lr.value, 8), "Lr_unit", "H", ...
                "Llk1", num2str(DABDesign.Llk1.value, 8), "Llk1_unit", "H", ...
                "Llk2", num2str(DABDesign.Llk2.value, 8), "Llk2_unit", "H");
            set_param(plantPath, "seriesInductorOption", seriesInductorOption);
        end

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
