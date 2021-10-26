function sDataMeta = session_meta(sData)

sDataMeta = sData;
%sDataMeta.spikemat = [];
%sDataMeta.dff = [];
%sDataMeta.roisignals = [];
%sDataMeta.deconvolved = [];

fields = {'spikemat','dff','roisignals','deconvolved','imgInfo'};
for f = 1:length(fields)
    sDataMeta.(fields{f}) = []; 
end

fields = {'time','trialNo','frameMovement','stagePositions','anglesRW','pupilArea','pupilCenter','bodyMovement',...
        'lickResponses','velocity','acceleration'};
for f = 1:length(fields)
    if isfield(sDataMeta,fields{f}) 
        x = sDataMeta.(fields{f});
        sDataMeta.(fields{f}) = single(x) ;
    else
        sDataMeta.(fields{f}) = [] ;    
    end
end