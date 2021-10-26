function [s,rotate,fire]=read_data_new(dataname,varargin)
% Read data, convert session and spikes
%
% Input:
%   dataname     : full path filename containing session data
%   spikesMethod : choose event extraction method ('spikes', 'spikes2', 'spikes3', 'dff') 
%   experiment   : 'normal','wallrotation'
% Output:
%   s  : sessionData  with tweaks (field called s.spikemat)
%   rotate : struct of timestamp for moving/stationary/clockwise/cclockwise
%   fire   : mean firing rate for moving/stationary/clockwise/cclockwise
%
% Modified 15.05.2019 

 
p = inputParser;
addRequired(p, 'dataname' , @(x)ischar(x) || (iscell(x) && length(x)==1) )
addParameter(p, 'spikesMethod', 'spikes', @(x)ismember(x,{'spikes','spikes2','spikes3','dff','deconvolved'}) );
addParameter(p, 'protocol'    , 'normal' ); %, @(x)ismember(x,{'normal','lightsOn','lightsOff','wallRotations','dark'}))
addParameter(p, 'speedThresh' ,  22.5   , @(x)isnumeric(x))  % 50% of max speed 45
addParameter(p, 'verbose'     ,  true   , @islogical)
addParameter(p, 'intv'        ,  6      , @(x) x >0 ) %mod(x,2)==0 )
addParameter(p, 'fixedNtrial' ,  []     )
parse(p, dataname, varargin{:})
v2struct(p.Results)

if iscell(dataname) 
    dataname = dataname{1};
end

if iscell(spikesMethod) 
    spikesMethod = spikesMethod{1};
end

if verbose
    fprintf(1, 'Read data %s\n', dataname);
    fprintf(1, 'speedThresh: %.2f, spikesMethod: %s, protocol: %s\n', speedThresh, spikesMethod, protocol);
end

%% GRAB DATA

warning off
tmp = load(dataname,'sessionData');
s = tmp.sessionData;
s.dataname = dataname;
clear tmp
warning on



%% Extract spikes into s.spikemat from different formatted data  ------------

if isfield(s,'spikeVec')
    format = 0; % old format
    s.spikemat = squeeze(s.spikeVec);
    s.dff      = squeeze(s.deltaFoverFch2);
    
elseif isfield (s,'roisignals')
    format = 1; % newer format
    switch spikesMethod
        case 'spikes'
            s.spikemat = squeeze(s.roisignals(2).spikes);
        case 'spikes2'
            s.spikemat = squeeze(s.roisignals(2).spikes2);
        case 'spikes3'
            s.spikemat = squeeze(s.roisignals(2).spikes3);
        case 'dff'
            s.spikemat = squeeze(s.roisignals(2).dff);
        case 'deconvolved'
            s.spikemat = squeeze(s.roisignals(2).deconvolved);
        otherwise 
            error('asasd')
    end
    s.dff = squeeze(s.roisignals(2).dff);

else
    display('session has no ROI data')
    s.spikemat = [];
    s.dff = [];
    s.spikesMethod = [];
    rotate = []; fire = [];
    
    return
    
end
idxnan = isnan(s.spikemat);
s.spikemat(idxnan) = 0;
if isfield( s.roisignals(2), 'deconvolved')
    s.deconvolved = squeeze(s.roisignals(2).deconvolved);
else
    s.deconvolved = [];
end
s.spikesMethod = spikesMethod;



%% FIX STUFF

%% Fix number of Rois
if  ~isequal( s.nRois, length(s.roiArray), size(s.spikemat,1) ) 
    fprintf(1, '%s fixing nRois: %d, roiArray: %d, s.spikemat: %d \n', s.sessionID, s.nRois, length(s.roiArray), size(s.spikemat,1) );
    s.nRois = min([s.nRois, length(s.roiArray), size(s.spikemat,1)]);
    s.roiArray = s.roiArray(1:s.nRois);
    s.spikemat = s.spikemat(1:s.nRois,:);
end

