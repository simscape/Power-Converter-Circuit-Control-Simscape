classdef tPWMGeneratorBlock < matlab.unittest.TestCase
    % This MATLAB unit test is a smoke test of the six PWM generator library
    % blocks in ConverterLibrary. The harness model ModelPWMGenerators drives
    % each generator with constant commands into a Scope. Each test replaces
    % one generator with the current library block and runs it in each solver
    % mode: variable-step with the model on a variable-step solver, and
    % fixed-step with the model on a fixed-step discrete solver at the
    % generator's own sample time. The test passes when the model simulates
    % without error. It does not check output values.

    % Copyright 2026 The MathWorks, Inc.

    properties (Constant)
        ModelName = "ModelPWMGenerators";
        LibraryFolder = "ConverterLibrary/Controller/PWM Generators/";
        GeneratorNames = ["Half Bridge PWM Generator", "Complementary PWM Generator", ...
            "Full Bridge PWM Generator", "DAB PWM Generator", "LLC PWM Generator", "CLLC PWM Generator"];
    end

    properties (TestParameter)
        generator = {"Half Bridge PWM Generator", "Complementary PWM Generator", ...
            "Full Bridge PWM Generator", "DAB PWM Generator", "LLC PWM Generator", "CLLC PWM Generator"};
        solverMode = {"Variable-step (continuous)", "Fixed-step (discrete)"};
    end

    methods (Test)

        function RunSimulateModel(testCase, generator, solverMode)
            % Simulate the harness with one generator from the library in one solver mode.
            load_system(testCase.ModelName);
            testCase.addTeardown(@() close_system(testCase.ModelName, 0));
            generatorPath = test.setupBlockForTesting(testCase.ModelName, generator, ...
                testCase.LibraryFolder + generator);
            % Every generator in the harness runs in the same mode, so a fixed-step
            % run has no continuous state left for the discrete solver.
            for other = testCase.GeneratorNames
                set_param(testCase.ModelName + "/" + other, "solverMode", solverMode);
            end
            if solverMode == "Fixed-step (discrete)"
                set_param(testCase.ModelName, "SolverType", "Fixed-step", "Solver", "FixedStepDiscrete", ...
                    "FixedStep", get_param(generatorPath, "Ts"));
            end
            sim(testCase.ModelName);
        end
    end
end
