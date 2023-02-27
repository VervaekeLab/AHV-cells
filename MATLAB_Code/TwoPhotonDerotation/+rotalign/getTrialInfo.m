function trialInfo = getTrialInfo(angularFramePosition)
%getTrialInfo Initialize trial info determined by angular frame positions
%
%   USAGE:                  
%       trialInfo = getTrialInfo(angularFramePosition)
%
%   INPUT:
%
%   OUTPUT:
%       trialInfo (struct)


    assert( isvector(angularFramePosition), 'Angles must be a vector' )
    angularFramePosition = transpose(angularFramePosition(:)); % Need to be column

    isRotating = horzcat(0, abs(diff(angularFramePosition)) > 0.1 );
    isRotating = imdilate(isRotating, ones(1,5));

    if all(isRotating == 0)
        numFrames = numel(angularFramePosition);

        batchSize = 2000;
        trialStartInd = 1:batchSize:numFrames;
        trialStopInd = cat(2, trialStartInd(2:end)-1, numFrames);
        isTrialRotating = false(size(trialStartInd));
        statPositions = zeros(size(trialStartInd));
        
    else
        
        % Prepare order of processing. Do stationary first, and then rotations
        [statStart, statStop] = rotalign.utility.findTransitions(~isRotating);
        [rotStart, rotStop] = rotalign.utility.findTransitions(isRotating);
            
        trialStartInd = [statStart, rotStart];
        trialStopInd = [statStop, rotStop];
        
        [trialStartInd, sortInd] = sort(trialStartInd);
        trialStopInd = trialStopInd(sortInd);

        isTrialRotating = false( size(trialStartInd) );
        isTrialRotating( ismember(trialStartInd, rotStart) ) = true;

        statPositions = nan( size(trialStartInd) );
        statMiddleInd = round(mean([statStart; statStop]));
        statPositions( ismember(trialStartInd, statStart) ) = ...
            mod(round(angularFramePosition(statMiddleInd)), 360);
        
    end

    trialInfo = struct(...
        'trialNumber', num2cell( 1:numel(trialStartInd) ), ...
        'startIdx', num2cell(trialStartInd), ...
        'stopIdx', num2cell(trialStopInd), ...
        'isRotationTrial', num2cell(isTrialRotating), ...
        'stationaryPosition', num2cell(statPositions) ...
        );


     [trialInfo(:).isTrialFinished] = deal(false);
     [trialInfo(:).imageDrift] = deal([nan, nan]);
     [trialInfo(:).angularSamplingDelay] = dean(nan);
%     [trialInfo(:).rotationCenterOffset] = deal([nan, nan]); % Todo
end