function outValue = PlotFaultCurrentVoltageEffects(faultImpedanceArray, testCondition,plotFlag)
    % Copyright 2023 The MathWorks, Inc.

    testConditionSelected = testCondition; % Storing the selected test condition
    
    % Setting up the grid forming converter parameters
    run("GridFormingConverterInputParameters.mlx");
    
    % Applying the original test condition
    testCondition.activePowerMethod = testConditionSelected.activePowerMethod;
    testCondition.currentLimitMethod = testConditionSelected.currentLimitMethod;
    testCondition.testCondition = testConditionSelected.testCondition;
    testCondition.XbyR = testConditionSelected.XbyR;
    testCondition.SCR = testConditionSelected.SCR;
    
    % Defining function output variable
    outValue = struct('P',0,'Q',0,'F',0,'V',0,'I',0);
    legendFault = cell(1,length(faultImpedanceArray));
    run('GridFormingConverterTestCondition.mlx');
    
    if plotFlag>0
        figure('Name', 'GridFormingConverterThreePhaseFault');
        set(gcf, 'Position',  [400, 300, 800, 700]);
        axisDatasetting(gcf);
    end
    
    % Defining simulink simulation input
    simIn = Simulink.SimulationInput('GridFormingConverter');

    for i = 1:length(faultImpedanceArray)
    
        testCondition.faultResistance = faultImpedanceArray(i); % pu

        % Setting up the simulation test condition
        simIn = setVariable(simIn,'testCondition',testCondition);
        
        % Running the simulation
        outData = sim(simIn);
    
        % Recording the output
        timeFaultSignal = outData.LogsoutGridFormingConverter.get('faultSignal').Values.Time; % pu
        faultSignal = reshape(outData.LogsoutGridFormingConverter.get('faultSignal').Values.Data,[1,length(timeFaultSignal)]); % pu
    
        timeArrayPmeas = outData.LogsoutGridFormingConverter.get('Pmeas').Values.Time; % s
        Pmeas = reshape(outData.LogsoutGridFormingConverter.get('Pmeas').Values.Data,[1,length(timeArrayPmeas)]); % pu
    
        timeArrayQmeas = outData.LogsoutGridFormingConverter.get('Qmeas').Values.Time; % s
        Qmeas = reshape(outData.LogsoutGridFormingConverter.get('Qmeas').Values.Data,[1,length(timeArrayQmeas)]); % pu
    
        timeArrayIgd = outData.LogsoutGridFormingConverter.get('Igd').Values.Time; % s
        Igd = reshape(outData.LogsoutGridFormingConverter.get('Igd').Values.Data,[1,length(timeArrayIgd)]); % pu
    
        timeArrayIgq = outData.LogsoutGridFormingConverter.get('Igq').Values.Time; % s
        Igq = reshape(outData.LogsoutGridFormingConverter.get('Igq').Values.Data,[1,length(timeArrayIgq)]); % pu
    
        timeArrayVgd = outData.LogsoutGridFormingConverter.get('Vgd').Values.Time; % s
        Vgd = reshape(outData.LogsoutGridFormingConverter.get('Vgd').Values.Data,[1,length(timeArrayVgd)]); % pu
    
        timeArrayVgq = outData.LogsoutGridFormingConverter.get('Vgq').Values.Time; % s
        Vgq = reshape(outData.LogsoutGridFormingConverter.get('Vgq').Values.Data,[1,length(timeArrayVgq)]); % pu
    
        Is = sqrt(Igd.*Igd+Igq.*Igq);
        Vs = sqrt(Vgd.*Vgd+Vgq.*Vgq);
        outValue(i).P = Pmeas(end);
        outValue(i).Q = Qmeas(end);
        outValue(i).V = Vgd(end);
        outValue(i).I = Is(end);
        outValue(i).Igd = Igd(end);
        outValue(i).Igq = -1*Igq(end);
        outValue(i).StdMin = -1.4578*outValue(i).V+1;
    
        if plotFlag>0
            % Plotting the result
    
            subplot(3,2,1:2)
            plot(timeFaultSignal,faultSignal, 'LineWidth',2);
            hold all
    
            subplot(3,2,3)
            plot(timeArrayVgd,Vs,'LineWidth',2);
            hold all
    
            subplot(3,2,4)
            plot(timeArrayIgd,Is,'LineWidth',2);
            hold all
    
            subplot(3,2,5)
            hold all
            plot(timeArrayPmeas,Pmeas, 'LineWidth',2);
            hold all
            legendFault{i} = sprintf('R_{fault} = %0.2f Ohm',faultImpedanceArray(i));
    
            subplot(3,2,6)
            plot(timeArrayQmeas,Qmeas, 'LineWidth',2);
            hold all
        end
    end
    
    % Storing the output data into the table
    FaultResistanceInOhm = faultImpedanceArray'; ActivePower = [outValue.P]'; ReactivePower = [outValue.Q]';
    Voltage = [outValue.V]';
    MinimumStandardCurrent  =[outValue.StdMin]'; MeasuredCurrentIs = [outValue.I]' ;
    outputTable=table(FaultResistanceInOhm,ActivePower,ReactivePower,Voltage,MinimumStandardCurrent,MeasuredCurrentIs);
    
    % Comparing with standard
    if plotFlag>0
        hold all
        subplot(3,2,1:2)
        xlim([disturbanceTime*0.8 simulationTime]);
        grid on
        legend(legendFault);
        hold all
    
        subplot(3,2,3)
        xlim([disturbanceTime*0.8 simulationTime]);
        grid on
        hold all
    
        subplot(3,2,4)
        xlim([disturbanceTime*0.8 simulationTime]);
        grid on
        hold all
    
        subplot(3,2,5)
        xlim([disturbanceTime*0.8 simulationTime]);
        grid on
        hold all
    
        subplot(3,2,6)
        xlim([disturbanceTime*0.8 simulationTime]);
        grid on
        hold all
    
        if min(MeasuredCurrentIs >= MinimumStandardCurrent)>0
            sgtitle(['Three-Phase Fault Measurement' newline 'Fault Current Injection is Within the Grid Code Limit'],'FontSize',13,'Color',[0,100,0]/256);
        else
            sgtitle(['Three-Phase Fault Measurement' newline 'Fault Current Injection is Outside the Grid Code Limit'],'FontSize',13,'Color',[139,0,0]/256);
        end
        figure('Name', 'GridFormingConverterThreePhaseFaultStandard');
        set(gcf, 'Position',  [400, 300, 800, 700]);
    
        plotCurrentLimitStandard(outValue);
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
    ylabel('Fault Trigger)');
    title('Fault Trigger Signal');
    box on
    grid on
    hold all
    
    subplot(3,2,3)
    grid on
    xlabel('time (s)');
    ylabel('Voltage (pu)');
    title('GFM Output Voltage Magnitude')
    box on
    hold all
    
    subplot(3,2,4)
    grid on
    xlabel('time (s)');
    ylabel('Current (pu)');
    title('GFM Output Current Magnitude')
    box on
    hold all
    
    subplot(3,2,5)
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Active Power')
    box on
    hold all
    
    subplot(3,2,6)
    grid on
    xlabel('time (s)');
    ylabel('Power (pu)');
    title('GFM Output Reactive Power')
    box on
    hold all
