# Overview
This code, `Bleaching`, downloads monthly NC files from the NOAA Coral
Reef Watch archive, outputs a time series at a certain location, outputs a
map-ready matrix of maximums, and creates sample plots.


# Running CRW

## Requirements

Any working install of:
* Matlab
* Octave
* Docker

### If using docker
* an X11 shell like XQuartz for MacOS


## Step 1. Create a `.env` file
Contents should be like what inside `.env.example`. Because of newline issues, we have to prepend our lines with the `^` symbol, and append each with the `$` symbols, as seen in `.env.example`.

## Step 2. Modify the script-control variables on `.env`
If you look at `.env`, there is a section labeled:
```
File: .env
23: ### Script-control variables
24: 
25: # Hide debug messages
26: debugVerbosity=false
(...)
```

That contains the different variables that you can modify to tweak how the code runs to suit your environment. For example, if you are working offline but already downloaded all input files you can set `skipDownloading` to `true`:
```
#Skip all file downloading, useful if you already have everything downloaded
skipDownloading=true
```

Here is a table to summarize the different global variables that affect runtime:
| Variable       | Default | Description |
| :------------- | :-----: | :---------- |
| debugVerbosity | false | Show debugging messages on the console |
| fetchMD5Everytime | false | Set this to `true` if you want to verify all your downloaded files  |
| skipDownloading | false | When set to `true`, no files will be downloaded, useful for offline work  |
| skipPlotting | false | Flag to control if plots will be generated  |
| skipIngesting | false | Flag to control if data will be ingested, set this to `true` if you ran the script inside the matlab shell with variables saved and you don't want to recompute the previously ingested data  |
| skipCsvCreation | false | Flag to control if data will be converted to csv files inside `./output`  |


## Step. 3 Run code in Matlab or Octave

### Running code in the Matlab shell

1. On the Matlab command line window, look for the `>>>` shell and run this:

    ```
    >>> Bleaching
    ```

### Run code in Octave using docker with a GUI

1. open `XQuartz`, set preferences->security->"Allow connections from network clients
2. Run this on the `XQuartz` shell:

    ```
    xhost + 127.0.0.1
    ```

3. Run this on any terminal:

    ```
    docker-compose run octave-gui
    ```

4. On the Octave command line window, look for the >>> shell and run this:

    ```
    >>> Bleaching
    ```

### Run code in Octave using docker without a GUI

1. Run this on any terminal:

    ```
    docker-compose run octave
    ```

2. Wait for the `>>>` shell prompt and run this:

    ```
    >>> Bleaching
    ```

# FAQ
## What do I do when I see `error: __ftp_mget__: Timeout was reached`?
  That means that the program was not able to reach ftp://ftp.star.nesdis.noaa.gov/. Check if that site is still up, or if your internet is stable. Re-run the code so you can retry downloading once you finish your checks.
## How can I work offline?
  Run the script with `skipDownloading` to `false` to download all the files first, then you can set `skipDownloading` to `true` to work offline. See [this section](#global-variables-to-control-how-the-script-runs) for more details.
## Why do I get this: `[ERROR] Can't create outputs because 'skipIngesting' is set to true without priming the variables first."`
 
  `skipIngesting` assumes that you already have the data precomputed, meaning you can safely skip all data ingestion routines. However, no data can be displayed if you set `skipIngesting` to `true` without "priming" the variables first, i.e. running the script inside a Matlab shell so the variables are saved. So to fix this, make sure you:

1. Set `skipIngesting` to `false` for now
2. Run the script in a Matlab/Octave shell: 
    ```
    # On the Matlab/Octave command line window, look for the >>> shell and run this:
    >>> Bleaching
    ```
3. Wait until all the variables are primed by just letting the script finish
4. And finally, you can now re-set `skipIngesting` to `true`.


# Sources
* NOAA Coral Reef Watch archive: https://coralreefwatch.noaa.gov/product/5km/index.php#data_access
* Composites: Monthly and annual max, min, and mean: https://coralreefwatch.noaa.gov/product/5km/index_5km_composite.php
* Monthly composites: ftp://ftp.star.nesdis.noaa.gov/pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/monthly/

# Notes:
* The Philippines appears on 3 maps: Coral triangle, "East" (Eastern hemisphere), and Pac (Pacific)
* Due to DHW computations, SST starts Jan 1985. DHW starts at April 1985.