function freqPupilReset = pupilResets_to_freq( pupilResetIdx, dpupilSmooth , windowSize, dt)


% Mark resets
dpupilReset = zeros(size(dpupilSmooth));
dpupilReset(pupilResetIdx) = sign(dpupilSmooth(pupilResetIdx));

% Turn resets into a velocity by smoothing
%smoothfactor = 133; %66;
%freqPupilReset = smooth(dpupilReset,windowSize)';
b = (1/windowSize)*ones(1,windowSize);
a = 1;
freqPupilReset = filter(b,a,dpupilReset) / dt;



