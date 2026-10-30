classdef tCLLCControllerBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the CLLC Controller library
    % block in ConverterLibrary. The harness model ModelCLLCController is the
    % CLLC converter model with its plant fixed to the Simplified variant, a
    % 390 V source, a 19.55 Ohm load and a 370 V reference. The test runs
    % every controller option and passes when the model simulates without
    % error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "ModelCLLCController";
        ControllerBlockName = "Controller";
        LibraryBlock = "ConverterLibrary/Controller/Soft-Switching Converters/CLLC Controller";
    end

    properties (TestParameter)
        controllerDomain = {"Continuous", "Discrete"};
        cntrlSelect = {"2P2Z compensator", "PI controller"};
        vcoSelect = {"Constant rate", "Two rate"};
    end

    methods (Test)

        function RunSimulateModel(testCase, controllerDomain, cntrlSelect, vcoSelect)
            % Simulate the harness for one combination of controller options.
            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));
            controllerPath = test.setupBlockForTesting(testCase.ModelName, ...
                testCase.ControllerBlockName, testCase.LibraryBlock);
            set_param(controllerPath, "controllerDomain", controllerDomain);
            set_param(controllerPath, "cntrlSelect", cntrlSelect);
            set_param(controllerPath, "vcoSelect", vcoSelect);
            sim(testCase.ModelName);
        end
    end
end
