% mt24_asc_converter.m
%--------------------------------------------------------------------------
% Danny Feucht                                  daniel.feucht@colorado.edu
% Department of Geological Sciences
% University of Colorado at Boulder
% Created: 12 June 2017
% Updated: 25 April 2018
%--------------------------------------------------------------------------
% Convert binary time series files output by EMTF into standard format ASCII
% files for U.S. Geological Survey data release
% 
% Output file naming convention (ex: for site 003)
%       your_dir_name_here/003/[JNL]dddhhmm.asc
%
% Header format - converted ASCII file (ex: run J2332204 at site rgr003)
%     SurveyID: RGR
%     SiteID: 003
%     RunID: J2332204
%     SiteLatitude: 39.28200
%     SiteLongitude: -108.15820
%     SiteElevation: 1803.07
%     AcqStartTime: 2012-08-21T22:05:00 UTC
%     AcqStopTime: 2012-08-21T22:10:01 UTC
%     AcqSmpFreq: 500.00000
%     AcqNumSmp: 150016
%     Nchan: 5
%     Channel coordinates relative to geographic north
%     ChnSettings:
%     ChnNum ChnID RespFile      Azimuth  Dipole_Length
%     0031   Hx    HF4-0309.RSP     9.0     0.0
%     0032   Ex    EF-24-HF.RSP     9.0   100.0
%     0033   Hy    HF4-0319.RSP    99.0     0.0
%     0034   Ey    EF-24-HF.RSP    99.0   102.0
%     0035   Hz    HF7-8011.RSP     0.0     0.0
%     MissingDataFlag: NaN
%     DataSet:
%             Hx         Ex         Hy         Ey         Hz
%
% H-field units: ???
% E-field units: mv/km
%
% Notes:
% - automatically locates and copies RSP files associated with each run
%   into new ascii directory
% - assumes that field channel pairs (e.g. Hx and Hy) are orthogonal.
%   E-field and H-field measurements can be misaligned (i.e. Hx and Ex do
%   not have to be parallel)

% TO DO URGENT
% - determine units for mag field
%--------------------------------------------------------------------------
function[] = mt24_asc_converter()
if isempty(strfind(pwd,'/'))
    slash = '\'; % Windows machines
else
    slash = '/'; % Mac machines
end
clc
%--------------------------------------------------------------------------
% Find all time series files and create time series ASCII directory tree
%--------------------------------------------------------------------------
% Identify project directory
% ex: /Volumes/hardrive/mt24/project/
propath = uigetdir(home,'Select project data directory');
propath = [propath,slash];
% propath = '/Volumes/DATA/mt24/rgr/';

% Determine location of new ASCII directory
ascpath = uigetdir(home,'Select place to put project ASCII folder');
ascpath = [ascpath,slash];
% ascpath = '/Volumes/DATA/';

% Name the ASCII directory
prompt = {'Give the survey a name (this will be the name of the ASCII directory):'};
scode = inputdlg(prompt,'Survey Name:');
ascdir = lower(scode{1});
% ascdir = 'mt24_asc_upd';

% Select meta data file
[mfile,mpath] = uigetfile('*.txt','Pick a metadata file');
% mfile = 'meta_rgr_upd.txt';
% mpath = '/Users/danny/Desktop/USGS-DataRelease/';

% Folder name prefix (ex: data for station 003 is in folder 'site003')
prefix = 'site';
%--------------------------------------------------------------------------
%                          END USER INPUT
%--------------------------------------------------------------------------
% Assume the following structure for data and sensor directories:
% propath/data/data_folders/run_folders/run_files
% propath/sensors/sensor_files
datadir = [propath,'data',slash];
if isempty(dir(datadir)); error(['Data directory ',datadir,' not found.']); end
sendir = [propath,'sensors',slash];
if isempty(dir(sendir)); error(['Data directory ',sendir,' not found.']); end
FoldersInDir = struct2cell(dir(datadir));
FolderNames = FoldersInDir(1,:);

% Eliminate inappropriate file and folder names 
% (including the strings '.','_','-','site')
findx = ones(size(FolderNames));
for tt = 1:length(FolderNames)
    iname = FolderNames{tt};
    if ~isempty(strfind(iname,'_')); findx(tt) = findx(tt)*0; end
    if ~isempty(strfind(iname,'-')); findx(tt) = findx(tt)*0; end
    if ~isempty(strfind(iname,'.')); findx(tt) = findx(tt)*0; end
    if isempty(strfind(iname,prefix)); findx(tt) = findx(tt)*0; end
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
% - write: acqdate,ex,ey (from info in band file)
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

