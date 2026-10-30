classdef tNonIsolatedDCDCControllerBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the Non-Isolated DC-DC
    % Controller library block in ConverterLibrary. The harness model
    % ModelNonIsolatedDCDCController is the non-isolated DC-DC converter
    % model with ideal plant devices, a 200 V source, a 106.667 Ohm load and
    % a 400 V reference. The controller's topology is the plant's topology,
    % so each topology runs with the matching plant. The test runs every
    % controller option and passes when the model simulates without error.
    % It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "ModelNonIsolatedDCDCController";
        ControllerBlockName = "Controller";
        PlantBlockName = "Non-Isolated DCDC";
        LibraryBlock = "ConverterLibrary/Controller/Non-Isolated DC-DC Converters/Non-Isolated DC-DC Controller";
    end

    properties (TestParameter)
        modelOption = {"Buck", "Synchronous Buck", "Boost", "Synchronous Boost", ...
            "Buck-Boost", "Synchronous Buck-Boost"};
        loopStructure = {"Single loop", "Double loop"};
        cntrlSelect = {"PI controller (Continuous)", "PI controller (Discrete)"};
        outputSelect = {"PWM Signal"};
    end

    methods (Test)

        function RunSimulateModel(testCase, modelOption, loopStructure, cntrlSelect, outputSelect)
            % Simulate the harness for one combination of controller options.
            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));
            controllerPath = test.setupBlockForTesting(testCase.ModelName, ...
                testCase.ControllerBlockName, testCase.LibraryBlock);
            set_param(testCase.ModelName + "/" + testCase.PlantBlockName, "modelOption", modelOption);
            set_param(controllerPath, "modelOption", modelOption);
            set_param(controllerPath, "loopStructure", loopStructure);
            set_param(controllerPath, "cntrlSelect", cntrlSelect);
            set_param(controllerPath, "outputSelect", outputSelect);
            sim(testCase.ModelName);
        end
    end
end
