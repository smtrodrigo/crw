% This code, 'Bleaching' downloads monthly NC files from the NOAA Coral
% Reef Watch archive, output a time series at a certain location, output a
% map-ready matrix of maximums, and creates sample plots.
%
% Bleaching is divided into several sections which can be run separately.

%% ========= SECTION: Notes about navigating the NOAA website ========= %

% NOAA Coral Reef Watch archive:
% --- https://coralreefwatch.noaa.gov/product/5km/index.php#data_access

% Composites: Monthly and annual max, min, and mean:
% --- https://coralreefwatch.noaa.gov/product/5km/index_5km_composite.php

% The Philippines appears on at least 3 maps: Coral triangle, 'East' (Eastern
% hemisphere), and Pac (Pacific)

% Monthly composites -- I'm having trouble accessing this link with Chrome
% and Firefox.
% --- ftp://ftp.star.nesdis.noaa.gov/pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/monthly/

% Due to DHW computations, SST starts Jan 1985. DHW starts at April 1985.

clear global

%% ======== SECTION DESCRIPTION: Matlab/Octave compatibility checks ======== %

% if isOctave() 
%     pkg load netcdf
%     pkg load statistics
%     graphics_toolkit('gnuplot')
% end

%% ======== SECTION DESCRIPTION: Inputs ======== %
% if isfile('.env')
    dotenv = fileread('.env');

    % Hide debug messages
    global debugVerbosity
    debugVerbosity = readDotenvFile(dotenv,'debugVerbosity','bool');
    if debugVerbosity == true, fprintf('[DEBUG] debugVerbosity is set to TRUE\n'); end

    % Verify each MD5 by redownloading it everytime, slow, but makes sure all your nc files are correct
    global fetchMD5Everytime 
    fetchMD5Everytime = readDotenvFile(dotenv,'fetchMD5Everytime','bool');

    % Skip all file downloading, useful if you already have everything downloaded
    global skipDownloading 
    skipDownloading = readDotenvFile(dotenv,'skipDownloading','bool');

    % Skip all plotting
    global skipPlotting 
    skipPlotting = readDotenvFile(dotenv,'skipPlotting','bool');

    % Skip all data ingestion, useful if we want to reuse precomputed data 
    global skipIngesting 
    skipIngesting = readDotenvFile(dotenv,'skipIngesting','bool');
    if exist('DhwSeries', 'var') ~=1 && skipIngesting == true
        error('[ERROR] Cant create outputs because skipIngesting is set to true without priming the variables first.')
    end

    global skipCsvCreation 
    skipCsvCreation = readDotenvFile(dotenv,'skipCsvCreation','bool');

    % Here is where the NC files are stored
    DirOfDownload = readDotenvFile(dotenv,'DirOfDownload','dir');

    % DirOfCode is where 'Bleaching.m', this script is stored.
    DirOfCode = readDotenvFile(dotenv,'DirOfCode','dir');
    
    if skipPlotting == false
        % Here is where m_map, a downloadable plotting toolbox, is stored.
        MmapPath = readDotenvFile(dotenv,'MmapPath','dir');
    end

    StartYr = readDotenvFile(dotenv,'StartYr','bounds');
    EndYr = readDotenvFile(dotenv,'EndYr','bounds');
    LatDesired = readDotenvFile(dotenv,'LatDesired','bounds');
    LonDesired = readDotenvFile(dotenv,'LonDesired','bounds');
    
% else
%      error('[ERROR] File inputs missing, please create a .env file.');
% end

addpath(DirOfCode);

if skipPlotting == false
    % Detect m_map, and download if missing
    addpath(MmapPath);
    if exist('m_proj') ~= 2

        fprintf ('[INFO] MmapPath (%s) doesnt seem to contain a working m_map, downloading one...\n', MmapPath);

        if ~isempty(regexp(MmapPath, '/m_map$', 'match')) 
            if debugVerbosity == true, fprintf ('[DEBUG] Trailing /m_map folder on MmapPath (%s) detected, truncating path\n', MmapPath); end
            MmapPath=regexprep(MmapPath,'m_map$','');
        end
         
        gunzip('http://www.eos.ubc.ca/\~rich/m_map1.4.tar.gz',MmapPath);
        
        if ispc
            Mmaptar = sprintf('%s/m_map1.4.tar',MmapPath)
            untar(Mmaptar,MmapPath);
        end
    else 
        fprintf ('[INFO] m_map is detected\n', MmapPath);
    end
