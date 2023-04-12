function T = ViconTMConnect_PSI(Ntrials, X, alpha_range, beta_range, pr_left_lookup, pr_right_lookup, TLstr, offset, Livedir, trial_dir, restart_str)

%Description: runs an AFC task using the PSI algorithm by connecting 
% through vicon and through the treadmill controller

%Inputs: 
% Ntrials: scalar, number of trials in the AFC task
% X: vector of all possible simulus location
% alpha_range: vector of the range of possible alpha values
% beta_range: vector of the range of possible beta values
% pr_left_lookup: matrix, look-up table for the probability of responding 'left'
% pr_right_lookup: matrix, look-up table for the probability of responding 'right'
% TLstr: string, specifying which limb is the test limb ('left' or 'right')
% offset: scalar, the difference between the ankle markers at baseline

%Outputs:
% alpha_EV: vector of the alpha estimate after each trial
% beta_EV: vector of the beta estimate after each trial
% AllStarts: vector of all the start positions for each trial
% AllStims: vector of all the stimulus positions for each trial
% AllResponses: cell array of all the responses for each trial
% BinaryResponses: vector of all the responses in binary (1 or 0) form for each trial
% StartSpeeds: vector of treadmill speeds to each start position
% StimSpeeds: vector of treadmill speeds to each stimulus position

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Set some parameters for the test
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

% if strcmp(restart_str,'yes')==1
%   cd(trial_dir);
% 
% end

cd(Livedir);

%Set the seed 
rng('shuffle');

%The start positions will be randomized based on this sigma
strtpos_sigma = 5;
strtpos_mu = 100-offset;

%Set the min and max treadmill Speeds
min_speed_stim = 10;
max_speed_stim = 30;
min_speed_start = 40;
max_speed_start = 50;

%The start positions should move from the bottom up to top down an even
%number of times (or as close to equal as possible; 1 = top down, 0 bottom up)
TBidx = rand(1,Ntrials)>0.5;
half = round(Ntrials/2);
while sum(TBidx)~=half
    TBidx = rand(1,Ntrials)>0.5;
end

%Specify the priors
alpha_p = normpdf(alpha_range,-offset,20);
beta_p = exppdf(beta_range,20);
prior = beta_p'*alpha_p;
All_priors = nan(length(alpha_p),length(beta_p),Ntrials);
All_priors(:,:,1) = prior;

%Add in random stimuli every 5 trials to gain a wider range of stimuli
random_space = 5;   %Inject random stimuli around the threshold estimate every 5 trials
start_rand = 6; %Starting both at the 5th trial
for r = 1:floor(Ntrials/random_space)

    current_rand_idx = start_rand:start_rand+random_space-1; %index 10 trials at a time
    rand_trials(r) = datasample(current_rand_idx,1,'Replace',false); %choose an extreme index 
    start_rand = current_rand_idx(end)+1;

end

%Add in extreme stimuli every 10 trials to prevent loss of focus
extreme_space = 10; %Inject extreme stimuli every 10 trials 
start_rand = 6; %Starting both at the 5th trial
for e = 1:floor(Ntrials/extreme_space)
    current_ext_idx = start_rand:start_rand+extreme_space-1; %index 10 trials at a time
    extreme_trials(e)  = datasample(current_ext_idx,1,'Replace',false); %choose an extreme index 
    while ismember(extreme_trials(e),rand_trials)==1
        extreme_trials(e)  = datasample(current_ext_idx,1,'Replace',false); %choose an extreme index 
    end
    start_rand = current_ext_idx(end)+1;
end
extreme_trials = [extreme_trials, nan]; %Pad with nans to prevent over indexing
rand_trials = [rand_trials, nan];
et_idx = 1; rand_idx = 1; %Set the index for these trials

%Psudorandomize the extreme options
random_levels = [-30,-20,-10,10,20,30]; %random stimuli options 
extreme_options = [-100,-100,-90,-90,90,90,100,100]-offset;
extreme_stims = extreme_options(randperm(length(extreme_options)));

