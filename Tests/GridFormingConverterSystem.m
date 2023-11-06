classdef GridFormingConverterSystem < matlab.unittest.TestCase
    % System level test for GridFormingConverter.slx

    % Copyright 2023 The MathWorks, Inc.
    
    properties
        model = 'GridFormingConverter';
        simIn;
    end

    properties(TestParameter)
        % Use TestParameter If you need to run the same test method for
        % different inputs or scenarios. In this case, this test runs
        % many test points with grid-forming (GFM) in virtual
        % synchronous machine mode and droop control mode. 
        powerControl = {'Virtual Synchronous Machine','Droop Control'};
        currentLimit = {'Virtual Impedance','Current Limiting','Virtual Impedance and Current Limiting'};
    end

    methods(TestMethodSetup)
        function loadAndTearDown(testCase)
            % This function executes before each test method runs. This
            % function loads the model and adds a teardown which is
            % executed after the test method is run
            % Load the model
            load_system(testCase.model);

            % Create a Simulink.SimulationInput object for the model
            testCase.simIn = Simulink.SimulationInput(testCase.model);
                      
            % Close the model after each test point
            testCase.addTeardown(@()bdclose(testCase.model));
        end
    end

    methods(Test)
        function testActivePowerTracking(testCase,powerControl)
            % Check if GFM is tracking the active power reference
            import Simulink.sdi.constraints.MatchesSignal
            import Simulink.sdi.constraints.MatchesSignalOptions
            
            % Disturbance and simulation end times
            disturbanceTime = [2 4];
            simulationTime = 8;
                    
            % Input power profile which GFM should track
            gfmRealPowerRefProfileVal = [0 0.2 0.2 0.5 0.5 0.9 0.85];
            gfmRealPowerRefProfileTime = seconds([0 1 disturbanceTime(1)-1e-3 disturbanceTime(1) disturbanceTime(2)-1e-3 disturbanceTime(2) simulationTime]);
            power = timetable(gfmRealPowerRefProfileVal','RowTimes',gfmRealPowerRefProfileTime');  %#ok<*STRNU>            
                        
            % Set the GFM to VSM or Droop control                                  
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Grid-Forming Converter/Grid-Forming Converter Control'),'powerControl',powerControl); %#ok<*NASGU> 
            
            % Set the power reference in the model
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Power Reference/Active power reference'),'VariableName','powerProfile');
            testCase.simIn = testCase.simIn.setVariable('powerProfile',power);

            % Simulate the model
            out = sim(testCase.simIn);
            
            % Get the actual values of active power from the simulation
            actualTime = seconds(out.LogsoutGridFormingConverter.getElement('Pmeas').Values.Time);
            actualPowerVal = out.LogsoutGridFormingConverter.getElement('Pmeas').Values.Data;
            
            % Set settling time to 0.5s after which all the
            % values reach steady state
            settlingTime = 0.5;
            
            % Remove data for the first 1.5 second to avoid any unnecessary
            % transients. Split the entire simulation in three different
            % time intervals depending on the number of reference changes.
            % Compare the simulation output with the reference in these
            % time intervals
            startTime = 1.5;
            timeWindow = {[startTime disturbanceTime(1)],[disturbanceTime(1)+settlingTime disturbanceTime(2)],...
                [disturbanceTime(2)+settlingTime simulationTime]};

            for compareIdx = 1:length(timeWindow)
                % Capture the values of the start time and end time in each
                % time window
                timeIdx = find(actualTime >= seconds(timeWindow{compareIdx}(1)) & actualTime <= seconds(timeWindow{compareIdx}(2)));
                actualPower = timetable(actualTime(timeIdx),actualPowerVal(timeIdx));
                expectedPower = timetable(gfmRealPowerRefProfileTime(compareIdx+1:compareIdx+2)',gfmRealPowerRefProfileVal(compareIdx+1:compareIdx+2)');
                
                % Verify if GFM actual power is equal to the power
                % reference given as input
                options = MatchesSignalOptions('IgnoringExtraData',true);
                testCase.verifyThat(actualPower,MatchesSignal(expectedPower,...
                    'AbsTol',1e-3,'RelTol',1e-3,'WithOptions',options),...
                    'Actual power is not following the reference active power input. Examine the model');
            end
        end

        function testReactivePowerTracking(testCase,powerControl)
            % Check if GFM is tracking the active power reference
            import Simulink.sdi.constraints.MatchesSignal
            import Simulink.sdi.constraints.MatchesSignalOptions

            % Disturbance and simulation end times
            disturbanceTime = [2 4];
            simulationTime = 8;

            % Input power profile which GFM should track
            gfmReactivePowerRefProfileVal = [0 0.2 0.2 0.5 0.5 0.9 0.85];
            gfmReactivePowerRefProfileTime = seconds([0 1 disturbanceTime(1)-1e-3 disturbanceTime(1) disturbanceTime(2)-1e-3 disturbanceTime(2) simulationTime]);
            power = timetable(gfmReactivePowerRefProfileVal','RowTimes',gfmReactivePowerRefProfileTime');
            
            % Set the GFM to VSM or Droop control                                  
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Grid-Forming Converter/Grid-Forming Converter Control'),'powerControl',powerControl); %#ok<*NASGU> 
                        
            % Set the power reference in the model
            testCase.simIn = testCase.simIn.setVariable('powerProfile',power);
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Power Reference/Reactive power reference'),'VariableName','powerProfile');
            
            % Simulate the model
            out = sim(testCase.simIn);

            % Get the actual values of active power from the simulation
            actualTime = seconds(out.LogsoutGridFormingConverter.getElement('Qmeas').Values.Time);
            actualPowerVal = out.LogsoutGridFormingConverter.getElement('Qmeas').Values.Data;
            
            % Set settling time to 0.5s after which all the
            % values reach steady state
            settlingTime = 0.5;
            
            % Remove data for the first 1.5 second to avoid any unnecessary
            % transients. Split the entire simulation in three different
            % time intervals depending on the number of reference changes.
            % Compare the simulation output with the reference in these
            % time intervals
            startTime = 1.5;
            timeWindow = {[startTime disturbanceTime(1)],[disturbanceTime(1)+settlingTime disturbanceTime(2)],...
                [disturbanceTime(2)+settlingTime simulationTime]};

            for compareIdx = 1:length(timeWindow)
                % Capture the values of the start time and end time in each
                % time window
                timeIdx = find(actualTime >= seconds(timeWindow{compareIdx}(1)) & actualTime <= seconds(timeWindow{compareIdx}(2)));
                actualPower = timetable(actualTime(timeIdx),actualPowerVal(timeIdx));
                expectedPower = timetable(gfmReactivePowerRefProfileTime(compareIdx+1:compareIdx+2)',gfmReactivePowerRefProfileVal(compareIdx+1:compareIdx+2)');
                
                % Verify if GFM actual power is equal to the power
                % reference given as input
                options = MatchesSignalOptions('IgnoringExtraData',true);
                testCase.verifyThat(actualPower,MatchesSignal(expectedPower,...
                    'AbsTol',2e-1,'RelTol',2e-1,'WithOptions',options),...
                    'Actual reactive power is not following the reference reactive power input. Examine the model');
            end
        end

        function testFrequencyChange(testCase)
            % Check if GFM is stable if the grid frequency changes
            
            % Disturbance and simulation end times
            disturbanceTime = 2;
            simulationTime = 20;

            % Grid frequency change with respect to time
            gridFrequencyProfileVal = [50 50 52 52 47 47];
            gridFrequencyProfileTime = seconds([0 disturbanceTime disturbanceTime+1 disturbanceTime+6 disturbanceTime+11 simulationTime]);
            
            % Set settling time to 0.5s after which all the
            % values reach steady state
            settlingTime = 0.5;
            
            % Remove data for first 1.5 second to avoid any unnecessary
            % transients.         
            startTime = 1.5;
            timeWindow = {[startTime simulationTime]};
            frequency = timetable(gridFrequencyProfileVal','RowTimes',gridFrequencyProfileTime');
            

            % Set the simulation stop time and the grid frequency profile
            testCase.simIn = testCase.simIn.setModelParameter('StopTime',mat2str(simulationTime));
            testCase.simIn = testCase.simIn.setVariable('frequencyProfile',frequency);
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Grid/Grid frequency'),'VariableName','frequencyProfile');
            
            % Simulate the model
            out = sim(testCase.simIn);

            % Threshold to check voltage, frequency and power are
            % with in the limits 
            limits.voltage = [0.9 1.25];
            limits.frequency = [46.5 52.5];
            limits.power = [-0.3 1.25];

            % Verify if voltage, frequency and power remains stable when
            % there are changes in the grid frequency
            condition = 'Grid frequency change';
            testCase.verifyStability(out.LogsoutGridFormingConverter,timeWindow,limits,condition);
        end

        function testPhaseJumps(testCase)
            % Check if GFM is stable if the grid phase jumps

            % Disturbance and simulation end times
            disturbanceTime = 3;
            simulationTime = 8;

            % Input power profile which GFM should track
            gridPhaseProfileVal = [0 60 60];
            gridPhaseProfileTime = seconds([0 disturbanceTime simulationTime]);

            % Set settling time to 0.5s after which all the
            % values reach steady state
            settlingTime = 0.5;
            
            % Remove data for first 1 second to avoid any unnecessary
            % transients. Split the entire simulation in two different time
            % intervals depending on the number of reference changes.
            % Compare the simulation output with the reference in these
            % time intervals         
            startTime = 1.5;
            timeWindow = {[1.5 disturbanceTime],[disturbanceTime+settlingTime simulationTime]};
            phase = timetable(gridPhaseProfileVal','RowTimes',gridPhaseProfileTime);

            % Create a Simulink.SimulationInput object for the model
            testCase.simIn = Simulink.SimulationInput(testCase.model);

            % Set the simulation stop time and the grid frequency profile
            testCase.simIn = testCase.simIn.setModelParameter('StopTime',mat2str(simulationTime));
            testCase.simIn = testCase.simIn.setVariable('phaseProfile',phase);
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Grid/Grid voltage phase'),'VariableName','phaseProfile');

            % Simulate the model
            out = sim(testCase.simIn);

            % Threshold to check voltage, frequency, and power are
            % within the limits 
            limits.voltage = [0.9 1.1];
            limits.frequency = [49 51];
            limits.power = [0.1 1.1];
            
            % Verify if voltage, power, and frequency are stable when there
            % is a phase jump in the grid voltage
            condition = 'Grid phase jump';
            testCase.verifyStability(out.LogsoutGridFormingConverter,timeWindow,limits,condition);
        end

        function testIslanding(testCase)
            % Check if GFM is stable in islanding scenario
            import Simulink.sdi.constraints.MatchesSignal
            import Simulink.sdi.constraints.MatchesSignalOptions

            % Disturbance and simulation end times
            disturbanceTime = 2;
            simulationTime = 4;

            circuitBreakerTripSignalVal = [0 1 1]; % Grid circuit breaker trip signal
            circuitBreakerTripSignalTime = seconds([0 disturbanceTime simulationTime]);  % s, Time array
            
            % Set settling time to 0.5s after which all the
            % values reach steady state
            settlingTime = 0.5;
            
            % Remove data for first 1 second to avoid any unnecessary
            % transients.         
            startTime = 1.5;
            timeWindow = {[disturbanceTime+1 simulationTime]};
            breaker = timetable(circuitBreakerTripSignalVal','RowTimes',circuitBreakerTripSignalTime');

            % Change the load power reference after islanding
            localLoadRealProfileVal = [0.7 0.7 0.8 0.8];
            localLoadRealProfileTime = seconds([0 disturbanceTime-1e-3 disturbanceTime simulationTime]);
            load = timetable(localLoadRealProfileVal','RowTimes',localLoadRealProfileTime');

            % Create a Simulink.SimulationInput object for the model
            testCase.simIn = Simulink.SimulationInput(testCase.model);

            % Set the simulation stop time, breaker, and load profiles
            testCase.simIn = testCase.simIn.setModelParameter('StopTime',mat2str(simulationTime));
            testCase.simIn = testCase.simIn.setVariable('breakerProfile',breaker);
            testCase.simIn = testCase.simIn.setVariable('loadProfile',load);
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Transformer 415 V//11 kV/Circuit breaker'),'VariableName','breakerProfile');
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Load/Load active power'),'VariableName','loadProfile');

            % Simulate the model
            out = sim(testCase.simIn);

            % Verify if GFM is stable when supplying the load
            gfmTime = seconds(out.LogsoutGridFormingConverter.getElement('Pmeas').Values.Time);
            gfmPowerVal = out.LogsoutGridFormingConverter.getElement('Pmeas').Values.Data;
            loadPowerVal = out.LogsoutGridFormingConverter.getElement('Ploadref').Values.Data;

            % Find the index of the time vector when the grid is
            % islanded and 1 second settling time is considered to avoid
            % transients
            settlingTime = 1;
            timeIdx = find(gfmTime >= seconds(disturbanceTime+settlingTime));
            gfmPower = timetable(gfmTime(timeIdx),gfmPowerVal(timeIdx));
            loadPower = timetable(gfmTime(timeIdx),loadPowerVal(timeIdx));

            % Verify if GFM is supplying the load after islanding
            options = MatchesSignalOptions('IgnoringExtraData',true);
            testCase.verifyThat(gfmPower,MatchesSignal(loadPower,...
                'AbsTol',5e-2,'RelTol',5e-2,'WithOptions',options),...
                'In Islanded condition, GFM is not able to supply the required power to the load. Examing the model');

            % Threshold to check voltage, frequency, and power are
            % within the limits 
            limits.voltage = [0.9 1.1];
            limits.frequency = [48.5 51.5];
            limits.power = [0.1 1.1];

            % Verify if voltage, power, and frequency are stable when the
            % main grid is islanded
            condition = 'Islanding';
            testCase.verifyStability(out.LogsoutGridFormingConverter,timeWindow,limits,condition);
        end

        function testCurrentLimitingVariants(testCase,currentLimit)
            % Check if all the current limiting variants are working
            % properly without any warnings and errors
            
            % Disturbance and simulation end times
            disturbanceTime = 2;
            simulationTime = 4;
            faultTriggerVal = [0 1 0 0];
            faultTriggerTime = [0 disturbanceTime disturbanceTime+2 simulationTime];
            fault = timetable(faultTriggerVal','RowTimes',seconds(faultTriggerTime'));
            
            % Set the simulation stop time, current limiting method
            testCase.simIn = testCase.simIn.setModelParameter('StopTime',mat2str(simulationTime));           
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Grid-Forming Converter/Grid-Forming Converter Control'),'currentLimit',currentLimit);
            testCase.simIn = testCase.simIn.setVariable('faultProfile',fault);
            testCase.simIn = testCase.simIn.setBlockParameter(strcat(testCase.model,'/Fault/Fault trigger'),'VariableName','faultProfile');
            sim(testCase.simIn);
        end
    end

    methods
        function verifyStability(testCase,LogsoutGridFormingConverter,timeWindow,limits,condition)
            % Function to verify if the values are within the limits and
            % there are no oscillations in voltage, power, and frequency
            actualTime = seconds(LogsoutGridFormingConverter.getElement('Vabc').Values.Time);
            gfmVoltage = squeeze(LogsoutGridFormingConverter.getElement('Vabc').Values.Data);
            gfmVd = LogsoutGridFormingConverter.getElement('Vgd').Values.Data;
            gfmPower = LogsoutGridFormingConverter.getElement('Pmeas').Values.Data;
            gfmFrequency = LogsoutGridFormingConverter.getElement('Freq').Values.Data;
            
            % Verify for all the intervals in the time window
            for compareIdx = 1:length(timeWindow)
                timeIdx = find(actualTime >= seconds(timeWindow{compareIdx}(1)) & actualTime <= seconds(timeWindow{compareIdx}(2)));

                % Convert the rms voltage to peak voltage
                voltage = gfmVd(timeIdx);
                reqTime = actualTime(timeIdx);
                rmsVoltage = rms(gfmVoltage(1:3,timeIdx)')*sqrt(2);
                activePower = gfmPower(timeIdx);
                frequency = gfmFrequency(timeIdx);

                % Choose 10% of the last samples
                voltage = voltage(end-ceil(length(voltage)*0.1):end);
                frequency = frequency(end-ceil(length(frequency)*0.1):end);
                power = activePower(end-ceil(length(activePower)*0.1):end);

                coloumn = 1;
                % Calculate the difference of last 10% of the voltage,
                % frequency and power samples
                for rowIdx = 1:length(voltage)
                    for coloumnIdx = rowIdx:length(voltage)
                        voltageDiff(coloumn) = abs(voltage(rowIdx)-voltage(coloumnIdx)); %#ok<*AGROW>
                        frequencyDiff(coloumn) = abs(frequency(rowIdx)-frequency(coloumnIdx));
                        powerDiff(coloumn) = abs(power(rowIdx)-power(coloumnIdx));
                        coloumn = coloumn+1;
                    end
                end

                % Verify if the RMS voltage of GFM is greater than 0.9 pu
                % and less than 1.1 pu and the difference among the last
                % 10% of the voltage samples is less than 5e-2
                voltageRMSFlag = any(rmsVoltage < limits.voltage(1)) || any(rmsVoltage > limits.voltage(2));
                voltageStabilityFlag = max(voltageDiff) > 1e-2;

                % Verify if the frequency of the GFM is stable and check
                % whether the difference among the last 10% of the
                % frequency samples is less than 5e-2
                frequencyFlag = any(frequency < limits.frequency(1)) || any(frequency > limits.frequency(2));
                frequencyStabilityFlag = max(frequencyDiff) > 5e-2;

                % Verify if the active power from GFM is stable and check
                % whether the difference among the last 10% of the voltage
                % samples is less than 1e-2
                powerFlag = any(activePower < limits.power(1)) || any(activePower > limits.power(2));
                powerStabilityFlag = max(powerDiff) > 1e-2;

                testCase.verifyFalse(voltageRMSFlag,sprintf('RMS value of GFM voltage is outside the limits during %s. Examine the model',condition));
                testCase.verifyFalse(voltageStabilityFlag,sprintf('GFM voltage is oscillatory during %s. Examine the model',condition));
                
                testCase.verifyFalse(frequencyFlag,sprintf('Frequency of GFM is outside the limits during %s. Examine the model',condition));
                testCase.verifyFalse(frequencyStabilityFlag,sprintf('GFM frequency is oscillatory during %s. Examine the model',condition));
             
                testCase.verifyFalse(powerFlag,sprintf('Active power from GFM is outside the limits during %s. Examine the model',condition));
                testCase.verifyFalse(powerStabilityFlag,sprintf('GFM active power is oscillatory during %s. Examine the model',condition));
            end
        end
    end
end