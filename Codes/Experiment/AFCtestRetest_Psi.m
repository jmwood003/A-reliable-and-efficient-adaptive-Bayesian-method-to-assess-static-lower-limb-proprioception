%% Set up subject
close all; clear all; clc; 

%Subject ID
SID = 'PSItest_20b'; 
%Set test limb (moving limb)
TestLimb = 'Left';
%Number of trials
Ntrials = 50;

%Set gamma and labmda
gamma = 0.02; lambda = 0.02;

%Set paths and directories 
addpath('C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Codes\Experiment');
addpath('C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Codes\Experiment\Functions');
Livedir = 'C:\Program Files\Vicon\DataStream SDK\Win64\MATLAB';
datadir = 'C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Data\TestRetest_PSI';
backupdir = 'C:\Users\Lab Account\University of Delaware - o365\Team-CHS-PT-Morton Lab - Split-Belt Recal - Jonathan - Split-Belt Recal - Jonathan\Data\Backup';
cd(datadir);

%% Psi test Orientation
cd(Livedir);
ViconTMConnect_Psi_orientation(TestLimb)

%% Baseline difference calculation
clc;

tic
%Do this right before the AFC trial
cd(Livedir);
S = 1;
%Calculate baseline difference
[BslDiff,~,~] = ViconTMConnect_StaticCal(S,TestLimb);
offset = round(BslDiff);

%Ranges for the stimulus, alpha and beta parameters
X = -100:10:100;
X = X - offset;
alpha_range = linspace(-100,100,201)-offset;
beta_range = linspace(0.001,100,201);

%Create lookup table
[pr_left_x, pr_right_x] = psi_lookupT(X, alpha_range, beta_range);

disp(['Trial Complete, baseline bias = ', num2str(BslDiff)]);

toc

%% AFC task

%Time variables
Date = datetime('now');
PhaseStart = datestr(Date);
timevar = tic;

%Run task
cd(Livedir);
[alpha_EV, beta_EV, AllStarts, AllStims, AllResponses, BinaryResponses] = ...
    ViconTMConnect_PSI(Ntrials, X, alpha_range, beta_range, ...
    pr_left_x, pr_right_x, TestLimb, lambda, gamma, offset);

elapsedTime = toc(timevar);

%Plot the estimated psi and the actual data
psi_est = gamma + (1-lambda-gamma) * normcdf(X,alpha_EV(end)+round(BslDiff),beta_EV(end));
C = lines(5);
dataC = C(1,:);
psiC = C(2,:);

%Create new vectors for repeated stimuli 
Unique_stims = unique(AllStims+round(BslDiff));
Nstims = []; Kleft = [];
for s = 1:length(Unique_stims)
  stim_idx = find(Unique_stims(s)==AllStims+round(BslDiff));
  Nstims(s) = length(stim_idx);
  Kleft(s) = sum(BinaryResponses(stim_idx));
end

t_x = 1:length(AllStims);
Corrected_stims = AllStims+round(BslDiff); 
%Plot
PSIfig = figure; subplot(2,4,1:2); hold on
plot(t_x,alpha_EV,'o-','linewidth',2);
plot(t_x(BinaryResponses==1), Corrected_stims(BinaryResponses==1),'ko','MarkerFaceColor','k');
plot(t_x(BinaryResponses==0), Corrected_stims(BinaryResponses==0),'ko','MarkerFaceColor','none');
plot(1:length(AllStims),AllStims+round(BslDiff),'k-','linewidth',1.5);
plot(1:length(alpha_EV),zeros(1,length(alpha_EV)),'k--','linewidth',2);
xlabel('Trial'); ylabel('Stimiulus');
legend(['\alpha estimate = ' num2str(round(alpha_EV(end),2))],'Stimulus (r = "left")','Stimulus (r = "right")');
legend('boxoff');
ylim([-100 100]);
title([strrep(SID,'_',' ') ' - trial by trial']);
set(gca,'FontName','Ariel','FontSize',15);

subplot(2,4,5:6); hold on
plot(1:length(beta_EV),beta_EV,'ro-','linewidth',2);
plot(1:length(beta_EV),zeros(1,length(beta_EV)),'k--','linewidth',2);
xlabel('Trial'); ylabel('Stimiulus');
legend(['\beta = ' num2str(round(beta_EV(end),2))]);
legend('boxoff');
ylim([0 100]);
set(gca,'FontName','Ariel','FontSize',15);

subplot(2,4,[3 4 7 8]); hold on
plot(X,psi_est,'Color',psiC,'linewidth',2);
plot(Unique_stims,(Kleft./Nstims),'o', 'MarkerEdgeColor',dataC, 'MarkerFaceColor',dataC);
legend('Estimated Psi','Responses','location','northwest'); legend('boxoff');
ylabel('p_{left more foreward}'); xlabel('Stimulus')
title('Estimate');    
xlim([-100 100]); ylim([0 1]);
set(gca,'FontName','Ariel','FontSize',15);

%Save data
cd(datadir);
save([SID '_data'], 'alpha_EV', 'beta_EV', 'AllStarts', 'AllStims', 'AllResponses', 'BinaryResponses', 'elapsedTime', 'PhaseStart', 'BslDiff');
saveas(PSIfig,[SID '_fig.fig']);
cd(backupdir);
save([SID '_data'], 'alpha_EV', 'beta_EV', 'AllStarts', 'AllStims', 'AllResponses', 'BinaryResponses', 'elapsedTime', 'PhaseStart', 'BslDiff');

