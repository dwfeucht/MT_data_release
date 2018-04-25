% edi_converter_v2.m
%--------------------------------------------------------------------------
% Danny Feucht                                  daniel.feucht@colorado.edu
% Department of Geological Sciences
% University of Colorado at Boulder
% Created: 6 July 2017
% Updated: 25 April 2018
%--------------------------------------------------------------------------
% 25 Apr 2018 - updated metadata file format (12 columns now)
% 18 Jan 2018 - Now with drop down menus!
% Now compatible with MATLAB 2017b!
% Now allows for whitespace between "SECTID=" and site name in EDI file.
%--------------------------------------------------------------------------
% Convert various forms of MT transfer function files into standard format
% EDI files.
% 
% Input file types:
%   a) Egbert format (*.z* files)
%   b) Impedance EDI (*.edi files)
%   c) Spectra EDI (*.edi files)
%   d) Zonge format (*.avg files)
%   e) Excel data (*.xls* files)
%
% Notes on # channels
% Notes on data rotation
% Notes on error rotation
%--------------------------------------------------------------------------
% METADATA TEXT FILE - NEED TO UPDATE THIS DOCUMENTATION
% A metadata text file is required for batch processing.
% Batch processing includes auotmated conversion of multiple files of 
% similar type OR conversion of one multisite spectra EDI into multiple 
% separate EDI files
%
% Metadata text file format requires AT LEAST six columns as follows:
%
% station_name  station_#   latitude   longitude   elevation   azimuth
%     999ga       009       dd.ddddd   -ddd.dddd   dddd.dd     dd
%    rgr003       003       dd.ddddd   -ddd.dddd   dddd.dd     dd
%     cp016       016       dd.ddddd   -ddd.dddd   dddd.dd     dd
%    site11       011       dd.ddddd   -ddd.dddd   dddd.dd     dd
%
% where station_name is identical to the file being converted (minus the
% extension, e.g., rgr003 for file rgr003.zmm)
%
% For multisite spectra EDI files, the metadata text file should have the
% following format:
%
% station_name  station_#   latitude   longitude   elevation   azimuth
%    jemez-1       001       dd.ddddd   -ddd.dddd   dddd.dd     dd
%    jemez-2       002       dd.ddddd   -ddd.dddd   dddd.dd     dd
%    jemez-3       003       dd.ddddd   -ddd.dddd   dddd.dd     dd
%    jemez-4       004       dd.ddddd   -ddd.dddd   dddd.dd     dd
%
% where station_name is identical to the data identifier (SECTID) that 
% proceeds each block of spectra data in the existing EDI file 
%
% there are three optional columns that may be included with either type of
% metadata file:
%     acqdate   ex_dipole(m)   ey_dipole(m)
%    mm/dd/yy      100            100
%
%--------------------------------------------------------------------------
% Output file format
%   One EDI file per site containing the following transfer functions:
%     - FREQ
%     - ZXXR, ZXXI, ZXX.VAR
%     - ZXYR, ZXYI, ZXY.VAR
%     - ZYXR, ZYXI, ZYX.VAR
%     - ZYYR, ZYYI, ZYY.VAR
%     - TXR, TXI, TXVAR.EXP (if 5 channels were recorded)
%     - TXR, TYI, TYVAR.EXP (if 5 channels were recorded)
%   PNG print out of transfer functions vs. period including:
%     - apparent resistivity (ohm-meters)
%     - impedance phase (degrees)
%     - complex tipper (TX and TY) (if 5 channels were recorded)
%   
%--------------------------------------------------------------------------
% TO DO URGENT:
% 
%--------------------------------------------------------------------------
function[] = edi_converter_v2()
%--------------------------------------------------------------------------
close all; clc
home = pwd;
if isempty(strfind(pwd,'/'))
    slash = '\'; % Windows machines
else
    slash = '/'; % Mac machines
end
home = [home,slash];
ipath = home;
wbox = [];
rad2deg = 180/pi;
plots_only = 0;
nat_map_on = 0;
ftype = [];
fs1 = 12;
fs2 = 14;
%--------------------------------------------------------------------------
xpercent = 0.20;
survey_opts = {'default','DRIFTER - Denver','DRIFTER - Taos',...
    'DRIFTER - Las Cruces','Jemez - Unocal 1983','SAGE 2017'...
    'SAGE 1991','SAGE 1992','SAGE 1993','SAGE 1994','SAGE 1995',...
    'SAGE 1996','SAGE 1998','SAGE 1999','SAGE 2010','SAGE 2011',...
    'SAGE 2012','SAGE 2013','SAGE 2014','SAGE 2015','SAGE 2016',...
    'EarthScope'};
%--------------------------------------------------------------------------
% Default survey wide metadata
def_proj = 'TITLE';
def_line = 'Location';
def_country = 'USA';
def_state = 'NM';
def_year = '2018';
def_acqby = 'U.S. Geological Survey';
def_procby = 'U.S. Geological Survey';
def_software = 'mtmerge/mtft/mtedit';
def_fileby = 'U.S. Geological Survey';
def_desc = ['Survey description goes here. This can include location',...
    ' details, survey parameters, instrumentation, etc.'];
%--------------------------------------------------------------------------
test_mode = 0;
test_gdrop = 3; % 2 = zmm, 3 = impedance, 4 = spectra, 5 = avg, 6 = xls
test_fdrop = 2; % 1 = single file. 2 = directory, 3 = multi spectra
% test_path = '/Users/danny/Desktop/DRIFTER_updated/ZMM_updated_12.08.17/';
% test_file = 'rgr018.zmm';
test_path = '/Users/danny/Desktop/SAGE_MT_archive/Jiracek_SAGE_EDI_raw/';
% test_file = 'jemez2.edi';
test_mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
test_mfile = 'meta_SAGE17.txt';
test_spin = 2; % 2 = geograph, 3 = geomag, 4 = acq, 5 = unknown
%--------------------------------------------------------------------------
%             DEFINE FIGURE PARAMETERS AND DRAW FIGURE
%               (skip to line 550 for rest of code)
%--------------------------------------------------------------------------
% Border width (in pixels, defined by screen size)
scrsize = get(0,'ScreenSize');
br = max(scrsize)/125;
% Button height (in pixels)
by = 2.5*br;
% Button width (in pixels)
bw = 24*br;

% Button panel width
bpw = 2*br+bw;
% Total figure wdith
tfw = 2*bpw+3*br;

% Panel height: data selection
phd = 6*br+4*by;
% Panel height: rotation
phr = 12*br;
% Panel height: single site info
phx = 5*br+8*by;
% Panel height: multisite metadata file
phm = 3*br+2*by;
% Left side total panel height
phls = phd+phr+phx+2*br;
% height of survey description box
dp = phls-phm-13*by-5*br;
% Panel height: EDI header info
phe = 4*br+13*by+dp;

% Total figure height
tfh = 4*br+phe+phm+by;

% Draw figure
p.fig1 = figure(1);
set(p.fig1,'units','pixels','toolbar','none','menu','none',...
    'numbertitle','off','color',[0.9 0.9 0.9]);
set(p.fig1,'position',[(scrsize(3)-tfw)/2 (scrsize(4)-tfh)/2 tfw tfh]);
%--------------------------------------------------------------------------
% DATA SELECTION
%--------------------------------------------------------------------------
% Select file or directory of files
dgroup = uibuttongroup('visible','off','unit','pixels',...
    'pos',[br 4*br+by+phx+phr bpw phd]);
d.button = uicontrol(dgroup,...
    'style','pushbutton',...
    'pos',[br 2*br+2*by bw by],...
    'string','select file or directory to convert',...
    'fontsize',fs2,...
    'callback',@fetch_data);
d.edit(1) = uicontrol(dgroup,...
    'style','edit',...
    'pos',[br 2*br+by bw by],...
    'string','',...
    'fontsize',fs1,...
    'enable','off');
d.text = uicontrol(dgroup,...
    'style','text',...
    'pos',[br br 0.5*bw 0.7*by],...
    'string','Survey Code:',...
    'horizontalalignment','center',...
    'fontsize',fs2);
d.edit(2) = uicontrol(dgroup,...
    'style','edit',...
    'pos',[br+0.5*bw br 0.5*bw by],...
    'string','',...
    'fontsize',fs2,...
    'backgroundcolor',[1 1 0],...
    'enable','on');
set(dgroup,'title','Select File(s)',...
    'fontsize',fs2,...
    'visible','on');
%--------------------------------------------------------------------------
% Select file type
ggroup = uibuttongroup('visible','off','unit','pixels',...
    'pos',[2*br 6.25*br+4*by+phx+phr bw/2 2*br+by],...
    'bordertype','none');
g.drop = uicontrol(ggroup,...
    'style','popupmenu',...
    'pos',[0 0 bw/2 by],...
    'string',{'(select one)','Z-Files','EDI - impedance','EDI - spectra','Zonge AVG','Excel'},...
    'fontsize',fs1,...
    'callback',@set_input);
set(ggroup,'title','Data Type',...
    'fontsize',fs2,...
    'visible','on');
%--------------------------------------------------------------------------
% Select single file or multiple files
fgroup = uibuttongroup('visible','off','unit','pixels',...
    'pos',[2*br+bw/2 6.25*br+4*by+phx+phr bw/2 2*br+by],...
    'bordertype','none');
f.drop = uicontrol(fgroup,...
    'style','popupmenu',...
    'pos',[0 0 bw/2 by],...
    'string','---',...
    'fontsize',fs1);
set(fgroup,'title','# Input Files',...
    'fontsize',fs2,...
    'visible','on');
%--------------------------------------------------------------------------
% Data Coordinate System and Rotation
rtitle = {'Input Data Coordinates','Hx Azimuth','ºE',...
    'Rotation Options','Rotation','ºCW'};
rgroup = uibuttongroup('visible','off','unit','pixels',...
    'pos',[br 3*br+by+phx bpw phr]);
for ss = 1:2
    switch ss
        case 1
            t1 = 1; t2 = 2; t3 = 3; btop = 8*br;
        case 2
            t1 = 4; t2 = 5; t3 = 6; btop = 3*br;
    end
    r.text(t1) = uicontrol(rgroup,...
        'style','text',...
        'pos',[br btop 7*bw/12 2*br],...
        'string',rtitle(t1),...
        'horizontalalignment','left',...
        'fontsize',fs1);
    r.text(t2) = uicontrol(rgroup,...
        'style','text',...
        'pos',[br+8*bw/12 btop 4*bw/12 2*br],...
        'string',rtitle(t2),...
        'horizontalalignment','left',...
        'fontsize',fs1);
    r.text(t3) = uicontrol(rgroup,...
        'style','text',...
        'pos',[br+10*bw/12 btop-2*br 2*bw/12 2*br],...
        'string',rtitle(t3),...
        'horizontalalignment','left',...
        'fontsize',fs1);
    r.edit(ss) = uicontrol(rgroup,...
        'style','edit',...
        'pos',[br+8*bw/12 btop-1.5*br 2*bw/12 2*br],...
        'string','',...
        'backgroundcolor',[1 1 1],...
        'enable','off',...
        'fontsize',fs2);
end
r.drop(1) = uicontrol(rgroup,...
    'style','popupmenu',...
    'pos',[br 6*br 7*bw/12 2*br],...
    'string','---',...
    'enable','off',...
    'fontsize',fs1,...
    'callback',@set_rotate1);
r.drop(2) = uicontrol(rgroup,...
    'style','popupmenu',...
    'pos',[br br 7*bw/12 2*br],...
    'string','---',...
    'enable','off',...
    'fontsize',fs1,...
    'callback',@set_rotate2);
set(rgroup,'title','Data Coordinate System & Rotation',...
    'fontsize',fs2,...
    'visible','on');
%--------------------------------------------------------------------------
% Select multi site metadata file
tgroup = uibuttongroup('visible','off','unit','pixels',...
    'pos',[2*br+bpw 3*br+by+phe bpw phm]); 
t.button = uicontrol(tgroup,...
    'style','pushbutton',...
    'pos',[br br+by bw by],...
    'string','load multisite metadata file (.txt)',...
    'fontsize',fs1,...
    'enable','off',...
    'callback',@fetch_meta);
t.edit = uicontrol(tgroup,...
    'style','edit',...
    'pos',[br br bw by],...
    'string','',...
    'fontsize',fs1,...
    'backgroundcolor',[1 1 1],...
    'enable','off');
set(tgroup,'title','Metadata File (multisite only)',...
    'fontsize',fs2,...
    'visible','on');
%--------------------------------------------------------------------------
% SINGLE SITE METADATA - single site processing only
%--------------------------------------------------------------------------
xgroup = uibuttongroup('visible','off','unit','pixels',...
    'pos',[br 2*br+by bpw phx]);
%--------------------------------------------------
% Station ID#
s.text(1) = uicontrol(xgroup,...
    'style','text',...
    'pos',[br 3*br+7*by 0.5*bw 0.7*by],...
    'string','Station ID (###):',...
    'horizontalalignment','left',...
    'fontsize',fs1);
s.edit(1) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.4*bw 3*br+7*by 0.5*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
%--------------------------------------------------
% Station Name
s.text(2) = uicontrol(xgroup,...
    'style','text',...
    'pos',[br 3*br+6*by 0.5*bw 0.7*by],...
    'string','Station Name:',...
    'horizontalalignment','left',...
    'fontsize',fs1);
s.edit(2) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.4*bw 3*br+6*by 0.5*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
%--------------------------------------------------
% Latitude: degrees:minute:seconds
m.edit(1) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.3*bw 2*br+5*by 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
m.edit(2) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.5*bw 2*br+5*by 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
m.edit(3) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.7*bw 2*br+5*by 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
% Longitude: degrees:minutes:seconds
m.edit(4) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.3*bw 2*br+4*by 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
m.edit(5) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.5*bw 2*br+4*by 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
m.edit(6) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.7*bw 2*br+4*by 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
%--------------------------------------------------
% Latitude: decimal degrees
m.edit(7) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.3*bw 2*br+2*by 0.6*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
% Longitude: decimal degrees
m.edit(8) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.3*bw 2*br+by 0.6*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
%--------------------------------------------------
% Labels:
for jj = 1:4
    if rem(jj,2) == 0
        loc_hdr1 = 'Longitude:';
        loc_hdr2 = [char(176),'E'];
    else
        loc_hdr1 = 'Latitude:';
        loc_hdr2 = [char(176),'N'];
    end
    if jj < 3
        dh = 2*br+(6-jj)*by;
    else
        dh = 2*br+(5-jj)*by;
    end
    m.text(jj) = uicontrol(xgroup,...
        'style','text',...
        'pos',[br dh 0.3*bw 0.7*by],...
        'string',loc_hdr1,...
        'horizontalalignment','left',...
        'fontsize',fs1);
    m.text(jj+4) = uicontrol(xgroup,...
        'style','text',...
        'pos',[bpw-br-0.1*bw dh 0.1*bw 0.7*by],...
        'string',loc_hdr2,...
        'horizontalalignment','center',...
        'fontsize',fs1);
end
m.text(9) = uicontrol(xgroup,...
    'style','text',...
    'pos',[br+0.3*bw 2*br+3*by 0.6*bw 0.7*by],...
    'string','- - - - - - - - - - OR - - - - - - - - - -',...
    'horizontalalignment','center',...
    'fontsize',fs1);
%--------------------------------------------------
% Station Elevation
z.text(1) = uicontrol(xgroup,...
    'style','text',...
    'pos',[br br 0.3*bw 0.7*by],...
    'string','Elevation:',...
    'horizontalalignment','left',...
    'fontsize',fs1);
z.edit(1) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.3*bw br 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
z.edit(2) = uicontrol(xgroup,...
    'style','edit',...
    'pos',[br+0.7*bw br 0.2*bw by],...
    'string','',...
    'backgroundcolor',[1 1 1],...
    'enable','off',...
    'fontsize',fs1);
z.text(2) = uicontrol(xgroup,...
    'style','text',...
    'pos',[br+0.5*bw br 0.2*bw 0.7*by],...
    'string','meters',...
    'horizontalalignment','center',...
    'fontsize',fs1);
z.text(2) = uicontrol(xgroup,...
    'style','text',...
    'pos',[br+0.9*bw br 0.1*bw 0.7*by],...
    'string','feet',...
    'horizontalalignment','center',...
    'fontsize',fs1);