pre_selects = [extreme_trials, rand_trials];
pre_selects(isnan(pre_selects)==1) = [];


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Set up Vicon SDK----------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


HostName = 'localhost:801';

% Load the SDK
fprintf( 'Loading SDK...' );
addpath( '..\dotNET' );
dssdkAssembly = which('ViconDataStreamSDK_DotNET.dll');
NET.addAssembly(dssdkAssembly);
fprintf( 'done\n' );

% Make a new client
MyClient = ViconDataStreamSDK.DotNET.Client();

% Connect to a server
fprintf( 'Connecting to %s ...', HostName );
while ~MyClient.IsConnected().Connected
  % Direct connection
  MyClient.Connect( HostName );
  fprintf( '.' );
end
fprintf( '\n' );

% Enable some different data types
MyClient.EnableSegmentData();
MyClient.EnableMarkerData();
MyClient.EnableUnlabeledMarkerData();
MyClient.EnableDeviceData();

% Set the streaming mode and buffer size
MyClient.SetBufferSize(1)
MyClient.SetStreamMode( ViconDataStreamSDK.DotNET.StreamMode.ClientPull  );


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Set up Treadmill SDK------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%Treadmill controller from this site:
% https://github.com/willpower2727/HMRL-Matlab-Treadmill-Functions

%Set treadmill speed and acceleration
accR = 1500;
accL = 1500;   
TMrefSpeed = 0; 

%Format treadmill input
format=0;
speedRR=0;
speedLL=0;
accRR=0;
accLL=0;
incline=0;

%Open treadmill communication 
t=tcpclient('localhost',1000);
set(t,'InputBufferSize',32,'OutputBufferSize',64);
fopen(t);


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Initialize user interfaces------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


%Subjects display
SubjDisp = uifigure('Name','Instrunctions','Position',[4000 300 500 500],'WindowState','fullscreen');
SubjDisp.Color = 'w';
%Set a label for standing normally
normlbl = uilabel(SubjDisp,'Position',[300 300 1000 500], 'FontSize',100);
normlbl.Text = 'Stand Normally';
normlbl.Visible = 'off';
%Set a label for choice
choicelbl = uilabel(SubjDisp,'Position',[300 300 1000 500], 'FontSize',50);
choicelbl.Text = {'Do you feel your right or left foot'; '            is more forward?'};
choicelbl.Visible = 'off';
%Buttons
LB = uibutton(SubjDisp,'Position',[200 200 300 200],'FontSize',75,'BackgroundColor','g');
LB.Text = 'Left';
LB.Visible = 'off';
RB = uibutton(SubjDisp,'Position',[800 200 300 200],'FontSize',75,'BackgroundColor','g');
RB.Text = 'Right';
RB.Visible = 'off'; 

