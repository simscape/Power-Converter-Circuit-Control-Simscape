classdef tInterleavedBoostPFCControllerBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the Interleaved Boost PFC
    % Controller library block in ConverterLibrary. The harness model
    % ModelInterleavedBoostPFCController is the interleaved boost PFC
    % converter model with its plant fixed to the Simplified variant, a
    % 230 V rms, 50 Hz source, an 80 Ohm load and a 400 V reference. The test
    % runs every controller option and passes when the model simulates
    % without error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "ModelInterleavedBoostPFCController";
        ControllerBlockName = "Controller";
        LibraryBlock = "ConverterLibrary/Controller/Power Factor Correction Converters/Interleaved Boost PFC Controller";
    end

    properties (TestParameter)
        outputSelect = {"PWM Signal", "Duty Cycle"};
        cntrlSelect = {"PI controller (Continuous)", "PI controller (Discrete)"};
    end

    methods (Test)

        function RunSimulateModel(testCase, outputSelect, cntrlSelect)
            % Simulate the harness for one combination of controller options.
            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));
            controllerPath = test.setupBlockForTesting(testCase.ModelName, ...
                testCase.ControllerBlockName, testCase.LibraryBlock);
            set_param(controllerPath, "outputSelect", outputSelect);
            set_param(controllerPath, "cntrlSelect", cntrlSelect);
            sim(testCase.ModelName);
        end
    end
end
