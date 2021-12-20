function [ freqPupilResetMax, freqPupilResetPlus, freqPupilResetMinus] = pupilResets_to_freq( pupilResetIdx, dpupilSmooth , windowSize, dt)

fprintf(1,'use freqPupilResetMax\n')

% Mark resets
dpupilReset = zeros(size(dpupilSmooth));
dpupilReset(pupilResetIdx) = sign(dpupilSmooth(pupilResetIdx));

% Turn resets into a velocity by smoothing
%smoothfactor = 133; %66;
%freqPupilReset = smooth(dpupilReset,windowSize)';
b = (1/windowSize)*ones(1,windowSize);
a = 1;
freqPupilReset = filter(b,a,dpupilReset) / dt;



% freq CW CCW
dpupilResetPlus  = zeros(size(dpupilSmooth));
dpupilResetMinus = zeros(size(dpupilSmooth));
dpupilResetPlus(pupilResetIdx & dpupilSmooth>0 )  = +1;
dpupilResetMinus(pupilResetIdx & dpupilSmooth<0 ) = -1;
% Turn resets into a velocity by smoothing
%smoothfactor = 133; %66;
%freqPupilReset = smooth(dpupilReset,windowSize)';
b = (1/windowSize)*ones(1,windowSize);
a = 1;
freqPupilResetPlus  = filter(b,a,dpupilResetPlus) / dt;
freqPupilResetMinus = filter(b,a,dpupilResetMinus) / dt;

A = [freqPupilResetPlus ; freqPupilResetMinus];
[freqPupilResetMax,idMax] = max( abs(A),[],1 );
