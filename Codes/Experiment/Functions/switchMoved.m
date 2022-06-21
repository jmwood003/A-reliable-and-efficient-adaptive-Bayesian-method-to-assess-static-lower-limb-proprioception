function switchMoved(src,event)

Fig = ancestor(src,"figure","toplevel");
if strcmp(src.Value,'Stop')==1
    Fig.UserData.Message.BackgroundColor = 'r';              
    uiwait(Fig);    
elseif strcmp(src.Value,'Go')==1
    uiresume(Fig);
    Fig.UserData.Message.BackgroundColor = 'w';          
end  
    
end