% NIMS_asc_converter.m
%--------------------------------------------------------------------------
% Danny Feucht                                  daniel.feucht@colorado.edu
% Department of Geological Sciences
% University of Colorado at Boulder
% Created: 12 June 2017
% Updated: 25 April 2018
%--------------------------------------------------------------------------
% Convert ASCII time series files output by EMTF into standard format ASCII
% files for U.S. Geological Survey data release
%
% Output file naming convention (ex: for site rgr003)
%       your_dir_name_here/rgr003/
%                            rgr003a_converted.asc
%                            rgr003b_converted.asc
%                            rgr003c_converted.asc
%                            rgr003a.bin
%                            rgr003b.bin
%                            rgr003c.bin
%
% Header format - converted ASCII file (ex: run rgr003a)
%     SurveyID: RGR
%     SiteID: 003
%     RunID: rgr003a
%     SiteLatitude: 39.28200
%     SiteLongitude: -108.15820
%     SiteElevation: 1803.07
%     AcqStartTime: 2012-08-21T22:02:27 UTC
%     AcqStopTime: 2012-08-24T16:25:26 UTC
%     AcqSmpFreq: 4.00000
%     AcqNumSmp: 955916
%     Nchan: 5
%     Channel coordinates relative to geographic north
%     ChnSettings:
%     ChnNum ChnID InstrumentID Azimuth Dipole_Length
%     0031   Hx    2311-11         9.0    0.0
%     0032   Ex    2311-11         9.0  100.0
%     0033   Hy    2311-11        99.0    0.0
%     0034   Ey    2311-11        99.0  102.0
%     0035   Hz    2311-11         0.0    0.0
%     MissingDataFlag: 1.000e+09
%     DataSet:
%             Hx         Ex         Hy         Ey         Hz
%
% H-field units: nT
% E-field units: mv/km
%
% Notes:
% - automaitcally locates and copies binary files associated with each
%   ASCII file into new ASCII directory
% - checks for internet connection and if found the code automatically 
%   queries the national map elevation data base for site elevation
% - data gaps (i = 44444444) are automatically detected and set to null
%   factor
% - assumes that field channel pairs (e.g. Hx and Hy) are orthogonal.
%   E-field and H-field measurements can be misaligned (i.e. Hx and Ex do
%   not have to be parallel)
% - IMPORTANT: assumes that stations are named 'aaa999'. Survey ID is
%   first three characters of station name (from directory structure),
%   site ID is remainder of station name
%
%--------------------------------------------------------------------------
function[] = NIMS_asc_converter()
if isempty(strfind(pwd,'/'))
    slash = '\'; % Windows machines
else
    slash = '/'; % Mac machines
end
clc
%--------------------------------------------------------------------------
%                            START USER INPUT
%--------------------------------------------------------------------------
% Find all time series files and create time series ASCII directory tree
%--------------------------------------------------------------------------
% Identify project directory
% ex: /Volumes/hardrive/nims/project/
propath = uigetdir(home,'Select project data directory');
propath = [propath,slash];
% propath = '/Volumes/DATA/nims/rgr/';

% Determine location of new ASCII directory
ascpath = uigetdir(home,'Select place to put project ASCII folder');
ascpath = [ascpath,slash];
% ascpath = '/Volumes/DATA/';

% Name the ASCII directory
prompt = {'Give the survey a name (this will be the name of the ASCII directory):'};
scode = inputdlg(prompt,'Survey Name:');
ascdir = lower(scode{1});
% ascdir = 'nims_asc_upd';

% Select meta data file
[mfile,mpath] = uigetfile('*.txt','Pick a metadata file');
% mfile = 'meta_rgr_upd.txt';
% mpath = '/Users/danny/Desktop/USGS-DataRelease/';

% Electric field gain for this survey
ec = 2.441406e-6;

% Null factor (empty data spaces)
null_factor = 1e9;