%Exerpimenter display
Fig = uifigure('Position',[2500 -90 800 850],'Name','Experimenter Interface');
gl = uigridlayout(Fig,[5,7]);
gl.RowHeight = {40,50,400,100,200};
gl.ColumnWidth = {60,150,150,150,70,70,70};
%Message bar
message_text = uitextarea(gl,'HorizontalAlignment','center','FontSize',25);
message_text.Layout.Row = 1;
message_text.Layout.Column = [1 6];
%Trial numbers
trial_label = uilabel(gl,'Text', 'Trial','FontSize',20);
trial_label.Layout.Row = 2;
trial_label.Layout.Column = 1;
trial_text = uitextarea(gl,'FontSize',20,'BackgroundColor',[0.93,0.93,0.93]);
trial_text.Layout.Row = 3;
trial_text.Layout.Column = 1;
%Start position texts
start_pos_label = uilabel(gl,'Text', '  Start Position','FontSize',20);
start_pos_label.Layout.Row = 2;
start_pos_label.Layout.Column = 2;
start_pos_text = uitextarea(gl,'FontSize',20);
start_pos_text.Layout.Row = 3;
start_pos_text.Layout.Column = 2;
%Stimulus position texts
stim_pos_label = uilabel(gl,'Text', '  Stim Position','FontSize',20);
stim_pos_label.Layout.Row = 2;
stim_pos_label.Layout.Column = 3;
stim_pos_text = uitextarea(gl,'FontSize',20);
stim_pos_text.Layout.Row = 3;
stim_pos_text.Layout.Column = 3;
%Response texts
resp_label = uilabel(gl,'Text', '  Responses','FontSize',20);
resp_label.Layout.Row = 2;
resp_label.Layout.Column = 4;
resp_text = uitextarea(gl,'FontSize',20);
resp_text.Layout.Row = 3;
resp_text.Layout.Column = 4;
%Alpha
alpha_label = uilabel(gl,'Text', ' Alpha','FontSize',20);
alpha_label.Layout.Row = 2;
alpha_label.Layout.Column = 5;
alpha_text = uitextarea(gl,'FontSize',20);
alpha_text.Layout.Row = 3;
alpha_text.Layout.Column = 5;
%Beta
beta_label = uilabel(gl,'Text', ' Beta','FontSize',20);
beta_label.Layout.Row = 2;
beta_label.Layout.Column = 6;
beta_text = uitextarea(gl,'FontSize',20);
beta_text.Layout.Row = 3;
beta_text.Layout.Column = 6;
%Buttons 
L_btn = uibutton(gl,'BackgroundColor','g','Text','Left','FontSize',50,'ButtonPushedFcn',@left_callback);
L_btn.Layout.Row = 4;
L_btn.Layout.Column = 2;
R_btn = uibutton(gl,'BackgroundColor','g','Text','Right','FontSize',50,'ButtonPushedFcn',@right_callback);
R_btn.Layout.Row = 4;
R_btn.Layout.Column = 3;
Err_btn = uibutton(gl,'BackgroundColor','r','Text','Error!','FontSize',50,'ButtonPushedFcn',{@error_callback, t, TLstr});
Err_btn.Layout.Row = 4;
Err_btn.Layout.Column = 4;
%Switch
Switch = uiswitch(gl,'rocker','Items', {'Go','Stop'}, 'ValueChangedFcn',{@switchMoved, t, TLstr});
Switch.Layout.Row = 4;
Switch.Layout.Column = 1;
%Error lamp
Err_lamp = uilamp(gl);
Err_lamp.Layout.Row = 1;
Err_lamp.Layout.Column = 7;
%Force ratio gauge 
uilabel(Fig, 'Position',[250 100 300 200], 'FontSize',20, 'Text', 'Force Ratio');
FG = uigauge(Fig, 'semicircular', 'Position',[150 10 300 300],'Limits',[50 150]);
FG.ScaleColors = {'red','yellow','green','yellow','red'};
FG.ScaleColorLimits = [50 80; 80 90; 90 110; 110 120; 120 150];
uilabel(Fig,'Position',[70 0 300 200], 'FontSize',15, 'Text','Left too high');
uilabel(Fig,'Position',[450 0 300 200], 'FontSize',15,'Text','Right too high');
%Position slider
stim_pos_label = uilabel(gl,'Text', {'Live'; 'Pos.'},'FontSize',20);
stim_pos_label.Layout.Row = 2;
stim_pos_label.Layout.Column = 7;
Pos_slide = uislider(gl,'Orientation','vertical','Limits',[-300 300],'MajorTicks',[-300:50:300]);
Pos_slide.Layout.Row = [3 5];
Pos_slide.Layout.Column = 7;

%Allow for indexing data within callback functions
Fig.UserData = struct("Resp_Text", resp_text, "Trials", trial_text, "Switch", Switch, ...
    "Message", message_text, "Stims", stim_pos_text, "Starts", start_pos_text,...
    "Position", Pos_slide, "Left_btn", L_btn, "Right_btn", R_btn, "a_est", alpha_text, "b_est", beta_text, ...
    "Error_btn", Err_btn, "Error_lamp", Err_lamp);

