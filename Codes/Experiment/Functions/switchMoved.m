function switchMoved(src, event, t, TLstr)

%Description: pauses the task or restarts it after a break

%Inputs: 
% src: the current user interface object (required for a callback function)
% event: the button press event structure (required for a callback function)
% t: the treadmill controller object
% TLstr: string, specifying which limb is the test limb ('left' or 'right')

%Treadmill Speeds
minspeed = 10;
maxspeed = 30;

%Preset treadmill stuff
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

%Index the user interfaceobject
Fig = ancestor(src,"figure","toplevel");

%If value is switched to stop
if strcmp(src.Value,'Stop')==1

    %Update the message
    Fig.UserData.Message.BackgroundColor = 'r'; 
    
    %Stop the treadmill
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

    %wait for a response
    uiwait(Fig);    

elseif strcmp(src.Value,'Go')==1

    %Resume the trial
    uiresume(Fig);

    %Double check the feet
    msgfig = msgbox('Click ok when the markers properly labeled in Vicon', 'WAIT!');
    uiwait(msgfig)

    %Update the user interface
    Fig.UserData.Message.BackgroundColor = 'w';   

    %Index the next stimulus start position
    next_start = str2double(Fig.UserData.Starts.Value{end});

    %Retrieve marker position data
    MkrDiff = Fig.UserData.Position.Value;

    %Move the treadmill
    speed = round(minspeed + (maxspeed-minspeed)*rand);
    Fig.UserData.Message.Value = ['Moving to start position (speed=' num2str(speed) ')'];
    if next_start < MkrDiff
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
    
end