% If check_hdr is set equal to 1, script will not write any real files but 
% will instead check header info for properly formatted sensor IDs and list
% improperly formatted headers. Good practice is to set check_hdr to 1, run
% script once, note improperly formatted sensor IDs, set check_hdr to zero,
% and run again with sensor ID information on hand.
check_hdr = 0;
scount = 0;
%--------------------------------------------------------------------------
%                          END USER INPUT
%--------------------------------------------------------------------------
% Assume the following structure for data directories:
% propath/data/site_folders/run_folders/run_files
datadir = [propath,'data',slash];
if isempty(dir(datadir)); error(['Data directory ',datadir,' not found.']); end
FoldersInDir = struct2cell(dir(datadir));
FolderNames = FoldersInDir(1,:);

% Eliminate inappropriate file and folder names 
% (e.g. any names including the strings '.','_','-')
findx = ones(size(FolderNames));
for tt = 1:length(FolderNames)
    iname = FolderNames{tt};
    if ~isempty(strfind(iname,'_')); findx(tt) = findx(tt)*0; end
    if ~isempty(strfind(iname,'-')); findx(tt) = findx(tt)*0; end
    if ~isempty(strfind(iname,'.')); findx(tt) = findx(tt)*0; end
end

% Compile list of stations and get station count
sta_list = FolderNames(logical(findx));
nsta = length(sta_list);

% Create ASCII directory for this project
if ~isdir([ascpath,ascdir])
    mkdir([ascpath,ascdir]); 
end

% Read multisite metadata file
% - use: station name,stationID,lat,lon,elev,azm*,nch*
% - write: acqdate,ex,ey (from info in ASCII headers)
fid0 = fopen([mpath,mfile],'r+');
meta = textscan(fid0,'%s%s%n%n%n%n%n%n%n%n%n%n');
fclose(fid0);
sta_name = meta{1}; % cell string array: must match folder names in data directory
sta_num = meta{2}; % cell string array
meta_lat = meta{3}; % float array
meta_lon = meta{4}; % float array
meta_elv = meta{5}; % float array
azm_hx = meta{6}; % float array
azm_ex = meta{7}; % float array
nch_wide = meta{11}; % float array
nch_long = meta{12}; % float array
% The following are dummy values that will be replaced during
% repeated calls to 'mine_hdr' function:
meta_acq = meta{8}; % float array (YYYYMMDD)
meta_ex = meta{9}; % float array
meta_ey = meta{10}; % float array
nmeta = length(sta_num);