%Disable buttons for now
set(L_btn,'Enable','off');
set(R_btn,'Enable','off');

%Pause to make sure the figure has time to load
pause(5);


%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Start Trial---------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%Double check the feet
msgfig = msgbox('Click ok when the markers properly labeled in Vicon', 'WAIT!');
uiwait(msgfig)

%Calculate first stimulus
for x = 1:length(X)
    
    %Calculate the probability of getting response r, after presenting
    %test x at the next trial
    pr_left_x = nansum(nansum(pr_left_lookup(:,:,x).*prior));
    pr_right_x = nansum(nansum(pr_right_lookup(:,:,x).*prior));

    %Calculate the posterior distribution for both responses
    Post_left = pr_left_lookup(:,:,x).*prior;
    Post_left = Post_left./pr_left_x;
    Post_right = pr_right_lookup(:,:,x).*prior;
    Post_right = Post_right./pr_right_x;        

    %Estimate the entropy of the posterior distribution for each response
    H_left = -nansum(nansum(Post_left.*log2(Post_left)));
    H_right = -nansum(nansum(Post_right.*log2(Post_right)));

    EH(x) = (H_left*pr_left_x) + (H_right*pr_right_x);

end
%find the simulus that minimizes entropy
[~,minH_idx] = min(EH);
AllStims(1) = X(minH_idx);

%Get a start position and record in a different variable
if TBidx(1)==1
    startpos = round(normrnd(strtpos_mu,strtpos_sigma));
    while startpos <= AllStims(1)
        startpos = round(normrnd(strtpos_mu,strtpos_sigma));
    end
elseif TBidx(1)==0
    startpos = round(normrnd(-strtpos_mu,strtpos_sigma));
    while startpos >= AllStims(1)
        startpos = round(normrnd(-strtpos_mu,strtpos_sigma));
    end    
end
AllStarts(1) = startpos;

%Initialize pre-set parameters 
Counter = 1;
tStart = tic;
trial = 1;
alpha_EV = [];
beta_EV = [];
AllResponses = [];
StimSpeeds = [];
StartSpeeds = [];

%Update the display
trial_text.Value = sprintf('%d \n',trial);
start_pos_text.Value = sprintf('%d \n',AllStarts);
stim_pos_text.Value = sprintf('%d \n',nan);

%Move treadmill to the start position position   
speed = round(min_speed_start + (max_speed_start-min_speed_start)*rand);
StartSpeeds(1) = speed; %Record the speed
message_text.Value = ['Moving to start position (speed=' num2str(speed) ')'];
if str2double(start_pos_text.Value{end}) < offset
  TMtestSpeed = speed;
elseif str2double(start_pos_text.Value{end}) > offset
  TMtestSpeed = -speed;
elseif str2double(start_pos_text.Value{end}) == offset
  TMtestSpeed = 0;
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

% Loop until the message box is dismissed
while trial <= Ntrials

  drawnow limitrate;
  Counter = Counter + 1;
  
  %Get a frame
  while MyClient.GetFrame().Result ~= ViconDataStreamSDK.DotNET.Result.Success
    fprintf( '.' );
  end% while
  
  %Index the heel markers 
  SubjectCount = MyClient.GetSubjectCount().SubjectCount;  
  SubjectIndex = typecast( SubjectCount, 'int32' ) -1; 
  SubjectName = MyClient.GetSubjectName( typecast( SubjectIndex, 'uint32') ).SubjectName;  
  Output_GetMarkerGlobalTranslation_Left = MyClient.GetMarkerGlobalTranslation( SubjectName, 'LMAL' );
  LMALY = Output_GetMarkerGlobalTranslation_Left.Translation( 2 );

  Output_GetMarkerGlobalTranslation_Left = MyClient.GetMarkerGlobalTranslation( SubjectName, 'RMAL' );
  RMALY = Output_GetMarkerGlobalTranslation_Left.Translation( 2 );
    
  %Calculate marker difference (test minus reference)
  if strcmp(TLstr,'Left')==1
      MkrDiff = round(LMALY - RMALY); %In mm
  elseif strcmp(TLstr,'Right')==1
      MkrDiff = round(RMALY - LMALY); %In mm      
  end  

  %Index Left Force plate
  DeviceCountL = MyClient.GetDeviceCount().DeviceCount;
  DeviceIndex = typecast( DeviceCountL, 'int32' ) - 1;
  Output_GetDeviceNameL = MyClient.GetDeviceName( typecast( DeviceIndex, 'uint32' ) );
  %The above should index the Left force plate (use the below expression to
  %check)