set(xgroup,'title','Station Metadata (single site only)',...
    'fontsize',fs2,...
    'visible','on');
%--------------------------------------------------------------------------
% SURVEY METADATA - required
%--------------------------------------------------------------------------
def_txt = {def_proj,def_line,def_country,def_state,def_year,def_acqby,...
    def_procby,def_software,def_fileby,def_desc};
hdr_txt = {'Survey Title';'Line/Array';'Country';...
    'State/Province';'Acquisition Year';'Data Acquired By';...
    'Processed By';'Processing Software';'File Created By';...
    'Survey Description'};
hgroup = uibuttongroup('visible','off','unit','pixels',...
    'pos',[2*br+bpw 2*br+by bpw phe]);
h.drop = uicontrol(hgroup,...
    'style','popupmenu',...
    'pos',[br+bw/2 3*br+dp+12*by bw/2 0.7*by],...
    'string',survey_opts,...
    'fontsize',fs1,...
    'callback',@set_survey);
h.text(1) = uicontrol(hgroup,...
    'style','text',...
    'pos',[br 3*br+dp+12*by bw/2 0.7*by],...
    'string',hdr_txt{1},...
    'horizontalalignment','left',...
    'fontsize',fs1);
h.edit(1) = uicontrol(hgroup,...
    'style','edit',...
    'pos',[br 3*br+dp+11*by bw by],...
    'string',def_txt{1},...
    'backgroundcolor',[1 1 1],...
    'fontsize',fs1);
for jj = 2:9
    if jj < 8
        dh_text = dp+2*br+(12-jj)*by;
        dh_edit = dp+2*br+(12-jj)*by;
        dw_edit = 0.5*bw;
        astr = 'center';
    else
        dh_text = dp+br+2*(10-jj)*by;
        dh_edit = dp+br+2*(9.5-jj)*by;
        dw_edit = bw;
        astr = 'left';
    end
    h.text(jj) = uicontrol(hgroup,...
        'style','text',...
        'pos',[br dh_text dw_edit 0.8*by],...
        'string',hdr_txt{jj},...
        'horizontalalignment',astr,...
        'fontsize',fs1);
    h.edit(jj) = uicontrol(hgroup,...
        'style','edit',...
        'pos',[br+bw-dw_edit dh_edit dw_edit by],...
        'string',def_txt{jj},...
        'backgroundcolor',[1 1 1],...
        'fontsize',fs1);
end
% Survey Description
h.text(10) = uicontrol(hgroup,...
    'style','text',...
    'pos',[br br+dp+0.1*by bw 0.7*by],...
    'string',hdr_txt{10},...
    'horizontalalignment','left',...
    'fontsize',fs1);
h.edit(10) = uicontrol(hgroup,...
    'style','edit',...
    'pos',[br br bw dp],...
    'string',def_txt{10},...
    'backgroundcolor',[1 1 1],...
    'fontsize',fs1,...
    'horizontalalignment','left',...
    'Max',4,'Min',2);
set(hgroup,'title','Survey Information (EDI conversion only)',...
    'fontsize',fs2,...
    'visible','on');
%--------------------------------------------------------------------------
% ACTION BUTTONS
%--------------------------------------------------------------------------
% Clear all entries button
bbw = (tfw-6*br)/5;
w.button(1) = uicontrol('style','pushbutton',...
    'unit','pixels',...
    'pos',[br br bbw by],...
    'string','CLEAR ALL',...
    'fontsize',fs1,...
    'callback',@clear_fields);
% Query national map
w.button(2) = uicontrol('style','pushbutton',...
    'unit','pixels',...
    'pos',[2*br+bbw br bbw by],...
    'string','Nat Map Elev',...
    'fontsize',fs1,...
    'foregroundcolor',[1 0 0],...
    'callback',@switch_elev);
% Print PNG only button
w.button(3) = uicontrol('style','pushbutton',...
    'unit','pixels',...
    'pos',[3*br+2*bbw br bbw by],...
    'string','Print PNG(s)',...
    'fontsize',fs1,...
    'enable','off',...
    'callback',@start_png);
% Write EDI button
w.button(4) = uicontrol('style','pushbutton',...
    'unit','pixels',...
    'pos',[4*br+3*bbw br bbw by],...
    'string','Write EDI File(s)',...
    'fontsize',fs1,...
    'enable','off',...
    'callback',@start_edi);
% Exit GUI button
w.button(5) = uicontrol('style','pushbutton',...
    'unit','pixels',...
    'pos',[5*br+4*bbw br bbw by],...
    'string','EXIT',...
    'fontsize',fs1,...
    'callback',@close_all);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALLBACK FUNCTIONS - SECTION I: MAIN CODE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @setup
