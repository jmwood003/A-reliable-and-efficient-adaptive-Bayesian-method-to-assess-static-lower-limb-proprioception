function ViconTMConnect_Psi_orientation(TLstr)

%Set the min and max treadmill Speeds
min_speed_stim = 10;
max_speed_stim = 30;
min_speed_start = 40;
max_speed_start = 50;

AllStarts = [-60, 60];
AllStims = [-100, 100];

startpos = AllStarts(1);
stimulus = nan; %Need the stimulus to be nan at first so the first treadmill stop is the start position 

%Treadmill controller from this site:
% https://github.com/willpower2727/HMRL-Matlab-Treadmill-Functions

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%Set up Vicon SDK----------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
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
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%Set up Treadmill SDK------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%Set treadmill speed (Lets say for now the right leg is the reference
%leg so we are only moving the left)
accR = 1500;
accL = 1500;   
TMrefSpeed = 0; 

%Set a random speed to start
speed = round(min_speed_start + (max_speed_start-min_speed_start)*rand);

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
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%Initialize user interfaces------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%Initialize user interface fig---------------------------------------------
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

%User interface
Fig = uifigure('Position',[2500 -90 700 850],'Name','Experimenter Interface');
gl = uigridlayout(Fig,[5,5]);
gl.RowHeight = {40,50,400,100,200};
gl.ColumnWidth = {60,150,150,150,70};

%Message bar
message_text = uitextarea(gl,'HorizontalAlignment','center','FontSize',25);
message_text.Layout.Row = 1;
message_text.Layout.Column = [1 4];

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

%Buttons 
L_btn = uibutton(gl,'BackgroundColor','g','Text','Left','FontSize',50,'ButtonPushedFcn',@left_callback);
L_btn.Layout.Row = 4;
L_btn.Layout.Column = 2;

R_btn = uibutton(gl,'BackgroundColor','g','Text','Right','FontSize',50,'ButtonPushedFcn',@right_callback);
R_btn.Layout.Row = 4;
R_btn.Layout.Column = 3;

Err_btn = uibutton(gl,'BackgroundColor','r','Text','Error!','FontSize',50);
Err_btn.Layout.Row = 4;
Err_btn.Layout.Column = 4;

Switch = uiswitch(gl,'rocker','Items', {'Go','Stop'}, 'ValueChangedFcn',{@switchMoved, t});
Switch.Layout.Row = 4;
Switch.Layout.Column = 1;

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
stim_pos_label.Layout.Column = 5;
Pos_slide = uislider(gl,'Orientation','vertical','Limits',[-300 300],'MajorTicks',-300:50:300);
Pos_slide.Layout.Row = [3 5];
Pos_slide.Layout.Column = 5;

Fig.UserData = struct("Resp_Text", resp_text, "Trials", trial_text, "Switch", Switch, "Message", message_text, "Stims",stim_pos_text, "Starts", start_pos_text, "Position", Pos_slide);

%Disable buttons for now
set(L_btn,'Enable','off');
set(R_btn,'Enable','off');

pause(5);

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%Start Trial---------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%Initialize pre-set parameters 
Counter = 1;
tStart = tic;
trial = 1;
All_trial_nums = [];

%Update the display
All_trial_nums(1) = trial;
trial_text.Value = sprintf('%d \n',trial);
start_pos_text.Value = sprintf('%d \n',AllStarts);
stim_pos_text.Value = sprintf('%d \n',AllStims);

% Loop until the message box is dismissed
while trial <= 2

  drawnow limitrate;
  Counter = Counter + 1;
  
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
  Output_GetDeviceOutputComponentNameR.DeviceOutputName