%   Output_GetDeviceName.DeviceName

  % Count the number of device outputs
  DeviceOutputCountL = MyClient.GetDeviceOutputCount( Output_GetDeviceNameL.DeviceName ).DeviceOutputCount;
  DeviceOutputIndexL = typecast( DeviceOutputCountL, 'int32' ) - 7;
  Output_GetDeviceOutputComponentName = MyClient.GetDeviceOutputComponentName( Output_GetDeviceNameL.DeviceName, typecast( DeviceOutputIndexL, 'uint32') );
  %The above should index the the Fz component of the force plate (use the
  %below expression to check):
%   Output_GetDeviceOutputComponentName.DeviceOutputName
%   Output_GetDeviceOutputComponentName.DeviceOutputComponentName

  % Get the device output value
  Output_GetDeviceOutputValue = MyClient.GetDeviceOutputValue( Output_GetDeviceNameL.DeviceName, Output_GetDeviceOutputComponentName.DeviceOutputName, Output_GetDeviceOutputComponentName.DeviceOutputComponentName);
  FZ_L = Output_GetDeviceOutputValue.Value();
  
  %Index Right Force plate
  DeviceCountR = MyClient.GetDeviceCount().DeviceCount;
  DeviceIndexR = typecast( DeviceCountR, 'int32' ) - 2;
  Output_GetDeviceNameR = MyClient.GetDeviceName( typecast( DeviceIndexR, 'uint32' ) );
  %The above should index the Left force plate (use the below expression to
  %check)
%   Output_GetDeviceNameR.DeviceName
  
  % Count the number of device outputs
  DeviceOutputCountR = MyClient.GetDeviceOutputCount( Output_GetDeviceNameR.DeviceName ).DeviceOutputCount;
  DeviceOutputIndexR = typecast( DeviceOutputCountR, 'int32' ) - 7;
  Output_GetDeviceOutputComponentNameR = MyClient.GetDeviceOutputComponentName( Output_GetDeviceNameR.DeviceName, typecast( DeviceOutputIndexR, 'uint32') );
  %The above should index the the Fz component of the force plate (use the
  %below expression to check):
