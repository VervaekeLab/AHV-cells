error('check figureS8H_psth_individual_velo')




%%¨

function [R_plus45, R_plus90, R_plus135, R_plus180, ...
    R_minus45, R_minus90, R_minus135, R_minus180, ...
    R_stat ] =  test20210824_singlevelo(protocol,tag0)

load sessionIDsPupil.mat


%%
%param = struct('trialSegment','moving','resetApart',500,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %
param = struct('trialSegment','moving','resetApart',1000,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %

param.filterVelo=[45]; param.resetDirectionAll = {'CCW'};
[R_plus45] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'plus45'], [], param)


param.filterVelo=[90]; param.resetDirectionAll = {'CCW'};
[R_plus90] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'plus90'], [], param)


param.filterVelo=[135]; param.resetDirectionAll = {'CCW'};
[R_plus135] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'plus135'], [], param)

param.filterVelo=[180]; param.resetDirectionAll = {'CCW'};
[R_plus180] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'plus180'], [], param)




%%
%param = struct('trialSegment','moving','resetApart',500,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %
param = struct('trialSegment','moving','resetApart',1000,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %

param.filterVelo=[-45]; param.resetDirectionAll = {'CW'};
[R_minus45] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'minus45'], [], param);


param.filterVelo=[-90]; param.resetDirectionAll = {'CW'};
[R_minus90] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'minus90'], [], param);


param.filterVelo=[-135]; param.resetDirectionAll = {'CW'};
[R_minus135] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'minus135'], [], param);


param.filterVelo=[-180]; param.resetDirectionAll = {'CW'};
[R_minus180] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,'minus180'], [], param);

%%

% %param = struct('trialSegment','stationaryplus','resetApart',500,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %
% param = struct('trialSegment','stationaryplus','resetApart',1000,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %
% param.filterVelo=[]; param.resetDirectionAll = {'CW','CCW'};
% [R_stat] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,''], [], param);

%param = struct('trialSegment','stationaryplusminus','resetApart',500,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %
param = struct('trialSegment','stationaryplusminus','resetApart',1000,'filterTrials', [],'noPupilResetBefore', 1000,'removeFirstPupilReset', false); %
param.filterVelo=[]; param.resetDirectionAll = {'CW','CCW'};
[R_stat] = figureS8E_psth(sessionIDsPupil, protocol, [tag0,''], [], param);


%%
if(1)
    manudir = localpath('manudir');
    savedir = sprintf('%s/figures/figureS8-pupil/%s-PSTH',manudir,datestr(now,'yyyymmdd'));
    savename = sprintf('%s/R_pupil_singlevelo',savedir);
    save(savename, 'R_plus45', 'R_plus90', 'R_plus135', 'R_plus180',...
        'R_minus45','R_minus90','R_minus135', 'R_minus180', 'R_stat')
    fprintf(1, 'Saved to %s\n',savename)
end
