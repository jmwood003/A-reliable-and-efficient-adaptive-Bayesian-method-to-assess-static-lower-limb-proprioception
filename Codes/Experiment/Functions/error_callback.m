function error_callback(src, event, t, TLstr)

%Description: function for when the error button is pressed in the
%experimenter interface

%Inputs: 
% src: the current user interface object (required for a callback function)
% event: the button press event structure (required for a callback function)
% t: the treadmill controller object
% alpha_range: vector of the range of possible alpha values
% beta_range: vector of the range of possible beta values
% prior: the current prior for the alpha and beta estimates, matrix
% extreme_trials: the trial index for the extreme stimuli 
% random_trials: the trial index for the randomly stimuli 
% X: vector of all possible simulus location
% pr_left_lookup: matrix, look-up table for the probability of responding 'left'
% pr_right_lookup: matrix, look-up table for the probability of responding 'right'
% strtpos_sigma: the variability for the start position selection
% TBidx: index for the start position being above or below the stim position
% TLstr: string, specifying which limb is the test limb ('left' or 'right')


%Stop the treadmill
accR = 1500;
accL = 1500;   
TMtestSpeed = 0;   
TMrefSpeed = 0; 
format=0;
speedRR=0;
speedLL=0;
accRR=0;
accLL=0;
incline=0;
%Format treadmill input
aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
actualData=reshape(aux',size(aux,1)*2,1);
secCheck=255-actualData; %Redundant data to avoid errors in comm
padding=zeros(1,27);
%Set speeds
Payload=[format actualData' secCheck' padding];
fwrite(t,Payload,'uint8');

%Index the user interface object
Fig = ancestor(src,"figure","toplevel");

%Update the interface
Fig.UserData.Switch.Value = 'Stop';
Fig.UserData.Message.Value = 'Error!';
Fig.UserData.Message.BackgroundColor = 'r';   
Fig.UserData.Error_lamp.Color = 'r';   

%Index all stimuli and start positions and turn the into numerical format
AllStims_str = Fig.UserData.Stims.Value;
AllStarts_str = Fig.UserData.Starts.Value;
AllTrials_str = Fig.UserData.Trials.Value;
for i = 1:length(AllTrials_str)
    AllStims(i) = str2double(AllStims_str{i});
    AllStarts(i) = str2double(AllStarts_str{i});
    AllTrials(i) = str2double(AllTrials_str{i});
end
AllStarts(isnan(AllStarts)==1) = [];
AllStims(isnan(AllStims)==1) = [];

AllAlpha_str = Fig.UserData.a_est.Value;
AllBeta_str = Fig.UserData.b_est.Value;
for i = 1:length(AllAlpha_str)
    AllAlphas(i) = str2double(AllAlpha_str{i});
    AllBetas(i) = str2double(AllBeta_str{i});
end

current_trial = AllTrials(end);

%Get user input for the error trial
error_str = questdlg('Which trial was wrong?','Correction','last trial','2 trials ago', 'nevermind, no error', 'nevermind, no error');

if strcmp(error_str, 'last trial') == 1
    error_trial = current_trial-1;
elseif strcmp(error_str, '2 trials ago') == 1
    error_trial = current_trial-2;
elseif strcmp(error_str, 'nevermind, no error') == 1
    return;
end

%Delete all trials after the error and update the display
AllStims = AllStims(1:error_trial);
AllStarts = AllStarts(1:error_trial);
AllTrials = AllTrials(1:error_trial);
AllAlphas = AllAlphas(1:error_trial);
AllBetas = AllBetas(1:error_trial);
Fig.UserData.Resp_Text.Value = [Fig.UserData.Resp_Text.Value(1:error_trial-1); ' ']; %Responses
Fig.UserData.Stims.Value = sprintf('%d \n', AllStims); %Stimulus positions
Fig.UserData.Trials.Value = sprintf('%d \n', AllTrials); %Trial number
Fig.UserData.Starts.Value = sprintf('%d \n', [AllStarts nan]); %Start positions
Fig.UserData.a_est.Value = sprintf('%d \n', AllAlphas); 
Fig.UserData.b_est.Value = sprintf('%d \n', AllBetas); 

error_stim = AllStims(end); 

%Retrieve marker position data
MkrDiff = Fig.UserData.Position.Value;

%Update interface
Fig.UserData.Message.BackgroundColor = 'white';
Fig.UserData.Switch.Value = 'Go';              

%Move treadmill to new stimulus position   
%Treadmill Speeds
minspeed = 40;
maxspeed = 50;
speed = round(minspeed + (maxspeed-minspeed)*rand);
Fig.UserData.Message.Value = ['Moving to errorneous stim position (speed=' num2str(speed) ')'];
if error_stim < MkrDiff
  TMtestSpeed = speed;
else
  TMtestSpeed = -speed;
end
%Format treadmill input
if strcmp(TLstr,'Left')==1
  aux=int16toBytes([TMrefSpeed TMtestSpeed speedRR speedLL accR accL accRR accLL incline]);      
elseif strcmp(TLstr,'Right')==1
  aux=int16toBytes([TMtestSpeed TMrefSpeed speedRR speedLL accR accL accRR accLL incline]);      
end
actualData=reshape(aux',size(aux,1)*2,1);
secCheck=255-actualData; %Redundant data to avoid errors in comm
padding=zeros(1,27);
%Set speeds
Payload=[format actualData' secCheck' padding];
fwrite(t,Payload,'uint8');

end