%   Output_GetDeviceOutputComponentNameR.DeviceOutputName
%   Output_GetDeviceOutputComponentNameR.DeviceOutputComponentName

  % Get the device output value
  Output_GetDeviceOutputValueR = MyClient.GetDeviceOutputValue( Output_GetDeviceNameR.DeviceName, Output_GetDeviceOutputComponentNameR.DeviceOutputName, Output_GetDeviceOutputComponentNameR.DeviceOutputComponentName);
  FZ_R = Output_GetDeviceOutputValueR.Value();
  
  %Ensure forces are being place through feet
  ForceRatio = (FZ_R / FZ_L)*100;
  if ForceRatio > 0 && ForceRatio < inf
    FG.Value = ForceRatio;    
  end
  
  %Update the marker difference display slider
  Pos_slide.Value = MkrDiff;


  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  %PSI Algorithm
  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  

  %Stops when the participant reaches the start position 
  if MkrDiff == str2double(start_pos_text.Value{end})

      %get the start position and end position from the GUI
      if trial ~=1 
          AllStims_str = Fig.UserData.Stims.Value;
          AllStarts_str = Fig.UserData.Starts.Value;
          AllTrials_str = Fig.UserData.Trials.Value;
          AllStims = []; AllStarts = []; All_trial_nums = []; 
          for i = 1:length(AllTrials_str)
              AllStims(i) = str2double(AllStims_str{i});
              AllStarts(i) = str2double(AllStarts_str{i});
              All_trial_nums(i) = str2double(AllTrials_str{i});
          end
          AllStarts(isnan(AllStarts)==1) = [];
          AllStims(isnan(AllStims)==1) = [];
      end
      AllResponses = resp_text.Value;
      empty_idx = contains(AllResponses,' ');
      AllResponses(empty_idx) = [];   

      %Stop treadmill
      TMtestSpeed = 0;  
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

      %Update the marker difference display slider
      Pos_slide.Value = MkrDiff;

      %update the start and stim position displays 
      start_pos_text.Value = sprintf('%d \n', [AllStarts, nan]);
      stim_pos_text.Value = sprintf('%d \n', AllStims);
      resp_text.Value = [AllResponses; ' '];
      scroll(start_pos_text,'bottom');
      scroll(resp_text,'bottom');
      scroll(stim_pos_text,'bottom');

      %Pause for a random time period from 0-2 seconds 
      pause(2*rand(1));

      %Move treadmill to new stimulus position   
      speed = round(min_speed_stim + (max_speed_stim-min_speed_stim)*rand);
      StimSpeeds(trial) = speed; %Record the speed
      message_text.Value = ['Moving to stimulus position (speed=' num2str(speed) ')']; %display message
      if str2double(stim_pos_text.Value{end}) < MkrDiff
          TMtestSpeed = speed;
      elseif str2double(stim_pos_text.Value{end}) > MkrDiff
          TMtestSpeed = -speed;
      elseif str2double(stim_pos_text.Value{end}) == MkrDiff
          TMtestSpeed = 0;
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

  %Stops when the limb position equals the stimulus    
  elseif MkrDiff == str2double(stim_pos_text.Value{end})
       
      %Need to get the start position and end position from the GUI
      AllStims_str = Fig.UserData.Stims.Value;
      AllStarts_str = Fig.UserData.Starts.Value;
      AllTrials_str = Fig.UserData.Trials.Value;   
      AllStims = []; AllStarts = []; All_trial_nums = []; 
      for i = 1:length(AllTrials_str)
          AllStims(i) = str2double(AllStims_str{i});
          AllStarts(i) = str2double(AllStarts_str{i});
          All_trial_nums(i) = str2double(AllTrials_str{i});       
      end
      AllStarts(isnan(AllStarts)==1) = [];
      AllStims(isnan(AllStims)==1) = [];
      trial = All_trial_nums(end);  
         
      %Index the correct prior
      prior = All_priors(:,:,trial);

      %Stop treadmill
      TMtestSpeed = 0;  
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

      %Update the marker difference display slider
      Pos_slide.Value = MkrDiff;
      
      %If there is no error, show the display
      if Err_lamp.Color(1) == 0 && Err_lamp.Color(2) == 1 && Err_lamp.Color(3) == 0

          %Engage the visual feedback/prompts
          choicelbl.Visible = 'on'; %Display the question for the subject
          LB.Visible = 'on';
          RB.Visible = 'on';

          %Engage the visual feedback/prompts
          message_text.Value = 'At stimulus location, make selection'; %Display message
          message_text.BackgroundColor = 'g';          
          Switch.Value = 'Stop';          

      else 

          %Engage the visual feedback/prompts
          message_text.Value = 'Correct the erroneous response'; %Display message
          message_text.BackgroundColor = 'r';          
             
      end

      set(L_btn,'Enable','on'); %Enable buttons
      set(R_btn,'Enable','on');
      set(Err_btn,'Enable','off'); %Disable error button
      Switch.Value = 'Stop';        
      uiwait(Fig); %Wait for a response
      Err_lamp.Color = 'g';

      %Turn off the display for the subject
      choicelbl.Visible = 'off';
      LB.Visible = 'off';
      RB.Visible = 'off';
                
      %Index the responses from the figure
      AllResponses = Fig.UserData.Resp_Text.Value;
      AllResponses = AllResponses(1:end-1); %remove the blank

      %Index the posterior and normalize
      stim_idx = find(AllStims(trial)==X);  %index the stimulus position
      if strcmp(AllResponses(trial),'left')==1 %index the appropriate page in the lookup table
          posterior = pr_left_lookup(:,:,stim_idx).*prior;        
      elseif strcmp(AllResponses(trial),'right')==1
          posterior = pr_right_lookup(:,:,stim_idx).*prior;
      end
      posterior = posterior./nansum(nansum(posterior)); %normalize

      %Marginalize and check the plot
      alpha_post = nansum(posterior,1);
      beta_post = nansum(posterior,2)';

      %Calculate the mean of each posterior
      alpha_EV(trial) = nansum(alpha_range.*alpha_post);
      beta_EV(trial) = nansum(beta_range.*beta_post); 

      alpha_text.Value = sprintf('%d \n', round(alpha_EV));
      beta_text.Value = sprintf('%d \n', round(beta_EV));
      scroll(alpha_text,'bottom');
      scroll(beta_text,'bottom');     

      %The posterior becomes the prior
      prior = posterior;

      %save the trial
      T = table;
      T.Trial_num = [1:trial]';
      T.AllStarts = AllStarts(1:trial)';
      T.AllStims = AllStims(1:trial)';
      T.AllResponses = AllResponses(1:trial);
      T.BinaryResponses = contains(AllResponses(1:trial),'left');
      T.Alpha_EV = alpha_EV(1:trial)';
      T.Beta_EV = beta_EV(1:trial)';
      T.StartSpeeds = StartSpeeds(1:trial)';
      T.StimSpeeds = StimSpeeds(1:trial)';
      cd(trial_dir);
      save('trial_data', 'T');
      cd(Livedir);
      
      %Move to the next trial
      trial = str2double(Fig.UserData.Trials.Value{end})+1; %Index from the display
      All_trial_nums(trial) = trial; %Add the trial
      trial_text.Value = sprintf('%d \n', All_trial_nums); %update the display
      scroll(trial_text,'bottom');

      All_priors(:,:,trial) = prior;

      %Pause the test if at trial 25
      if trial > Ntrials
          break
      elseif trial == 26 %Break at 25 
          message_text.Value = '25 trial break. Flip switch to continue';
          message_text.BackgroundColor = 'c';
          Switch.Value = 'Stop';
          uiwait(Fig);
      elseif trial==51 %Break at 50 
          message_text.Value = '50 trial break. Flip switch to continue';
          message_text.BackgroundColor = 'c';          
          Switch.Value = 'Stop';          
          uiwait(Fig);
      end
      
      %Select the next stimulus (using entropy or the pre-set random stims)
      if trial==extreme_trials(et_idx) %Extreme stimulus 

          %Select an extreme stimulus
          AllStims(trial) = extreme_stims(et_idx);
          et_idx = et_idx+1;

      elseif trial==rand_trials(rand_idx) %less extreme stimulus

          %Add the random values to the current estimate for alpha
          potential_stims = round(alpha_EV(trial-1))+random_levels; 
          new_stim = potential_stims(randi(length(potential_stims)));
          [~, stimidx] = min(abs(X-new_stim)); %Find the value closest to the stim location
          AllStims(trial) = X(stimidx);
          rand_idx = rand_idx+1; %Update the index

      else %Entropy calculation 

          %Calculate the best stimulus for the next trial using information entropy     
          %Loop through all potential stimulus values
          for x = 1:length(X) 

              %Calculate the probability of getting response r, after presenting
              %test x at the next trial
              pr_left_x = nansum(nansum(pr_left_lookup(:,:,x).*prior));
              pr_right_x = nansum(nansum(pr_right_lookup(:,:,x).*prior));

              %Calculate the posterior distribution for both responses
              Post_left = pr_left_lookup(:,:,x).*prior;
              Post_left = Post_left./pr_left_x;
              Post_right = pr_right_lookup(:,:,x).*prior;
              Post_right = Post_right./pr_right_x;        

              %Estimate the entropy of the posterior distribution for each response
              H_left = -nansum(nansum(Post_left.*log2(Post_left)));
              H_right = -nansum(nansum(Post_right.*log2(Post_right)));

              EH(x) = (H_left*pr_left_x) + (H_right*pr_right_x);
          end
          %Find the simulus that minimizes entropy
          [~,minH_idx] = min(EH);
          AllStims(trial) = X(minH_idx);

      end

      %Get a new start position based on the next stim position
      if TBidx(trial)==1
          startpos = round(normrnd(strtpos_mu,strtpos_sigma));
          while startpos <= AllStims(trial)
              startpos = round(normrnd(strtpos_mu,strtpos_sigma));
          end    
      elseif TBidx(trial)==0
          startpos = round(normrnd(-strtpos_mu,strtpos_sigma));
          while startpos >= AllStims(trial)
              startpos = round(normrnd(-strtpos_mu,strtpos_sigma));
          end            
      end
      AllStarts(trial) = startpos;
      
      %Update the display
      stim_pos_text.Value = sprintf('%d \n',[AllStims nan]);
      resp_text.Value = [AllResponses; ' '; ' '];      
      start_pos_text.Value = sprintf('%d \n',AllStarts);
      scroll(start_pos_text,'bottom');
      scroll(stim_pos_text,'bottom');
      scroll(resp_text, 'bottom');

      %Move treadmill to new stimulus position   
      speed = round(min_speed_start + (max_speed_start-min_speed_start)*rand);
      StartSpeeds(trial) = speed; %Record the speed
      message_text.Value = ['Moving to start position (speed=' num2str(speed) ')'];
      if str2double(start_pos_text.Value{end}) < MkrDiff
          TMtestSpeed = speed;
      elseif str2double(start_pos_text.Value{end}) > MkrDiff
          TMtestSpeed = -speed;
      elseif str2double(start_pos_text.Value{end}) == MkrDiff
          TMtestSpeed = 0;          
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

  elseif MkrDiff >= 250 || MkrDiff <= -250 %If the foot is moving to far, stop and go back
  
      %Move treadmill to new stimulus position   
      if str2double(start_pos_text.Value{end}) < MkrDiff || str2double(stim_pos_text.Value{end}) < MkrDiff
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

end% while true  

%Convert the response to a binary response (probability of left)
BinaryResponses = contains(AllResponses,'left');

%Remove nans
AllStarts(isnan(AllStarts)==1) = [];
AllStims(isnan(AllStims)==1) = [];
%Create a logical array for the preselected stimuli
pre_selects = pre_selects(pre_selects<Ntrials);
trial_num = 1:Ntrials;
pre_selectcs_logic = ismember(trial_num,pre_selects);

%Create table for the output
T = table;
T.Trial_num = trial_num';
T.AllStarts = AllStarts';
T.AllStims = AllStims';
T.SelectedStims = pre_selectcs_logic';
T.AllResponses = AllResponses;
T.BinaryResponses = BinaryResponses;
T.Alpha_EV = alpha_EV';
T.Beta_EV = beta_EV';
T.StartSpeeds = StartSpeeds';
T.StimSpeeds = StimSpeeds';

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%End Trial-----------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------


close(SubjDisp);
delete(SubjDisp);

close(Fig);
delete(Fig);

clear t;

%Disconnect from Vicon
MyClient.Disconnect();

tEnd = toc( tStart );
minutes = tEnd / 60;
fprintf( 'Time Elapsed (minutes): %4.2f', minutes );

end