% @fetch_data
% @fetch_meta
% @initialize
% @process_info
% @plot_png
%--------------------------------------------------------------------------
% @setup: define global variables
%--------------------------------------------------------------------------
    function setup(~,~)
        global dtype        % data type {z,e,s,a,x}
        global ifiles       % list of data files to read
        global mfile        % metadata text file
        global mpath        % path to metadata text file
        global rtype        % rotation parameter tags [0 0 0]
        global mtloc        % location [nsta x lat/lon/elev/spin]
        global site_name    % station names (REFLOC)
        global sta          % station IDs (###)
        global acq_info     % additional metadata (acqdate, ex, ey)
        
        dtype = [];
        ftype = [];
        rtype = [];
        mtloc = [];
        mfile = [];
        mpath = home;
        ifiles = {};
        site_name = {};
        sta = {};
        acq_info = [];
    end
%--------------------------------------------------------------------------
% @fetch_data: select data files or file directory to read
%--------------------------------------------------------------------------
    function fetch_data(~,~)
        global dtype        % data type {z,e,s,a,x}
        global ifiles       % list of data files to read 
        global mfile
        global mpath
        setup
        
        % anticpate warning messages
        if ishghandle(wbox); delete(wbox); end

        % Determine data type from drop down menu selection
        if test_mode == 1
            set(g.drop,'value',test_gdrop)
            set_input
            set(f.drop,'value',test_fdrop)
        end
        switch get(g.drop,'value')
            case 1
                wbox = warndlg('Please specify a data file type');
                return
            case 2
                dtype = 'z';
                fstr = '*.z*';
            case 3
                dtype = 'e';
                fstr = '*.edi';
            case 4
                dtype = 's';
                fstr = '*.edi';
            case 5
                dtype = 'a';
                fstr = '*.avg';
            case 6
                dtype = 'x';
                fstr = '*.xls*';
        end

        %--------------------------------------------------------------
        % Fetch directory containing multiple data files
        %--------------------------------------------------------------
        if get(f.drop,'value') == 2
            % Select directory to look for data files
            if test_mode == 1
                tpath = test_path;
            else
                tpath = uigetdir(ipath);
            end
            % If found, continue to data file search...
            if tpath ~= 0
                % Add slash to end of path
                if ~strcmp(tpath(end),slash)
                    tpath = [tpath,slash];
                end
                get_file = tpath;
                gtick = 3;
                % Look for file names with appropriate extensions
                % (Z-file look up requires 2 steps: *.zmm and *.zss)
                if strcmp(dtype,'z')
                    tfiles_zmm = struct2cell(dir([tpath,'*.zmm']));
                    tfiles_zss = struct2cell(dir([tpath,'*.zss']));
                    FilesInDir = [tfiles_zmm,tfiles_zss];
                else
                    FilesInDir = struct2cell(dir([tpath,fstr]));
                end
                % If files with appropriate extension found...
                if ~isempty(FilesInDir)
                    % Assign global variables
                    ifiles = FilesInDir(1,:);
                    ipath = tpath;
                    ftype = 'batch';
                    % Turn GUI elements on/off
                    set_GUI
                else
                    wbox = warndlg(['No files with extension ',...
                        fstr,' found.']);
                end
            end
        %--------------------------------------------------------------
        % Fetch single data file
        %--------------------------------------------------------------
        else
            % Select a single data file
            if test_mode == 1
                tpath = test_path;
                tfile = test_file;
                if get(f.drop,'value') == 3
                    mpath = test_mpath;
                    mfile = test_mfile;
                end
            else
                [tfile,tpath] = uigetfile([ipath,fstr]);
            end
            if tpath ~= 0
                % Add slash to end of path
                if ~strcmp(tpath(end),slash)
                    tpath = [tpath,slash];
                end
                get_file = [tpath,tfile];
                gtick = 2;
                % If importing a single site EDI file, use existing
                % header to populate select metadata fields in GUI
                if strcmp(dtype,'e') || strcmp(dtype,'s')
                    if get(f.drop,'value')==1
                        if test_mode ~= 1
                            fill_GUI(get_file);
                        end
                    end
                end
                % Assign global variables
                ifiles{1} = tfile;
                ipath = tpath;
                % Turn GUI elements on/off
                if get(f.drop,'value')==3
                    ftype = 'batch';
                else
                    ftype = 'single';
                end
                set_GUI
            end
        end
        %--------------------------------------------------------------
        % Display file or directory name in GUI
        %--------------------------------------------------------------
        if isempty(ifiles)
            set(d.edit(1),'string','');
        else  
            gindx = strfind(get_file,slash);
            if length(gindx)>gtick+1
                pfile = ['...',get_file(gindx(end-gtick):end)];
            else
                pfile = get_file;
            end
            set(d.edit(1),'string',pfile)
            set(w.button(3),'enable','on')
            set(w.button(4),'enable','on')
        end
    end
%--------------------------------------------------------------------------
% @fetch_meta: select multisite metadata file
%--------------------------------------------------------------------------
    function fetch_meta(~,~)
        global mfile        % metadata text file
        global mpath        % path to metadata text file
        
        % Select a text file
        [tfile,tpath] = uigetfile([mpath,'*.txt']);
        if tpath ~= 0
            % Add slash to end of path
            if ~strcmp(tpath(end),slash)
                tpath = [tpath,slash];
            end
            get_file = [tpath,tfile];
            % Assign global variables
            mfile = tfile;
            mpath = tpath;
        end
        
        % Display file name in GUI
        if isempty(mfile)
            set(t.edit,'string','');
        else  
            gindx = strfind(get_file,slash);
            if length(gindx)>3
                pfile = ['...',get_file(gindx(end-3):end)];
            else
                pfile = get_file;
            end
            set(t.edit,'string',pfile);
        end
    end
%--------------------------------------------------------------------------
% @initialize: check GUI inputs and read metadata text file
%--------------------------------------------------------------------------
    function initialize(~,~)
        global ifiles       % list of data files to read
        global mfile        % metadata text file
        global mpath        % path to metadata text file
        global rtype        % rotation parameter tags [0 0 0]
        global mtloc        % location [nsta x lat/lon/elev/spin]
        global site_name    % station names (REFLOC)
        global sta          % station IDs (###)
        global acq_info     % additional metadata (acqdate, ex, ey)
        
        % Check for data files or a directory to read
        if isempty(ifiles)
            wbox = warndlg({'Please specify a file or directory to read.'});
            return
        end
        
        % Check for survey code
        survey_code = get(d.edit(2),'string');
        if size(survey_code,2) == 0; survey_code = ''; end
        if strcmp(survey_code,'')
            wbox = warndlg({'Please enter a survey code.'});
            return
        end
        
        % Check that data coordinate system has been specified
        if get(r.drop(1),'value') == 1
            wbox = warndlg({'Please specify a data coordinate system.'});
            return
        end
        
        % Determine rotation parameters
        rtype = [0 0 0];
        fetch_rotation;
        
        % Check Hx azimuth value (if necessary)
        if rtype(2) == 1 || rtype(3) == 1
            pass = check_value(r.edit(1),'Hx azimuth',-180,180,0);
        else
            pass = 1;
        end
        if pass == 0; return; end
        
        % Check rotation angle value (if necessary)
        if rtype(2) == 2 || rtype(3) == 2
            pass = check_value(r.edit(2),'rotation angle',-180,180,0);
        else
            pass = 1;
        end
        if pass == 0; return; end
            
        %------------------------------------------------------------------
        %                      COLLECT METADATA
        %------------------------------------------------------------------
        % Multisite metadata processing
        %------------------------------------------------------------------
        switch ftype
            case 'batch'
                % Check for metadata text file
                if isempty(mfile)
                    wbox = warndlg({'Please specify a multisite metadata file.'});
                    return
                end
                
                % Read multisite metadata
                fid0 = fopen([mpath,mfile],'r');
                mdata = textscan(fid0,'%s%s%n%n%n%n%n%n%n%n%n%n');
                fclose(fid0);
                
                % Collect station IDs and station count
                sta = mdata{2};
                nsta = length(sta);
                spin = zeros(nsta,1);
                
                % Determine rotation angle
                switch rtype(2)
                    case 1 % use survey wide acq. coords. (i.e. decl.)
                        theta = str2double(get(r.edit(1),'string'));
                        spin = -theta+spin;
                    case 2 % user defined rotation
                        theta = str2double(get(r.edit(2),'string'));
                        spin = theta+spin;
                    case 3 % use angles from metadata file
                        for ww = 1:nsta
                            spin(ww) = -mdata{6}(ww);
                        end
                end
                mtloc = [zeros(nsta,3) spin];
                site_name = mdata{1};
                
                % The following metadata are not required for plotting
                if plots_only == 0
                    
                    L = {'latitude','longitude','elevation'};
                    for ww = 1:nsta
                        % Check latitude
                        if check_input(num2str(mdata{3}(ww)),-90,90)
                            % Check longitude
                            if check_input(num2str(mdata{4}(ww)),-180,180)
                                % Check elevation
                                if ~check_input(num2str(mdata{5}(ww)),-1000,8000)
                                    wbox = warndlg(['Please check ',L{3},...
                                        ' value for site ',sta{ww}]);
                                    return
                                end
                            else
                                wbox = warndlg(['Please check ',L{2},...
                                    ' value for site ',sta{ww}]);
                                return
                            end
                        else
                            wbox = warndlg(['Please check ',L{1},...
                                ' value for site ',sta{ww}]);
                            return
                        end
                    end

                    % Collect ACQDATE and electric dipole lengths
                    % either farm from metadata file or insert dummy values
                    acq_info = nan(nsta,3);
                    for ww = 1:nsta
                        mtloc(ww,1) = mdata{3}(ww);
                        mtloc(ww,2) = mdata{4}(ww);
                        mtloc(ww,3) = mdata{5}(ww);
                        % ACQDATE, EX, EY (if available)
                        if isempty(mdata{8}(1))
                            acq_info(ww,1) = 20010101;
                            acq_info(ww,2) = 100;
                            acq_info(ww,3) = 100;
                        else
                            acq_info(ww,1) = mdata{8}(ww);
                            acq_info(ww,2) = mdata{9}(ww);
                            acq_info(ww,3) = mdata{10}(ww);
                        end 
                    end
                    
                    % Continue processing:
                    process_info;
                else
                    % Continue to plotting:
                    process_info;
                end
            %------------------------------------------------------------------
            % Single site metadata processing
            %------------------------------------------------------------------
            case 'single'
                % Check GUI for station ID
                isite = get(s.edit(1),'string');
                if size(isite,2) == 0; isite = ''; end
                if strcmp(isite,'')
                    wbox = warndlg({'Please enter a station ID.'});
                    return
                else
                    sta{1} = isite;
                end
                
                % Determine rotation angle
                switch rtype(2)
                    case 1 % use declination/acquisition coordinates
                        spin = str2double(get(r.edit(1),'string'));
                    case 2 % user defined rotation
                        spin = str2double(get(r.edit(2),'string'));
                    otherwise
                        spin = 0;
                end
                mtloc = [0 0 0 spin];
                
                % The following meta data are not required for plotting
                if plots_only == 0
                    % Check GUI for station name
                    iname = get(s.edit(2),'string');
                    if size(iname,2) == 0; iname = ''; end
                    site_name{1} = iname;
                    
                    % Check GUI for decimal degree values of lat and lon
                    declat = get(m.edit(7),'string');
                    declon = get(m.edit(8),'string');
                    if size(declat,2) == 0; declat = ''; end
                    if size(declon,2) == 0; declon = ''; end

                    % If dd.dddd is empty, check dd:mm:ss values of lat and lon
                    if strcmp(declat,'') && strcmp(declon,'')
                        L = {'latitude degree';'latitude minute';...
                            'latitude second';'longitude degree';...
                            'longitude minute';'longitude second'};
                        p2 = 0; p3 = 0; p4 = 0; p5 = 0; p6 = 0;
                        p1 = check_value(m.edit(1),L{1},-90,90,1);
                        if p1 == 1; p2 = check_value(m.edit(2),L{2},0,59,1);
                        if p2 == 1; p3 = check_value(m.edit(3),L{3},0,59.99999,0);
                        if p3 == 1; p4 = check_value(m.edit(4),L{4},-180,180,1);
                        if p4 == 1; p5 = check_value(m.edit(5),L{5},0,59,1);
                        if p5 == 1; p6 = check_value(m.edit(6),L{6},0,59.99999,0);
                        if p6 == 1
                            dd1 = str2double(get(m.edit(1),'string'));
                            mm1 = str2double(get(m.edit(2),'string'));
                            ss1 = str2double(get(m.edit(3),'string'));
                            ilat = sign(dd1)*(abs(dd1)+mm1/60+ss1/3600);
                            dd2 = str2double(get(m.edit(4),'string'));
                            mm2 = str2double(get(m.edit(5),'string'));
                            ss2 = str2double(get(m.edit(6),'string'));
                            ilon = sign(dd2)*(abs(dd2)+mm2/60+ss2/3600);
                        end
                        end
                        end
                        end
                        end
                        end
                        if p1+p2+p3+p4+p5+p6 < 6; return; end
                    else
                        % Check decimal degree values and convert to numbers
                        L = {'latitude','longitude'};
                        p2 = 0;
                        p1 = check_value(m.edit(7),L{1},-90,90,0);
                        if p1 == 1; p2 = check_value(m.edit(8),L{2},-180,180,0);
                        if p2 == 1
                            ilat = str2double(declat);
                            ilon = str2double(declon);
                        end
                        end
                        if p1+p2 < 2; return; end
                    end
                    
                    % Check GUI entry for elevation
                    % If elevation is available in both feet and meters, 
                    % default to elevation in meters
                    mloc = get(z.edit(1),'string');
                    floc = get(z.edit(2),'string');
                    if size(mloc,2) == 0; set(z.edit(1),'string',''); end
                    if size(floc,2) == 0; set(z.edit(2),'string',''); end
                    
                    % If both are empty, set elevation to zero and try again
                    if strcmp(get(z.edit(1),'string'),'')
                        if strcmp(get(z.edit(2),'string'),'')
                            wbox = warndlg({'No elevation entered. Elevation set to sea level.'});
                            set(z.edit(1),'string','0');
                            return
                        else
                            % Convert elevation in feet to meters
                            z1 = check_value(z.edit(2),'elevation',-7000,24000,0);
                            if z1 == 1
                                ielv = 0.3048*str2double(get(z.edit(2),'string'));
                            else
                                return 
                            end
                        end
                    else
                        % Collect elevation in meters
                        z1 = check_value(z.edit(1),'elevation',-8000,8000,0);
                        if z1 == 1
                            ielv = str2double(get(z.edit(1),'string'));
                        else
                            return
                        end
                    end
                    mtloc = [ilat ilon ielv spin];
                    
                    % Prompt acquisition start date, EX and EY dipole lengths
                    if test_mode == 1
                        acq_info = [19870929 100 100];
                    else
                        dprompt = {'Acquisition Start Date (YYYYMMDD):',...
                            'Ex dipole length (m)','Ey dipole length (m)'};
                        estr = inputdlg(dprompt,'Additional Info',1,...
                            {'19990131','100','100'});
                        acq_info = [str2double(estr{1}) str2double(estr{2}) str2double(estr{3})];
                    end
                    
                    % Continue processing:
                    process_info;
                else
                    % Continue to plotting:
                    process_info;
                end
        end
    end
%--------------------------------------------------------------------------
% @process_info: use gathered info to write new EDI files
%-------------------------------------------------------------------------- 
    function process_info(~,~)
        global ifiles
        global site_name
        global sta
        global rtype
        global dtype
        global acq_info
        global mtloc
        
        % Extract survey code from GUI
        survey_code = get(d.edit(2),'string');
        
        % Extract survey wide header info (EDI conversion only)
        if plots_only == 0
            surv_hdr = cell(12,1);
            for hh = 1:10
                surv_hdr{hh} = get(h.edit(hh),'string');
            end
            % Replace spaces and semicolons with underscores '_'
            % (this is only necessary for GeoTools compatibility)
            for hh = [1:4 6:9]
                surv_hdr{hh} = replace_space(surv_hdr{hh});
            end
            surv_hdr{11} = survey_code;
            % Determine final data coordinate system and add to description
            switch rtype(1)
                case 1
                    add_desc = {'','GEOGRAPHIC'};
                case 2
                    add_desc = {'','GEOMAGNETIC'};
                case 3
                    add_desc = {'','ACQUISITION'};
                case 4
                    add_desc = {'','USER DEFINED'};
                otherwise
                    add_desc = {'WARNING: ','UNKNOWN'};
            end
            surv_hdr{10} = [add_desc{1},'Data provided in ',add_desc{2},...
                ' coordinate frame. ',surv_hdr{10}];
            % Determine data orientation
            
            switch rtype(3)
                case 0 % geographic
                    surv_hdr{12} = [0 90];
                case 1 % geomagnetic
                    xazm = str2double(get(r.edit(1),'string'));
                    surv_hdr{12} = [xazm xazm+90];
                case 2 % user defined
                    xazm = str2double(get(r.edit(2),'string'));
                    surv_hdr{12} = [xazm xazm+90];
                otherwise
                    surv_hdr{12} = [0 90];
            end
        end
        
        %--------------------------------------------------------------------------
        % READ ONE INPUT DATA FILE AT A TIME
        %--------------------------------------------------------------------------
        for rr = 1:length(ifiles)
            rfile = ifiles{rr};
            nsite = 0;
            
            % Strip file extension from file name
            ptag = strfind(rfile,'.');
            isite = rfile(1:ptag(end)-1);
            
            % For batch processing, index file name against site_name 
            % variable extracted from metadata file
            uindx = find(strcmp(isite,site_name));
            if isempty(uindx)
                switch ftype
                    case 'batch'
                        % In special case of multisite spectra EDI, ignore
                        % uindx for now and make nsta > 1
                        if get(f.drop,'value') == 3
                            dfile = [ipath,rfile];
                            nsta = 2;
                        else
                            % Site not found in metadata
                            nsta = 0;
                        end
                    case 'single'
                        % For single site files, metadata index is not
                        % required, so set nsta = 1 and uindx = 1
                        dfile = [ipath,rfile];
                        nsta = 1;
                        uindx = 1;
                end
            else
                dfile = [ipath,rfile];
                nsta = 1;
            end
            
            %--------------------------------------------------------------
            % DATA EXTRACTION & ROTATION
            %--------------------------------------------------------------
            if nsta == 1
                % Rotation angle
                theta = mtloc(uindx,4);
                % Only Z-files and EDI spectra can be rotated during data
                % extraction - all others should be rotated afterwards
                switch dtype
                    case 'z' % EGBERT
                        [ff,iZ,iZvar,nch] = read_zmm(dfile,theta);
                    case 'e' % EDI
                        [ff,iZ,iZvar,nch] = read_impedance(dfile);
                        [iZ,iZvar] = spinZ(iZ,iZvar,theta);
                    case 's' % EDI SPECTRA
                        [ff,iZ,iZvar,nch] = read_spectra(dfile,theta);
                    case 'a' % ZONGE AVG
                        [ff,iZ,iZvar,nch] = read_avg(dfile);
                        [iZ,iZvar] = spinZ(iZ,iZvar,theta);
                    case 'x' % XLS
                        [ff,iZ,iZvar,nch] = read_xls(dfile);
                        [iZ,iZvar] = spinZ(iZ,iZvar,theta);
                end
                tfreq = {ff};
                tZ = {iZ};
                tZvar = {iZvar};
            elseif nsta > 1 % only applies to multisite spectra EDI files
                % Rotation angle
                theta = mtloc(:,4);
                fprintf('Reading %s...\n',rfile);
                [tfreq,tZ,tZvar,nch,edi_list] = read_spectra(dfile,theta);
                nsta = length(edi_list);
            end
            %-------------------------------------------------------------- 
            % DATA WRITING & PLOTTING
            %--------------------------------------------------------------
            if nsta > 0
                for ww = 1:nsta % usually nsta = 1
                    % Check for SECTID in site_name variable
                    if nsta > 1
                        isite = edi_list{ww};
                        uindx = find(strcmp(isite,site_name));
                    end
                    if isempty(uindx); return; end
                    
                    % Collect station ID and lat/lon/elev
                    tsite = [survey_code,sta{uindx}];
                    
                    % Select data for plotting and EDI
                    freq = tfreq{ww};
                    Z = tZ{ww};
                    Zvar = tZvar{ww};
                    nfreq = length(freq);
                    
                    % New .png file name
                    pfile = [tsite,'.png'];
                    
                    if plots_only == 1
                        % Update command line
                        clc; fprintf('Plotting %s...\n',pfile)
                        
                        % Plot transfer functions
                        plot_png(freq,Z,Zvar,tsite);
                    else
                        %--------------------------------------------------
                        % WRITE EDI FILES
                        %--------------------------------------------------
                        % New EDI file name
                        efile = [tsite,'.edi'];
                        
                        % Update command line
                        clc; fprintf('Writing %s...\n',efile)

                        % Collect data orientation from metadata file
                        if rtype(3) == 3
                            surv_hdr{12} = [mtloc(uindx,4) mtloc(uindx,4)+90];
                        end
                        
                        % File print #
                        nsite = nsite+1;
                            
                        % Collect site specific header information
                        site_hdr = {sta{uindx},acq_info(uindx,1),...
                            mtloc(uindx,1),mtloc(uindx,2),mtloc(uindx,3),...
                            nsite,acq_info(uindx,2),acq_info(uindx,3),nfreq};
                        
                        % Write new EDI file
                        fid2 = fopen(efile,'w+');
                        write_hdr(fid2,site_hdr,surv_hdr)
                        write_edi(fid2,freq,Z,Zvar,nch)
                        
                        % % Plot transfer functions
                        plot_png(freq,Z,Zvar,tsite);
                        %--------------------------------------------------
                    end
                end
            end
        end 
        close(p.fig2);
        fprintf('DONE!\n')
    end 
%--------------------------------------------------------------------------
% @plot_png: plot transfer functions
%--------------------------------------------------------------------------
    function[] = plot_png(tfreq,zt,ztvar,isite)
        
        % Collect off-diagonal impedances
        zxyr = zt(:,3);
        zxyi = zt(:,4);
        zyxr = zt(:,5);
        zyxi = zt(:,6);
        
        % Collect tipper
        txr = zt(:,9);
        txi = zt(:,10);
        tyr = zt(:,11);
        tyi = zt(:,12);
        
        % Standard impedance and tipper error
        zxy_std = sqrt(ztvar(:,2));
        zyx_std = sqrt(ztvar(:,3));
        tx_std = sqrt(ztvar(:,5));
        ty_std = sqrt(ztvar(:,6));
        
        % Calculate transfer functions
        rho_xy = (zxyr.^2+zxyi.^2)./(5*tfreq);
        rho_yx = (zyxr.^2+zyxi.^2)./(5*tfreq);
        phs_xy = rad2deg*atan2(zxyi,zxyr);
        phs_yx = rad2deg*atan2(zyxi,zyxr);
        
        % Mask HUGE tipper (>1e8)
        txr(txr > 1e8) = NaN;
        txi(txi > 1e8) = NaN;
        tyr(tyr > 1e8) = NaN;
        tyi(tyi > 1e8) = NaN;
        
        % Change phase quadrant, if necessary (for plotting only)
        if sum(phs_yx<0) > 0.75*length(phs_yx)
            phs_yx = phs_yx+180;
        end
        
        % Calculate resistivity errors (in log10)
        rxy_std = 0.4343*2*zxy_std./sqrt(zxyr.^2+zxyi.^2);
        ryx_std = 0.4343*2*zyx_std./sqrt(zyxr.^2+zyxi.^2);
              
        % Calculate phase errors
        pxy_std = rad2deg*zxy_std./sqrt(zxyr.^2+zxyi.^2);
        pyx_std = rad2deg*zyx_std./sqrt(zyxr.^2+zyxi.^2);

        % Error bars for plotting - resistivity
        drhoxy_plt = vbar(rho_xy,rxy_std);
        drhoyx_plt = vbar(rho_yx,ryx_std);
        
        % Error bars for plotting - phase
        dphsxy_plt = [phs_xy'-pxy_std'; phs_xy'+pxy_std'];
        dphsyx_plt = [phs_yx'-pyx_std'; phs_yx'+pyx_std'];
        
        % Error bars for plotting - tipper
        dtxr_plt = [txr'-tx_std'; txr'+tx_std'];
        dtxi_plt = [txi'-tx_std'; txi'+tx_std'];
        dtyr_plt = [tyr'-ty_std'; tyr'+ty_std'];
        dtyi_plt = [tyi'-ty_std'; tyi'+ty_std'];
        
        % Period for plotting
        tt = log10(1./tfreq);
        tte = [tt';tt'];
        
        % Plot transfer functions
        % Plot apparent resistivity and error bars
        p.fig2 = figure(2);
        set(p.fig2,'units','pixels','toolbar','none','menu','none',...
            'numbertitle','off');
        set(p.fig2,'position',[(scrsize(3)-1.3*tfw)/2 (scrsize(4)-0.9*tfh)/2 1.3*tfw 0.9*tfh]);
        subplot(5,6,[1:5,7:11,13:17])
        hzxy = semilogy(tt,rho_xy,'ro'); hold on
        hzyx = semilogy(tt,rho_yx,'bx');
        xbounds = get(gca,'xlim');
        semilogy(tte,drhoxy_plt,'r-')
        semilogy(tte,drhoyx_plt,'b-')
        lgd = legend([hzxy(1) hzyx(1)],'Zxy','Zyx');
        set(lgd,'fontsize',0.8*fs1,'orientation','horizontal')
        ylabel('App. Resistivity [\Omega\cdotm]','fontsize',fs1);
        title(isite,'fontsize',fs1*1.5,'fontweight','bold');
        set(gca,'fontsize',fs1)
        set(gca,'xticklabel','')
        set(gca,'xtick',-5:5)
        xlim(xbounds)
        ylim([0.5 10^(3.8)])
        set(gca,'ytick',10.^(0:4))
        grid on
        set(gca,'gridlinestyle','--')
        set(gca,'minorgridlinestyle','none')
        
        hold off
        
        % Plot impedance phase and error bars
        subplot(5,6,19:23)
        plot(tt,phs_xy,'ro'); hold on
        plot(tt,phs_yx,'bx')
        plot(tte,dphsxy_plt,'r-')
        plot(tte,dphsyx_plt,'b-')
        set(gca,'YTick',0:30:90)
        ylabel('Phase [deg.]','fontsize',fs1)
        ylim([-15 105])
        set(gca,'xticklabel','')
        set(gca,'xtick',-5:5)
        xlim(xbounds)
        set(gca,'fontsize',fs1)
        grid on
        set(gca,'gridlinestyle','--')
        set(gca,'minorgridlinestyle','none')
        hold off
        
        % Tippers will only plot if they exist (tipper = NaN for nch = 4)

        % Plot Tx tipper
        subplot(5,6,25:29)
        plot(tt,txr,'ro'); hold on
        plot(tt,txi,'bx')
        plot(tte,dtxr_plt,'r-')
        plot(tte,dtxi_plt,'b-')
        ylim([-0.7 0.7])
        xlim(xbounds)
        ylabel('|Tzx|','fontsize',fs1);
        xlabel('log_1_0(period) [sec]','fontsize',fs1);
        set(gca,'fontsize',fs1)
        grid on
        set(gca,'gridlinestyle','--')
        set(gca,'minorgridlinestyle','none')
        set(gca,'xtick',-5:5)
        hold off
        
        % Plot Ty tipper
        subplot(5,6,6:6:30)
        htzr = plot(tyr,tt,'ro'); hold on
        htzi = plot(tyi,tt,'bx');
        plot(dtyr_plt,tte,'r-')
        plot(dtyi_plt,tte,'b-')
        plot([0 0],xbounds,'k:')
        xlim([-0.7 0.7])
        ylim(xbounds)
        xlabel('|Tzy|','fontsize',fs1);
        ylabel('log_1_0(period) [sec]','fontsize',fs1);
        set(gca,'ytick',-5:5)
        set(gca,'fontsize',fs1)
        set(gca,'yaxislocation','right','ydir','reverse')
        grid on
        set(gca,'gridlinestyle','--')
        set(gca,'minorgridlinestyle','none')
        hleglines = [htzr(1) htzi(1)];
        lgd2 = legend(hleglines,'Re(Tz)','Im(Tz)');
        set(lgd2,'fontsize',0.8*fs1,'location','north')
        hold off
        pause(0.1)
        
        savefile = [isite,'.png'];
        print(gcf,'-dpng',savefile,'-r300');
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALLBACK FUNCTIONS - SECTION II: READ & REFORMAT MT DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @read_zmm
% @read_impedance
% @read_spectra
% @read_avg
% @read_xls
% @zmm_block
% @edi_block
% @spec2spec
% @spec2z
% @spinZ

% GOT TO HERE - need to code/check the following
% read_avg
% read_xls
% plot_png
% directory functionality - of zmm, avg, xls
%--------------------------------------------------------------------------
% @read_zmm: recover MT data from z-files (i.e. Egbert format)
%--------------------------------------------------------------------------
    function[ifreq,ZT,ZTvar,ich] = read_zmm(read_file,spin)
        % Open input EDI file
        fid = fopen(read_file,'r');
        done = 0;
        
        % Rotation matrix
        if spin ~= 0
            B = spin*pi/180;
            R = [cos(B) sin(B); -sin(B) cos(B)];
        end
        
        % Read z-file line by line
        ifreq = [];
        tline = fgetl(fid);
        while done == 0
            if tline == -1
                done = 1;
            else
                hline = strtrim(tline);
                if isempty(hline); hline = ' '; end
                hline = strsplit(hline);
                cline = [hline{1},'               '];
                switch cline(1:5)
                    case 'perio' % period information
                        if strcmp(hline{2},':')
                            ifreq = [ifreq; 1./str2double(hline{3})];
                        else
                            ifreq = [ifreq; 1./str2double(hline{2})];
                        end
                        nf = length(ifreq);
                        tline = fgetl(fid);
                    case 'Trans' % transfer functions (Z and tipper)
                        [iZ,tline] = zmm_block(fid);
                        % Reorder transfer functions to put impedance 1st
                        if length(iZ) > 8
                           iZ = [iZ(5:12) iZ(1:4)]; 
                        end
                        data{nf,1} = iZ;
                    case 'Inver' % inverse coherent signal power matrix
                        [iV,tline] = zmm_block(fid);
                        data{nf,2} = iV;
                    case 'Resid' % residual covariance
                        [iR,tline] = zmm_block(fid);
                        data{nf,3} = iR;
                    otherwise
                        tline = fgetl(fid);
                end
            end
        end
        fclose(fid);
        chn_count = 4*ones(nf,1);
        
        % Create output variables
        ZT = nan(nf,12);
        ZTvar = nan(nf,6);
        
        % Process one frequency at a time
        for tt = 1:nf
            % Collect data at this frequency
            impZ = data{tt,1};
            impV = data{tt,2};
            impR = data{tt,3};
            % Determine # of channels
            if length(impZ) > 8
                nch = 5;
                chn_count(tt) = 5;
            else
                nch = 4;
            end
            % Construct full impedance tensor
            Z = [impZ(1)+1i*impZ(2) impZ(3)+1i*impZ(4);
                  impZ(5)+1i*impZ(6) impZ(7)+1i*impZ(8)];
            % Construct inverse coherent signal power matrix
            % Note this matrix is symmetric (sxy = syx)
            S = [impV(1)+1i*impV(2) impV(3)-1i*impV(4);
                  impV(3)+1i*impV(4) impV(5)-1i*impV(6)];
            % Construct residual covariance (and tipper)
            % Note this matrix is symmetric conjugate (nxy = nxy*)
            if nch == 5
                N = [impR(1)+1i*impR(2) impR(3)-1i*impR(4) impR(7)-1i*impR(8);
                     impR(3)+1i*impR(4) impR(5)+1i*impR(6) impR(9)-1i*impR(10);
                     impR(7)+1i*impR(8) impR(9)+1i*impR(10) impR(11)+1i*impR(12)];
                Tz = [impZ(9)+1i*impZ(10);
                       impZ(11)+1i*impZ(12)];
            else
                N = [impR(1)+1i*impR(2) impR(3)-1i*impR(4);
                     impR(3)+1i*impR(4) impR(5)+1i*impR(6)];
                Tz = NaN(2,1)*(1+1i*1);
            end
            
            if spin ~= 0
                % Rotate impedance
                Z = R*Z*R';
                % Rotate signal power matrix
                % (see Eisel & Egbert GJI 2001 for reference)
                S = R*URS*R';
                % Rotate tipper (if available)
                % Also generate rotation matrix for residual covariance
                % (see Eisel & Egbert GJI 2001 for reference)
                if nch == 5
                    T = R*T;
                    R3 = [1 0 0;
                        0 R(1,1) R(1,2);
                        0 R(2,1) R(2,2)];
                else
                    R3 = R;
                end
                % Rotate residual covariance (varies with # chn)
                N = R3*N*R3';
            end
            
            % Calculate variance
            sxxr = real(S(1,1));
            syyr = real(S(2,2));
            if nch == 5
                nxx = N(2,2);
                nyy = N(3,3);
                txvar = sxxr.*N(1,1);
                tyvar = syyr.*N(1,1);
            else
                nxx = N(1,1);
                nyy = N(2,2);
                txvar = sxxr*0;
                tyvar = syyr*0;
            end
            zxxvar = sxxr.*nxx;
            zxyvar = syyr.*nxx;
            zyxvar = sxxr.*nyy;
            zyyvar = syyr.*nyy;
            
            % Distribute impedance tensor elements
            zxx = Z(1,1);
            zxy = Z(1,2);
            zyx = Z(2,1);
            zyy = Z(2,2);
            tzx = Tz(1);
            tzy = Tz(2);
            
            % Assign to output variables
            ZT(tt,:) = [real(zxx) imag(zxx) real(zxy) imag(zxy),...
                real(zyx) imag(zyx) real(zyy) imag(zyy),...
                real(tzx) imag(tzx) real(tzy) imag(tzy)];
            ZTvar(tt,:) = [zxxvar zxyvar zyxvar zyyvar txvar tyvar];
        end
        
        % Output # of channels 
        ich = max(chn_count);
    end
%--------------------------------------------------------------------------
% @read_impedance: recover MT data from impedance EDI files
%--------------------------------------------------------------------------
    function[ifreq,ZT,ZTvar,ich] = read_impedance(read_file)
        % Open input EDI file
        fid = fopen(read_file,'r');
        done = 0;
        
        % Data block tags to search for in EDI file
        data_tag = {'>ZXXR','>ZXXI','>ZXYR','>ZXYI','>ZYXR',...
            '>ZYXI','>ZYYR','>ZYYI','>TXR.','>TXI.','>TYR.','>TYI.',...
            '>ZXX.','>ZXY.','>ZYX.','>ZYY.','>TXVA','>TYVA'};
        var_tag = {'>ZXX.','>ZXY.','>ZYX.','>ZYY.','>TXVA','>TYVA'};

        % Read EDI file line by line
        nfreq = -1;
        while done == 0
            tline = fgetl(fid);
            if tline == -1
                done = 1;
            else
                hline = strtrim(tline);
                if isempty(hline); hline = ' '; end
                hline = strsplit(hline);
                cline = [hline{1},'               '];
                if nfreq <= 0
                    if strncmp(cline(1:5),'>FREQ',5)
                        % ">FREQ // ##" or ">FREQ NFREQ=38 ORDER=DEC // ##"
                        if isempty(strfind(hline{end},'/'))
                            nfreq = str2double(hline{end});
                        else % ">FREQ //##"
                            itag = max(strfind(hline{end},'/'))+1;
                            nfreq = str2double(hline{end}(itag:end));
                        end
                        ifreq = edi_block(fid,nfreq);
                        ZT = nan(nfreq,12);
                        ZTvar = nan(nfreq,6);
                    end
                else
                    % Look for MT data and variances (once frequencies have
                    % been counted)
                    switch cline(1:5)
                        % Collect impedance data
                        case data_tag{1}
                            ZT(:,1) = edi_block(fid,nfreq);
                        case data_tag{2}
                            ZT(:,2) = edi_block(fid,nfreq);
                        case data_tag{3}
                            ZT(:,3) = edi_block(fid,nfreq);
                        case data_tag{4}
                            ZT(:,4) = edi_block(fid,nfreq);
                        case data_tag{5}
                            ZT(:,5) = edi_block(fid,nfreq);
                        case data_tag{6}
                            ZT(:,6) = edi_block(fid,nfreq);
                        case data_tag{7}
                            ZT(:,7) = edi_block(fid,nfreq);
                        case data_tag{8}
                            ZT(:,8) = edi_block(fid,nfreq);
                        % Collect tipper data
                        case data_tag{9}
                            ZT(:,9) = edi_block(fid,nfreq);
                        case data_tag{10}
                            ZT(:,10) = edi_block(fid,nfreq);
                        case data_tag{11}
                            ZT(:,11) = edi_block(fid,nfreq);
                        case data_tag{12}
                            ZT(:,12) = edi_block(fid,nfreq);
                        % Collect variance data
                        case var_tag{1}
                            ZTvar(:,1) = edi_block(fid,nfreq);
                        case var_tag{2}
                            ZTvar(:,2) = edi_block(fid,nfreq);
                        case var_tag{3}
                            ZTvar(:,3) = edi_block(fid,nfreq);
                        case var_tag{4}
                            ZTvar(:,4) = edi_block(fid,nfreq);
                        case var_tag{5}
                            ZTvar(:,5) = edi_block(fid,nfreq);
                        case var_tag{6}
                            ZTvar(:,6) = edi_block(fid,nfreq);
                    end
                end
            end
        end
        fclose(fid);
        % If tipper data not found, # channels = 4
        if isnan(sum(ZT(:,9)))
            ich = 4;
        else
            ich = 5;
        end
    end
%--------------------------------------------------------------------------
% @read_spectra: recover MT data from spectral EDI files
%--------------------------------------------------------------------------
    function[ifreq,ZT,ZTvar,ich,edi_list] = read_spectra(read_file,spin)
        global site_name
        % Open input EDI file
        fid = fopen(read_file,'r');
        nsites = 0;
        
        % Strip file extension and path from file name
        ptag = strfind(read_file,'.');
        stag = strfind(read_file,'/');
        isite = read_file(stag(end)+1:ptag(end)-1);
        
        % Read EDI file line by line
        done = 0;
        tline = fgetl(fid);
        while done == 0
            % Stop reading at end of file
            if tline == -1
                done = 1;
            else
                hline = strtrim(tline);
                if isempty(hline); hline = ' '; end
                hline = strsplit(hline);
                if strcmp(hline{1},'>=SPECTRASECT')
                    % Found new data block!
                    % Next line contains SECTID
                    tline = fgetl(fid);
                    hline = strtrim(tline);
                    if isempty(hline); hline = ' '; end
                    hline = strsplit(hline);
                    % Collect SECTID
                    % May or may not be white space after 'SECTID='
                    if length(hline{1}) > 7
                        tsect = hline{1}(8:end);
                    else
                        tsect = hline{2};
                    end
                    % Remove quotations from SECTID
                    isect = tsect(tsect~='"');
                    % Look for SECTID in metadata (site_name)
                    % Note: only SECTID with corresponding metadata will be printed
                    switch get(f.drop,'value')
                        case 1 % single file
                            uindx = 1;
                            B = spin*pi/180;
                            filetype = 1;
                        case 2 % multiple single files
                            uindx = find(strcmp(isite,site_name));
                            B = spin*pi/180;
                            filetype = 1;
                        case 3 % single multisite file
                            uindx = find(strcmp(isect,site_name));
                            B = spin(uindx)*pi/180;
                            filetype = 2;
                    end
                    if ~isempty(uindx)
                        % Assign sect id to list of sect ids
                        nsites = nsites+1;
                        edi_list{nsites} = isect;
                        nf_max = 150;
                       
                        % Set up station variables
                        tspec = cell(nf_max,1); 
                        tfreq = nan(nf_max,1); 
                        tavgt = nan(nf_max,1);
                        site_end = 0; nfreq = 0;
                        % Read one site at a time
                        while site_end == 0
                            % Skip lines until '>SPECTRA' is found
                            hdr_stop = 0;
                            while hdr_stop == 0
                                hline = strtrim(tline);
                                if isempty(hline); hline = ' '; end
                                hline = strsplit(hline);
                                if strcmp(hline{1},'>SPECTRA')
                                    nfreq = nfreq+1;
                                    hdr_stop = 1;
                                else
                                    tline = fgetl(fid);
                                end
                            end

                            % Extract frequency and avgt
                            sect_hdr = strclean(tline);
                            ftag = find(strcmp(sect_hdr,'FREQ'));
                            tfreq(nfreq) = sect_hdr{ftag+2};
                            atag = find(strcmp(sect_hdr,'AVGT'));
                            tavgt(nfreq) = sect_hdr{atag+2};
                            
                            % Extract spectra block
                            [pdata,tline] = zmm_block(fid);
                            nch = sqrt(length(pdata));
                            tspec{nfreq} = transpose(reshape(pdata,nch,nch));
                            
                            % If current line is blank, advance one line
                            hline = strtrim(tline);
                            while isempty(hline);
                                tline = fgetl(fid);
                                hline = strtrim(tline);
                            end
                            hline = strsplit(hline); 

                            % Check for site ending qualifiers
                            if nfreq == nf_max;
                                site_end = 1;
                            elseif strcmp(hline{1},'>=SPECTRASECT')
                                site_end = 1;
                            elseif strcmp(hline{1},'>=MTSECT')
                                site_end = 1;
                            elseif strcmp(hline{1},'>END')
                                site_end = 1;
                                
                            end
                            
                            % Clean up variables
                            if site_end == 1
                                indx = ~isnan(tfreq);
                                tfreq = tfreq(indx);
                                tavgt = tavgt(indx);
                                tspec = tspec(indx);
                            end
                        end
                        
                        % Compile and rotate transfer functions and errors
                        % Work with one spectra block at a time
                        fcount = length(tfreq);
                        tZ = nan(fcount,12);
                        tZvar = nan(fcount,6);
                        for cc = 1:fcount
                            % Transform to impedance
                            ispec = spec2spec(tspec{cc});
                            [iZ,iZvar] = spec2z(ispec);
                            tZ(cc,:) = iZ;
                            tZvar(cc,:) = iZvar;
                        end
                        % Rotate impedance, tipper, and variance
                        if B ~= 0
                            [tZ,tZvar] = spinZ(tZ,tZvar,B);
                        end
                        
                        % Assign to output variables
                        if filetype == 1 % one site per file
                            ZT = tZ;
                            ZTvar = tZvar;
                            ifreq = tfreq;
                            ich = nch;
                        else % multiple sites per file
                            ZT{nsites} = tZ;
                            ZTvar{nsites} = tZvar;
                            ifreq{nsites} = tfreq;
                            ich(nsites) = nch;
                        end
                    end
                else
                    tline = fgetl(fid);
                end
            end
        end
        fclose(fid);
    end
%--------------------------------------------------------------------------
% @read_avg: recover MT data from AVG file (i.e. Zonge format)
%--------------------------------------------------------------------------
    function[ifreq,ZT,ZTvar,ich] = read_avg(read_file)
        
    end
%--------------------------------------------------------------------------
% @read_xls: recover MT data from Excel files
%--------------------------------------------------------------------------
    function[ifreq,ZT,ZTvar,ich] = read_xls(read_file)
        % Read input Excel file
        [data,hdr] = xlsread(read_file);

        % Organize data
        ifreq = data(:,strcmpi(hdr,'freq'));
        zxxr = data(:,strcmpi(hdr,'zxxr'));
        zxxi = data(:,strcmpi(hdr,'zxxi'));
        zxyr = data(:,strcmpi(hdr,'zxyr'));
        zxyi = data(:,strcmpi(hdr,'zxyi'));
        zyxr = data(:,strcmpi(hdr,'zyxr'));
        zyxi = data(:,strcmpi(hdr,'zyxi'));
        zyyr = data(:,strcmpi(hdr,'zyyr'));
        zyyi = data(:,strcmpi(hdr,'zyyi'));
        zstrk = data(:,strcmpi(hdr,'rot'));
        zxxv = data(:,strcmpi(hdr,'zxxvar'));
        zxyv = data(:,strcmpi(hdr,'zxyvar'));
        zyxv = data(:,strcmpi(hdr,'zyxvar'));
        zyyv = data(:,strcmpi(hdr,'zyyvar'));
        zxx = zxxr+1i*zxxi;
        zxy = zxyr+1i*zxyi;
        zyx = zyxr+1i*zyxi;
        zyy = zyyr+1i*zyyi;
        
        % Look for tipper info (if none, set tippers to nan)
        txr = data(:,strcmpi(hdr,'txr'));
        nfreq = length(ifreq);
        if isempty(txr)
            impT = nan(nfreq,1)*(1+1i*1);
            txr = impT;
            txi = impT;
            tyr = impT;
            tyi = impT;
            txv = impT;
            tyv = impT;
            ich = 4;
        else
            txi = data(:,strcmpi(hdr,'txi'));
            tyr = data(:,strcmpi(hdr,'tyr'));
            tyi = data(:,strcmpi(hdr,'tyi'));
            txv = data(:,strcmpi(hdr,'txvar'));
            tyv = data(:,strcmpi(hdr,'tyvar'));
            ich = 5;
        end
        tzx = txr+1i*txi;
        tzy = tyr+1i*tyi;
        
        % Store percent error magnitude
        exx = 2*sqrt(zxxv./(real(zxx).^2+imag(zxx).^2));
        exy = 2*sqrt(zxyv./(real(zxy).^2+imag(zxy).^2));
        eyx = 2*sqrt(zyxv./(real(zyx).^2+imag(zyx).^2));
        eyy = 2*sqrt(zyyv./(real(zyy).^2+imag(zyy).^2));
        ER = [exx exy eyx eyy];
        
        % Undo principal axes rotation
        for rr = 1:nfreq
            % Define rotation as degrees east of north:
            B = -zstrk(rr)*pi/180;

            % Construct 2x2 rotation matrix
            R = [cos(B) sin(B); -sin(B) cos(B)];

            % Construct unrotated impedance tensor and rotate
            URZ = [zxx(rr) zxy(rr);
                zyx(rr) zyy(rr)];
            % Rotate impedance
            ZS = R*URZ*R';
            % Reassign variables
            zxx(rr) = ZS(1,1);
            zxy(rr) = ZS(1,2);
            zyx(rr) = ZS(2,1);
            zyy(rr) = ZS(2,2);
            zxxv(rr) = 0.25*ER(rr,1)^2.*(real(ZS(1,1)).^2+imag(ZS(1,1)).^2);
            zxyv(rr) = 0.25*ER(rr,2)^2.*(real(ZS(1,2)).^2+imag(ZS(1,2)).^2);
            zyxv(rr) = 0.25*ER(rr,3)^2.*(real(ZS(2,1)).^2+imag(ZS(2,1)).^2);
            zyyv(rr) = 0.25*ER(rr,4)^2.*(real(ZS(2,2)).^2+imag(ZS(2,2)).^2);
            % Rotate tipper, if available
            if ich == 5
                URT = [tzx(rr); tzy(rr)];
                TS = R*URT;
                tzx(rr) = TS(1,1);
                tzy(rr) = TS(2,1);
            end
        end
       
        % Assign to output variables
        ZT = [real(zxx) imag(zxx) real(zxy) imag(zxy),...
            real(zyx) imag(zyx) real(zyy) imag(zyy),...
            real(tzx) imag(tzx) real(tzy) imag(tzy)];
        ZTvar = [zxxv zxyv zyxv zyyv txv tyv];
    end
%--------------------------------------------------------------------------
% @zmm_block: extract a data block from a z-file
%--------------------------------------------------------------------------
    function[output,tline] = zmm_block(fid0)
        done = 0; fcount = 0; output = nan(1,12);
        % Skip to next line
        while done == 0
            tline = fgetl(fid0);
            % Stop reading data block at end of file
            if tline == -1
                done = 1;
            else
                hline = strtrim(tline);
                % Stop reading data block at blank line
                if isempty(hline);
                    done = 1;
                else
                    % Stop reading data block at character (allow for '-')
                    if isnan(str2double(hline(1))) && ~strcmp(hline(1),'-')
                        done = 1;
                    else
                        hline = strsplit(hline);
                        nd = length(hline);
                        for dd = 1:nd
                            fcount = fcount+1;
                            output(fcount) = str2double(hline{dd});
                        end
                    end
                end
            end
        end
        % Remove trailing NaN from output
        indx = ~isnan(output);
        output = output(indx);
    end
%--------------------------------------------------------------------------
% @edi_block: extract a data block from an impedance EDI file
%--------------------------------------------------------------------------
    function[output] = edi_block(fid0,nf)
        output = NaN(nf,1);
        done = 0; fcount = 0;
        % Skip to next line
        while done == 0
            tline = fgetl(fid0);
            hline = strtrim(tline);
            % Stop reading data block at blank line
            if isempty(hline)
                done = 1;
            else
                % Stop reading data block at character (allow for '-')
                if isnan(str2double(hline(1))) && ~strcmp(hline(1),'-')
                    done = 1;
                else
                    hline = strsplit(hline);
                    nd = length(hline);
                    for dd = 1:nd
                        output(fcount+dd,1) = str2double(hline{dd});
                    end
                    fcount = fcount+nd;
                end
            end
            if fcount >= nf; done = 1; end
        end
    end
%--------------------------------------------------------------------------
% @spec2spec: assemble spectra data into a 5x5 or 7x7 matrix with proper
% conjugation (according to convention in mtpy)
%--------------------------------------------------------------------------
    function[output_spec] = spec2spec(input_spec)
        % Spectra data comes into the script as [nch x nch] matrix
        fspec = input_spec;
        nch = size(fspec,1);

        % Rearrange spectra for mtpy methods
        mspec = nan(size(fspec));
        for i = 1:nch
            for j = i:nch
                if i==j
                    mspec(i,j) = fspec(i,j);
                else
                    % complex conjugation of the original entries
                    mspec(i,j) = fspec(j,i)-1i*fspec(i,j);
                    % keep complex conjugated entries in the lower
                    % triangular matrix:
                    mspec(j,i) = fspec(j,i)+1i*fspec(i,j);
                end
            end
        end
        output_spec = mspec;
    end
%--------------------------------------------------------------------------
% @spec2z: calculate transfer functions (impedance and tipper) from spectra
%--------------------------------------------------------------------------
    function[Z,Zvar] = spec2z(input_spec)
        mspec = input_spec;
        nch = size(mspec,1);
        % We use the mtpy and ProcMT method for calculating Z and T
        switch nch
            case 4 % no remote reference, no tipper
                zdet = mspec(1,1)*mspec(2,2) - mspec(1,2)*mspec(2,1);
                zxx = (mspec(3,1)*mspec(2,2) - mspec(3,2)*mspec(2,1))/zdet;
                zxy = (mspec(3,2)*mspec(1,1) - mspec(3,1)*mspec(1,2))/zdet;
                zyx = (mspec(4,1)*mspec(2,2) - mspec(4,2)*mspec(2,1))/zdet;
                zyy = (mspec(4,2)*mspec(1,1) - mspec(4,1)*mspec(1,2))/zdet;
                tzx = nan(size(zxx))*(1+1i*1);
                tzy = nan(size(zxx))*(1+1i*1);
            case 5 % no remote reference, tipper
                zdet = mspec(1,1)*mspec(2,2) - mspec(1,2)*mspec(2,1);
                zxx = (mspec(4,1)*mspec(2,2) - mspec(4,2)*mspec(2,1))/zdet;
                zxy = (mspec(4,2)*mspec(1,1) - mspec(4,1)*mspec(1,2))/zdet;
                zyx = (mspec(5,1)*mspec(2,2) - mspec(5,2)*mspec(2,1))/zdet;
                zyy = (mspec(5,2)*mspec(1,1) - mspec(5,1)*mspec(1,2))/zdet;
                tzx = (mspec(3,1)*mspec(2,2) - mspec(3,2)*mspec(2,1))/zdet;
                tzy = (mspec(3,2)*mspec(1,1) - mspec(3,1)*mspec(1,2))/zdet;
            case 6 % remote reference, no tipper
                zdet = mspec(1,5)*mspec(2,6) - mspec(1,6)*mspec(2,5);
                zxx = (mspec(3,5)*mspec(2,6) - mspec(3,6)*mspec(2,5))/zdet;
                zxy = (mspec(3,6)*mspec(1,5) - mspec(3,5)*mspec(1,6))/zdet;
                zyx = (mspec(6,5)*mspec(2,6) - mspec(4,6)*mspec(2,5))/zdet;
                zyy = (mspec(6,6)*mspec(1,5) - mspec(4,5)*mspec(1,6))/zdet;
                tzx = nan(size(zxx))*(1+1i*1);
                tzy = nan(size(zxx))*(1+1i*1);
            case 7 % remote reference, tipper
                zdet = mspec(1,6)*mspec(2,7) - mspec(1,7)*mspec(2,6);
                zxx = (mspec(4,6)*mspec(2,7) - mspec(4,7)*mspec(2,6))/zdet;
                zxy = (mspec(4,7)*mspec(1,6) - mspec(4,6)*mspec(1,7))/zdet;
                zyx = (mspec(5,6)*mspec(2,7) - mspec(5,7)*mspec(2,6))/zdet;
                zyy = (mspec(5,7)*mspec(1,6) - mspec(5,6)*mspec(1,7))/zdet;
                tzx = (mspec(3,6)*mspec(2,7) - mspec(3,7)*mspec(2,6))/zdet;
                tzy = (mspec(3,7)*mspec(1,6) - mspec(3,6)*mspec(1,7))/zdet;
        end

        % Calculate errors (for now default hardwire is 20% error on Z)
        zxxv = 0.25*xpercent^2.*(real(zxx).^2+imag(zxx).^2);
        zxyv = 0.25*xpercent^2.*(real(zxy).^2+imag(zxy).^2);
        zyxv = 0.25*xpercent^2.*(real(zyx).^2+imag(zyx).^2);
        zyyv = 0.25*xpercent^2.*(real(zyy).^2+imag(zyy).^2);
        tx_std = 0.06; txv = tx_std^2;
        ty_std = 0.06; tyv = ty_std^2;

        % Assign to output variables
        Z = [real(zxx) imag(zxx) real(zxy) imag(zxy),...
            real(zyx) imag(zyx) real(zyy) imag(zyy),...
            real(tzx) imag(tzx) real(tzy) imag(tzy)];
        Zvar = [zxxv zxyv zyxv zyyv txv tyv];
    end
%--------------------------------------------------------------------------
% @spinZ: calculate rotated impedance tensors
%--------------------------------------------------------------------------
    function[ZR,ZRvar] = spinZ(iZ,iZvar,B)
        % iZ: [nfreq x 12]
        %   columns 1-8: complex impedance components
        %   columns 9-12: complex tipper components
        % iZvar: [nfreq x 6]
        %   columns 1-4: impedance component variance
        %   columns 5-6: tipper component variance
        %------------------------------------------------------------------
        % Make rotation matrix
        R = [cos(B) sin(B); -sin(B) cos(B)];
        
        % Parse out impedance and variances
        zxxv = iZvar(:,1);
        zxyv = iZvar(:,2);
        zyxv = iZvar(:,3);
        zyyv = iZvar(:,4);
        zxx = iZ(:,1)+1i*iZ(:,2);
        zxy = iZ(:,3)+1i*iZ(:,4);
        zyx = iZ(:,5)+1i*iZ(:,6);
        zyy = iZ(:,7)+1i*iZ(:,8);
        tzx = iZ(:,9)+1i*iZ(:,10);
        tzy = iZ(:,11)+1i*iZ(:,12);
        
        % Determine # channels
        nfreq = length(zxx);
        if sum(isnan(tzx)) < nfreq
            nch = 5;
        else
            nch = 4;
        end
        
        % Determine percent error of unrotated data
        exx = 2*sqrt(zxxv./(real(zxx).^2+imag(zxx).^2));
        exy = 2*sqrt(zxyv./(real(zxy).^2+imag(zxy).^2));
        eyx = 2*sqrt(zyxv./(real(zyx).^2+imag(zyx).^2));
        eyy = 2*sqrt(zyyv./(real(zyy).^2+imag(zyy).^2));
        ER = [exx exy eyx eyy];
        
        % Rotate data one frequency at a time
        for dd = 1:nfreq
            % Construct impedance tensor
            URZ = [zxx(dd) zxy(dd);
                zyx(dd) zyy(dd)];
            % Rotate impedance
            ZS = R*URZ*R';
            % Reassign variables
            zxx(dd) = ZS(1,1);
            zxy(dd) = ZS(1,2);
            zyx(dd) = ZS(2,1);
            zyy(dd) = ZS(2,2);
            zxxv(dd) = 0.25*ER(dd,1)^2.*(real(ZS(1,1)).^2+imag(ZS(1,1)).^2);
            zxyv(dd) = 0.25*ER(dd,2)^2.*(real(ZS(1,2)).^2+imag(ZS(1,2)).^2);
            zyxv(dd) = 0.25*ER(dd,3)^2.*(real(ZS(2,1)).^2+imag(ZS(2,1)).^2);
            zyyv(dd) = 0.25*ER(dd,4)^2.*(real(ZS(2,2)).^2+imag(ZS(2,2)).^2);
            % Rotate tipper, if available
            if nch == 5
                URT = [tzx(dd); tzy(dd)];
                TS = R*URT;
                tzx(dd) = TS(1,1);
                tzy(dd) = TS(2,1);
            end
        end
        
        % Assign to output variables
        ZR = [real(zxx) imag(zxx) real(zxy) imag(zxy),...
            real(zyx) imag(zyx) real(zyy) imag(zyy),...
            real(tzx) imag(tzx) real(tzy) imag(tzy)];
        ZRvar = [zxxv zxyv zyxv zyyv iZvar(:,5) iZvar(:,6)];

    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALLBACK FUNCTIONS - SECTION III: WRITE EDI FILES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @write_hdr
% @write_edi
% @edi_output
%--------------------------------------------------------------------------
% @write_hdr: write EDI file header
%--------------------------------------------------------------------------
    function write_hdr(fid,site_info,survey_info)
        
        % Data section ID
        sect_id = [survey_info{11},site_info{1}];
        
        % lat/lon values
        ilat = site_info{3};
        ilon = site_info{4};
        % lat/lon strings
        site_lat = dec2deg(ilat);
        site_lon = dec2deg(ilon);
        
        % query national map elevation database
        % (requires internet connection)
        if nat_map_on == 1
            ielv = natmaplook(ilat,ilon);
        else
            ielv = site_info{5};
        end
        % elevation string
        site_elv = num2str(round(100*ielv)/100,6);

        % file print number
        nsite = num2str(site_info{6});
        while length(nsite)<3
            nsite = ['0',nsite];
        end        
        
        % number of frequencies
        nfreq = site_info{9};

        % Convert YYYMMDD to mm/dd/yy
        idate = num2str(site_info{2});
        start_stamp = [idate(5:6),'/',idate(7:8),'/',idate(3:4)];
        
        %------------------------------ PRINT EDI FILE HEADER -----
        fprintf(fid,'>HEAD\n\n');
        fprintf(fid,' DATAID="%s"\n',sect_id);
        fprintf(fid,' ACQBY="%s"\n',survey_info{6});
        fprintf(fid,' FILEBY=%s\n',survey_info{9});
        fprintf(fid,' ACQDATE=%s\n',start_stamp);
        fprintf(fid,' FILEDATE=%s\n',datestr(now,'mm/dd/yy'));
        fprintf(fid,' COUNTRY=%s\n',survey_info{3});
        fprintf(fid,' STATE=%s\n',survey_info{4});
        fprintf(fid,' LAT=%s\n',site_lat);
        fprintf(fid,' LONG=%s\n',site_lon);
        fprintf(fid,' ELEV=%s\n',site_elv);
        fprintf(fid,' UNITS=M\n');
        fprintf(fid,' STDVERS=1.0\n');
        fprintf(fid,' PROGVERS=edi_converter_v2.m\n');
        fprintf(fid,' PROGDATE=04/17/18\n');
        fprintf(fid,'\n');
        fprintf(fid,'>INFO\n');  
        fprintf(fid,' MAXINFO=999\n');  
        fprintf(fid,' PROJECT=%s\n',survey_info{1});                                                                  
        fprintf(fid,' SURVEY="%s"\n',survey_info{2});                                                       
        fprintf(fid,' YEAR=%s\n',survey_info{5});                                                                        
        fprintf(fid,' PROCESSEDBY=%s\n',survey_info{7});                                                         
        fprintf(fid,' PROCESSINGSOFTWARE=%s\n',survey_info{8});                                                                                                        
        fprintf(fid,'\n');
        %--------------------------- PRINT SURVEY DESCRIPTION -----
        % Print the description as a series of lines 50 char long:
        description = survey_info{10};
        cline = 50;
        if isempty(description)
            fprintf(fid,'\n');
        elseif length(description) <= cline
            fprintf(fid,'%s\n\n',description);
        else
            ndlines = ceil(length(description)/cline);
            space_id = strfind(description,' ');
            for j = 1:ndlines
                tag1 = j*cline;
                tag2 = (j-1)*cline;
                lowrange = find(space_id <= tag1);
                if lowrange(end) == length(space_id) && j == ndlines
                    fprintf(fid,'%s\n',description(grab(length(grab))+1:end));
                else
                    uprange = find(space_id > tag2);
                    if j == 1
                        grab = space_id(intersect(lowrange,uprange));
                        iprint = description(1:grab(end)-1);
                    else
                        grab = space_id([uprange(1)-1,intersect(lowrange,uprange)]);
                        iprint = description(grab(1)+1:grab(end)-1);
                    end
                    fprintf(fid,'%s\n',iprint);
                end
                if j == ndlines; fprintf(fid,'\n'); end
            end
        end
        %----------------------------------------------------------
        fprintf(fid,'>=DEFINEMEAS\n');
        fprintf(fid,' MAXCHAN=7\n');
        fprintf(fid,' MAXRUN=999\n');
        fprintf(fid,' MAXMEAS=99999\n');
        fprintf(fid,' UNITS=M\n');
        fprintf(fid,' REFLOC="%s"\n',survey_info{2}); 
        fprintf(fid,' REFLAT=%s\n',site_lat);
        fprintf(fid,' REFLONG=%s\n',site_lon);
        fprintf(fid,' REFELEV=%s\n',site_elv);
        fprintf(fid,'\n');
        fprintf(fid,'>HMEAS ID=%s1.001 CHTYPE=HX X=0.0 Y=0.0 Z=0.0 AZM=%0.1f\n',...
            nsite,survey_info{12}(1));
        fprintf(fid,'>HMEAS ID=%s2.001 CHTYPE=HY X=0.0 Y=0.0 Z=0.0 AZM=%0.1f\n',...
            nsite,survey_info{12}(2));
        fprintf(fid,'>HMEAS ID=%s3.001 CHTYPE=HZ X=0.0 Y=0.0 Z=0.0 AZM=0.0\n',nsite);
        fprintf(fid,'>EMEAS ID=%s4.001 CHTYPE=EX X=0.0 Y=0.0 Z=0.0 ',nsite);
        fprintf(fid,'X2=%0.1f Y2=0.0 AZM=%0.1f\n',site_info{7},survey_info{12}(1));
        fprintf(fid,'>EMEAS ID=%s5.001 CHTYPE=EY X=0.0 Y=0.0 Z=0.0 ',nsite);
        fprintf(fid,'X2=0.0 Y2=%0.1f AZM=%0.1f\n',site_info{8},survey_info{12}(2));
        fprintf(fid,'\n');
        fprintf(fid,'>=MTSECT\n');
        fprintf(fid,' SECTID="%s"\n',sect_id);
        fprintf(fid,' NFREQ=%i\n',nfreq);
        fprintf(fid,' HX= %s1.001\n',nsite);
        fprintf(fid,' HY= %s2.001\n',nsite);
        fprintf(fid,' HZ= %s3.001\n',nsite);
        fprintf(fid,' EX= %s4.001\n',nsite);
        fprintf(fid,' EY= %s5.001\n',nsite);
        fprintf(fid,'\n');
    end
%--------------------------------------------------------------------------
% @write_edi: write freq, zrot, and data blocks of EDI file
%--------------------------------------------------------------------------
    function write_edi(fid,ifreq,ZT,ZTvar,ich)
        
        % Default values
        nf = length(ifreq);
        zrot = zeros(nf,1); % rotation data block
        ncol = 6; % number of columns to print in each data block
        
        % Print frequency and ZROT
        fprintf(fid,'>!****FREQUENCIES****!\n');
        fprintf(fid,'>FREQ NFREQ=%0.0f ORDER=DEC // %0.0f\n',nf,nf);
        edi_output(fid,ifreq,nf,ncol);
        fprintf(fid,'>!****IMPEDANCE ROTATION ANGLES****!\n');
        fprintf(fid,'>ZROT // %0.0f\n',nf);
        edi_output(fid,zrot,nf,ncol);
       
        % Print impedance data blocks
        L = {'ZXX','ZXY','ZYX','ZYY','TX','TY'};
        fprintf(fid,'>!****IMPEDANCES****!\n');
        for dd = 1:4
            fprintf(fid,['>',L{dd},'R ROT=ZROT // %0.0f\n'],nf);
            edi_output(fid,ZT(:,2*dd-1),nf,ncol);
            fprintf(fid,['>',L{dd},'I ROT=ZROT // %0.0f\n'],nf);
            edi_output(fid,ZT(:,2*dd),nf,ncol);
            fprintf(fid,['>',L{dd},'.VAR ROT=ZROT // %0.0f\n'],nf);
            edi_output(fid,ZTvar(:,dd),nf,ncol);
        end
        % Print tipper data blocks (if availble)
        if ich > 4
            fprintf(fid,'>!****TIPPER PARAMETERS****!\n');
            for dd = 5:6
                fprintf(fid,['>',L{dd},'R.EXP // %0.0f\n'],nf);
                edi_output(fid,ZT(:,2*dd-1),nf,ncol);
                fprintf(fid,['>',L{dd},'I.EXP // %0.0f\n'],nf);
                edi_output(fid,ZT(:,2*dd),nf,ncol);
                fprintf(fid,['>',L{dd},'VAR.EXP // %0.0f\n'],nf);
                edi_output(fid,ZTvar(:,dd),nf,ncol);
            end
        end
        
        % End file and close
        fprintf(fid,'\n>END\n');
        fclose(fid);
    end
%--------------------------------------------------------------------------
% @edi_output: print a block of MT data in EDI format
%--------------------------------------------------------------------------
    function edi_output(fid,data_vector,nf,ncol)
        for ww = 1:nf
            fprintf(fid,'%s',data2str(data_vector(ww),4));
            if rem(ww,ncol)==0 || ww==nf
                fprintf(fid,'\n');
            end
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALLBACK FUNCTIONS - SECTION IV: GUI CONTROLS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @set_input
% @set_GUI
% @set_rotate1
% @set_rotate2
% @fetch_rotation
% @fill_GUI
% @switch_elev
% @start_edi
% @start_png
% @clear_fields
% @close_all
%--------------------------------------------------------------------------
% @set_input: change options for "# Input Files" drop down menu
%--------------------------------------------------------------------------
    function set_input(~,~)
        switch get(g.drop,'value')
            case 1
                set(f.drop,'string','---');
            case 4
                set(f.drop,'string',{'single file','directory','multisite file'});
            otherwise
                set(f.drop,'string',{'single file','directory'});
        end
    end
%--------------------------------------------------------------------------
% @set_GUI: turn GUI elements on/off depending on data type
%--------------------------------------------------------------------------
    function set_GUI(~,~)
        switch ftype
            case 'single'
                set(r.drop(1),'string',{'select one','geographic','geomagnetic',...
                    'acquisition','unknown'});
                set(t.button,'enable','off')
                if test_mode == 1
                    set(s.edit(1),'string','001')
                    set(s.edit(2),'string','test_site')
                    set(z.edit(1),'string','999.99')
                    set(z.edit(2),'string','')
                    set(m.edit(7),'string','42.123456789')
                    set(m.edit(8),'string','-102.123456789')
                else
                    set(s.edit(1),'enable','on','backgroundcolor',[1 1 0])
                    set(s.edit(2),'enable','on')
                    set(z.edit(1),'enable','on')
                    set(z.edit(2),'enable','on')
                    for mm = 1:8
                        set(m.edit(mm),'enable','on')
                    end
                end
            case 'batch'
                set(t.button,'enable','on')
                set(s.edit(1),'enable','off','backgroundcolor',[1 1 1])
                set(s.edit(2),'enable','off')
                set(z.edit(1),'enable','off')
                set(z.edit(2),'enable','off')
                for mm = 1:8
                    set(m.edit(mm),'enable','off')
                end
                set(r.drop(1),'string',{'select one','geographic','geomagnetic (uniform decl.)',...
                    'acquisition (site dependent)','unknown'});
        end
        if test_mode == 1
            set(r.drop(1),'enable','on','value',test_spin)
            set(d.edit(2),'string','test');
            set_rotate1
        else
            set(r.drop(1),'enable','on','value',1)
        end
        set(r.drop(2),'enable','off','value',1,'string','---')
        set(r.edit(1),'enable','off','backgroundcolor',[1 1 1])
        set(r.edit(2),'enable','off','backgroundcolor',[1 1 1])
        set(t.edit,'string','')
    end
%--------------------------------------------------------------------------
% @set_rotate1: edit rotation options depending on data coordinate system
%--------------------------------------------------------------------------
    function set_rotate1(~,~)
        % Clear edit boxes and turn off by default
        set(r.edit(1),'string','','enable','off','backgroundcolor',[1 1 1])
        set(r.edit(2),'string','','enable','off','backgroundcolor',[1 1 1])
        % Edit rotation option drop down menus
        set(r.drop(2),'value',1,'enable','on')
        switch get(r.drop(1),'value')
            case 2
                set(r.drop(2),'string',{'do not rotate','user defined'})
                set(r.edit(1),'string','0') 
            case 3
                set(r.drop(2),'string',{'do not rotate','rotate to geographic'})
                set(r.edit(1),'enable','on','backgroundcolor',[1 1 0])
            case 4
                set(r.drop(2),'string',{'do not rotate','rotate to geographic'})
                if strcmp(ftype,'single')
                    set(r.edit(1),'enable','on','backgroundcolor',[1 1 0])
                end
            otherwise
                set(r.drop(2),'string','---')
        end
    end
%--------------------------------------------------------------------------
% @set_rotate2: turn on rotation angle box (if necessary)
%--------------------------------------------------------------------------
    function set_rotate2(~,~)
        % Turn on rotation angle box for user defined rotation only
        if get(r.drop(1),'value') == 2 && get(r.drop(2),'value') == 2
            set(r.edit(2),'enable','on','backgroundcolor',[1 1 0])
        else
            set(r.edit(2),'string','','enable','off','backgroundcolor',[1 1 1])
        end
    end
%--------------------------------------------------------------------------
% @fetch_rotation: determine rotation preferences
%--------------------------------------------------------------------------
    function fetch_rotation(~,~)
        %   rtype(1) = final coordinate system id
        %      0 = UNKNOWN
        %      1 = GEOGRAPHIC
        %      2 = GEOMAGNETIC
        %      3 = ACQUISITION
        %      4 = USER DEFINED
        %   rtype(2) = rotation angle tag
        %      0 = no rotation
        %      1 = r.edit(1)
        %      2 = r.edit(2)
        %      3 = metadata file
        %   rtype(3) = x-direction azimuth tag
        %      0 = zero degrees
        %      1 = r.edit(1)
        %      2 = r.edit(2)
        %      3 = metadata file
        global rtype
        
        % Get values from rotation drop down menus
        ctype = get(r.drop(1),'value');
        rpick = get(r.drop(2),'value');
        if rpick == 1 % no rotation
            switch ctype
                case 2 % geographic
                    rtype = [1 0 0];
                case 3 % geomagnetic
                    rtype = [2 0 1];
                case 4
                    if strcmp(ftype,'single')
                        rtype = [3 0 1];
                    else
                        rtype = [3 0 3];
                    end
                otherwise
                    rtype = [0 0 0];
            end
        else % rotation
            switch ctype
                case 2 % geographic to user defined
                    rtype = [4 2 2];
                case 3 % geomagnetic rotated to geographic
                    rtype = [1 1 0];
                case 4 % acquisition to geographic
                    if strcmp(ftype,'single')
                        rtype = [1 1 0];
                    else
                        rtype = [1 3 0];
                    end
                otherwise
                    rtype = [0 0 0];
            end  
        end
    end
%--------------------------------------------------------------------------
% @fill_GUI: use header info from selected EDI file to fill select 
% metadata fields in Single Site Metadata section of GUI
%--------------------------------------------------------------------------
    function fill_GUI(read_file)
        % Fills in the following metadata fields
        %  s.edit(2) - station name
        %  h.edit(3) - country
        %  h.edit(4) - state/province
        %  h.edit(5) - acquistion year
        %  z.edit(1) - elevation (assumed given in meters)
        %  m.edit(1):m.edit(8) - lat & lon (assumed given in dd:mm:ss.s)
        
        % Open input EDI file
        fid = fopen(read_file,'r');
        hdr_end = 0;
        set(s.edit(1),'string','')
        
        % Read EDI header line by line
        while hdr_end == 0
            tline = fgetl(fid);
            if tline == -1
                hdr_end = 1;
            else
                hline = strtrim(tline);
                if isempty(hline); hline = ' '; end
                hline = strsplit(hline);
                cline = [hline{1},'               '];
                if strcmp(hline{1},'>HMEAS')
                    % Stop reading if >HMEAS has been reached
                    hdr_end = 1;
                elseif strncmp(cline(1:8),'ACQDATE=',8)
                    % acquisition year
                    % Find equal sign "=" & remove quotations
                    etag = strfind(tline,'=');
                    dstr = strtrim(tline(etag+1:end));
                    dstr = dstr(dstr~='"');
                    % Isolate year and add '19--' or '20--'
                    stag = strfind(dstr,'/');
                    iyr = dstr(stag(end)+1:end);
                    if length(iyr) < 4
                        if str2double(iyr) < 50
                            ystr = ['20',iyr];
                        else
                            ystr = ['19',iyr];
                        end
                    else
                        ystr = iyr;
                    end
                    set(h.edit(5),'string',ystr);
                elseif strncmp(cline(1:7),'REFLOC=',7)
                    % site name
                    etag = strfind(tline,'=');
                    dstr = strtrim(tline(etag+1:end));
                    dstr = dstr(dstr~='"');
                    set(s.edit(2),'string',dstr);
                elseif strncmp(cline(1:8),'COUNTRY=',8)
                    % country
                    etag = strfind(tline,'=');
                    dstr = strtrim(tline(etag+1:end));
                    dstr = dstr(dstr~='"');
                    set(h.edit(3),'string',dstr);
                elseif strncmp(cline(1:6),'STATE=',6)
                    % state
                    etag = strfind(tline,'=');
                    dstr = strtrim(tline(etag+1:end));
                    dstr = dstr(dstr~='"');
                    set(h.edit(4),'string',dstr);
                elseif strncmp(cline(1:5),'ELEV=',5)
                    % elevation
                    etag = strfind(tline,'=');
                    dstr = strtrim(tline(etag+1:end));
                    dstr = dstr(dstr~='"');
                    set(z.edit(1),'string',dstr);
                    set(z.edit(2),'string','');
                elseif strncmp(cline(1:4),'LAT=',4)
                    % latitude
                    etag = strfind(tline,'=');
                    dstr = strtrim(tline(etag+1:end));
                    dstr = dstr(dstr~='"');
                    if strcmp(dstr(end),'.')
                        dstr = dstr(1:end-1);
                    end
                    dindx = strfind(dstr,':');
                    set(m.edit(1),'string',dstr(1:dindx(1)-1));
                    set(m.edit(2),'string',dstr(dindx(1)+1:dindx(2)-1));
                    set(m.edit(3),'string',dstr(dindx(2)+1:end));
                    set(m.edit(7),'string','');
                elseif strncmp(cline(1:5),'LONG=',5)
                    % longitude
                    etag = strfind(tline,'=');
                    dstr = strtrim(tline(etag+1:end));
                    dstr = dstr(dstr~='"');
                    if strcmp(dstr(end),'.')
                        dstr = dstr(1:end-1);
                    end
                    dindx = strfind(dstr,':');
                    set(m.edit(4),'string',dstr(1:dindx(1)-1));
                    set(m.edit(5),'string',dstr(dindx(1)+1:dindx(2)-1));
                    set(m.edit(6),'string',dstr(dindx(2)+1:end));
                    set(m.edit(8),'string','');
                end
            end
        end
        fclose(fid);
    end
%--------------------------------------------------------------------------
% @switch_elev: toggle national map elevation query tool on/off
%--------------------------------------------------------------------------
    function switch_elev(~,~)
        if ishghandle(wbox); delete(wbox); end
        if nat_map_on == 0
            online = webcheck;
            if online == 1
                nat_map_on = 1;
                set(w.button(2),'foregroundcolor',[0 1 0])
            else
                wbox = warndlg({'Please connect to the Internet.'});
                return
            end
        else
            nat_map_on = 0;
            set(w.button(2),'foregroundcolor',[1 0 0])
        end
    end
%--------------------------------------------------------------------------
% @start_edi: run initialize such that both EDIs and PNGs are printed
%--------------------------------------------------------------------------
    function start_edi(~,~)
        plots_only = 0;
        initialize;
    end
%--------------------------------------------------------------------------
% @start_png: run initialize such that only PNGs are printed
%--------------------------------------------------------------------------
    function start_png(~,~)
        plots_only = 1;
        initialize;
    end
%--------------------------------------------------------------------------
% @clear_fields: clear all GUI edit boxes and reset settings
%--------------------------------------------------------------------------
    function clear_fields(~,~)
        % Clear data file/directory selection
        set(d.edit(1),'string','')
        set(d.edit(2),'string','')
        % Clear drop down menus
        set(g.drop,'value',1)
        set(f.drop,'value',1,'string','---');
        % Clear rotation preferences
        set(r.drop(1),'value',1,'string','---','enable','off')
        set(r.drop(2),'value',1,'string','---','enable','off')
        set(r.edit(1),'string','','backgroundcolor',[1 1 1],'enable','off')
        set(r.edit(2),'string','','backgroundcolor',[1 1 1],'enable','off')
        % Clear metadata file
        set(t.edit,'string','')
        % Clear single site information
        set(s.edit(1),'string','','enable','off')
        set(s.edit(2),'string','','enable','off')
        for kk = 1:8
            set(m.edit(kk),'string','','enable','off')
        end
        set(z.edit(1),'string','','enable','off')
        set(z.edit(2),'string','','enable','off')
        set(t.edit(1),'string','')
        % Clear survey information
        for kk = 1:10
            set(h.edit(kk),'string','')
        end
        % Turn off Nat Map query tool
        if nat_map_on == 1
            switch_elev;
        end
        ipath = home;
    end
%--------------------------------------------------------------------------
% @close_all: close GUI
%--------------------------------------------------------------------------
    function close_all(~,~)
        cd(home)
        close(p.fig1)
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALLBACK FUNCTIONS - SECTION V: 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%--------------------------------------------------------------------------
% @read_avg: load Zonge avg file data
%--------------------------------------------------------------------------
%     function[tfreq,ZT,ZTvar] = read_avg(avg_file,spin)
%         zblock = cell(1,6);
%         % Open spectra EDI file
%         fid1 = fopen(avg_file,'r');
%         
%         % Read to end of file, starting with line #1
%         tline = fgetl(fid1);
%         if isempty(tline); tline = ' '; end
%         tcount = 0;
%         while tline > -1
%             cline = strtrim(tline);
%             % Account for empty lines
%             if isempty(cline); cline = ' '; end
%             cline = strsplit(cline);
%             tcount = tcount+1;
%             % Locate section header
%             if strcmp(cline{1},'$Rx.Cmp')
%                 [zdata,tline] = read_avg_block(fid1);
%                 switch char(cline{3})
%                     case 'Zxx'
%                         zindx = 1;
%                     case 'Zxy'
%                         zindx = 2;
%                     case 'Zyx'
%                         zindx = 3;
%                     case 'Zyy'
%                         zindx = 4;
%                     case 'Tzx'
%                         zindx = 5;
%                     case 'Tzy'
%                         zindx = 6;
%                 end
%                 zblock{zindx} = zdata;
%             else
%                 tline = fgetl(fid1);
%             end            
%         end % END of avg file  
%         fclose(fid1);
%         
%         % Convert to complex values
%         [tfreq,ZT,ZTvar] = avg2z(zblock);
%         
%     end
%--------------------------------------------------------------------------
% @read_avg_block: read in a block of AVG transfer functions
%--------------------------------------------------------------------------
    function[dblock,tline] = read_avg_block(f)
        exit_func = 0;
        dblock = [];
        while exit_func == 0
            tline = fgetl(f);
            if tline == -1
                exit_func = 1;
            else
                cline = strtrim(tline);
                % Account for empty lines
                if isempty(cline); cline = ' '; end
                cline = strsplit(cline);
                if strcmp(cline{1},'$Rx.Cmp')
                    exit_func = 1;
                elseif ~strcmp(cline{1}(1),'$')
                    nline = strsplit(tline(tline~=','));
                    dline = str2num(char(nline))';
                    dblock = [dblock; dline([2 5 6 9])];
                end
            end
        end
    end
%--------------------------------------------------------------------------
% @avg2z: calculate EDI format transfer functions (e.g. zxxr, zxxi, zxyr) 
% from avg transfer functions (z_mag, z_phs)
%--------------------------------------------------------------------------
    function[freq,transfer_func,var_estimates] = avg2z(avg_data)
        
        % Double check for similar frequency sets at single site
        nfreq = length(avg_data{1}(:,1));
        for rr = 2:6
            fsize = length(avg_data{rr}(:,1));
            if fsize ~= nfreq
                error('Frequency sets in AVG file do not match!')
            end
        end
        
        transfer_func = nan(nfreq,12);
        var_estimates = nan(nfreq,6);
        for rr = 1:6
            idata = avg_data{rr};
            if rr == 1
                freq = idata(:,1); % frequency [Hz]
            end
            zmag = idata(:,2); % magnitude
            zphs = idata(:,3)/1e3; % phase in radians
            zreal = zmag.*cos(zphs);
            zimag = zmag.*sin(zphs);
            
            % Assign to transfer function matrix
            transfer_func(:,rr*2-1) = zreal;
            transfer_func(:,rr*2) = zimag;

            % Calcuate variance
            zperc = idata(:,4)/1e3; % z phase error in radians
            zstd = zperc.*zmag; % standard error
            var_estimates(:,rr) = zstd.^2; % variance
        end
    end
%--------------------------------------------------------------------------
% @read_xls: extract magnetotelluric impedance data from an Excel file
% NOTE: assumes specific header strings but does not assume column order
%--------------------------------------------------------------------------
%     function [tfreq,ZT,ZTvar] = read_xls(xlsfile)
%         
%         % Read Excel file
%         [data,hdr] = xlsread(xlsfile);
% 
%         % Organize data
%         tfreq = data(:,strcmpi(hdr,'freq'));
%         zxxr = data(:,strcmpi(hdr,'zxxr'));
%         zxxi = data(:,strcmpi(hdr,'zxxi'));
%         zxyr = data(:,strcmpi(hdr,'zxyr'));
%         zxyi = data(:,strcmpi(hdr,'zxyi'));
%         zyxr = data(:,strcmpi(hdr,'zyxr'));
%         zyxi = data(:,strcmpi(hdr,'zyxi'));
%         zyyr = data(:,strcmpi(hdr,'zyyr'));
%         zyyi = data(:,strcmpi(hdr,'zyyi'));
%         zstrk = data(:,strcmpi(hdr,'rot'));
%         
%         zxxvar = data(:,strcmpi(hdr,'zxxvar'));
%         zxyvar = data(:,strcmpi(hdr,'zxyvar'));
%         zyxvar = data(:,strcmpi(hdr,'zyxvar'));
%         zyyvar = data(:,strcmpi(hdr,'zyyvar'));
%         
%         % Look for tipper info (if none, set tippers to zero)
%         txr = data(:,strcmpi(hdr,'txr'));
%         if isempty(txr)
%             impT = zeros(length(tfreq),1);
%             txr = impT;
%             txi = impT;
%             tyr = impT;
%             tyi = impT;
%             txvar = impT;
%             tyvar = impT;
%         else
%             txi = data(:,strcmpi(hdr,'txi'));
%             tyr = data(:,strcmpi(hdr,'tyr'));
%             tyi = data(:,strcmpi(hdr,'tyi'));
%             txvar = data(:,strcmpi(hdr,'txvar'));
%             tyvar = data(:,strcmpi(hdr,'tyvar'));
%         end
% 
%         % Store error magnitudes
%         emag_xx = 2*sqrt(zxxvar)./sqrt(zxxr.^2+zxxi.^2);
%         emag_xy = 2*sqrt(zxyvar)./sqrt(zxyr.^2+zxyi.^2);
%         emag_yx = 2*sqrt(zyxvar)./sqrt(zyxr.^2+zyxi.^2);
%         emag_yy = 2*sqrt(zyyvar)./sqrt(zyyr.^2+zyyi.^2);
%         
%         % Undo principal axes rotation
%         for rr = 1:length(tfreq)
%             % Define rotation as degrees east of north:
%             B = -zstrk(rr)*pi/180;
% 
%             % Construct 2x2 rotation matrix
%             R = [cos(B) sin(B); -sin(B) cos(B)];
% 
%             % Construct unrotated impedance tensor and rotate
%             ZUR = [zxxr(rr)+1i*zxxi(rr) zxyr(rr)+1i*zxyi(rr);
%                  zyxr(rr)+1i*zyxi(rr) zyyr(rr)+1i*zyyi(rr)];
%             ZR = R*ZUR*R';
%             zxxr(rr) = real(ZR(1,1));
%             zxxi(rr) = imag(ZR(1,1));
%             zxyr(rr) = real(ZR(1,2));
%             zxyi(rr) = imag(ZR(1,2));
%             zyxr(rr) = real(ZR(2,1));
%             zyxi(rr) = imag(ZR(2,1));
%             zyyr(rr) = real(ZR(2,2));
%             zyyi(rr) = imag(ZR(2,2));
%         end
%         
%         % Apply percent error to rotated data
%         zxxvar = (0.5*sqrt(zxxr.^2+zxxi.^2).*emag_xx).^2;
%         zxyvar = (0.5*sqrt(zxyr.^2+zxyi.^2).*emag_xy).^2;
%         zyxvar = (0.5*sqrt(zyxr.^2+zyxi.^2).*emag_yx).^2;
%         zyyvar = (0.5*sqrt(zyyr.^2+zyyi.^2).*emag_yy).^2;
%         
%         % Define output variables
%         ZT = [zxxr zxxi zxyr zxyi zyxr zyxi zyyr zyyi txr txi tyr tyi];
%         ZTvar = [zxxvar zxyvar zyxvar zyyvar txvar tyvar];
%     end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALLBACK FUNCTIONS - SECTION V: DATA FORMATTING 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% @check_value
% @check_input
% @dec2deg
% @data2str
% @strclean
% @vbar
% @replace_space
% @webcheck
% @natmaplook
%--------------------------------------------------------------------------
% @check_value: determine if entry into uicontrol edit box is a number and 
%    within appropriate given range of values
%--------------------------------------------------------------------------
    function[pass] = check_value(h,title,min,max,integer)
        %------------------------------------------------------------------
        %       h: handle of the uicontrol object (e.g., edit box)
        %   title: the value that's being evaluated (e.g., rotation angle)
        %     min: minimum allowable value
        %     max: maximum allowable value
        % integer: 1 if value must be an integer, 0 otherwise
        %------------------------------------------------------------------
        if ishghandle(wbox); delete(wbox); end
        pass = 1;
        ivalue = get(h,'string');
        % Check for existence of value in edit box
        if isempty(ivalue)
            pass = 0;
            wbox = warndlg(['Please enter a value for ',title,'.']);
        else
            % Check if value is a number
            nvalue = str2double(ivalue);
            if isnan(nvalue)
                pass = 0;
                wbox = warndlg(['Please enter a number value for ',title,'.']);
                set(h,'string','');
            else
                % Check if value is between min and max
                if nvalue < min || nvalue > max
                    pass = 0;
                    wbox = warndlg(['Please enter ',title,' between ',...
                        num2str(min),' and ',num2str(max),'.']);
                else
                    % Check if value is an integer (if required)
                    if integer == 1
                        if abs(rem(nvalue,1)) > 0
                            pass = 0;
                            wbox = warndlg(['Please enter an integer value for ',title,'.']);
                        end
                    end
                end
            end
        end
    end
%--------------------------------------------------------------------------
% @check_input: determine if input number is a number and within 
%    appropriate given range of values
%--------------------------------------------------------------------------
    function[pass] = check_input(ivalue,min,max)
        %------------------------------------------------------------------
        % ivalue: the value that's being evaluated (e.g., rotation angle)
        %    min: minimum allowable value
        %    max: maximum allowable value
        %------------------------------------------------------------------
        pass = 1;
        % Check if value is a number
        nvalue = str2double(ivalue);
        if isnan(nvalue)
            pass = 0;
        else
            % Check if value is between min and max
            if nvalue < min || nvalue > max
                pass = 0;
            end
        end
    end
%--------------------------------------------------------------------------
% @dec2deg: convert decimal degrees into degree:minutes:seconds
%--------------------------------------------------------------------------
    function[print_loc] = dec2deg(coord)
        %------------------------------------------------------------------
        %     coord: coordinate number in the format dd.dddd. 
        % print_loc: coordinate string in the format dd:dd:dd.d
        %------------------------------------------------------------------
        % Determine degrees East of Greenwich
        d_coord = floor(abs(coord));
        if coord < 0; d_coord = -d_coord; end

        % Determine minutes and seconds (in numbers)
        m_coord = floor(abs(coord - d_coord)*60);
        s_coord = 3600*(abs(coord-d_coord)-m_coord/60);

        % Limit seconds to one decimal of precision
        s_coord = 0.1*round(10*s_coord);

        % Convert to strings
        d_string = num2str(d_coord);

        % Add preceding zero for minutes < 10
        if m_coord > 9
            m_string = num2str(m_coord);
        else
            m_string = ['0',num2str(m_coord)];
        end

        % Add preceding zero for seconds < 10
        if floor(s_coord) > 9
            s_string = num2str(s_coord);
        else
            s_string = ['0',num2str(s_coord)];
        end

        % Add trailing zero decimal to seconds string if seconds place is
        % an integer
        if round(s_coord) == s_coord
            s_string = [s_string,'.0'];
        end

        % Compile degree:minutes:seconds string
        print_loc = [d_string,':',m_string,':',s_string];
    end
%--------------------------------------------------------------------------
% @data2str: converts a number into an exponential string. 
%--------------------------------------------------------------------------
    function[datastr] = data2str(data,varargin)
        %------------------------------------------------------------------
        % ndec: zeros past the decimal in the exponential (default = 4)
        % ex) datastr(105.12345)   = '1.0512E+02'
        % ex) datastr(0.10512345)  = '1.0512E-01' 
        % ex) datastr(105.12345,2) = '1.05E+02'
        %------------------------------------------------------------------
        
        if isempty(varargin)
            ndec = 4;
        else
            ndec = varargin{1};
        end
        logid = floor(log10(abs(data)));
        % Determine sign of exponent
        if logid < 0
            signstr = '-';
        else
            signstr = '+';
        end
        % Assemble exponent string
        if logid == -Inf % zero data point
            expstr = 'E+00';
        elseif abs(logid) < 10
            expstr = ['E',signstr,'0',num2str(abs(logid))];
        else
            expstr = ['E',signstr,num2str(abs(logid))];
        end
        % Convert data to string
        if data == 0
            rdata = 0;
        else
            rdata = abs((1/10^logid)*data);
        end
        sdata = num2str(rdata,ndec+1);
        % Add zeros if necessary
        if length(sdata) == 1; sdata = [sdata,'.0']; end
        if length(sdata) < ndec+2
            while length(sdata) < ndec+2
                sdata = [sdata,'0'];
            end
        end
        % Assemble data string
        if data < 0
            datastr = ['-',sdata,expstr,' '];
        else
            datastr = [' ',sdata,expstr,' '];
        end
    end
