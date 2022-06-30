%% Set up subject
close all; clear all; clc; 

%Subject ID
SID = 'PSItest_28b'; 
%Set test limb (moving limb)
TestLimb = 'Left';
%Number of trials
Ntrials = 75;

%Set paths and directories 
addpath('C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Codes\Experiment');
addpath('C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Codes\Experiment\Functions');
Livedir = 'C:\Program Files\Vicon\DataStream SDK\Win64\MATLAB';
datadir = 'C:\Users\Lab Account\Documents\GitHub\Split-Belt-AFC-Reliability\Data\TestRetest_PSI';
backupdir = 'C:\Users\Lab Account\University of Delaware - o365\Team-CHS-PT-Morton Lab - Split-Belt Recal - Jonathan - Split-Belt Recal - Jonathan\Data\Backup';
serverdir = 'C:\Users\Lab Account\University of Delaware - o365\Team-CHS-PT-Morton Lab - Split-Belt Recal - Jonathan - Split-Belt Recal - Jonathan\Data\PSI';
cd(datadir);

%Initialize subject table
T = table;
SID_cell = {};
test_cell = {};
TestLimb_cell = {};
for t = 1:Ntrials
    SID_cell{t,1} = SID(1:end-1);
    test_cell{t,1} = SID(end);
    TestLimb_cell{t,1} = TestLimb;
end
T.SID = SID_cell;
T.Test = test_cell;
T.TestLimb = TestLimb_cell;

%% Psi test Orientation

cd(Livedir);
ViconTMConnect_Psi_orientation(TestLimb);

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

%Save in table
T.BslDiff = ones(Ntrials,1)*BslDiff;

toc

%% AFC task

%Time variables
Date = datetime('now');
PhaseStart = datestr(Date);
timevar = tic;

%Run task
cd(Livedir);
Data_table = ViconTMConnect_PSI(Ntrials, X, alpha_range, beta_range, ...
    pr_left_x, pr_right_x, TestLimb, offset);

elapsedTime = toc(timevar);

%Add more data into tables and combine
TestStart_cell = {};
for t = 1:Ntrials
    TestStart_cell{t,1} = PhaseStart;
end
T.StartTime = TestStart_cell;
T.TestLen = ones(Ntrials,1)*elapsedTime;
Subj_table = [T, Data_table];

%Plot the test and estimate
PSIfig = plotPsi(Subj_table, X);

%Save
cd(datadir);
save([SID '_data'], 'Subj_table');
saveas(PSIfig,[SID '_fig.fig']);
writetable(Subj_table,[SID '_data.csv']);

cd(backupdir);
save([SID '_data'], 'Subj_table');
writetable(Subj_table,[SID '_data.csv']);

cd(serverdir);
save([SID '_data'], 'Subj_table');
saveas(PSIfig,[SID '_fig.fig']);
writetable(Subj_table,[SID '_data.csv']);
