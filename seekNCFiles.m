% Define a function to skip downloads if checksums match
function seekNCFiles(ftpobj,filename,DirOfDownload)

    global debugVerbosity
    global fetchMD5Everytime
    global skipDownloading

    if debugVerbosity == true, fprintf ('[DEBUG] Checking %s if valid \n', filename); end
    
    if skipDownloading == false
        if exist([DirOfDownload,'/',filename,'.md5']) ~= 2 || fetchMD5Everytime == true
            if debugVerbosity && exist([DirOfDownload,'/',filename,'.md5']) ~= 2 , fprintf ('[DEBUG] Missing MD5, downloading %s.md5\n', filename); end
            mget(ftpobj,[filename,'.md5'],DirOfDownload); % Download checksum
        end
    end

    RemoteMD5FileContents = fileread([DirOfDownload,'/',filename,'.md5']);

    if ispc
        RemoteMD5 = regexp(RemoteMD5FileContents, '(\w{32})\s+.*\.nc', 'tokens');
    else
        RemoteMD5 = regexp(RemoteMD5FileContents, sprintf('(\\w{32})\\s+.*\\.nc'), 'tokens');
    end
    if isempty(RemoteMD5)
        error('[ERROR] Invalid MD5 for %s\\%s.md5, please delete that file so the script can redownload it', DirOfDownload, filename)
    end
    RemoteMD5 = RemoteMD5{1}{1};

    if exist([DirOfDownload,'/',filename]) == 2
        LocalMD5 = checkMD5Sum([DirOfDownload,'/',filename]);
        if strcmp(RemoteMD5,LocalMD5) == true
            fprintf ('[INFO] Skipping pre-downloaded file: %s\n', filename);
            return
        else
            fprintf ('[INFO] Checksum mismatch on %s: %s vs %s, needs redownloading\n', filename, RemoteMD5, LocalMD5);
        end
    end

    if skipDownloading == false 
        fprintf ('[INFO] Downloading %s\n', filename);
        mget(ftpobj,filename,DirOfDownload); % Download file
    else
        error('[ERROR]: %s is not available, cant download because skipDownloading is set to true.', filename)
    end
end

% Define a function to check md5sums
function md5 = checkMD5Sum(filename)
    if isunix
        [err, md5] = system(sprintf('md5sum %s | cut -d " " -f 1',filename));
        if err ~= 0 
            error('[ERROR] Cant compute md5 checksums using unix hosts md5sum')
        end
        md5 = md5(1:end-1);
    elseif ispc
        [~, md5] = system(sprintf('certUtil -hashfile %s md5 | find /i /v "md5" | find /i /v "certutil"',filename));
        md5 = md5(1:end-1);
    else
        error('[ERROR] Platform not supported, cant compute md5 checksums');
    end
end