%--------------------------------------------------------------------------
% @strclean: converts a line of several ITEM=VALUE strings into a uniformly
% organized cell array in the format {'ITEM','=','VALUE'}
%--------------------------------------------------------------------------
    function[phrase] = strclean(inline)
        inline = strtrim(inline);
        line = strsplit(inline);

        count = 0; phrase = {};
        for tt = 1:length(line)
            iword = line{tt};
            if strfind(iword,'=') % contains equal sign
                if strcmp(strtrim(iword),'=')
                    count = count+1;
                    phrase{count} = '=';
                else
                    if strcmp(iword(1),'=') % equal sign in front
                        count = count+1;
                        phrase{count} = '=';
                        count = count+1;
                        uword = strtrim(iword(2:end));
                        if isnan(str2double(uword))
                            phrase{count} = uword;
                        else
                            phrase{count} = str2double(uword);
                        end
                    elseif strcmp(iword(end),'=') % equal sign at end
                        count = count+1;
                        uword = strtrim(iword(1:end-1));
                        if isnan(str2double(uword))
                            phrase{count} = uword;
                        else
                            phrase{count} = str2double(uword);
                        end
                        count = count+1;
                        phrase{count} = '=';
                    else % equal sign in middle
                        etag = strfind(iword,'=');
                        count = count+1;
                        uword1 = iword(1:etag-1);
                        if isnan(str2double(uword1))
                            phrase{count} = uword1;
                        else
                            phrase{count} = str2double(uword1);
                        end
                        count = count+1;
                        phrase{count} = '=';
                        count = count+1;
                        uword2 = iword(etag+1:end);
                        if isnan(str2double(uword2))
                            phrase{count} = uword2;
                        else
                            phrase{count} = str2double(uword2);
                        end
                    end
                end
            elseif isnan(str2double(iword)) % character string
                count = count+1;
                phrase{count} = strtrim(iword);
            else % number
                count = count+1;
                phrase{count} = str2double(strtrim(iword));
            end
        end
    end
