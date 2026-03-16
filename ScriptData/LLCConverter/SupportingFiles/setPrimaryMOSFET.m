function setPrimaryMOSFET(LLCPlantPath,options)
%   This function updates the referenced subsystem for the four primary MOSFETs
%   in the inverter stage of an LLC converter Simulink model to the specified
%   device option. Use this function to switch between MOSFET models with or
%   without thermal effects.
%
%   Inputs:
%     LLCPlantPath    String. Path to the LLC converter plant subsystem in the model.
%     options         Structure with the following optional field:
%       .DeviceOption   Char. Device model to use for the primary MOSFETs.
%                      Must be one of:
%                       - 'MOSFET (Ideal, Switching) without Thermal' (default)
%                       - 'MOSFET (Ideal, Switching) with Thermal'
%
%   Example:
%     setPrimaryMOSFET("LLCConverterModel/LLC Converter Power Circuit", ...
%                      DeviceOption="MOSFET (Ideal, Switching) with Thermal")

% Copyright 2025-2026 The MathWorks, Inc.
    arguments
    LLCPlantPath string
    options.DeviceOption (1,:) char {mustBeMember(options.DeviceOption,{'MOSFET (Ideal, Switching) without Thermal','MOSFET (Ideal, Switching) with Thermal'})} = 'MOSFET (Ideal, Switching) without Thermal';
    end
    primarySwitchChoice = options.DeviceOption;
    
    primarySwitchLoc1 = strcat(LLCPlantPath, "/Inverter/MOSFETA1");
    primarySwitchLoc2 = strcat(LLCPlantPath, "/Inverter/MOSFETA2");
    primarySwitchLoc3 = strcat(LLCPlantPath, "/Inverter/MOSFETB1");
    primarySwitchLoc4 = strcat(LLCPlantPath, "/Inverter/MOSFETB2");
    
    switch primarySwitchChoice
    case 'MOSFET (Ideal, Switching) without Thermal'
        set_param(primarySwitchLoc1,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithoutThermal');
        set_param(primarySwitchLoc2,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithoutThermal');
        set_param(primarySwitchLoc3,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithoutThermal');
        set_param(primarySwitchLoc4,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithoutThermal');
    case 'MOSFET (Ideal, Switching) with Thermal'
        set_param(primarySwitchLoc1,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithThermal');
        set_param(primarySwitchLoc2,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithThermal');
        set_param(primarySwitchLoc3,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithThermal');
        set_param(primarySwitchLoc4,"ReferencedSubsystem", 'LLCModelIdealMOSFETWithThermal');
    otherwise
        disp('Select the proper primary switch option')
    end
end