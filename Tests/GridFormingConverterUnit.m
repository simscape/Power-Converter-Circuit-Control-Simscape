
classdef GridFormingConverterUnit < matlab.unittest.TestCase
    % This MATLAB unit test is used to run all the codes used in the
    % Design and Analysis of Grid-Forming Converter (GFM) example.

    % Test for the GridFormingConverter example model
    methods (Test)
        function GFMModelSimulate(~)
            close all
            bdclose all
            mdl = "GridFormingConverter";
            load_system(mdl)
            sim(mdl);
            close all
            bdclose all
        end

        %  Test for the GridFormingConverterMain plot Script
        % Running all test conditions in the GFM model
        function GFMRunPlotGridFormingConverter(~)
            mdl = "GridFormingConverter";
            load_system(mdl)

            % Configure for default test scenario
            % Select the active power control method
            testCondition.activePowerMethod = 'Virtual Synchronous Machine';
            % Select the fault ride-through method
            testCondition.currentLimitMethod = 'Virtual Impedance';
            % Select the grid SCR value
            testCondition.SCR = 2.5;
            % Select the grid X/R ratio
            testCondition.XbyR = 5;

            % Select the operating scenarios
            testCondition.testCondition = 'Normal operation';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>

            % Select the operating scenarios
            testCondition.testCondition = 'Change in active power reference';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in reactive power reference';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in grid voltage';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in local load';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Temporary three-phase fault';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Islanding condition';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in grid frequency 1Hz/s, +0.5Hz';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in grid frequency 2Hz/s, +2Hz';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;
            %
            % Select the operating scenarios
            testCondition.testCondition = 'Change in grid frequency 2Hz/s, +2Hz and 1Hz/s till -5Hz';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in grid phase by 10 degrees';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in grid phase by 60 degrees';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;

            % Select the operating scenarios
            testCondition.testCondition = 'Permanent three-phase fault';
            % Calling the plot function
            outputTable = PlotGridFormingConverter(testCondition,1); %#ok<*NASGU>;
            close all
            bdclose all
        end

        % Test for the PlotInertiaConstantEffects MATLAB function

        function GFMRunPlotInertiaConstantEffect(~)
            mdl = "GridFormingConverter";
            load_system(mdl)
            % Configure for default test scenario
            % Select the active power control method
            testCondition.activePowerMethod = 'Virtual Synchronous Machine';
            % Select the fault ride-through method
            testCondition.currentLimitMethod = 'Virtual Impedance';
            % Select the grid SCR value
            testCondition.SCR = 2.5;
            % Select the grid X/R ratio
            testCondition.XbyR = 5;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in active power reference';
            inertiaConstantArray = [0.1 0.4 1 3];
            % Calling the plot function
            outValue = PlotInertiaConstantEffects(inertiaConstantArray, testCondition,1);
            close all
            bdclose all
        end

        % Test for the GFMRunPlotFaultCurrentVoltageEffects MATLAB function

        function GFMRunPlotFaultCurrentVoltageEffects(~)
            close all
            bdclose all
            mdl = "GridFormingConverter";
            load_system(mdl)
            % Configure for default test scenario
            % Select the active power control method
            testCondition.activePowerMethod = 'Virtual Synchronous Machine';
            % Select the fault ride-through method
            testCondition.currentLimitMethod = 'Virtual Impedance';
            % Select the grid SCR value
            testCondition.SCR = 2.5;
            % Select the grid X/R ratio
            testCondition.XbyR = 5;

            % Select the operating scenarios
            testCondition.testCondition = 'Permanent three-phase fault';
            % Fault impedance array
            faultImpedanceArray = [0.05 0.1 0.25 0.4]; % Three phase fault impedance
            % Calling the plot function
            outValue = PlotFaultCurrentVoltageEffects(faultImpedanceArray, testCondition,1);
            close all
            bdclose all
        end

        % Test for the GFMRunPlotDampingEffects MATLAB function
        function GFMRunPlotDampingEffects(~)
            mdl = "GridFormingConverter";
            load_system(mdl)
            % Configure for default test scenario
            % Select the active power control method
            testCondition.activePowerMethod = 'Virtual Synchronous Machine';
            % Select the fault ride-through method
            testCondition.currentLimitMethod = 'Virtual Impedance';
            % Select the grid SCR value
            testCondition.SCR = 2.5;
            % Select the grid X/R ratio
            testCondition.XbyR = 5;

            % Select the operating scenarios
            testCondition.testCondition = 'Change in active power reference';
            dampingArray = [0.6 2 4];

            % Calling the plot function
            outValue = PlotDampingEffects(dampingArray, testCondition,1);
            close all
            bdclose all
        end

        % Test for the GFMRunPlotCompareFaultRideThroughMethod MATLAB function
        function GFMRunPlotCompareFaultRideThroughMethod(~)
            mdl = "GridFormingConverter";
            load_system(mdl)
            % Configure for default test scenario
            % Select the active power control method
            testCondition.activePowerMethod = 'Virtual Synchronous Machine';
            % Select the fault ride-through method
            testCondition.currentLimitMethod = 'Virtual Impedance';
            % Select the grid SCR value
            testCondition.SCR = 2.5;
            % Select the grid X/R ratio
            testCondition.XbyR = 5;

            % Select the operating scenario
            testCondition.testCondition = 'Permanent three-phase fault';
            % Calling the plot function
            outTable = PlotCompareFaultRideThroughMethod(testCondition, 1);
            close all
            bdclose all
        end
    end
end

% Copyright 2023 The MathWorks, Inc.
