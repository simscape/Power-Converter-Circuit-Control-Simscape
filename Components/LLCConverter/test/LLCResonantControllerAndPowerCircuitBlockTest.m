classdef LLCResonantControllerAndPowerCircuitBlockTest < matlab.unittest.TestCase
    % This MATLAB unit test is used to test the library blocks
    %  1. LLC controller
    %  2. LLC Converter power circuit
    % The test model tLLCResonantControllerAndPowerCircuit is used to test
    % both LLC controller and Power circuit library blocks

    % Copyright 2025 - 2026 The MathWorks, Inc.

    properties (TestParameter)
        primarySwitchingDevice = {  "Ideal semiconductor switch",...
                                    "MOSFET (Ideal, Switching) without Thermal",...
                                    "MOSFET (Ideal, Switching) with Thermal"};

        secondaryDiode = {"Ideal Diode", "Tabulated Diode"}
    end


    methods (Test)

        function RunSimulateModel(testCase, primarySwitchingDevice, secondaryDiode)
            % Test for the harness model tLLCResonantControllerAndPowerCircuit model
            
            % Load system and add teardown
            modelname = "ModelLLCResonantControllerAndPowerCircuit";
            load_system(modelname);
            testCase.addTeardown(@()close_system(modelname, 0));

            % Update 'LLC Converter Power Circuit' from library
            libraryBlock = "LLCConverterLibrary/LLC Converter Power Circuit";
            circuitPath = test.setupBlockForTesting(modelname, "LLC Converter Power Circuit", libraryBlock);

            % Update 'LLC Controller' from library
            controllerBlock = "LLCConverterLibrary/LLC Controller";
            [~] = test.setupBlockForTesting(modelname, "LLC Controller", controllerBlock);

            % Reduce 'StopTime'
            if strcmp(primarySwitchingDevice, "MOSFET (Ideal, Switching) with Thermal")
                set_param(modelname, "StopTime", "1e-3");
            end

            % Run the model for Ideal semiconductor and Basic Diode
            set_param(circuitPath,"primaryDeviceOption", primarySwitchingDevice);
            set_param(circuitPath,"secondaryDeviceOption", secondaryDiode);

            % Simulate model
            sim(modelname);
        end
    end
end
