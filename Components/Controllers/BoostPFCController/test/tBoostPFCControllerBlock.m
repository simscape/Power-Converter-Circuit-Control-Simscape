classdef tBoostPFCControllerBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the Boost PFC Controller
    % library block in ConverterLibrary. The harness model
    % ModelBoostPFCController is the boost PFC converter model with its
    % plant fixed to the Simplified variant, a 230 V rms, 50 Hz source, a
    % 160 Ohm load and a 400 V reference. The test runs every controller
    % option and passes when the model simulates without error. It does not
    % check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "ModelBoostPFCController";
        ControllerBlockName = "Controller";
        LibraryBlock = "ConverterLibrary/Controller/Power Factor Correction Converters/Boost PFC Controller";
    end

    properties (TestParameter)
        outputSelect = {"PWM Signal", "Duty Cycle"};
        cntrlSelect = {"PI controller (Continuous)", "PI controller (Discrete)"};
    end

    methods (Test)

        function RunSimulateModel(testCase, outputSelect, cntrlSelect)
            % Simulate the harness for one combination of controller options.

            % Load system and add teardown
            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));

            % Update the controller from the library
            controllerPath = test.setupBlockForTesting(testCase.ModelName, ...
                testCase.ControllerBlockName, testCase.LibraryBlock);

            % Set the controller options and simulate
            set_param(controllerPath, "outputSelect", outputSelect);
            set_param(controllerPath, "cntrlSelect", cntrlSelect);
            sim(testCase.ModelName);
        end
    end
end
