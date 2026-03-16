classdef LLCResonantConverterSystem < matlab.unittest.TestCase
    % System level test for LLCResonantConverterFullBridge.slx

    properties
        Model = "LLCResonantConverterFullBridge";
        SimIn;
        BaseWorkspace;
    end

    methods(TestMethodSetup)
        function loadAndTearDown(testCase)
            % This function executes before each test method runs. This
            % function loads the model and adds a teardown which is
            % executed after the test method is run
            % Load the model
            open_system(testCase.Model);

            % Create a Simulink.SimulationInput object for the model
            testCase.SimIn = Simulink.SimulationInput(testCase.Model);
                      
            % Close the model after each test point
            testCase.addTeardown(@()bdclose(testCase.Model));
        end

        function CreateCopyOfBaseWorkspace(testCase)
            % Creating copy of baseworkspace variable as these are required
            % for setting SimIn obejct parameters.
            testCase.BaseWorkspace = matlab.lang.Workspace.baseWorkspace();
        end

    end

    methods(Test)

        function TestDesignWithMinVinMaxVrefAndMaxLoad(testCase)
            % The test check the functionality of the LLC Resonant
            % converter based on input voltage and output reference
            % voltage.

            % Log
            testCase.log(1, "TEST CONDITION: MIN VIN, MAX VREF, AND MAX LOAD.");

            % Set parameter- Input Voltage
            dcVoltage = testCase.BaseWorkspace.LLCSpec.minInputVoltage;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage', num2str(dcVoltage.value));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage_unit', string(dcVoltage.unit));

            % Set parameter- Reference Voltage
            referenceVoltage = testCase.BaseWorkspace.LLCSpec.maxOutputVoltage;
            referenceVoltage = convert(referenceVoltage, 'V');
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vref'), 'Value', num2str(referenceVoltage.value));

            % Set paramter- Load
            ratedOutputPower = testCase.BaseWorkspace.LLCSpec.ratedOutputPower;
            ratedOutputPower = convert(ratedOutputPower, 'W');
            load = (referenceVoltage.value)^2/ratedOutputPower.value;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R', num2str(load));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R_unit', 'Ohm');

            % Simulate the model
            out = sim(testCase.SimIn);

            % Verify output voltage
            outputVoltage = out.SimlogLLCConverter.Rload.v.series.values('V');
            testCase.verifyEqual(outputVoltage(end), referenceVoltage.value, 'AbsTol', 1, 'RelTol', 0.05,...
                "The output voltage should be equal to reference voltage.");

        end

        function TestDesignWithMinVinMaxVrefAndMinLoad(testCase)
            % The test check the functionality of the LLC Resonant
            % converter based on input voltage and output reference
            % voltage.

            % Log
            testCase.log(1, "TEST CONDITION: MIN VIN, MAX VREF, AND MIN LOAD.");

            % Set parameter- Input Voltage
            dcVoltage = testCase.BaseWorkspace.LLCSpec.minInputVoltage;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage', num2str(dcVoltage.value));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage_unit', string(dcVoltage.unit));

            % Set parameter- Reference Voltage
            referenceVoltage = testCase.BaseWorkspace.LLCSpec.maxOutputVoltage;
            referenceVoltage = convert(referenceVoltage, 'V');
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vref'), 'Value', num2str(referenceVoltage.value));

            % Set paramter- Load
            minOutputVoltage = testCase.BaseWorkspace.LLCSpec.minOutputVoltage;
            minOutputVoltage = convert(minOutputVoltage, 'V');
            ratedOutputPower = testCase.BaseWorkspace.LLCSpec.ratedOutputPower;
            ratedOutputPower = convert(ratedOutputPower, 'W');
            load = (minOutputVoltage.value)^2/ratedOutputPower.value;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R', num2str(load));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R_unit', 'Ohm');

            % Simulate the model
            out = sim(testCase.SimIn);

            % Verify output voltage
            outputVoltage = out.SimlogLLCConverter.Rload.v.series.values('V');
            testCase.verifyEqual(outputVoltage(end), referenceVoltage.value, 'AbsTol', 1, 'RelTol', 0.08,...
                "The output voltage should be equal to reference voltage.");

        end

        function TestDesignWithMaxVinMinVrefAndMinLoad(testCase)
            % The test check the functionality of the LLC Resonant
            % converter based on input voltage and output reference
            % voltage.

            % Log
            testCase.log(1, "TEST CONDITION: MAX VIN, MIN VREF, AND MIN LOAD.");

            % Set parameter- Input Voltage
            dcVoltage = testCase.BaseWorkspace.LLCSpec.maxInputVoltage;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage', num2str(dcVoltage.value));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage_unit', string(dcVoltage.unit));

            % Set parameter- Reference Voltage
            referenceVoltage = testCase.BaseWorkspace.LLCSpec.minOutputVoltage;
            referenceVoltage = convert(referenceVoltage, 'V');
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vref'), 'Value', num2str(referenceVoltage.value));

            % Set paramter- Load
            ratedOutputPower = testCase.BaseWorkspace.LLCSpec.ratedOutputPower;
            ratedOutputPower = convert(ratedOutputPower, 'W');
            load = (referenceVoltage.value)^2/ratedOutputPower.value;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R', num2str(load));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R_unit', 'Ohm');

            % Simulate the model
            out = sim(testCase.SimIn);

            % Verify output voltage
            outputVoltage = out.SimlogLLCConverter.Rload.v.series.values('V');
            testCase.verifyEqual(outputVoltage(end), referenceVoltage.value, 'AbsTol', 1, 'RelTol', 0.05,...
                "The output voltage should be equal to reference voltage.");

        end

        function TestDesignWithMaxVinMinVrefAndMaxLoad(testCase)
            % The test check the functionality of the LLC Resonant
            % converter based on input voltage and output reference
            % voltage.

            % Log
            testCase.log(1, "TEST CONDITION: MAX VIN, MIN VREF, AND MAX LOAD.");

            % Set parameter- Input Voltage
            dcVoltage = testCase.BaseWorkspace.LLCSpec.maxInputVoltage;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage', num2str(dcVoltage.value));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vin'), 'dc_voltage_unit', string(dcVoltage.unit));

            % Set parameter- Reference Voltage
            referenceVoltage = testCase.BaseWorkspace.LLCSpec.minOutputVoltage;
            referenceVoltage = convert(referenceVoltage, 'V');
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Vref'), 'Value', num2str(referenceVoltage.value));

            % Set paramter- Load
            maxOutputVoltage = testCase.BaseWorkspace.LLCSpec.maxOutputVoltage;
            maxOutputVoltage = convert(maxOutputVoltage, 'V');
            ratedOutputPower = testCase.BaseWorkspace.LLCSpec.ratedOutputPower;
            ratedOutputPower = convert(ratedOutputPower, 'W');
            load = (maxOutputVoltage.value)^2/ratedOutputPower.value;
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R', num2str(load));
            testCase.SimIn = testCase.SimIn.setBlockParameter(strcat(testCase.Model,'/Rload'), 'R_unit', 'Ohm');

            % Simulate the model
            out = sim(testCase.SimIn);

            % Verify output voltage
            outputVoltage = out.SimlogLLCConverter.Rload.v.series.values('V');
            testCase.verifyEqual(outputVoltage(end), referenceVoltage.value, 'AbsTol', 1, 'RelTol', 0.05,...
                "The output voltage should be equal to reference voltage.");

        end

    end

end