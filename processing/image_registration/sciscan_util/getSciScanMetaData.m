function [ metadata ] = getSciScanMetaData( folderPath )
%getSciScanMetaData Return metadata from a SciScan recording.
%
%   META2P = getSciScanMetaData(FOLDERPATH) returns a struct with metadata, 
%   META2P, from a SciScan recording. FOLDERPATH is the path to a folder 
%   containing the imaging data recorded by SciScan.
%
%   The function can also be called without the input argument. Then a
%   browser will open and let you navigate to the recording folder
%
%   META2P contains following fields:
%
%       - microscope          :   OS1 (OsloScope1) or OS2 (OsloScope2)
%       - xpixels             :   width of image in pixels
%       - ypixels             :   height of image in pixels
%       - fps                 :   frames per second
%       - dt                  :   time interval between each frame
%       - objective           :   not necessary for now (not added)
%       - zoomFactor          :   zoomfactor during the recording
%       - zPosition           :   relative z position of objective during imaging
%       - fovSizeX            :   width of field of view in micrometer
%       - fovSizeY            :   height of field of view in micrometer
%       - umPerPxX            :   um per pixel conversion factor along x axis
%       - umPerPxY            :   um per pixel conversion factor along y axis
%       - pockelSetting       :   laser power in percent as set in SciScan
%       - nChannels           :   number of channels acquired
%       - pmtGain             :   the gain set on PMT(s) during recording. (e.g, [10, 20])
%       - channelNumbers      :   list of channels that are recorded (e.g. [2, 3])
%       - channelNames        :   list of corresponding channel names e.g. {'Ch2', 'Ch3'}
%       - channelColor        :   list of corresponding color for each channel e.g. {'green', 'red'}
%       - nFrames             :   number of frames recorded
%       - piezoActive         :   true or false
%       - piezoMode           :   Description piezo mode, either 'saw' or 'zig'
%       - piezoNumberOfPlanes :   Number of planes used by the piezo.
%       - piezoImagingRateHz  :   The volume rate in Hz (basically overall imaging rate divided by number of piezo planes).
%       - piezoVolumeDepth    :   The number of micrometer the volume imaging spans.
%
%       see also loadSciScanStack

% NOTE: channels has changed name to channelNumbers
%       nCh has changed name to nChannels


% Open file browser if folderPath is not entered
if nargin < 1
    folderPath = uigetdir();
end

% Locate the inifile within the recording folder and read file to a string
ini_file = dir(fullfile(folderPath, '20*.ini'));  % This will definitely break down in 2100. I obviously learnt nothing from Y2K
inifilepath = fullfile(folderPath, ini_file(1).name);
inistring = fileread(inifilepath);

% Determine which microscope was used
metadata.microscope = readinivar(inistring,'microscope');
if isempty(metadata.microscope) % Old recordings do not have this info	
    % Use the difference in root folder as indicator
    root_folder = readinivar(inistring,'root.path');
    if root_folder(1) == 'E'
        metadata.microscope = 'OS2';
    elseif root_folder(1) == 'D'
        metadata.microscope = 'OS1';
    else
        metadata.microscope = 'N/A';
        warning('root.path is missing. Microscope is not added to metadata');
    end
end

% Get data acquisition parameters for recording
metadata.xpixels = readinivar(inistring,'x.pixels');
metadata.ypixels = readinivar(inistring,'y.pixels');
metadata.fps = readinivar(inistring,'frames.p.sec');
metadata.dt = 1/metadata.fps;
metadata.nFrames = readinivar(inistring, 'no.of.frames.acquired');

    
% Get spatial parameters for recording
metadata.zoomFactor = readinivar(inistring,'ZOOM');
metadata.zPosition = abs(readinivar(inistring,'setZ'));
metadata.fovSizeX = abs(readinivar(inistring,'x.fov')) * 1e6;
metadata.fovSizeY = abs(readinivar(inistring,'y.fov')) * 1e6;
metadata.umPerPxX = metadata.fovSizeX / metadata.xpixels;
metadata.umPerPxY = metadata.fovSizeY / metadata.ypixels;

metadata.pockelSetting = readinivar(inistring,'Laser.Power');

% Get information about recorded channels

% The channel colors are reversed on OS1 and OS2
if metadata.microscope == 'OS1'
    colors = {'Red', 'Green', 'N/A', 'N/A'};
else
    colors = {'Green', 'Red', 'N/A', 'N/A'};
end

metadata.nChannels = 0;
metadata.pmtGain = [];
metadata.channelNumbers = [];
metadata.channelNames = {};
metadata.channelColor = {};
for ch = 1:4
    if strcmp(strtrim(readinivar(inistring, sprintf('save.ch.%d', ch))), 'TRUE')
        metadata.nChannels = metadata.nChannels + 1;
        try
            metadata.pmtGain(end+1) = readinivar(inistring, sprintf('pmt%d.gain', ch));
        catch
            metadata.pmtGain(end+1) = nan;
        end
        metadata.channelNumbers(end+1) = ch;
        metadata.channelNames{end+1} = ['Ch', num2str(ch)];
        metadata.channelColor{end+1} = colors{ch};
    end
end

% Add settings for when the piezo is used.
wasPiezoActive = strtrim(readinivar(inistring, 'piezo.active'));
if wasPiezoActive(1:4) == 'TRUE'
    metadata.piezoActive = true;
    metadata.piezoNumberOfPlanes = readinivar(inistring,'frames.per.z.cycle');
    metadata.piezoImagingRateHz = readinivar(inistring,'volume.rate.(in.Hz)');
    metadata.zDepthYm = (readinivar(inistring,'z.spacing') * ...
                         readinivar(inistring,'no.of.planes')) - readinivar(inistring,'z.spacing');
    
    % Detect if zig-zag or sawtooth mode for piezo is used
    piezoMode = readinivar(inistring,'piezo.mode');
    if (piezoMode(2:5) == 'TRUE')
        metadata.piezoMode = 'saw';
    else
        metadata.piezoMode = 'zig';
    end
    
else
    metadata.piezoActive = false;
end


end