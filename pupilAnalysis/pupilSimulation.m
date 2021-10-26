function [simSessionIDs, simData] = pupilSimulation(regionRSC)

dropboxdir = localpath('dropbox-aree');
dropboxdir = replace( dropboxdir, '\','/');

if regionRSC 
    dirname = sprintf('%s/Other Peoples Data/eivind', dropboxdir);
    files = dir(sprintf('%s/2020_06_08*.mat',dirname));
else
    dirname = sprintf('%s/Other Peoples Data/eivind/Not RSC', dropboxdir);
    files = dir(sprintf('%s/2020_06_09*.mat',dirname))
end

%'2020_06_08_m0116-20190709-1114-002_simulatedData_pupil_resets.mat'

clear simData simSessionIDs
for i = 1:length(files)
    fullfile = sprintf('%s/%s', dirname,files(i).name);
    simSessionIDs{i,1} = files(i).name(12:34);
    simData{i,1} = load(fullfile);
end