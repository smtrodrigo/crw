function dotenvValue = readDotenvFile(dotenvFile, dotenvKey, dotenvType)
    global debugVerbosity

    dotenvValue = regexp(dotenvFile, sprintf('\\^%s=(.*?)(?:\n|$|\\$)', dotenvKey), 'tokens');
    if isempty(dotenvValue)
        error('[ERROR] %s not detected on .env file.\n', dotenvKey);
    end

    dotenvValue = dotenvValue{1}{1};
    if strcmp(dotenvType,'dir')
        if exist(dotenvValue, 'dir') ~= 7
            error('[ERROR] %s path doesnt exist: %s', dotenvKey, dotenvValue);
        end
        if debugVerbosity == true, fprintf('[DEBUG] %s is set to %s\n', dotenvKey, dotenvValue); end
    elseif strcmp(dotenvType,'bounds')
        dotenvValue = str2double(dotenvValue);
        if debugVerbosity == true, fprintf('[DEBUG] %s is set to %f\n', dotenvKey, dotenvValue); end
    elseif strcmp(dotenvType,'bool')
        if strcmp(dotenvValue,'true')
            dotenvValue = true;
            if debugVerbosity == true, fprintf('[DEBUG] %s is set to TRUE\n', dotenvKey); end
        elseif  strcmp(dotenvValue,'false')
            dotenvValue = false;
            if debugVerbosity == true, fprintf('[DEBUG] %s is set to FALSE\n', dotenvKey); end
        else    
            fprintf('[WARNING] %s is not set properly, defaulting to false\n', dotenvKey);
        end
    end

    
    return
end