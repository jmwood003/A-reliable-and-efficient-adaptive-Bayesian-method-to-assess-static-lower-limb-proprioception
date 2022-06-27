function switchMoved(src,event, t, TLstr)

%Treadmill Speeds
minspeed = 10;
maxspeed = 50;

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

Fig = ancestor(src,"figure","toplevel");
if strcmp(src.Value,'Stop')==1

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

    uiwait(Fig);    

elseif strcmp(src.Value,'Go')==1
    
    uiresume(Fig);

    %Index the next stimulus and start position
    next_stim = str2double(Fig.UserData.Stims.Value{end});
    next_start = str2double(Fig.UserData.Starts.Value{end});

    %Retrieve marker position data
    MkrDiff = Fig.UserData.Position.Value;

    %Set a random speed to start
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

    Fig.UserData.Message.BackgroundColor = 'w';          
end  
    
end