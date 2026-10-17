function output = read_coordinate_cfg2016(cfgpath)
% read_coordinate_cfg.m
% written on 2010/10/29
% updated on 2012/11/14, new format for cfg file adopted
% updated read_coordinate_cfg2012 for new KRISSMEG coil results in 2017
% updated on 2021-2-22, added coil_sensor to the output
% Input:
%       - cfgpath: ex :  'Coordinate_coil01.cfg';
% OUTPUT
%       - output : structure
%           ='nasion';  position of nasion in head coordinate
%           ='lpa';  position of left preauricular in head coordinate
%           ='rpa'; position of right preauricular in head coordinate
%           ='head_radius';  best-fit radius of head model, in meter
%           ='coil';  (3 x 4) [coil1 coil2 coil3 coil4] positions in head coordinate
%           ='coil_sensor'; (3 x 4) [coil1 coil2 coil3 coil4] positions in sensor coordinate
% Usage
% > cfgpath = 'Coordinate_coil01.cfg';
% > head_info = read_coordinate_cfg(cfgpath);

% label of 7 points
label={'Nasion'; 'L-preauricular'; 'R_preauricular'; 'Coil-1'; 'Coil-2'; 'Coil-3'; 'Coil-4'};

fid = fopen(cfgpath);
dummy = fread(fid,length('[Raw data]\n'),'*char');

r_digit=[];     % positions of 7 points in digitizer coordinate
for ind_r = 1:7
    dummy = fread(fid,length([label{ind_r} ' = "']), '*char');
    tmp = fscanf(fid,'%f',9);      % (x1,y1,z1) (x2,y2,z2) (xm,ym,zm) : 1st trial, 2nd trial, mean
    r_digit = [r_digit tmp(7:9)];
    dummy = fread(fid,1,'*char');
    dummy = fscanf(fid,'\n',1);
end

r_head=[];      % positions of 7 points in head coordinate
for ind_r=1:7
    dummy = fscanf(fid,'\n',1); % skip a blink line
	dummy = fscanf(fid,'%s \n',1); % skip a text line
    tmp = fscanf(fid,'%*4c %f \n',3);   % skip 4 characters, get float number, go to nextline, repeat 3 times
    r_head = [r_head tmp];
end

dummy = fscanf(fid,'\n',1);
dummy = fscanf(fid,'%s \n', 1);
Originshift = fscanf(fid, '%*4c %f \n',3)
dummy = fscanf(fid,'\n',1);
dummy = fscanf(fid,'%s \n',1);
head_radius = fscanf(fid, '%*4c %f\n',1)

coil_sensor=[];     % positions of 4 coils in sensor coordinate
for ind_r=1:4
    dummy = fscanf(fid,'\n',1);
    dummy = fscanf(fid,'%s \n', 1);
    tmp = fscanf(fid, '%*4c %f \n',3)
    coil_sensor = [coil_sensor tmp];
end

fclose(fid);

output=struct('nasion', r_head(:,1)*0.001, ... % position of nasion in head coordinate
                    'lpa', r_head(:,2)*0.001, ... % position of left preauricular in head coordinate
                    'rpa', r_head(:,3)*0.001, ... % position of right preauricular in head coordinate
                    'head_radius', head_radius*0.001, ... % best-fit radius of head model, in meter
                    'origin',Originshift*0.001, ... % spherical center in sensor coordinate
                    'coil', r_head(:,4:7)*0.001, ...        % (3 x 4) [coil1 coil2 coil3 coil4] positions in head coordinate
                    'coil_sensor', coil_sensor*0.001);        % (3 x 4) [coil1 coil2 coil3 coil4] positions in sensor coordinate
                