%--------------------------------------------------------------------------
% @vbar: construct vertical error bar 
%--------------------------------------------------------------------------
    function[dyb] = vbar(rho,drho)
        y1 = rho';
        dy = drho';
        y0 = log10(y1) - dy;
        y2 = log10(y1) + dy;
        y0 = 10.^(y0);
        y2 = 10.^(y2);
        dyb = [y0; y2];
    end
%--------------------------------------------------------------------------
% @replace_space: replace spaces and punctuation in string with underscore
%--------------------------------------------------------------------------
    function[new_string] = replace_space(old_string)
        words = strsplit(old_string);
        % Eliminate semicolons
        for rr = 1:length(words)
            iword = words{rr};
            wtag = findstr(iword,';');
            if ~isempty(wtag)
                iword(wtag) = '';
                words{rr} = iword;
            end
        end
        % Eliminate spaces
        new_string = [];
        for tt = 1:length(words)
            if tt < length(words)
                new_string = [new_string,words{tt},'_'];
            else
                new_string = [new_string,words{tt}];
            end
        end
    end
%--------------------------------------------------------------------------
% @ webcheck: determine if this computer is is connected to the internet
%--------------------------------------------------------------------------
    function[tf] = webcheck(~,~)
        tf = false;
        try
            address = java.net.InetAddress.getByName('www.google.com');
            tf = true;
        end
    end
