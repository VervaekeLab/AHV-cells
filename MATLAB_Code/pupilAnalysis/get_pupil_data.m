function [pupil, dpupilSmooth] = get_pupil_data(session, varargin)

%% input Parser
inputP = inputParser;
addRequired(inputP, 'session')
addParameter(inputP, 'deltaT', 3) % how many intervals to get velocity
parse(inputP, session, varargin{:})
p = (inputP.Results);



% Get pupil tracking and velocity
pupil  = squeeze(session.pupilCenter(:,:,1)); pupil(pupil==0)=nan;
velocity = session.velocity;
stagePositions = session.stagePositions;
rotationLength = session.trialSummary.rotationLength;

% Normalize to a range [0,1]
if(0)
    pupil = normalize(pupil, 'range');
    pupil = pupil - nanmedian(pupil);
end

% Get velocity
%dpupil = [0, diff(pupil)];
deltap =  [ pupil((p.deltaT+1):end)-pupil(1:end-p.deltaT) ] ;
dpupil = horzcat( zeros(1,p.deltaT) , deltap / p.deltaT );

%b = (1/smoothdpupilSize)*ones(1,smoothdpupilSize);
%a = 1;
%dpupilSmooth = filter(b,a,dpupil);
%dpupilSmooth = smooth(dpupil, smoothdpupilSize)';
dpupilSmooth = (dpupil); fprintf(1,'no smoothing dpupil\n');