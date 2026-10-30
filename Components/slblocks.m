function blkStruct = slblocks
%SLBLOCKS Register the converter component library with the Library Browser.
%   blkStruct = slblocks returns the Library Browser entry for ConverterLibrary,
%   under the display name Simscape Power Converter Components.

% Copyright 2026 The MathWorks, Inc.

Browser.Library = "ConverterLibrary";
Browser.Name = "Simscape Power Converter Components";
blkStruct.Browser = Browser;
end