%--------------------------------------------------------------------------
% @natmaplook: query National Map elevation database
%--------------------------------------------------------------------------
    function[elevation] = natmaplook(lat,lon)
        str1 = num2str(lon,9);
        str2 = num2str(lat,9);
        url = ['https://nationalmap.gov/epqs/pqs.php?x=',str1,'&y=',str2,'&units=Meters&output=xml'];
        html_str = urlread(url);
        indx1 = regexp(html_str,'<Elevation>');
        indx2 = regexp(html_str,'</Elevation>');
        elevation = str2double(html_str(indx1+11:indx2-1));
    end
%--------------------------------------------------------------------------
% @set_survey: load one of many pre-filled survey headers
%--------------------------------------------------------------------------
    function set_survey(~,~)
        global mpath
        global mfile
        survey_id = get(h.drop,'value');
        
        switch survey_id
            case 1 % default
                set(d.edit(2),'string','aaa')
                set(h.edit(1),'string',def_proj)
                set(h.edit(2),'string',def_line)
                set(h.edit(3),'string',def_country)
                set(h.edit(4),'string',def_state)
                set(h.edit(5),'string',def_year)
                set(h.edit(6),'string',def_acqby)
                set(h.edit(7),'string',def_procby)
                set(h.edit(8),'string',def_software)
                set(h.edit(9),'string',def_fileby)
                set(h.edit(10),'string',def_desc)
            case 2 % DRIFTER - Denver
                set(d.edit(2),'string','rgr')
                set(h.edit(1),'string','DRIFTER')
                set(h.edit(2),'string','Denver')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','CO')
                set(h.edit(5),'string','2012-2014')
                set(h.edit(6),'string','University of Colorado Boulder')
                set(h.edit(7),'string','DWF')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband and long period',...
                    ' magnetotelluric survey of the Rio Grande rift',...
                    ' and southern Rocky Mountains in Colorado.',...
                    ' Geophysical target was electrical resistivity',...
                    ' structure of the crust and upper mantle to depths',...
                    ' >150 km with specific interest in lithospheric',...
                    ' modification due to late Cenozoic continental',...
                    ' rifting. Instrumentation: NIMS (8 Hz) and/or EMI',...
                    ' MT24 (6.25, 50, and 500 Hz) provided by U.S.',...
                    ' Geological Survey, Denver, CO.'])
            case 3 % DRIFTER - Taos
                set(d.edit(2),'string','rgr')
                set(h.edit(1),'string','DRIFTER')
                set(h.edit(2),'string','Taos')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2012-2013')
                set(h.edit(6),'string','University of Colorado Boulder')
                set(h.edit(7),'string','DWF')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband and long period',...
                    ' magnetotelluric survey of the Rio Grande rift',...
                    ' in northern New Mexico. Geophysical target was',...
                    ' electrical resistivity structure of the crust',...
                    ' and upper mantle to depths >150 km with specific',...
                    ' interest in lithospheric modification due to late',...
                    ' Cenozoic continental rifting. Instrumentation:',...
                    ' NIMS (8 Hz) and/or EMI MT24 (6.25, 50, and 500 Hz)',...
                    ' provided by U.S. Geological Survey, Denver, CO.'])
            case 4 % DRIFTER - Las Cruces
                set(d.edit(2),'string','rgr')
                set(h.edit(1),'string','DRIFTER')
                set(h.edit(2),'string','Cruces')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2013')
                set(h.edit(6),'string','University of Colorado Boulder')
                set(h.edit(7),'string','DWF')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband and long period',...
                    ' magnetotelluric survey of the Rio Grande rift',...
                    ' in southern New Mexico. Geophysical target was',...
                    ' electrical resistivity structure of the crust',...
                    ' and upper mantle to depths >150 km with specific',...
                    ' interest in lithospheric modification due to late',...
                    ' Cenozoic continental rifting. Instrumentation:',...
                    ' NIMS (8 Hz) and/or EMI MT24 (6.25, 50, and 500 Hz)',...
                    ' provided by U.S. Geological Survey, Denver, CO.'])
            case 5 % Jemez - Unocal 1983
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_JEMEZ.txt';
                set(d.edit(2),'string','jmz')
                set(h.edit(1),'string','JEMEZ')
                set(h.edit(2),'string','Valles Caldera')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1983')
                set(h.edit(6),'string','UNOCAL')
                set(h.edit(7),'string','UNOCAL')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired by',...
                    ' Unocal in 1983 for geothermal exploration in the',...
                    ' Valles Caldera. All stations are located within',...
                    ' the topographic rim of the Valles/Toledo calderas;',...
                    ' many are within the ring fracture delineated by',...
                    ' resurgent volcanism and post-caldera eruptions.',...
                    ' Maximum period for all sites is ~600 seconds.'])
            case 6 % SAGE 2017 - Bandelier
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE17.txt';
                set(d.edit(2),'string','bnd')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Pajarito Plateau')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2017')
                set(h.edit(6),'string','SAGE')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','mtmerge/mtft/mtedit')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2017. Stations were located on the',...
                    ' Pajarito Plateau along Highway 4 between Bandelier',...
                    ' National Monument and the Valles Caldera. Data',...
                    ' were recorded using ZEN data loggers and induction',...
                    ' coil magnetometers.'])
            case 7 % SAGE 1991
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE91.txt';
                set(d.edit(2),'string','sage91')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Jemez Mtns')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1991')
                set(h.edit(6),'string','EMI for SAGE')
                set(h.edit(7),'string','EMI')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 1991. Stations were located on the',...
                    ' western flank of the Jemez Mountains, New Mexico',...
                    ' between the Valles Caldera and the Naciemento uplift.'])
            case 8 % SAGE 1992
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE92.txt';
                set(d.edit(2),'string','sage92')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Jemez Mtns')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1992')
                set(h.edit(6),'string','EMI for SAGE')
                set(h.edit(7),'string','EMI')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 1992. Stations were located on the',...
                    ' flanks of the Jemez Mountains, New Mexico, SW and',...
                    ' NE of the Valles Caldera.'])
            case 9 % SAGE 1993
                set(d.edit(2),'string','sage93')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Las Vegas')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','SAGE students and faculty')
                set(h.edit(6),'string','SAGE')
                set(h.edit(7),'string','ZEPHYR GEO')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in northern New Mexico 1993.'])
            case 10 % SAGE 1994
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE94.txt';
                set(d.edit(2),'string','sage94')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','SAGE 94')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1994')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','ZEPHYR GEO')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 1994. Stations were located on the',...
                    ' western flank of the Jemez Mountains and southeast',...
                    ' of the town of Velarde, New Mexico.'])
            case 11 % SAGE 1995
                set(d.edit(2),'string','sage95')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Black Mesa')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1995')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','ZEPHYR GEO')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 1995. Stations were located northwest',...
                    ' of the Rio Grande across Black Mesa, south',...
                    ' of the town of Velarde, New Mexico.'])
            case 12 % SAGE 1996
                set(d.edit(2),'string','sage96')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Embudo Fault Zone')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1996')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','ZEPHYR GEO')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 1996. Stations were located on either',...
                    ' side of the Rio Grande in the Embudo Fault Zone',...
                    ' south of Velarde, New Mexico.'])
            case 13 % SAGE 1998
                set(d.edit(2),'string','sage98')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Hagan Embayment')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1998')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','SAGE')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 1998. Stations were located south of',...
                    ' Santa Fe, New Mexico along an east-west trending',...
                    ' profile in the Hagan Embayment of the Espanola',...
                    ' Basin in the Rio Grande rift.'])
            case 14 % SAGE 1999
                set(d.edit(2),'string','sage99')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Hagan Embayment')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','1999')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','SAGE')
                set(h.edit(8),'string','unknown')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' for the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 1999. Stations were located south of',...
                    ' Santa Fe, New Mexico along an east-west trending',...
                    ' profile in the Hagan Embayment of the Espanola',...
                    ' Basin in the Rio Grande rift.'])
            case 15 % SAGE 2010 - Santa Domingo Basin
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE10.txt';
                set(d.edit(2),'string','sage2010')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Santa Domingo Basin')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2010')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' by the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2010. All sites located',...
                    ' in northern Santa Domingo Basin, NW of the Rio',...
                    ' Grande. Instruments: EMI MT24 (500, 50 and 6.25 Hz',...
                    ' recordings).'])
            case 16 % SAGE 2011 - Caja del Rio
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE11.txt';
                set(d.edit(2),'string','sage2011')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Cerros del Rio/Buckman Well Field')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2011')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' by the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2011. All sites',...
                    ' located NW of Santa Fe, New Mexico in Cerros del',...
                    ' Rio volcanic field, Buckman water-well field, and',...
                    ' several arroyos adjacent to Old Buckman Road.',...
                    ' Instruments: EMI MT24 (500, 50 and 6.25 Hz',...
                    ' recordings).'])
            case 17 % SAGE 2012 - Caja del Rio
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE12.txt';
                set(d.edit(2),'string','sage2012')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Cerros del Rio/Buckman Well Field')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2012')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' by the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2012. All sites',...
                    ' located NW of Santa Fe, New Mexico in Cerros del',...
                    ' Rio volcanic field, Buckman water-well field, and',...
                    ' several arroyos adjacent to Old Buckman Road.',...
                    ' Instruments: EMI MT24 (500, 50 and 6.25 Hz',...
                    ' recordings).'])
            case 18 % SAGE 2013 - Caja del Rio
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE13.txt';
                set(d.edit(2),'string','sage2013')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Cerros del Rio/Buckman Well Field')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2013')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' by the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2013. All sites',...
                    ' located NW of Santa Fe, New Mexico in Cerros del',...
                    ' Rio volcanic field, Buckman water-well field, and',...
                    ' several arroyos adjacent to Old Buckman Road.',...
                    ' Instruments: EMI MT24 (500, 50 and 6.25 Hz',...
                    ' recordings).'])
            case 19 % SAGE 2014 - Santa Domingo Basin
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE14.txt';
                set(d.edit(2),'string','sage2014')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Santa Domingo Basin')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2014')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' by the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2014. All sites located',...
                    ' in northern Santa Domingo Basin, NW of the Rio',...
                    ' Grande. Instruments: EMI MT24 (500, 50 and 6.25 Hz',...
                    ' recordings).'])
            case 20 % SAGE 2015 - Santa Domingo Basin
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE15.txt';
                set(d.edit(2),'string','sage2015')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Santa Domingo Basin')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2015')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','mtmerge/mtft/mtedit')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' by the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2015. All sites located',...
                    ' in northern Santa Domingo Basin, NW of the Rio',...
                    ' Grande. Instruments: Zonge ZEN systems.'])
            case 21 % SAGE 2016 - Caja del Rio
                mpath = '/Users/danny/Desktop/SAGE_MT_archive/';
                mfile = 'meta_SAGE16.txt';
                set(d.edit(2),'string','sage2016')
                set(h.edit(1),'string','SAGE')
                set(h.edit(2),'string','Cerros del Rio/Buckman Well Field')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','NM')
                set(h.edit(5),'string','2016')
                set(h.edit(6),'string','SAGE students and faculty')
                set(h.edit(7),'string','PAB')
                set(h.edit(8),'string','mtmerge/mtft/mtedit')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['Broadband MT data acquired',...
                    ' by the Summer of Applied Geophysical Experience',...
                    ' (SAGE) in 2016. All sites',...
                    ' located NW of Santa Fe, New Mexico in Cerros del',...
                    ' Rio volcanic field, Buckman water-well field, and',...
                    ' several arroyos adjacent to Old Buckman Road.',...
                    ' Instruments: Zonge ZEN systems.'])
            case 22 % EarthScope MT
                set(d.edit(2),'string','USArray')
                set(h.edit(1),'string','EarthScope')
                set(h.edit(2),'string','USArray')
                set(h.edit(3),'string','USA')
                set(h.edit(4),'string','US')
                set(h.edit(5),'string','2010-2018')
                set(h.edit(6),'string','contractors')
                set(h.edit(7),'string','Anna Kelbert')
                set(h.edit(8),'string','EMTF')
                set(h.edit(9),'string','U.S. Geological Survey')
                set(h.edit(10),'string',['EarthScope MT data collected on 1 Hz NIMS.'])
        end
        % Display file name in GUI
        if isempty(mfile)
            set(t.edit,'string','');
        else
            if ~strcmp(mpath(end),slash)
                mpath = [mpath,slash];
            end
            get_file = [mpath,mfile];
            gindx = strfind(get_file,slash);
            if length(gindx)>3
                pfile = ['...',get_file(gindx(end-3):end)];
            else
                pfile = get_file;
            end
            set(t.edit,'string',pfile);
        end
    end
end % END function