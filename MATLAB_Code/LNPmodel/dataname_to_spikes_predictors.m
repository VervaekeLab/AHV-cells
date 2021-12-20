
function [spikes, predictors, trialNo, session , idxTime, infoPredictors, uniquePredictors, uid ] = dataname_to_spikes_predictors( data, setup )

% setup empty argument out
spikes         = [];
predictors     = [];
trialNo        = [];
session        = [];
idxTime        = [];
infoPredictors = [];

% from dataname to [session, rotate, hd]
[session,rotate,~]=read_data_new(data,'verbose',true,'protocol',setup.protocol,...
    'spikesMethod',setup.spikesMethod);
fprintf(1,'%s...', session.sessionID),
if (session.passQC==0)
    fprintf(1,'Skipping - no QC.\n')
    return
end

% Head direction
hd = head_direction(session,'nbins',setup.nbins,'frame',setup.hdframe,'hdcircular',setup.hdcircular);

% Trim Session
session = trimSession(session,setup);

%% Prepare data
[spikesFull, predictorsFull, idxTime, infoPredictors, uniquePredictors] = prepare_data_lnp_general(session,rotate,hd,setup);

if isempty(idxTime) || (islogical(idxTime) && sum(idxTime)==0)
    warning('Skipping - no idxTime.\n')
    return
end

%uid0 = {session.roiArray.uid}';
%sessionMeta = session_meta(session);

% SELECT TIME
for i=1:length(predictorsFull)
    predictors{i} = predictorsFull{i}(idxTime);
end
spikes = spikesFull(idxTime,:);
trialNo = uint8(session.trialNo(idxTime));



uid = {session.roiArray.uid}';


end





%%

function session = trimSession(session,setup)

% Trim Neurons
if ~isempty(setup.fixedN)
    
    % Check if data is good to trim
    if setup.fixedN > session.nRois
        fprintf(1,'too few N, skip.\n')
        session.passQC = 0;
        return
    end
    
    % Fix random number generator seed for comparable testing
    randomizeRoi = 0;
    if randomizeRoi
        idxRoi = 1:setup.fixedN;
    else
        rng(1)
        idxRoi = sort( randperm(session.nRois,setup.fixedN) ,'ascend');
    end
    session.idxRoiOriginal = idxRoi;
    session.roiArray       = session.roiArray(idxRoi);
    session.nRois          = setup.fixedN;
    session.roisignals(2)  = structfun(@(x)x(:,idxRoi,:),session.roisignals(2),'UniformOutput',false);
    session.spikemat       = session.spikemat(idxRoi,:);
    session.dff            = session.dff(idxRoi,:);
    
    fprintf(1,'%s trimmed to %d Rois\n',session.sessionID,session.nRois)
    
end

% Trim Trials
if ~isempty(setup.fixedNTrial)
    nTrials = length(session.trialSummary.trialNo);
    if setup.fixedNTrial > session.nRois
        fprintf(1,'too few Trials, skip.\n')
        session.passQC = 0;
        return
    end
    trialNo = session.trialSummary.trialNo;
    
    % Trim trial sessions
    idxTrial = trialNo(1 : setup.fixedNTrial);
    session.trialSummary = structfun(@(x)trimTrialField(x,idxTrial),session.trialSummary,'UniformOutput',false);
    
    % Trim time points
    idxTime = find( ismember( session.trialNo, idxTrial) );
    fieldsAll = fields(session);
    length2 = structfun(@(x)size(x,2),session) == session.nSamples;
    fieldsToTrim = fieldsAll(length2);
    % fieldsToTrim = {'time','trialNo','frameMovement','stagePositions','anglesRW','rotating','wallPositions','wallAnglesRW','wallRotating',...
    %     'lickResponses','waterRewards','airpuff','spikemat','dff','lightsOn','velocity','acceleration'};
    for field = fieldsToTrim(:)'
        if isfield(session,field{1})
            tmp = session.(field{1});
            if ~isempty(tmp)
                session.(field{1}) = tmp(:,idxTime);
            end
        end
    end
    session.nSamples = length(idxTime);
    session.roisignals(2)  = structfun(@(x)x(:,:,idxTime),session.roisignals(2),'UniformOutput',false);
    
    
    fprintf(1,'%s trimmed to %d trials (%d time bins)\n',...
        session.sessionID,length(session.trialSummary.trialNo),session.nSamples)
end

end



%%


function x = trimTrialField(x,idxTrial)

if isnumeric(x) | islogical(x)
    x = x(idxTrial,:);
end


%function x = trimSessionField(x,idxTime)
%
%if isnumeric(x) | islogical(x)
%    x = x(:,idxTime);
%end

end





