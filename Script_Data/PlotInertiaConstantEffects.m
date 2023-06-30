function outValue = PlotInertiaConstantEffects(inertiaConstantArray, testCondition,plotFlag)
    
    % Copyright 2023 The MathWorks, Inc.
    testConditionSelected = testCondition; % Storing the selected test condition
    
    % Input the grid-forming converter parameters
    run("GridFormingConverterInputParameters.mlx");
    
    
    % Applying the original test condition
    testCondition.activePowerMethod = testConditionSelected.activePowerMethod;
    testCondition.currentLimitMethod = testConditionSelected.currentLimitMethod;
    testCondition.testCondition = testConditionSelected.testCondition;
    testCondition.XbyR = testConditionSelected.XbyR;
    testCondition.SCR = testConditionSelected.SCR;
    
    % Input the test condition data
    run('GridFormingConverterTestCondition.mlx');
    
    
    % Defining function output variable
    outValue = struct('P',0,'Q',0,'F',0,'V',0,'I',0,'testOutcome','Initialization');
    legendPower = cell(1,length(inertiaConstantArray)+1);
    legendPlot = cell(1,length(inertiaConstantArray));
    
    if plotFlag>0
        figure('Name', 'GridFormingConverterIntertiaEffect');
        set(gcf, 'Position',  [400, 300, 800, 700]);
        axisDatasetting(gcf);
    end
    
    % Defining Simulink simulation input
    simIn = Simulink.SimulationInput('GridFormingConverter');

    for i = 1:length(inertiaConstantArray)
        gridInverter.vsm.inertiaConstant = inertiaConstantArray(i); % pu

        % Setting up the simulation test condition using Simulink simulation input
        simIn = setVariable(simIn,'testCondition',testCondition);
        simIn = setVariable(simIn,'gridInverter',gridInverter);

        % Running the simulation
        outData = sim(simIn);
    
        % Recording the output
        timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
        Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu
    
        timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
        Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu
    
        timeArrayPref = outData.LogsoutGridFormingConverter.get('Pref').Values.Time; % s
        Pref = reshape(outData.LogsoutGridFormingConverter.get('Pref').Values.Data,[1,length(timeArrayPref)]); % pu
    
        timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
        Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu
    
        timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
        Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu
    
        timeArrayFreq = outData.LogsoutGridFormingConverter.get('Freq').Values.Time; % s
        freq = reshape(outData.LogsoutGridFormingConverter.get('Freq').Values.Data,[1,length(timeArrayFreq)]);  % Hz
    
        timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
        Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu
    
        timeArrayVgq = outData.LogsoutGridFormingConverter.get('Vgq').Values.Time; % s
        Vgq = reshape(outData.LogsoutGridFormingConverter.get('Vgq').Values.Data,[1,length(timeArrayVgq)]); % pu
    
        if strcmp(testCondition.activePowerMethod, 'Virtual Synchronous Machine')
            timeArrayPinertia = outData.LogsoutGridFormingConverter.get('Pinertia').Values.Time; % s
            Pinertia = reshape(outData.LogsoutGridFormingConverter.get('Pinertia').Values.Data,[1,length(timeArrayPinertia)]); % pu
        else
            timeArrayPinertia = timeArrayPref; % s
            Pinertia = zeros(1,length(timeArrayPref));
        end
    
    
        Is = sqrt(Igd.*Igd+Igq.*Igq);
        Vs = sqrt(Vgd.*Vgd+Vgq.*Vgq);
        outValue(i).P = Pmeas(end);
        outValue(i).Q = Qmeas(end);
        outValue(i).F = freq(end);
        outValue(i).V = Vgd(end);
        outValue(i).I = Is(end);
    
        if plotFlag>0
            % Plotting the result
    
            subplot(3,2,1:2)
            if i <2
                plot(timeArrayPref,Pref, 'LineWidth',2);
                legendPower{1} = sprintf('P_{ref}');
    
            end
            hold all
            plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
            hold all
            legendPower{i+1} = sprintf('P_{meas} at inertia = %0.2f pu',inertiaConstantArray(i));
    
            subplot(3,2,3)
            plot(timeArrayPinertia,Pinertia, 'LineWidth',2);
            hold all
            legendPlot{i} = sprintf('inertia = %0.2f pu',inertiaConstantArray(i));
    
            subplot(3,2,4)
            plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
            hold all
    
            subplot(3,2,5)
            plot(timeArrayVgd,Vs,'LineWidth',2);
            hold all
    
            subplot(3,2,6)
            plot(timeArrayIgd,Is,'LineWidth',2);
            hold all
        end
    end
    
    Inertia = inertiaConstantArray'; ActivePower = [outValue.P]'; ReactivePower = [outValue.Q]';
    Voltage = [outValue.V]'; Current = [outValue.I]'; FrequencyHz = [outValue.F]';
    outputTable=table(Inertia,ActivePower,ReactivePower,Voltage,Current,FrequencyHz);
    
    if plotFlag >0
        hold all
        subplot(3,2,1:2)
        grid on
        xlim([disturbanceTime*0.8 simulationTime]);
        legend(legendPower);
        legend('Location','southeast');
        hold all
    
        subplot(3,2,3)
        xlim([disturbanceTime*0.8 simulationTime]);
        hold all
        legend(legendPlot);
        legend('Location','southeast');
    
        subplot(3,2,4)
        xlim([disturbanceTime*0.8 simulationTime]);
        legend(legendPlot);
        legend('Location','southeast');
        hold all
    
    
        subplot(3,2,5)
        xlim([disturbanceTime*0.8 simulationTime]);
        legend(legendPlot);
        legend('Location','southeast');
        hold all
    
        subplot(3,2,6)
        xlim([disturbanceTime*0.8 simulationTime]);
        legend(legendPlot);
        legend('Location','southeast');
        hold all
    
        sgtitle('Effects of Virtual Synchronous Machine Inertia Constant','FontSize',13,'Color',[0,100,0]/256);
    end
    disp('Steady State Grid-Forming Converter Output Measurement in pu');
    disp(outputTable);
end

function axisDatasetting(gcf)
    figure(gcf);
    hold all
    subplot(3,2,1:2)
    
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power ')
    box on
    hold all
    
    subplot(3,2,3)
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Inertia Power')
    box on
    hold all
    
    subplot(3,2,4)
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power ')
    box on
    hold all
    
    subplot(3,2,5)
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage Magnitude')
    box on
    hold all
    
    subplot(3,2,6)
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current Magnitude')
    box on
    hold all

end
    
