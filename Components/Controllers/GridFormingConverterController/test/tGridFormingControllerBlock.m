classdef tGridFormingControllerBlock < matlab.unittest.TestCase
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

            % Update 'GFM Converter Controller' from library
            libraryBlock = "ConverterLibrary/Controller/Inverter-Based Resources/Grid-Forming Converter Controller";
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

        function RunSwitchingPowerCircuit(testCase)
            % Run the controller with the two-level switching power circuit
            % instead of the average-value converter, for 1 s.

            % Load system and add teardown
            modelname = "ModelGridFormingController";
            load_system(modelname);
            testCase.addTeardown(@()close_system(modelname, 0));

            % Update 'GFM Converter Controller' from library
            libraryBlock = "ConverterLibrary/Controller/Inverter-Based Resources/Grid-Forming Converter Controller";
            controllerPath = test.setupBlockForTesting(modelname, "Grid-Forming Converter Controller", libraryBlock);

            % Switching fidelity: the switching branch of setGFMConverterModelFidelity,
            % a 5 kHz carrier and a 10 us sample time for the plant and every controller rate
            sampleTime = "1e-5";
            evalin("base", "gridInverter.switchingFrequency = 5e3;");
            evalin("base", "localSolverSampleTime = " + sampleTime + ";");
            evalin("base", "gridInverter.vsm.samplingTime = " + sampleTime + ";");
            evalin("base", "gridInverter.measurementSampleTime = " + sampleTime + ";");
            evalin("base", "gridInverter.droopControl.sampleTime = " + sampleTime + ";");
            evalin("base", "gridInverter.controller.VoltageControlSampleTime = " + sampleTime + ";");
            evalin("base", "gridInverter.controller.CurrentControlSampleTime = " + sampleTime + ";");
            set_param(controllerPath, "measSampleTime", sampleTime, "activePowerSampleTime", sampleTime, ...
                "voltControlTs", sampleTime, "currentControlTs", sampleTime);
            set_param(modelname + "/Grid-Forming Converter Power Circuit/Grid Forming Converter", ...
                "LabelModeActiveChoice", "Switching");

            % Run the model with Virtual Synchronous Machine control
            set_param(controllerPath,'powerControl',"Virtual Synchronous Machine");
            set_param(controllerPath,'currentLimit',"Virtual Impedance");
            set_param(controllerPath,'freqOption',"Constant Frequency Reference");
            sim(modelname, "StopTime", "1");
        end
    end
end