end

% WhichData = 1;
% Determine which dataset you want -- I haven't fixed this part

if skipIngesting == false
    %% ======== SECTION DESCRIPTION: Downloads NC files from NOAA  ======== %

    ftpobj = [];
    if skipDownloading == false
        % Connect to FTP server
        ftpURL = 'ftp.star.nesdis.noaa.gov';
        fprintf ('[INFO] Connecting to FTP server: %s\n', ftpURL);
        ftpobj = ftp(ftpURL);
        % 'FtpDir' contains the directory name within the NOAA server.
        FtpDir = sprintf('pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/monthly/%d/',StartYr);
    end 

    for Year = StartYr:EndYr
        
        if skipDownloading == false
            fprintf ('[INFO] Travesing FTP directory: %s\n', FtpDir);
            % Change directory within the FTP server to the desired year.
            cd(ftpobj,FtpDir);
        end

        for i = 1:12
            % Name of file to download: DHW
            FileDl = sprintf('ct5km_dhw-max_v3.1_%d%02d.nc',Year,i);
            seekNCFiles(ftpobj,FileDl,DirOfDownload);% Download file

            % Name of file to download: SSTA mean
            FileDl = sprintf('ct5km_ssta-mean_v3.1_%d%02d.nc',Year,i);
            seekNCFiles(ftpobj,FileDl,DirOfDownload);% Download file

            % Name of file to download: SST mean
            FileDl = sprintf('ct5km_sst-mean_v3.1_%d%02d.nc',Year,i);
            seekNCFiles(ftpobj,FileDl,DirOfDownload); % Download file
        end

        if skipDownloading == false
            cd(ftpobj,'..');
            FtpDir = sprintf('%d/',Year+1);
        end
    end

    if skipDownloading == false
        % Close the connection to the FTP server
        close(ftpobj)
    end

    %% ======== SECTION DESCRIPTION: Timeseries for certain location ======== %
    % This section assumes that you've already downloaded the NC files from
    % 'StartYr' to 'EndYr'. It opens the NC files for DHW, mean SST, and mean
    % SSTA from the start to end year. This can take some time.

    %It will then create a montly time series nearest to your desired location,
    %('LatDesired' and 'LonDesired').

    % The time series will be contained in these three matrices, 'DhwSeries,'
    % 'SstaSeries,' and 'SstSeries.' For example, if you have one year, the
    % first column of DhwSeries will contain the DHW for each month and the
    % second column will contain the date (in Matlab's 'datenum' format). For
    % one year, DhwSeries will be a 12x2 matrix meaning 12 rows (one row is one
    % month) and 2 columns.

    DhwSeries  = zeros([[],2]);
    SstaSeries = zeros([[],2]);
    SstSeries  = zeros([[],2]);

    SeriesInd = 1;

    for Year = StartYr:EndYr
        for i = 1:12
            % --- Degree Heating Weeks
            % --- This section reads the NC files for Degree Heating Weeks.
            ncfile = sprintf('%s/ct5km_dhw-max_v3.1_%d%02d.nc',DirOfDownload,Year,i);
            fprintf ('[INFO] Ingesting to DhwSeries: %s\n', ncfile);

            if i == 1 && Year == StartYr % this only needs to be done once
                LatNC = ncread(ncfile,'lat');
                LonNC = ncread(ncfile,'lon');
                % Find the index of the Latitude and Longitude in the NC file
                [~,LatIndex] = nanmin(abs(LatNC-LatDesired)); % Finds the nearest Lat/Lon to your desired location.
                [~,LonIndex] = nanmin(abs(LonNC-LonDesired));
            end
            
            DhwTemp = ncread(ncfile,'degree_heating_week');
            DhwSeries(SeriesInd,1) = DhwTemp(LonIndex,LatIndex);
            
            RefTimeTemp = ncread(ncfile,'time'); % 'reference time of the last day of the composite temporal coverage'
                    % 'seconds since 1981-01-01 00:00:00'
            base = datenum(1981,01,01);
            RefTime = double(RefTimeTemp)/86400 + base;
            VecTemp = datevec(RefTime);
            RefTime = datenum(VecTemp(1),VecTemp(2),1);    % Instead of e.g. Jan 31, we choose Jan 1
            DhwSeries(SeriesInd,2) = RefTime;

            % --- Mean Sea Surface Temperature Anomaly
            % --- This section reads the NC files for SST Anomaly.
            ncfile = sprintf('%s/ct5km_ssta-mean_v3.1_%d%02d.nc',DirOfDownload,Year,i);
            fprintf ('[INFO] Ingesting to SstaSeries: %s\n', ncfile);

            SstaTemp = ncread(ncfile,'sea_surface_temperature_anomaly');
            SstaSeries(SeriesInd,1) = SstaTemp(LonIndex,LatIndex);
            SstaSeries(SeriesInd,2) = RefTime;

            % --- Mean Sea Surface Temperature
            ncfile = sprintf('%s/ct5km_sst-mean_v3.1_%d%02d.nc',DirOfDownload,Year,i);
            fprintf ('[INFO] Ingesting to SstSeries: %s\n', ncfile);

            SstTemp = ncread(ncfile,'sea_surface_temperature');
            SstSeries(SeriesInd,1) = SstTemp(LonIndex,LatIndex);
            SstSeries(SeriesInd,2) = RefTime;
            
            SeriesInd = SeriesInd + 1;
        end
    end

    %% ======== SECTION DESCRIPTION: Maximum values per grid point ======== %
    % This section assumes that you've already downloaded the NC files from
    % 'StartYr' to 'EndYr'. It opens the NC files for DHW, mean SST, and mean
    % SSTA from the start to end year. This can take some time.

    % Then, it will create one matrix for each variable (DHW, mean SST, and
    % mean SSTA) that is ready to plot in a map. The matrix will contain the
    % maximum values for the time period specified by StartYr and EndYr.

    % -------- INPUT REQUIRED HERE
    % In its current form, these lines require some input.
    % Here, enter the latitude and longitude 'box' of interest:
    LonStart = 115; % Lowest value of Longitude
    LonEnd   = 135; % Highest value of Longitude

    LatStart = 25; % Start at the higher value because NC Latitudes are from +90 to -90.
    LatEnd   = 5;  % Lowest value of Latitude
    % --------------------------------------

    % Create Lat/Lon limits
    LonLim = [LonStart LonEnd];
    LatLim = [LatEnd LatStart]; % start and end flipped because of the above

    % Searching for the nearest Lat/Lon values in the NC files.
    [~,LatStartIndex] = nanmin(abs(LatNC-LatStart)); % finds the nearest
    [~,LatEndIndex] = nanmin(abs(LatNC-LatEnd));
    [~,LonStartIndex] = nanmin(abs(LonNC-LonStart));
    [~,LonEndIndex] = nanmin(abs(LonNC-LonEnd));

    LatUse = LatNC(LatStartIndex:LatEndIndex);
    LonUse = LonNC(LonStartIndex:LonEndIndex);

    % Here, we create the matrices for each variable: DhwMaxs are the maximum
    % values of DHW within the time period from StartYr to EndYr (similarly for
    % SstaMaxs for SSTA, and SstMaxs for SST). The size of the matrices will
    % depend on the number of grid points in your predefined 'box'.
    DhwMaxs = zeros(length(LonUse),length(LatUse));
    SstaMaxs = zeros(length(LonUse),length(LatUse));
    SstMaxs = zeros(length(LonUse),length(LatUse));

    for Year = StartYr:EndYr
        for i = 1:12
            % --- Degree Heating Weeks
            % --- This section reads the NC files for Degree Heating Weeks.
            ncfile = sprintf('%s/ct5km_dhw-max_v3.1_%d%02d.nc',DirOfDownload,Year,i);
            fprintf ('[INFO] Ingesting to DhwMaxs: %s\n', ncfile);
            DhwTemp = ncread(ncfile,'degree_heating_week');
            
            if i == 1 && Year == StartYr % this only needs to be done once
                DhwMaxs = DhwTemp(LonStartIndex:LonEndIndex,LatStartIndex:LatEndIndex);
            end
            DhwCheck = DhwTemp(LonStartIndex:LonEndIndex,LatStartIndex:LatEndIndex);
            
            DhwMaxs(DhwCheck>DhwMaxs) = DhwCheck(DhwCheck>DhwMaxs);

            % --- Mean Sea Surface Temperature Anomaly
            % --- This section reads the NC files for SST Anomaly.
            ncfile = sprintf('%s/ct5km_ssta-mean_v3.1_%d%02d.nc',DirOfDownload,Year,i);
            fprintf ('[INFO] Ingesting to SstaMaxs: %s\n', ncfile);            
            SstaTemp = ncread(ncfile,'sea_surface_temperature_anomaly');
            
            if i == 1 && Year == StartYr % this only needs to be done once
                SstaMaxs = SstaTemp(LonStartIndex:LonEndIndex,LatStartIndex:LatEndIndex);
            end
            SstaCheck = SstaTemp(LonStartIndex:LonEndIndex,LatStartIndex:LatEndIndex);
            
            SstaMaxs(SstaCheck>SstaMaxs) = SstaCheck(SstaCheck>SstaMaxs);
            
            
            % --- Mean Sea Surface Temperature
            ncfile = sprintf('%s/ct5km_sst-mean_v3.1_%d%02d.nc',DirOfDownload,Year,i);
            fprintf ('[INFO] Ingesting to SstMaxs: %s\n', ncfile);   
            SstTemp = ncread(ncfile,'sea_surface_temperature');
            
            if i == 1 && Year == StartYr % this only needs to be done once
                SstMaxs = SstTemp(LonStartIndex:LonEndIndex,LatStartIndex:LatEndIndex);
            end
            SstCheck = SstTemp(LonStartIndex:LonEndIndex,LatStartIndex:LatEndIndex);
            
            SstMaxs(SstCheck>SstMaxs) = SstCheck(SstCheck>SstMaxs);
            
        end
    end
else
    fprintf('[INFO] Skipping all data ingestion becase skipIngesting is set to true\n')
end

if skipPlotting == false 

    close all

    fprintf ('[INFO] Starting plot routines\n');

    %% ======== SECTION DESCRIPTION: Timeseries visualization *sample* ======== %
    % In this section, we create a 2-subplot figure where we plot DHW, SST, and
    % SSTA. Please adjust this to your needs.

    % Line Width
    LinWi = 2;

    % Number of months between ticks: Change this depending on what looks nice.
    TickSpace = 12;

    figure
    subplot(121)
    plot(SstSeries(:,2),SstSeries(:,1),'-*','linewidth',LinWi), hold on, grid on
    % I plot here mean SST + SST Anomaly. I don't know if this makes ANY
    % phyiscal/biological sense at all. Please change as needed.
    plot(SstSeries(:,2),SstSeries(:,1)+SstaSeries(:,1),'--*','linewidth',LinWi), hold on, grid on

    set(gca, 'XTick', SstSeries(1:TickSpace:end,2));
    datetick('x','mmm-yyyy','keepticks','keeplimits')
    xlim([SstSeries(1,2)-10 SstSeries(end,2)+10])
    set(gca,'FontSize',12,'TickLabelInterpreter','latex')
    xlabel('Date','interpreter','latex','fontsize',16),
    ylabel('Temperature ($^\circ$C)','interpreter','latex','fontsize',16)

    legend('Mean SST','Mean SST + Mean SST Anomaly',...
        'interpreter','latex','location','southeast')

    subplot(122)
    plot(DhwSeries(:,2),DhwSeries(:,1),'-*','linewidth',LinWi), hold on, grid on

    set(gca, 'XTick', SstSeries(1:TickSpace:end,2));
    datetick('x','mmm-yyyy','keepticks','keeplimits')
    xlim([SstSeries(1,2)-10 SstSeries(end,2)+10])
    set(gca,'FontSize',12,'TickLabelInterpreter','latex')
    xlabel('Date','interpreter','latex','fontsize',16),
    ylabel('Degree Heating Weeks ($^\circ$C week)','interpreter','latex','fontsize',16)

    % Make sure to change your title for what is appropriate.
    Title = sprintf('Measurements at 13.77N and 120.87E \n(random point near Anilao)');
    % sgtitle(Title,'fontsize',16,'interpreter','latex');

    set(gcf,'position',[100,100,1200,500])

    %% ======== SECTION DESCRIPTION: Map visualization ======== %
    % In this section, we create a 3-subplot figure where we make maps of
    % maximum DHW, SST, and SSTA for a specified latitude and longitude range
    % (Speficied in LonStart, LonEnd, LatStart, and LatEnd). This is just a
    % sample. Please adjust it to your needs.

    figure

    ValsUse = SstMaxs';
    subplot(131)
    m_proj('mercator', 'longitude', LonLim, 'latitude', LatLim);
    m_pcolor(LonUse,LatUse,ValsUse); shading flat;
    % m_grid('linewi',1,'tickdir','in', 'fontsize', 11);

    % This line adds nice coastlines. It takes a while to load but 'uncomment'
    % it when you want to add nice coastlines:

    % m_gshhs_f ('patch',[0.8 0.8 0.8]);

    xlabel('Longitude (\circE)','fontsize',12);
    ylabel('Latitude (\circN)','fontsize',12);
    % Add title here:
    title('Maximum SST from 2018-2020','fontsize',12);
    colorbar;

    subplot(133)
    ValsUse = DhwMaxs';
    m_proj('mercator', 'longitude', LonLim, 'latitude', LatLim);
    m_pcolor(LonUse,LatUse,ValsUse); shading flat;
    % m_grid('linewi',1,'tickdir','in', 'fontsize', 11);

    % This line adds nice coastlines. It takes a while to load but 'uncomment'
    % it when you want to add nice coastlines:

    % m_gshhs_f ('patch',[0.8 0.8 0.8]);

    xlabel('Longitude (\circE)','fontsize',12);
    ylabel('Latitude (\circN)','fontsize',12);
    % Add title here:
    title('Maximum DHW from 2018-2020','fontsize',12);
    colorbar;
    caxis([0 8]) % Use the function 'caxis' to change the range of the
    % colorbar like from 0 to 8.

    subplot(132)
    ValsUse = SstaMaxs';

    m_proj('mercator', 'longitude', LonLim, 'latitude', LatLim);
    m_pcolor(LonUse,LatUse,ValsUse); shading flat;
    % m_grid('linewi',1,'tickdir','in', 'fontsize', 11);

    % This line adds nice coastlines. It takes a while to load but 'uncomment'
    % it when you want to add nice coastlines:

    % m_gshhs_f ('patch',[0.8 0.8 0.8]);

    xlabel('Longitude (\circE)','fontsize',12);
    ylabel('Latitude (\circN)','fontsize',12);
    % Add title here:
    title('Maximum SSTA from 2018-2020','fontsize',12);
    colorbar;

    set(gcf,'position',[100,100,1600,500])


    fprintf('Press enter to continue...\n')
    pause()
else
    fprintf('[INFO] Skipping all plotting routines skipPlotting is set to true\n')
end


if skipCsvCreation == false

    mkdir('output');

    fileID = fopen(sprintf('output/sst-%d-%d.csv',StartYr,EndYr),'w');
    fprintf(fileID,'sst,date\n');
    for i = 1 : length(SstSeries)
        fprintf(fileID,'%f,%s\n',SstSeries(i,1),datestr(SstSeries(i,2),'yyyy/mm/dd'));
    end
    fclose(fileID);

    fileID = fopen(sprintf('output/ssta-%d-%d.csv',StartYr,EndYr),'w');
    fprintf(fileID,'ssta,date\n');
    for i = 1 : length(SstaSeries)
        fprintf(fileID,'%f,%s\n',SstaSeries(i,1),datestr(SstaSeries(i,2),'yyyy/mm/dd'));
    end
    fclose(fileID);

    fileID = fopen(sprintf('output/dhw-%d-%d.csv',StartYr,EndYr),'w');
    fprintf(fileID,'dhw,date\n');
    for i = 1 : length(DhwSeries)
        fprintf(fileID,'%f,%s\n',DhwSeries(i,1),datestr(DhwSeries(i,2),'yyyy/mm/dd'));
    end
    fclose(fileID);
end