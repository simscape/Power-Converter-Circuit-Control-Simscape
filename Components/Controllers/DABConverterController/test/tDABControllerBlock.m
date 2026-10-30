classdef tDABControllerBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the DAB Controller (SPS)
    % library block in ConverterLibrary. The harness model ModelDABController
    % is the DAB converter model with its plant fixed to the Simplified
    % variant, a 770 V source, a 35.1125 Ohm load and a 530 V reference. The
    % test runs every controller option and passes when the model simulates
    % without error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "ModelDABController";
        ControllerBlockName = "DAB Controller";
        LibraryBlock = "ConverterLibrary/Controller/Soft-Switching Converters/DAB Controller (SPS)";
    end

    properties (TestParameter)
        outputSelect = {"Gate Signals"};
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
