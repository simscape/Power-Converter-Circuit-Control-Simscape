classdef tLLCControllerBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the LLC Voltage Controller
    % library block in ConverterLibrary. The harness model ModelLLCController
    % is the full-bridge LLC converter model with ideal plant devices, a
    % 385 V source, a 20.48 Ohm load and a 390 V reference. The test runs
    % every controller option and passes when the model simulates without
    % error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "ModelLLCController";
        ControllerBlockName = "Controller";
        LibraryBlock = "ConverterLibrary/Controller/Soft-Switching Converters/LLC Voltage Controller";
    end

    properties (TestParameter)
        cntrlSelect = {"Compensator (Continuous S domain)", "Compensator (Discrete Z domain)", ...
            "PI controller (Continuous)", "PI controller (Discrete)"};
        vcoSelect = {"Constant rate", "Two rate"};
    end

    methods (Test)

        function RunSimulateModel(testCase, cntrlSelect, vcoSelect)
            % Simulate the harness for one combination of controller options.
            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));
            controllerPath = test.setupBlockForTesting(testCase.ModelName, ...
                testCase.ControllerBlockName, testCase.LibraryBlock);
            set_param(controllerPath, "cntrlSelect", cntrlSelect);
            set_param(controllerPath, "vcoSelect", vcoSelect);
            sim(testCase.ModelName);
        end
    end
end
