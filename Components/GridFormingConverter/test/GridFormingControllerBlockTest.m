classdef GridFormingControllerBlockTest < matlab.unittest.TestCase
    % This MATLAB unit test is used to test the Grid-Forming
    % Controller library block

    % Copyright 2025 - 2026 The MathWorks, Inc.

    methods (Test)

        function RunSimulateModel(testCase)
            % Test for the harness model tLLCResonantControllerAndPowerCircuit model

            % Load system and add teardown
            modelname = "ModelGridFormingController";
            load_system(modelname);
            testCase.addTeardown(@()close_system(modelname, 0));

            % Update 'LLC Converter Power Circuit' from library
            libraryBlock = "GFMLibrary/Grid-Forming Converter Controller";
            controllerPath = test.setupBlockForTesting(modelname, "Grid-Forming Converter Controller", libraryBlock);

            % Run the model with Virtual Synchronous Machine control
            set_param(controllerPath,'powerControl',"Virtual Synchronous Machine");
            set_param(controllerPath,'currentLimit',"Virtual Impedance");
            set_param(controllerPath,'freqOption',"Constant Frequency Reference");
            sim(modelname);

           % Run the model with Virtual Synchronous Machine control
            set_param(controllerPath,'powerControl',"Droop Control");
            set_param(controllerPath,'currentLimit',"Virtual Impedance");
            set_param(controllerPath,'freqOption',"Constant Frequency Reference");
            sim(modelname);

           % Run the model with Current Limiting fault ride-through
            set_param(controllerPath,'powerControl',"Virtual Synchronous Machine");
            set_param(controllerPath,'currentLimit',"Current Limiting");
            set_param(controllerPath,'freqOption',"Constant Frequency Reference");
            sim(modelname);

           % Run the model with Current Limiting fault ride-through with
           % droop control
            set_param(controllerPath,'powerControl',"Droop Control");
            set_param(controllerPath,'currentLimit',"Current Limiting");
            set_param(controllerPath,'freqOption',"Constant Frequency Reference");
            sim(modelname);

            % Run the model with Virtual Impedance and Current Limiting
            % fault ride-through with Virtual Synchronous Machine power
            % method
            set_param(controllerPath,'powerControl',"Virtual Synchronous Machine");
            set_param(controllerPath,'currentLimit',"Virtual Impedance and Current Limiting");
            set_param(controllerPath,'freqOption',"Constant Frequency Reference");
            sim(modelname);

         % Run the model with Virtual Impedance and Current Limiting fault ride-through with droop control
            set_param(controllerPath,'powerControl',"Droop Control");
            set_param(controllerPath,'currentLimit',"Virtual Impedance and Current Limiting");
            set_param(controllerPath,'freqOption',"Constant Frequency Reference");
            sim(modelname);
            
        end
    end
end