% Iterate through each station:
for yy = 1:nsta
    isite = sta_list{yy}; % station list from reading data directory
    
    % Find this station in the metadata
    mindx = find(strcmp(sta_name,isite));
    if isempty(mindx)
        error(['No metadata found for ',isite]);
    end
   
    % These are 'global' because they are called in 'mine_hdr'
    site_lat = meta_lat(mindx);
    site_lon = meta_lon(mindx);
    site_hdir = azm_hx(mindx);
    site_edir = azm_ex(mindx);
    site_chn = nch_long(mindx);
    
    % If connected to the web, query national map elevation based on
    % provided latitude and longitude
    % If offline, use elevation from metadata file
    online = webcheck;
    if online == 1
       site_elev = natmaplook(site_lat,site_lon);
       if isempty(site_elev)
           % If unsuccessful, keep original elevation from metadata
          site_elev = meta_elv(mindx);
       else
           % If successful, correct metadata variable to reflect new elevation
           meta_elv(mindx) = site_elev;
       end
    else
        % Use elevation from meta data file
        site_elev = meta_elv(mindx);
    end

    % Hardwired site folder (based on assumed file structure)
    sitedir = [datadir,isite,slash];
    % Find run folders (based on assumed file structure)
    iruns = struct2cell(dir([sitedir,isite,'*']));
    run_list = iruns(1,:);
    
    % Create ASCII folder for this station
    savefile = [ascpath,ascdir,slash,isite];
    if ~isdir(savefile)
        mkdir(savefile); 
    end
        
    % Count # runs for this site
    nruns = length(run_list);
    
    % Iterate over each run at this station
    for jj = 1:nruns
        irun = run_list{jj};
        
        % Find time series file for this run
        tsfile = struct2cell(dir([sitedir,irun,slash,'*.asc']));
        tsfiles = tsfile(1,:);
        if length(tsfiles) > 1
            tsfile = tsfiles{end};
        else
            tsfile = tsfiles{1};
        end
        asc_file = [sitedir,run_list{jj},slash,tsfile];
        
        % New filename for converted ASCII time series
        new_file = [savefile,slash,irun,'_converted.asc'];
        
        % Count lines in header block (denoted by #), skim relevant info
        % from original header, and print reformatted header to new ASCII
        fid1 = fopen(asc_file,'r');
        fid2 = fopen(new_file,'w+');
        [dex,dey,fcount] = mine_hdr(isite,irun,fid1,fid2);
        
        % Read data block from old ASCII file
        if check_hdr == 0
            fid1 = fopen(asc_file,'r');
            if site_chn == 4
                data = textscan(fid1,'%n%n%n%n','HeaderLines',fcount);
            else
                data = textscan(fid1,'%n%n%n%n%n','HeaderLines',fcount);
            end
            fclose(fid1);

            % Auto search for data gaps
            gap_indx = find(data{1}==44444444);

            % Convert time series to real units
            hx = data{1}/100;
            hy = data{2}/100;
            if site_chn == 4
                ex = data{3}*ec*1000/dex;
                ey = data{4}*ec*1000/dey;
            else
                hz = data{3}/100;
                ex = data{4}*ec*1000/dex;
                ey = data{5}*ec*1000/dey;
            end
            
            % Assign time series to data block
            if site_chn == 5
                data_block = [hx ex hy ey hz];
            else % 4-channel data and 5-channel data with bad Hz
                data_block = [hx ex hy ey];
            end
                
            % Null out data gaps
            if ~isempty(gap_indx)
                data_block(gap_indx,:) = null_factor;
            end

            % Print data block to new ASCII file
            if site_chn == 5
                fprintf(fid2,'%10.2f %10.5f %10.2f %10.5f %10.2f\n',data_block');
            else
                fprintf(fid2,'%10.2f %10.5f %10.2f %10.5f\n',data_block');
            end
            fclose(fid2);
        else
            fclose(fid2);
        end
        
        % Find and copy binary time series file into new ASCII directory
        bnfile = struct2cell(dir([sitedir,irun,slash,'*.bnn']));
        if isempty(bnfile)
            bnfile = struct2cell(dir([sitedir,irun,slash,'*.bin']));
        end
        if ~isempty(bnfile)
            bnfiles = bnfile(1,:);
            if length(bnfiles) > 1
                bnfile = bnfiles{end};
            else
                bnfile = bnfiles{1};
            end
            bin_file = [sitedir,run_list{jj},slash,bnfile];
            if check_hdr == 0
                copyfile(bin_file,[savefile,slash,char(bnfile)]);
            end
        end
    end
end

% Rewrite meta data file with skimmed header info
if check_hdr == 0
    fid4 = fopen([mpath,'new_',mfile],'w+');
    for ww = 1:nmeta
        mblock = [meta_lat(ww),meta_lon(ww),meta_elv(ww),azm_hx(ww),azm_ex(ww),...
            meta_acq(ww),meta_ex(ww),meta_ey(ww),nch_wide(ww),nch_long(ww)];
        fprintf(fid4,'%s %s %10.5f %10.5f %10.2f %10.1f %10.1f %10i %10.1f %10.1f %10i %10i\n',...
            sta_name{ww},sta_num{ww},mblock);
    end
    fclose(fid4);
end
%--------------------------------------------------------------------------
% @mine_hdr: extract meta data from original header file and print
% reformatted header to new ASCII file
%--------------------------------------------------------------------------
    function [iex,iey,icount] = mine_hdr(site,run,h1,h2)
        % Read and store full header block
        hdr_end = 1; icount = 0;
        while hdr_end > 0
            tline = fgetl(h1);
            if tline(1)~='#'
                hdr_end = 0;
            else
                icount = icount+1;
                hdr_block{icount} = tline;
            end
        end
        % Close original ASCII file
        fclose(h1);
        
        % Read survey, site, and run IDs
        if length(site)<4
            % Prompt manual entry of survey code and site ID if site name
            % is less than 4 characters long
            prompt = {'ASCII file','Survey Name:','Site ID:'};
            scode = inputdlg(prompt,'Meta Data Entry',[1;1;1],{run;'AAA';'999'});
            surveyid = upper(scode{2});
            siteid = scode{3};
        else
            surveyid = upper(site(1:3));
            siteid = site(4:end);
        end
        
        % Read NIMS box and mag IDs
        sys_indx = 0;
        for gg = 1:length(hdr_block)
            if ~isempty(strfind(char(hdr_block{gg}),'SYSTEM BOX'))
                sys_indx = gg;
            end
        end
        if sys_indx ~= 0
            cline = strsplit(hdr_block{sys_indx});
            box_id = cline{2}(1:end-1);
            mag_id = cline{3};
        end
        
        % Check box and mag ID
        valid_string = {'0','1','2','3','4','5','6','7','8','9','-'};
        if sys_indx ~= 0
            bcount = 0; done = 0; vid = 1;
            while done == 0
                bcount = bcount+length(strfind(box_id,valid_string{vid}));
                if bcount == length(box_id)
                    done = 1;
                else
                    vid = vid+1;
                end
                if vid == 12
                    done = 1;
                    sys_indx = 0;
                end
            end
        end
        if sys_indx ~= 0
            mcount = 0; done = 0; vid = 1;
            while done == 0
                mcount = mcount+length(strfind(mag_id,valid_string{vid}));
                if mcount == length(mag_id)
                    done = 1;
                else
                    vid = vid+1;
                end
                if vid == 12
                    done = 1;
                    sys_indx = 0;
                end
            end
        end
        % Ask for manual entry of box and mag IDs if header entries were
        % not properly formatted
        if sys_indx == 0
            if check_hdr == 0
                beep; beep; beep;
                switch run
                    case 'rgr006b'
                        fprintf('Found 006b\n');
                        box_id = '2311-14'; mag_id = box_id;
                    case 'rgr023a'
                        fprintf('Found 023a\n');
                        box_id = '1105-5'; mag_id = box_id;
                    case 'rgr104b'
                        fprintf('Found 104b\n');
                        box_id = '2311-12'; mag_id = '2311-13';
                    case 'rgr202a'
                        fprintf('Found 202a\n');
                        box_id = '2311-8'; mag_id = box_id;
                    case 'rgr206a'
                        fprintf('Found 206a\n');
                        box_id = '1105-2'; mag_id = box_id;
                    case 'rgr209b'
                        fprintf('Found 209b\n');
                        box_id = '2311-11'; mag_id = box_id;
                    otherwise
                        prompt = {['NIMS ID# (',run,'):'];'Fluxgate ID#:'};
                        sys = inputdlg(prompt,'',[1;1],{'',''});
                        box_id = sys{1};
                        mag_id = sys{2};
                end
            else
                scount = scount+1;
                if scount == 1
                    fprintf('Need sensor IDs for the following runs:\n');
                    fprintf(' %s\n',run);
                else
                    fprintf(' %s\n',run);
                end
            end
        end
        
        % Read dipole information
        % Locations come from metadata file
        plabel = {'Ex dipole length (m)','Ey dipole length (m)'};
        loc_indx = zeros(2,1); loc_info = loc_indx;
        for gg = 1:length(hdr_block)
            if ~isempty(strfind(char(hdr_block{gg}),'Ex WIRE LENGTH'))
                loc_indx(1) = gg;
            end
            if ~isempty(strfind(char(hdr_block{gg}),'Ey WIRE LENGTH'))
                loc_indx(2) = gg;
            end
        end
        for hh = 1:2
            hpass = 1;
            if loc_indx(hh) == 0
                hpass = 0;
            else
                cline = strsplit(hdr_block{loc_indx(hh)});
                iloc = str2double(cline{2});
                if isnan(iloc)
                    hpass = 0;
                else
                    loc_info(hh) = iloc;
                end
            end
            if hpass == 0
                prompt = {['Please enter a value for ',plabel{hh},...
                    ' for site ',siteid]};
                mloc = inputdlg(prompt,'',1,{''});
                loc_info(hh) = str2double(mloc{1});
            end
        end
        % Double-check dipole lengths
        dipole_yes = 0;
        while dipole_yes ~= 1
            for kk = 1:2
                if loc_info(kk) < 0 || loc_info(kk) > 400
                    prompt = {['Please enter a value for ',plabel{kk},...
                        ' for site ',siteid]};
                    mloc = inputdlg(prompt,'',1,{''});
                    loc_info(kk) = str2double(mloc{1});
                else
                    dipole_yes = 1;
                end
            end
        end
        % Read acquisition start, sampling rate, and # records
        alabel = {'# data scans','scan interval (seconds)','1st scan (yyyy mm dd hh mm ss)'};
        acq_indx = zeros(3,1); acq_info = cell(size(acq_indx));
        for gg = 1:length(hdr_block)
            if ~isempty(strfind(char(hdr_block{gg}),'== total number of'))
                acq_indx(1) = gg;
            end
            if ~isempty(strfind(char(hdr_block{gg}),'== data scan'))
                acq_indx(2) = gg;
            end
            if ~isempty(strfind(char(hdr_block{gg}),'== 1st data'))
                acq_indx(3) = gg;
            end
        end
        for hh = 1:length(acq_indx)
            if acq_indx(hh) == 0
                prompt = {['Please enter a value for ',alabel{hh},' for site ',siteid]};
                mloc = inputdlg(prompt,'',1,{''});
                acq_info{hh} = mloc{1};
            else
                cline = strsplit(hdr_block{acq_indx(hh)});
                if hh < 3
                    acq_info{hh} = str2double(cline{2});
                else
                    acq_info{hh} = cline{2};
                    for pp = 3:7
                        acq_info{hh} = [acq_info{hh},' ',cline{pp}];
                    end
                end
            end
        end
        % Assemble start date:
        idate = strsplit(acq_info{3});
        for dd = 2:6
            if str2double(idate{dd}) < 10; idate{dd} = ['0',idate{dd}]; end
        end
        read_time = [idate{2},'.',idate{3},'.',idate{1},'-',idate{4},...
            ':',idate{5},':',idate{6}];

        % Collect acquisition start time:
        year = read_time(7:10);
        month = read_time(1:2);
        day = read_time(4:5);
        hour = read_time(12:13);
        minute = read_time(15:16);
        second = read_time(18:19);
        start_time = [year,'-',month,'-',day,'T',read_time(12:end),' UTC'];
        
        % Calculate acquisition stop time
        tstp = add_seconds({year,month,day,hour,minute,second},...
            acq_info{1},1/acq_info{2});
        stop_time = [num2str(tstp{1}),'-',tstp{2},'-',tstp{3},'T',...
                    tstp{4},':',tstp{5},':',tstp{6},' UTC'];

        % Determine number of data channels to write
        nch = nch_long(mindx);
        if nch == 5
            hdr_text = '        Hx         Ex         Hy         Ey         Hz';
            ichn = 5;
        else
            hdr_text = '        Hx         Ex         Hy         Ey';
            ichn = 4;
        end
        
        if check_hdr == 0
            % Print survey, site, and run IDs
            fprintf(h2,'SurveyID: %s\n',surveyid);
            fprintf(h2,'SiteID: %s\n',siteid);
            fprintf(h2,'RunID: %s\n',run);
            % Print location info
            fprintf(h2,'SiteLatitude: %0.5f\n',site_lat);
            fprintf(h2,'SiteLongitude: %0.5f\n',site_lon);
            fprintf(h2,'SiteElevation: %0.2f\n',site_elev);
            % Print acquisition times, samples, # records
            fprintf(h2,'AcqStartTime: %s\n',start_time);
            fprintf(h2,'AcqStopTime: %s\n',stop_time);
            fprintf(h2,'AcqSmpFreq: %0.5f\n',1/acq_info{2});
            fprintf(h2,'AcqNumSmp: %i\n',acq_info{1});
            % Print instrument serial numbers and channel info
            fprintf(h2,'Nchan: %i\n',ichn);
            fprintf(h2,'Channel coordinates relative to geographic north\n');
            fprintf(h2,'ChnSettings:\n');
            fprintf(h2,'ChnNum ChnID InstrumentID Azimuth Dipole_Length\n');
            fprintf(h2,'%s1   Hx %10s %11.1f    0.0\n',siteid,mag_id,site_hdir);
            fprintf(h2,'%s2   Ex %10s %11.1f %6.1f\n',siteid,box_id,site_edir,loc_info(1));
            fprintf(h2,'%s3   Hy %10s %11.1f    0.0\n',siteid,mag_id,site_hdir+90);
            fprintf(h2,'%s4   Ey %10s %11.1f %6.1f\n',siteid,box_id,site_edir+90,loc_info(2));
            if ichn == 5
                fprintf(h2,'%s5   Hz %10s %11.1f    0.0\n',siteid,mag_id,0);
            end
            fprintf(h2,'MissingDataFlag: %0.3e\n',null_factor);
            fprintf(h2,'DataSet:\n');
            fprintf(h2,'%s\n',hdr_text);
        end
        
        % Electric dipole lengths [m] in float:
        iex = loc_info(1);
        iey = loc_info(2);
        
        % Write dipole lengths to 'global' metadata variables
        meta_ex(mindx) = iex;
        meta_ey(mindx) = iey;
        
        % Assign start time to 'global' metadata variable (first run only)
        % Convert to YYYYMMDD format
        if strcmp(run,run_list{1})
            yy0 = str2double(idate{1});
            mm0 = str2double(idate{2});
            dd0 = str2double(idate{3});
            start_stamp = yy0*1e4 + mm0*1e2 + dd0;
            meta_acq(mindx) = start_stamp;
        end
end
%--------------------------------------------------------------------------
% @ add_seconds
%--------------------------------------------------------------------------
    function[ftime] = add_seconds(itime,nscans,sps)
        % This function is used to determine run end time provided the 
        % start time (itime), the total number of data scans (nscans), and 
        % the data scan rate in scans per second (sps).  Run script with 
        % nscans and sps equal to zero to simply reformat a time string.
        %
        % Inputs:
        % 1) itime: cell array of strings that define the start time for a run
        %    format itime = {'yyyy','mm','dd','hh','mm','ss'}
        % 2) nscans: number of data scans for the run
        % 3) sps: number of scans per second (e.g. scan interval=0.25 --> sps=4)

        % Output:
        % 1) ftime: cell array of strings the define the end time for a run
        %    format similar to that of itime
        %--------------------------------------------------------------------------
        % itime = {'2012','6','27','17','0','19'};
        % nscans = 2424656;
        % sps = 4;

        iyear = str2num(itime{1});
        imonth = str2num(itime{2});
        iday = str2num(itime{3});
        ihour = str2num(itime{4});
        imin = str2num(itime{5});
        isec = str2num(itime{6});

        new_sec = ceil(nscans/sps);

        % Check for timing data. Some headers have 0 0 0 0 0 0 time.  If this is
        % found, just make the start time 000000.

        if iyear == 0
            ftime = {0,'00','00','00','00','00'};
        else

        % Check for problems in input time
        if imonth > 12 || imonth < 1; error('Problem with input month'); end
        if iday > 31 || iday < 1; error('Problem with input day'); end
        if ihour > 23 || ihour < 0; error('Problem with input hour'); end
        if imin > 59 || imin < 0; error('Problem with input minute'); end
        if isec > 59 || isec < 0; error('Problem with input second'); end

        % Check for month-day pairs that don't make sense
        if imonth == 1 && iday > 31; error('January only has 31 days'); end
        if imonth == 3 && iday > 31; error('March only has 31 days'); end
        if imonth == 4 && iday > 30; error('April only has 30 days'); end
        if imonth == 5 && iday > 31; error('May only has 31 days'); end
        if imonth == 6 && iday > 30; error('June only has 30 days'); end
        if imonth == 7 && iday > 31; error('July only has 31 days'); end
        if imonth == 8 && iday > 31; error('August only has 31 days'); end
        if imonth == 9 && iday > 30; error('September only has 30 days'); end
        if imonth == 10 && iday > 31; error('October only has 31 days'); end
        if imonth == 11 && iday > 30; error('November only has 30 days'); end
        if imonth == 12 && iday > 31; error('December only has 31 days'); end

        % Days/month for year in which run starts
        if rem(iyear,4) == 0
            month_day = [31 60 91 121 152 182 213 244 274 305 335 366];
            if imonth == 2 && iday > 29; 
                error(['February only has 29 days in ',num2str(iyear)]); 
            end
        else
            month_day = [31 59 90 120 151 181 212 243 273 304 334 365];
            if imonth == 2 && iday > 28; 
                error(['February only has 28 days in ',num2str(iyear)]); 
            end
        end

        if nscans == 0
            fyear = iyear;
            fmonth = imonth;
            fday = iday;
            fhour1 = ihour;
            fmin1 = imin;
            fsec1 = isec;
        else

            % Determine day of year for start of run:
            if imonth > 1
                doy = month_day(imonth-1) + iday;
            else
                doy = iday;
            end

            start_sec = (doy-1)*24*60*60 + ihour*60*60 + imin*60 + isec;
            fsec0 = start_sec + new_sec;

            % Decompose final_sec into day:hour:min:sec
            fsec1 = round((fsec0/60 - floor(fsec0/60))*60);
            fmin0 = (fsec0-fsec1)/60;

            fmin1 = round((fmin0/60 - floor(fmin0/60))*60);
            fhour0 = (fmin0-fmin1)/60;

            fhour1 = round((fhour0/24 - floor(fhour0/24))*24);
            fday0 = (fhour0-fhour1)/24;

            fdoy = fday0+1;

            % Convert DOY into year-month-day
            if fdoy < 32
                fyear = iyear;
                fmonth = 1;
                fday = fdoy;
            elseif fdoy > 31 && fdoy <= month_day(end)
                fyear = iyear;
                fmonth = find(month_day == min(month_day(find(month_day-fdoy >= 0))));
                fday = fdoy - month_day(fmonth-1);
            else
                fyear = iyear + 1;
                fdoy = fdoy-month_day(end);
                if fdoy < 32
                    fmonth = 1;
                    fday = fdoy;
                else
                    fmonth = find(month_day == min(month_day(find(month_day-fdoy >= 0))));
                    fday = fdoy - month_day(fmonth-1);
                end
            end
        end

        % Check for problems in final time
        if fmonth > 12 || fmonth < 1; error('Problem with final month'); end
        if fday > 31 || fday < 1; fprintf(['final day = ',num2str(fday)]); error('Problem with final day'); end
        if fhour1 > 23 || fhour1 < 0; error('Problem with final hour'); end
        if fmin1 > 59 || fmin1 < 0; error('Problem with final minute'); end
        if fsec1 > 59 || fsec1 < 0; error('Problem with final second'); end

        % Convert final time to appropriate strings
        if fmonth > 9;
            fmonth = num2str(fmonth);
        else
            fmonth = ['0',num2str(fmonth)];
        end
        if fday > 9
            fday = num2str(fday);
        else
            fday = ['0',num2str(fday)];
        end
        if fhour1 > 9
            fhour = num2str(fhour1);
        else
            fhour = ['0',num2str(fhour1)];
        end
        if fmin1 > 9
            fmin = num2str(fmin1);
        else
            fmin = ['0',num2str(fmin1)];
        end
        if fsec1 > 9
            fsec = num2str(fsec1);
        else
            fsec = ['0',num2str(fsec1)];
        end

        ftime = {fyear,fmonth,fday,fhour,fmin,fsec};
        end
    end
%--------------------------------------------------------------------------
% @natmaplook: query national map elevation database
%--------------------------------------------------------------------------
    function[elevation] = natmaplook(lat,lon)
        str1 = num2str(lon,9);
        str2 = num2str(lat,9);
        url = ['https://nationalmap.gov/epqs/pqs.php?x=',str1,'&y=',str2,'&units=Meters&output=xml'];
        elevation = [];
        try
            html_str = urlread(url);
            indx1 = regexp(html_str,'<Elevation>');
            indx2 = regexp(html_str,'</Elevation>');
            elevation = str2double(html_str(indx1+11:indx2-1));
        end
    end
%--------------------------------------------------------------------------
% @ webcheck: determine if this computer is is connected to the
% internet. returns 1 if true, 0 if false
%--------------------------------------------------------------------------
function[tf] = webcheck(~,~)
    tf = false;
    try
        address = java.net.InetAddress.getByName('www.google.com');
        tf = true;
    end
end
%--------------------------------------------------------------------------
end