%% Fix time 
if  ~isequal( s.nSamples, size(s.time,2), size(s.trialNo,2) , size(s.spikemat,2) ) 
    fprintf(1, '%s fixing nSamples: %d, time: %d, trialNo: %d, s.spikemat: %d \n', s.sessionID, s.nSamples, size(s.time,2), size(s.trialNo,2), size(s.spikemat,2) );
    s.nSamples = min( [s.nSamples, size(s.time,2), size(s.trialNo,2) , size(s.spikemat,2)] );
    fields = {     'time'
        'trialNo'
        'frameMovement'
        'stagePositions'
        'anglesRW'
        'rotating'
        'wallPositions'
        'wallAnglesRW'
        'wallRotating'
        'bodyMovement'
        'lickResponses'
        'waterRewards'
        'airpuff'
        'spikemat'
        'dff'
        'deconvolved' };
    for i=1:length(fields)
        if ~isfield(s, fields{i})
            fprintf(1,'sData field "%s" is missing \n',fields{i});
            s.(fields{i}) = [];
        else
            s.(fields{i})(:,s.nSamples+1:end) = [];
        end
    end
end

%% Fix Trial Summary

% trialSummary does not exist
if isempty(s.trialSummary)
    fprintf(1,'%s missing trial Summary\n',s.sessionID);
    s.trialSummary.trialNo = [];
    s.passQC = 0;
    rotate = []; fire = [];
    return
end

% Wrong number of trials
trialSummary = s.trialSummary;
lengthField = structfun(@length,trialSummary);
notChar = ~structfun(@ischar,trialSummary);
if numel(unique(lengthField(notChar)))~=1 
    fprintf(1,'Fixing trialSummary lengths.. ');
    minLengthField = min(lengthField(notChar));    
    fields = fieldnames(trialSummary);
    for k = 1:length(fields)
        tmp = trialSummary.(fields{k}) ;
        if ischar(tmp)
            trialSummary1.(fields{k}) = tmp;
        else
            if length(tmp)>minLengthField
            fprintf(1,'%s ',fields{k})
            trialSummary1.(fields{k}) = tmp(1:minLengthField) ;
            end
        end
    end
    fprintf(1,'\n')
    s.trialSummary = trialSummary1;
end

% lightsOn field does not exist
if ~isfield(s.experimentInfo,'LightsOn')
    s.experimentInfo.LightsOn = true;
end

% problematic field lightsOn
if ~isfield(s.trialSummary,'lightsOn') % create if not exist
    s.trialSummary.lightsOn = true(size(s.trialSummary.trialNo));
end
if isfield(s.trialSummary,'LightsOn') % fix naming if incorrect
    s.trialSummary.lightsOn = s.trialSummary.LightsOn;
    s.trialSummary = rmfield(s.trialSummary,'LightsOn');
end
if isempty(s.trialSummary.lightsOn) % fill with ones if empty
    s.trialSummary.lightsOn  = true(size(s.trialSummary.trialNo));
end


% DarkProbes
if s.experimentInfo.LightsOn % Dark Probes, some LightsOn some LightsOff
    uniqTrialNo = intersect( unique(s.trialNo) , unique(s.trialSummary.trialNo) );
    s.lightsOn = true(1, s.nSamples);
    for j = 1:numel(uniqTrialNo)
        idxT = s.trialNo==uniqTrialNo(j);
        s.lightsOn(idxT) = s.trialSummary.lightsOn(j);
    end
else % entire session is dark
    s.lightsOn = false(1, s.nSamples);
end



% Correct fovLocationNames
if ~isfield(s, 'fovLocationName'), s.fovLocationName = '';  end
if isempty(s.fovLocationName)
    if contains(s.sessionID,{'m0106','m0107','m0108','m0109','m0110'}), s.fovLocationName = 'RSC-manual'; end
    if contains(s.sessionID,{'m0113'}), s.fovLocationName = 'PPC-manual'; end
    if contains(s.sessionID,{'m0114'}), s.fovLocationName = 'V2-manual'; end
    if contains(s.sessionID,{'m0115'}), s.fovLocationName = 'M2-manual'; end
    if contains(s.sessionID,'m0118-20190716-1420'), s.fovLocationName = 'posterior RSC'; end
    if contains(s.sessionID,'m0118-20190713-2004'), s.fovLocationName = 'V1-manual'; end
    if contains(s.sessionID,{'m0119'}), s.fovLocationName = 'RSC-manual'; end
    if contains(s.sessionID,{'m0120-20191030','m0120-20191115','m0120-20191120'}), s.fovLocationName = 'RSC-manual'; end
end


%% CORRECT FOR PROTOCOL LIGHTS ON/OFF/WALL etc.
if ~isfield(s.trialSummary,'stageSpeed')
    s.trialSummary.stageSpeed = [];
    s.trialSummary.wallSpeed = [];
end