%   Output_GetDeviceOutputComponentNameR.DeviceOutputComponentName

  % Get the device output value
  Output_GetDeviceOutputValueR = MyClient.GetDeviceOutputValue( Output_GetDeviceNameR.DeviceName, Output_GetDeviceOutputComponentNameR.DeviceOutputName, Output_GetDeviceOutputComponentNameR.DeviceOutputComponentName);
  FZ_R = Output_GetDeviceOutputValueR.Value();
  
  %Ensure forces are being place through feet
  ForceRatio = (FZ_R / FZ_L)*100;
  if ForceRatio > 0 && ForceRatio < inf
    FG.Value = ForceRatio;    
  end
  
  %Update the marker difference
  Pos_slide.Value = MkrDiff;

  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  %PSI Algorithm
  %------------------------------------------------------------------------
  %------------------------------------------------------------------------
  
  %Stops when the participant reaches the start position 
  if MkrDiff == startpos

      %Stop treadmill
      TMtestSpeed = 0;  
      %Format treadmill input
      %If test leg is right the right moves and vice versa; the treadmill
      %input is formatted as right belt speed first then left belt speed
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

      %Set start and stimulus positions
      startpos = nan; %reset so it only moves to stim position
      stimulus = AllStims(trial);

      %Pause for a random time period from 0-2 seconds 
      pause(2*rand(1));

      %Move treadmill to new stimulus position   
      speed = round(min_speed_stim + (max_speed_stim-min_speed_stim)*rand);
      message_text.Value = ['Moving to stimulus position (speed=' num2str(speed) ')'];
      if stimulus <= MkrDiff
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

  %Stops when the limb position equals the stimulus    
  elseif MkrDiff == stimulus
       
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
      
      %Engage the visual feedback/prompts
      choicelbl.Visible = 'on'; %Display the question for the subject
      LB.Visible = 'on';
      RB.Visible = 'on';
      message_text.Value = 'At stimulus location, make selection'; %Display message
      message_text.BackgroundColor = 'g';          
      set(L_btn,'Enable','on'); %Enable buttons
      set(R_btn,'Enable','on');
      set(Err_btn,'Enable','off');
      Switch.Value = 'Stop';
      uiwait(Fig);
      
      message_text.BackgroundColor = 'white';

      %Disable buttons again
      set(L_btn,'Enable','off');
      set(R_btn,'Enable','off');      
      set(Err_btn,'Enable','on');
          
      AllResponses = Fig.UserData.Resp_Text.Value;
      AllResponses = AllResponses(1:end-1);

      %Go back to stand normally prompt
      choicelbl.Visible = 'off';
      LB.Visible = 'off';
      RB.Visible = 'off';
       
      %Reset stimulus position
      stimulus = nan;
      
      %Move to the next trial
      trial = str2double(Fig.UserData.Trials.Value{end}) + 1;
      All_trial_nums(trial) = trial; 
      trial_text.Value = sprintf('%d \n', All_trial_nums);

      %Pause the test if at the breakpoints
      if trial > 2
          break
      end

      startpos = AllStarts(trial);
        
      %Update the display
      start_pos_text.Value = sprintf('%d \n',AllStarts);
      stim_pos_text.Value = sprintf('%d \n',AllStims);

      %Move treadmill to new start position   
      speed = round(min_speed_start + (max_speed_start-min_speed_start)*rand);
      message_text.Value = ['Moving to start position (speed=' num2str(speed) ')'];
      if startpos <= MkrDiff
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

  elseif MkrDiff >= 250 || MkrDiff <= 250
  
      %Move treadmill to new stimulus position   
      if startpos < MkrDiff || stimulus < MkrDiff
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

    %Move treadmill to the start position position   
    message_text.Value = ['Moving to start position (speed=' num2str(speed) ')'];
    if startpos <= MkrDiff || stimulus <= MkrDiff
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


end% while true  

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%End Trial-----------------------------------------------------------------
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
close(SubjDisp);
delete(SubjDisp);

close(Fig);
delete(Fig);

clear t;

% Disconnect and dispose
MyClient.Disconnect();

%Disconnect from Vicon
tEnd = toc( tStart );
minutes = tEnd / 60;
fprintf( 'Time Elapsed (minutes): %4.2f', minutes );

end