end

% Function to visualize the result with standard values
function plotCurrentLimitStandard(outValue)
    standardVoltage = 0:0.1:0.9;
    standardCurrent =-1.4578*standardVoltage+1;
    standardCurrent(end+1) = 1.8;
    standardVoltage(end+1) = 0;
    xlim([-0.4 1.8]);
    plot(standardCurrent,standardVoltage,'LineWidth',3);
    hold all
    a=area(standardCurrent,standardVoltage,1);
    a.FaceColor = [0.5625    0.9297    0.5625];
    hold all
    plot([outValue.I],[outValue.V],'o','LineWidth',3);
    hold all
    plot([outValue.Igq],[outValue.V],'o','LineWidth',3);
    
    legend('Standard Line','Standard Operating Area','Simulated Peak Current (I_{s})','Simulated Peak Quadrature Axis Current (I_{q})');
    legend('Location','southwest');
    grid on
    box on
    
    ylabel('GFM Output Voltage (pu)');
    xlabel('GFM Output Current (pu)');
    MinimumStandardCurrent  =[outValue.StdMin]'; MeasuredCurrentIs = [outValue.I]' ;
    if min(MeasuredCurrentIs >= MinimumStandardCurrent)>0
        title(['GC0137 Reactive Current Injection Standard at Low Voltage' newline 'Fault Current Injection is Within the Grid Code Limit'],'FontSize',13,'Color',[0,100,0]/256);
    else
        title(['GC0137 Reactive Current Injection Standard at Low Voltage' newline 'Fault Current Injection is Outside the Grid Code Limit'],'FontSize',13,'Color',[139,0,0]/256);
    end
    hold all
end

