
intvExclude = round(1);

%sessioin timeinTrial 
session.trialStart = [];
session.trialTime = [];
session.timeInTrial = [];

for i=1:length(uniqTrialNo)
session.trialStart(i) = find( session.trialNo==uniqTrialNo(i),1,'first');
end
for i=1:length(uniqTrialNo)
idx = find( session.trialNo==uniqTrialNo(i));
session.timeInTrial(idx) = session.time(idx) - session.time(session.trialStart(i));
end



% %%
% 
% [h,x,bin] = histcounts(velocity(idx), [-180:45:180]);
% figure
% boxplot( dpupil1(idx), bin )

%%
%idx = abs(dpupil1smooth)< std(dpupil1smooth)*3;

%excludeIdx = false(size(pupilResetIdx));
includeIdx = true(size(pupilResetIdx));

x = find(pupilResetIdx);
for i=1:length(x)
   idx = x(i) + [-intvExclude:intvExclude];
   idx(idx<1) = [];
   idx(idx>length(pupilResetIdx)) = [];
   includeIdx(idx) = false; 
end

%includeIdx(session.timeInTrial > 0.5) = false;
%includeIdx(session.timeInTrial > 1) = false;
% 
% 
% figure
% scatter( velocity(includeIdx), dpupil1(includeIdx) ) 
% xlabel('Velocity (deg/s)')
% ylabel('Pupil movement (a.u.)')



%%

%deg_per_pixel = 0.3141

%%
%%
%idx = session.timeInTrial <= 0.5; % & abs(session.acceleration)<50;
%idx = session.timeInTrial <= 0.5 & ~pupilResetIdx; txt='500ms, exclude fast reset';
%idx = session.timeInTrial <= 0.5 & includeIdx; txt='500ms, exclude fast reset';
%idx = session.timeInTrial <= 1.0 & includeIdx; txt='1000ms, exclude fast reset';
idx = session.timeInTrial <= 1.0 & includeIdx; txt='1000ms, exclude fast reset';

idxplot = idx & abs(session.velocity) >=22.5;
gain = -1* dpupil1 ./ velocity;
scale = 1/nanmean(gain(idxplot));


bincenters = -180:45:180;
binedges = [-(180+22.5) : 45 : (180+22.5)] ;
[h,x,bin] = histcounts(velocity(idxplot), binedges);
%figure
clear G
for i=1:length(h)
    ix = find(idxplot);
    idxBin = ix(bin==i); 
    
    p = dpupil1(idxBin) * scale;
    
    P.mean(i) = nanmean(p); 
    P.std(i)  = nanstd(p);
    P.ste(i) = P.std(i) / sqrt(length(p));

    g = gain(idxBin) * scale;
    G.mean(i) = nanmean(g); 
    G.std(i)  = nanstd(g);
    G.ste(i) = G.std(i) / sqrt(length(g));
end



%%

manudir = localpath('manudir');

figure
set(gcf,'units','normalized','OuterPosition',[0.3,0.2,0.2,0.4])
fontSize = 14;

%%
subplot(2,1,1)
plot( velocity(idx), dpupil1(idx) * scale, 'o','Color', 0.8* [1,1,1], 'MarkerSize', 4 )
hold all
x = mean( velocity(idx) ); 
y = dpupil1(idx) * scale ;

plot(x, y, 'o','Color', 0.8* [1,1,1], 'MarkerSize', 4 )
set(gca,'XTick',[-180:45:180])
xlabel('Velocity (deg/s)')
ylabel('Pupil movement (a.u.)')
set(gca,'FontSize',fontSize)
%ylim( [-1,+1]*max(abs(ylim)) )
ylim( [-1,+1]* 300 )

box off
%title(txt)
hold all
errorbar( bincenters, P.mean, P.ste, 'Color','k')
%savedir = sprintf('%s/figures/tmp/%s-pupil/',manudir,datestr(now,'yyyyddmm'));
%mkdir(savedir)
%savename = sprintf('%s/%s_pupil_velocity_vs_velocity.png', savedir,session.sessionID);
%saveas(gcf,savename)
%fprintf(1,'Saved to %s\n',savename)

%%


subplot(2,1,2)
plot( velocity(idxplot), gain(idxplot) * scale, 'o','Color', 0.8* [1,1,1], 'MarkerSize', 4)
set(gca,'XTick',[-180:45:180])
xlabel('Velocity')
ylabel('Gain (normalized)')
box off
set(gca,'FontSize',10)
ylim( [-1,+1]*max(abs(ylim)) )
hold all
errorbar( bincenters, G.mean, G.ste, 'Color','k')
%boxplot( -dpupil1(idx)  ./velocity(idx), bincenters(bin) , 'PlotStyle', 'compact','Symbol', '')
xlabel('Velocity (deg/s)')
ylabel('Gain (-)')
ylim([0,3])
box off
set(gca,'FontSize',fontSize)
clear dpupil_median
savename = sprintf('%s/%s_pupil_gain_vs_velocity_means.fig',savedir,session.sessionID);
saveas(gcf,savename,'fig')
savename = sprintf('%s/%s_pupil_gain_vs_velocity_means.pdf',savedir,session.sessionID);
saveas(gcf,savename,'pdf')
savename = sprintf('%s/%s_pupil_gain_vs_velocity_means.png',savedir,session.sessionID);
saveas(gcf,savename,'png')
fprintf(1,'Saved to %s\n',savename)


pause(0)





%uniqBin = unique(bin);
%for i=1:length(uniqBin)
%    dp = dpupil1(idx);
%    dpupil_median(i) = nanmedian( dp(bin==uniqBin(i)) );
%end
%set(gca,'FontSize',10)
%ylim([0,1])

% 
% figure
% gain = -dpupil1 * deg_per_pixel ./ (velocity);
% %gain = gain./nanmedian(gain);
% boxplot( gain(idx),bincenters(bin) , 'PlotStyle', 'compact','Symbol', '')
% xlabel('Velocity (deg/s)')
% ylabel('Gain')
% clear gain_median
% uniqBin = unique(bin);
% for i=1:length(uniqBin)
%     g = gain(idx) ;
%     gain_median(i) = nanmean( g(bin==uniqBin(i)) );
% end
% %ylim([0,10])
% set(gca,'FontSize',10)
% 
% 
% %figure
% %plot([-180:45:180], dpupil_median,'-x')
% %ylim([-1,1] * max(abs(ylim)))
% %xlabel('Velocity (deg/s)')
% %ylabel('Pupil movement (a.u.)')
% 
% %saveas(gcf,'../tmp/pupilVelo')

