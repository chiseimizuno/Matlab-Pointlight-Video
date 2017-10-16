% July 1st, by Yujia Peng + Chisei Mizuno
% Read in txt files of CMU actions, generate data3d files and make .mat
% files for different viewpoints. Generate videos.

%% define which action to load in
clear

[buffer,list] = xlsread('videolists.xlsx');
%foldername = 'subject 01-81/';
numfiles = length(list); 

for actionnumber = 2:numfiles
    
clearvars -except list numfiles actionnumber buffer
subjectnumber = strtok(list{actionnumber},'_');
foldername = strcat('subjects/',subjectnumber,'/');
filename = list{actionnumber};


bvhconverter1([ foldername filename]);  % convert txt file to data3d
jointindx = [17  19 20 21  26 27 28  3 4 5  8 9 10];

%% read in the data3d file using BioMotion toolbox
bm = BioMotion(sprintf('%s%s.data3d.txt',foldername,filename),'Filetype','data3d.txt','anchor','none');
bm.RotatePath(pi/4);
Markers13 = bm.NormJointsInfo;

%% generating folders and save .mat data for different viewpoints
action = actionnumber; % need to change this for different actions
mkdir(sprintf('matdata/action%d', action))
nFrames = size(Markers13, 2);
skipframe = 4 - (2*buffer(actionnumber-1));  % 2 for 60Hz actions and 4 for 120Hz actions, you can find the information of refreshrate on the CMU website
frameall = [1:skipframe:nFrames]; % keep 30hz

for angletrial = 1:7
    frame_all = [];
    frame = [];
    for ii = 1 : length(frameall)
        % here we skip some frames to make it 30Hz
        frame = squeeze(Markers13(:,frameall(ii),:));
        % rotate
        angle        = -pi/18*4 + angletrial*pi/18;
        rot          = frame*RotationMatrix(angle,[0 1 0]);
        frame(:,1)   = rot(1:length(jointindx));
        frame(:,2)   = rot(length(jointindx) + (1:length(jointindx)));
        frame(:,3)   = rot((2*length(jointindx))+(1:length(jointindx)));
        % we recenter the frames and resize them according to the 1st frame
        if ii == 1
            anchor = frame;
            frame = frame - repmat(mean(frame([8 11], :)), length(frame),1);
            ratio = 20 ./ (max(frame(:,2)) - min(frame(:,2)));
            frame = frame * ratio;
        else
            frame = frame - repmat(mean(anchor([8 11],:)), length(frame),1);
            frame = frame * ratio;
        end
        frame_all(:,:,ii) = frame;
    end;
    
    save( [ sprintf( 'matdata/action%d/%s_%d', action, filename, angletrial), '.mat'], 'frame_all'); 
end

%% generating videos
    spacelim = [0 0 0 0];
    for angletrial = 1:7
        action_angle{angletrial} = load( [ sprintf( 'matdata/action%d/%s_%d', action, filename, angletrial), '.mat']);
        frame_all = action_angle{angletrial}.frame_all;
        % spacelim is for getting the boundary of the video
        spacelim = [min(spacelim(1), min(min(frame_all(:,1,:)))) ...
            min(spacelim(2), min(min(frame_all(:,2,:))))  ...
            max(spacelim(3), max(max(frame_all(:,1,:))))  ...
            max(spacelim(4), max(max(frame_all(:,2,:))))];   
    end
    spacelim = spacelim + [-10 -10 10 10];
    
    mkdir(sprintf('actionvideos/action%d', action))
    for angletrial = 1:7
        vidObj = VideoWriter( sprintf( 'actionvideos/action%d/%s_%d.avi', action, filename, angletrial));
        vidObj.FrameRate = 30;
        open(vidObj);
        frame_all = action_angle{angletrial}.frame_all;
        for fr  = 1:length(frame_all)      
            plot(frame_all(:,1,fr), frame_all(:,2,fr),'k.','MarkerSize', 30);
            axis equal
            axis off
            grid off
            xlim([spacelim(1) spacelim(3)]);
            ylim([spacelim(2) spacelim(4)]);
            x = getframe;
            writeVideo(vidObj,x);                 
        end
        close(vidObj);
    end
end
