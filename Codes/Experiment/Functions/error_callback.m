function error_callback(src,event,t)

%Treadmill Speeds
minspeed = 10;
maxspeed = 50;

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

%Change the user input configuration 
Fig = ancestor(src,"figure","toplevel");
Fig.UserData.Switch.Value = 'Stop';
Fig.UserData.Message.Value = 'Error!';
Fig.UserData.Message.BackgroundColor = 'r';              

%Stop the trial
uiwait(Fig);

%Index the current trial
trials = Fig.UserData.Trials.Value;
current_trial = str2num(trials{end});

%Index the erroneous response 
Responses = Fig.UserData.Resp_Text.Value;
Error_response = Responses{end};



Fig.UserData.Resp_Text.Value = Responses;

uiresume(Fig);

Fig.UserData.Switch.Value = 'Go';

end