switch protocol
    case {'normal','lightsOn','lightsOff','Speed Modulation - Constant Distance','Speed Modulation - Dark - Constant Distance'}
        % Do nothing
    case {'wallRotations', 'Speed Modulation - Wall - Constant Distance'}
        % WALL ROTATION INVERSION!
        fprintf(1,'Read data: Wall rotations\n')
        s.stagePositions = (-1) * s.wallPositions;
        s.trialSummary.stageSpeed = (-1) * s.trialSummary.wallSpeed;
    otherwise
        error('invalid experiment type')
end


%% FILL IN BODYMOVEMENT
if ~isfield(s.trialSummary,'bodyMovement')
%     s.bodyMovement = nan(1, s.nSamples );
     s.QC_notes = 'missing bodyMovement';
end


%% QUALITY CONTROL
s.passQC = 1;
if isempty(s.roiArray)
    s.passQC = 0;
end





%% --------------------------------------------------------
%
% ADDITIONAL STUFF FOR AREE 




%% VELOCITY / ACCELERATION 

% Calculate rotation
pos = s.stagePositions(:)'; 
pos = pos(1:s.nSamples);
if isfield(s,'stagePosition')
    s=rmfield(s,'stagePosition');
end

% Calculate s.velocity
pos2 =  pos(1+intv:end); t2 = s.time(1+intv:end);
pos1 =  pos(1:end-intv); t1 = s.time(1:end-intv);
%s.velocity  = [ zeros(1,intv/2), (pos2-pos1)/intv , zeros(1,intv/2)] / s.dt ;
velo = (pos2-pos1)./ (intv * s.dt);
s.velocity = [zeros(1,intv), velo ] ;

% Calculate s.acceleration
velo2 =  s.velocity(1+intv:end); t2 = s.time(1+intv:end);
velo1 =  s.velocity(1:end-intv); t1 = s.time(1:end-intv);
%s.acceleration  = [ zeros(1,intv/2), (velo2-velo1)/intv , zeros(1,intv/2)] / s.dt ;
acc = (velo2-velo1)./ (intv * s.dt);
s.acceleration = [zeros(1,intv), acc ] ;



%% TRIM
if ~isempty(fixedNtrial)
    setup = setupClass;
    setup.fixedNTrial = fixedNtrial;
    s = trimSession(s,setup);
    fprintf(1,'trimmed to trials N = %d',fixedNtrial)
end

%% ROTATE, FIRE

[rotate, fire] = rotate_fire(s,speedThresh);
    

%% OUTPUT
fprintf(1,'stage position [%.02f %.02f], ' , min(s.stagePositions), max(s.stagePositions))
fprintf(1,'velocity [%.02f %.02f]\n', min(s.velocity),max(s.velocity)) 



%% -------------------------------------------------------


function [rotate, fire] = rotate_fire(s, speedThresh)

%% ROTATIONS


% Calculate rotation, with threshold
rotation = (abs(s.velocity)>speedThresh) .* sign(s.velocity);
%rotation = s.rotating.* sign(speed);


% identify times of rotation
rotate.speed   = s.velocity;
rotate.speedThresh = speedThresh;
rotate.clockwise   = rotation<0;  % cartesian counterclockwise decreasing angles
rotate.cclockwise  = rotation>0;
rotate.stationary = rotation==0;
rotate.moving  = rotation~=0;

% firing rate depend on rotation
fire.all       = mean(s.spikemat,2) / s.dt;
fire.stationary= mean(s.spikemat(:,rotate.stationary),2) / s.dt;
fire.moving    = mean(s.spikemat(:,rotate.moving),2) / s.dt;
fire.clockwise     = mean(s.spikemat(:,rotate.clockwise),2)  / s.dt;
fire.cclockwise    = mean(s.spikemat(:,rotate.cclockwise),2) / s.dt;


rt.fire_all = mean(s.spikemat,2);
rt.fire = [ fire.stationary, fire.moving, fire.clockwise, fire.cclockwise ];
rt.odds = rt.fire ./ repmat( rt.fire_all ,1,4 );

% plot proportion
if(0)
    figure
    subplot(4,1,1)
    [x,n]=hist(rt.odds(:,1),20);
    bar(n,x)
    legend({'stationary'})
    subplot(4,1,2)
    [x]=hist(rt.odds(:,2),n);
    bar(n,x)
    legend({'moving'})
    subplot(4,1,3)
    [x]=hist(rt.odds(:,3),n);
    bar(n,x)
    legend({'CW'})
    subplot(4,1,4)
    [x]=hist(rt.odds(:,4),n);
    bar(n,x)
    legend({'CCW'})
end












