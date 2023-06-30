function testOutcome = FindTestOutCome(Pmeas, Vgd, freq)
    % Copyright 2023 The MathWorks, Inc.

    if max([abs(Pmeas(end)-Pmeas(round(0.9*end))) abs(Pmeas(end)-Pmeas(round(0.95*end))) abs(Pmeas(round(0.95*end))-Pmeas(round(0.9*end)))])<2e-2
        testFlag(1) = 1;
    else
        testFlag(1) = 0;
    end
    if max([abs(Vgd(end)-Vgd(round(0.9*end))) abs(Vgd(end)-Vgd(round(0.95*end))) abs(Vgd(round(0.95*end))-Vgd(round(0.9*end)))])<2e-2
        testFlag(2) = 1;
    else
        testFlag(2) = 0;
    end
    
    if max([abs(freq(end)-freq(round(0.9*end))) abs(freq(end)-freq(round(0.95*end))) abs(freq(round(0.95*end))-freq(round(0.9*end)))])<2e-2
        testFlag(3) = 1;
    else
        testFlag(3) = 0;
    end
    
    if min(testFlag(1:3))>0
        stablity = 'Stable';
    else
        stablity = 'Unstable';
    end
    testOutcome = stablity;
end