% Define proper channel order
ch_order = {'Hx','Ex','Hy','Ey','Hz','Ez'};

% Repeat for each station
for yy = 1:nsta
    % station list from reading data directory
    isite = sta_list{yy}(length(prefix)+1:end); 
    
    % Find this station in the metadata
    mindx = find(strcmp(sta_num,isite));
    if isempty(mindx)
        error(['No metadata found for ',isite]);
    end
    
    % Use lat,lon,xdir from metadata file
    site_lat = meta_lat(mindx);
    site_lon = meta_lon(mindx);
    site_hdir = azm_hx(mindx);
    site_edir = azm_ex(mindx);
    site_chn = nch_wide(mindx);

    % Determine number of data channels to write
    if site_chn == 5
        hdr_text = '        Hx         Ex         Hy         Ey         Hz';
        ichn = 5;
    else
        hdr_text = '        Hx         Ex         Hy         Ey';
        ichn = 4;
    end
        
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
    sitedir = [datadir,prefix,isite,slash,isite,slash];
    
    % Collect all files for this station
    % Identify run folders
    jpass = 1; npass = 1; Lpass = 1;
    ifolder = [datadir,prefix,isite,slash,isite];
    jfiles = struct2cell(dir([ifolder,slash,'J*']));
    nfiles = struct2cell(dir([ifolder,slash,'N*']));
    Lfiles = struct2cell(dir([ifolder,slash,'L*']));
    dfiles = cell(1,3);
    
    % Check for lower case J-band files
    if isempty(jfiles)
        jfiles = struct2cell(dir([ifolder,slash,'j*']));
        if isempty(jfiles)
            fprintf('WARNING: no J-band run files found for site %s.\n',isite)
            jpass = 0;
        end
    end
    if jpass == 1; dfiles{1} = jfiles(1,:); end
    % Check for lower case N-band files
    if isempty(nfiles)
        nfiles = struct2cell(dir([ifolder,slash,'n*']));
        if isempty(nfiles)
            fprintf('WARNING: no N-band run files found for site %s.\n',isite)
            npass = 0;
        end
    end
    if npass == 1; dfiles{2} = nfiles(1,:); end
    % Check for lower case L-band files
    if isempty(Lfiles)
        Lfiles = struct2cell(dir([ifolder,slash,'l*']));
        if isempty(Lfiles)
            fprintf('WARNING: no L-band run files found for site %s.\n',isite)
            Lpass = 0;
        end
    end
    if Lpass == 1; dfiles{3} = Lfiles(1,:); end
    all_pass = [jpass npass Lpass];

    if sum(all_pass) > 0
       % Create ASCII folder for this station
       savefile = [ascpath,ascdir,slash,isite];
        if ~isdir(savefile)
            mkdir(savefile); 
        end
    end

    % Read and convert each set of time series files into one ASCII
    % Cycle through all three bands (J, N, L) 
    surveyid = [];
    for tt = 1:3
        if all_pass(tt) == 1
            % Collect all runs for this site at this freq band
            ufiles = dfiles{tt};
            nruns = length(ufiles);

            % Identify time series file names for each run at this band
            for jj = 1:nruns
                irun = ufiles{jj};
                % Name ASCII file for this run
                nfile = [savefile,slash,irun,'.asc'];
                % Find band file
                bfile = struct2cell(dir([sitedir,irun,slash,'*.b*']));
                if size(bfile,2) > 1
                    bfile = bfile(:,2);
                end
                bfile = [sitedir,irun,slash,char(bfile(1,:))];

                % Set up empty cell arrays to receive header info 
                % (one cell per channel)
                if jj == 1
                    rcount = 1;
                    chstr = cell(6,1);
                    chdir = cell(6,1);
                    rsp_file = cell(6,1);
                    igain = nan(6,1);
                    vsmpl = nan(6,1);
                    dipole = nan(6,1);
                end

                % Read band file and find relevant header info
                fid1 = fopen(bfile,'r');
                site_end = 0;
                while site_end == 0
                    hline = fgetl(fid1);
                    hline = strtrim(hline);
                    hline = strsplit(hline);
                    if jj == 1
                        switch hline{1}
                            case 'SurveyID:'
                                if isempty(surveyid)
                                    surveyid = hline{2};
                                end
                            case 'AcqStartTime:'
                                read_time = hline{2};
                            case 'AcqSmpFreq:'
                                sps = hline{2};
                            case 'AcqNumSmp:'
                                nrec = hline{2};
                            case 'ChnSettings:'
                                chstr{rcount} = [upper(hline{3}),lower(hline{4}(2))];
                                chdir{rcount} = hline{4}(1);
                                rsp_file{rcount} = hline{6};
                                igain(rcount) = str2double(hline{7});
                                vsmpl(rcount) = str2double(hline{14});
                            case 'ChnCoord:'
                                dipole(rcount) = str2double(hline{5});
                                rcount = rcount+1;
                        end
                        if rcount == 7; site_end = 1; end
                    else
                        if strcmp(hline{1},'AcqStartTime:')
                            read_time = hline{2};
                        end
                        if strcmp(hline{1},'ChnSettings:')
                            site_end = 1;
                        end
                    end
                end
                fclose(fid1);
                     
                % Construct proper order channel settings
                chn_map = zeros(6,1);
                for cc = 1:6
                    chid = ch_order{cc};
                    chn_map(cc) = find(strcmp(chid,chstr));
                end
                % If channels are out of order, flip them around according
                % to channel map
                if sum(chn_map == [1:6]') < 6
                    chstr = chstr(chn_map);
                    chdir = chdir(chn_map);
                    vsmpl = vsmpl(chn_map);
                    igain = igain(chn_map);
                    rsp_file = rsp_file(chn_map);
                    dipole = dipole(chn_map);
                end
                
                % Collect acqusition start time
                year = read_time(7:10);
                month = read_time(1:2);
                day = read_time(4:5);
                hour = read_time(12:13);
                minute = read_time(15:16);
                second = read_time(18:19);
                start_time = [year,'-',month,'-',day,'T',...
                    read_time(12:end),' UTC'];
                
                % Calculate acquisition stop time
                tstp = add_seconds({year,month,day,hour,minute,second},...
                    str2double(nrec),str2double(sps));
                stop_time = [num2str(tstp{1}),'-',tstp{2},'-',tstp{3},'T',...
                    tstp{4},':',tstp{5},':',tstp{6},' UTC'];
    
                % Print band file header info to new ASCII file:
                fid2 = fopen(nfile,'w+');
                % Print survey, site, and run IDs
                fprintf(fid2,'SurveyID: %s\n',surveyid);
                fprintf(fid2,'SiteID: %s\n',isite);
                fprintf(fid2,'RunID: %s\n',irun);
                % Print location info
                fprintf(fid2,'SiteLatitude: %0.5f\n',site_lat);
                fprintf(fid2,'SiteLongitude: %0.5f\n',site_lon);
                fprintf(fid2,'SiteElevation: %0.2f\n',site_elev);
                % Print acquisition times, samples, # records
                fprintf(fid2,'AcqStartTime: %s\n',start_time);
                fprintf(fid2,'AcqStopTime: %s\n',stop_time);
                fprintf(fid2,'AcqSmpFreq: %s\n',sps);
                fprintf(fid2,'AcqNumSmp: %s\n',nrec);
                % Print instrument serial numbers and channel info
                fprintf(fid2,'Nchan: %i\n',ichn);
                fprintf(fid2,'Channel coordinates relative to geographic north\n');
                fprintf(fid2,'ChnSettings:\n');
                fprintf(fid2,'ChnNum ChnID RespFile      Azimuth  Dipole_Length\n');
                for cc = 1:ichn
                    switch chstr{cc}
                        case 'Hx'
                            azm = site_hdir;
                        case 'Hy'
                            azm = site_hdir+90;
                        case 'Ex'
                            azm = site_edir;
                        case 'Ey'
                            azm = site_edir+90;
                        otherwise
                            azm = 0;
                    end
                    fprintf(fid2,'%s %4s %15s %7.1f %7.1f\n',...
                        [isite,num2str(cc)],chstr{cc},upper(rsp_file{cc}),...
                        azm,dipole(cc));
                end
                fprintf(fid2,'MissingDataFlag: NaN\n');
                fprintf(fid2,'DataSet:\n');
                fprintf(fid2,'%s\n',hdr_text);
                fclose(fid2);

                % Find time series files for this run
                sfiles = struct2cell(dir([sitedir,irun,slash,'*.t*']));
                sfiles = sfiles(1,:);
                if length(sfiles) < 6
                    error('One or more time series files missing for run %s at site %s.\n',irun,isite);
                end
%--------------------------------------------------------------------------
% CALCULATE CONVERSION TO PHYSICAL UNITS - NEEDS VERIFICATION
                % Convert electrics to mv/km
                % data = data*flip*vps*1000/(gain*dy);
                % Convert magnetics to nT/s?
                % data = data*flip*vps/(gain*100);
                dp = dipole;
                % Multiplication factor (H = 0.01, E = 1000)
                mf = zeros(size(dp));
                mf(dp~=0) = 1e3;
                mf(dp==0) = 0.01;
                dp(dp==0) = 1;
                flip0 = strcmp(chdir,'+');
                flip = flip0-(flip0==0);
                scale = flip.*vsmpl.*mf./(igain.*dp);
%-------------------------------------------------------------------------- 
% READ BINARY TIME SERIES FILES
                % Read and convert each time series file to data block
                for cc = 1:6 
                    % Identify the binary time series file to convert
                    tsfile = [sitedir,irun,slash,sfiles{cc}];
                    % BIN 2 ASCII conversion
                    idata = bin2ascii(tsfile,scale(cc,:));
                    if cc == 1
                        data_block = zeros(length(idata),6);
                    end
                    dindx = chn_map(cc);
                    data_block(:,dindx) = idata;
                end
%--------------------------------------------------------------------------
% WRITE DATA BLOCK TO NEW ASCII
                % Open new time series ascii
                fid3 = fopen(nfile,'a+');
                if ichn == 5
                    % Do not use Ez data
                    data_block = data_block(:,1:5);
                    fprintf(fid3,'%10.6f %10.5f %10.6f %10.5f %10.6f\n',data_block');
                else
                    % Do not use Ez or Hz data
                    data_block = data_block(:,1:4);
                    fprintf(fid3,'%10.6f %10.5f %10.6f %10.5f\n',data_block');
                end
                fclose(fid3);
                
                % Copy rsp files to new ASCII file directory
                % assign dipole lengths to meta data variables
                if jj == 1
                    get_files = unique(rsp_file);
                    for ff = 1:length(get_files)
                        gfile = get_files{ff};
                        copyfile([sendir,gfile],[savefile,slash,gfile])
                    end
                    % Write dex, dey, acq. date to metadata variables
                    meta_ex(mindx) = dipole(2);
                    meta_ey(mindx) = dipole(4);
                    yy0 = str2double(year);
                    mm0 = str2double(month);
                    dd0 = str2double(day);
                    start_stamp = yy0*1e4 + mm0*1e2 + dd0;
                    meta_acq(mindx) = start_stamp;
                end
            end
        end
    end
end

% Rewrite meta data file
fid4 = fopen([mpath,'new_',mfile],'w+');
for ww = 1:nmeta
    mblock = [meta_lat(ww),meta_lon(ww),meta_elv(ww),azm_hx(ww),azm_ex(ww),...
        meta_acq(ww),meta_ex(ww),meta_ey(ww),nch_wide(ww),nch_long(ww)];
    fprintf(fid4,'%s %s %10.5f %10.5f %10.2f %10.1f %10.1f %10i %10.1f %10.1f %10i %10i\n',...
        sta_name{ww},sta_num{ww},mblock);
   
end
fclose(fid4);

%--------------------------------------------------------------------------
% UTILITY FUNCTIONS
%--------------------------------------------------------------------------
% @bin2ascii: convert .bin file into .asc file
%  input - full directory path of time series file to convert
%  conv - scale factor
%--------------------------------------------------------------------------
    function[data] = bin2ascii(input,conv)
        % Collect time series data
        fid = fopen(input,'r+');
        all_data = fread(fid,inf,'int32');
        fclose(fid);
        % Chop off header block
        tdata = all_data(1025:end);

        % Convert time series data from counts to real units
        % see file dnff/emi_gtsp.f in EMTF processing code
        % Convert electrics to mv/km and magnetics to nT/s(?)
        data = tdata*conv;
        
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
        %    format itime = {'year','month','day','hour','min','sec'}
        % 2) nscans: number of data scans for the run
        % 3) sps: number of scans per second (e.g. scan interval=0.25 --> sps=4)

        % Output:
        % 1) ftime: cell array of strings the define the end time for a run
        %    format similar to that of itime described above
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
            if imonth == 2 && iday > 29
                error(['February only has 29 days in ',num2str(iyear)]); 
            end
        else
            month_day = [31 59 90 120 151 181 212 243 273 304 334 365];
            if imonth == 2 && iday > 28 
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

            if fhour1==24
                fhour1 = 0;
                fday0 = fday0+1;
            end
            
            fdoy = round(fday0+1);

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
        if fmonth > 9
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
