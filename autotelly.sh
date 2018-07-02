#!/usr/bin/env bash

source config.shlib;   # load the config library functions
source channels.shlib; # load the channels library functions
source scripts.shlib;  # load the scripts library functions

echo_config=0

create_sd_script="$(config_get create_sd)";
create_hd_script="$(config_get create_hd)";
create_shell_scripts="$(config_get create_shell_scripts)";
add_channels="$(config_get add_channel_numbers)";

iptv_m3u_url="$(config_get m3u_url)";
iptv_epg_url="$(config_get epg_url)";

CG="$(config_get channelgroups)";

base_loc=$PWD;

original_loc="${base_loc}"/"$(config_get original)";
sorted_loc="${base_loc}"/"$(config_get sorted)";
hd_loc="${base_loc}"/"$(config_get HD)";
sd_loc="${base_loc}"/"$(config_get SD)";
m3u_editor_loc="${base_loc}"/"$(config_get m3u)";

sorted_channels="$sorted_loc/sorted.channels.txt" # Channels from A-Z
sorted_channels_tmp="$sorted_loc/sorted.channels.tmp" # Channels from A-Z
sorted_channels_no_group="$sorted_loc/sorted.channels.nogroup.txt" # Channels from A-Z without Group    

hd_channels_file="$hd_loc/hd.channels.only.txt" # No SD Channels List
iptv_hd_unique="$hd_loc/HDTV.unique.txt" # HD Channels List without Duplicates
hd_output_file="$hd_loc/hdtv" 
hd_m3u="${hd_output_file}".m3u8

sd_channels_file="$sd_loc/sd.channels.only.txt" # No HD Channels List
iptv_sd_unique="$sd_loc/SDTV.unique.txt" # SD Channels List without Duplicates
sd_output_file="$sd_loc/sdtv" 
sd_m3u="${sd_output_file}".m3u8

m3u_editor_repo="$(config_get m3u_editor_repo)";

build_telly="$(config_get build_telly)";

telly_repo="$(config_get build_telly_repo)";
telly_link="$(config_get latest_telly_url)";
built_telly_exe="$(config_get built_telly_exe)";
latest_telly_exe="$(config_get latest_telly_exe)";

is_vaders=0
is_osx=0
sed_exe=sed
awk_exe=awk

if [[ $OSTYPE == darwin* ]]; then 
    # Check for Homebrew, install if we don't have it
    if test ! $(which brew); then
        echo "Installing homebrew..."
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    fi

    # Update homebrew recipes
    echo "updating homebrew..."
    brew update

    # Install GNU core utilities (those that come with OS X are outdated)
    brew install gnu-sed gawk

    sed_exe=gsed
    awk_exe=gawk
else
    echo "Default configuration is assuming Mac OS X."
    if [ $build_telly == 0 ]; then
        echo "You're configured to download a built release."
        echo "If errors occur verify that this link is platform-appropriate:"
        echo ${telly_link}
    fi
fi

if [[ $iptv_m3u_url = *"vader"* ]]; then
    is_vaders=1
fi

echo_config_details

echo 'retrieving m3u-epg-editor...'

DIR=${m3u_editor_loc}

if [ -d $DIR ]; then
   echo updating $m3u_editor_repo
   cd $DIR
   git pull
   cd ..
else
   git clone -q $m3u_editor_repo
fi

# if we're not generating shell scripts there's no reason to build or retrieve telly
if [ $create_shell_scripts == 1 ]; then
    if [ $build_telly == 1 ]; then

        echo 'building telly from tip...'

        DIR="telly"
        if [ -d $DIR ]; then
           echo updating $telly_repo
           cd $DIR
           git pull
           rm -f bin/telly
           cd ..
        else
           git clone -q $telly_repo
        fi

        echo 'setting up telly tip...'
        cd telly

        DIR="vendor/github.com/koron/go-ssdp/.git"
        SSDPDIR="vendor/github.com/koron/go-ssdp/"
        if [ -d $DIR ]; then
           echo updating ${SSDPDIR}
           pushd .
           cd ${SSDPDIR}
           git pull
           popd
        else
           pushd .
           cd vendor/github.com/koron/
           git clone -q https://github.com/koron/go-ssdp.git
           popd
        fi

        echo 'building telly tip...'
        make

        echo 'running new telly build...'
        cd ..
        ${built_telly_exe} -h
    
        telly_exe=${built_telly_exe}
    else

        echo 'Retrieving latest telly build...'
    
        echo curl -f -L -O ${telly_link}
        curl -f -L -O ${telly_link}
        chmod a+x ${latest_telly_exe}

        echo 'running latest telly build...'
        ./${latest_telly_exe} -h

        telly_exe=./${latest_telly_exe}
    fi
fi

echo ''
echo ''

echo 'clearing directories'

rm -fr ${original_loc}
rm -fr ${sorted_loc}
rm -fr ${hd_loc}
rm -fr ${sd_loc}

mkdir ${original_loc}
mkdir ${sorted_loc}
if [ $create_sd_script == 1 ]; then
    mkdir ${sd_loc}
fi
if [ $create_hd_script == 1 ]; then
    mkdir ${hd_loc}
fi

if [ -d "${m3u_editor_loc}" ]; then

    sorted_output_file="${sorted_loc}"/sorted
    
    cd "${m3u_editor_loc}"
    pwd
    
    python m3u-epg-editor.py --sortchannels --m3uurl="$iptv_m3u_url" -e="$iptv_epg_url" -g "$CG" -c="$no_epg_channels" --outdirectory="$sorted_loc" --outfilename="$sorted_output_file";

    mv "${sorted_loc}"/original.* "${original_loc}"

    sorted_m3u="${sorted_output_file}".m3u8
    sorted_epg="${sorted_output_file}".xml

    # "${sorted_loc}" now contains:
    #     no_epg_channels.txt    - Channels without any EPG data
    # [These next three were named according to $sorted_output_file]
    #     sorted.channels.txt    - sorted list of channels filtered by channel groups
    #     sorted.m3u8            - sorted m3u8 containing channels from sorted filtered list
    #     sorted.xml             - EPG file containing channels from sorted filtered list

    # "${original_loc}" now contains:
    #     original.channels.txt  - Full original channel list from provider m3u
    #     original.gz            - original gzip EPG file from provider
    #     original.m3u8          - original M3U8 file from provider
    #     original.xml           - original expanded EPG file from provider

     channel_processing "${sorted_epg}"
    
    # 1 name sorted_channels
    # 2 loc  "${sorted_loc}/telly_sorted.sh"
    # 3 playlist "${sorted_m3u}"
    # 4 temp "${sorted_loc}"
    # 5 friendly "Sorted_Channels"
    # 6 epg ${sorted_epg}

    script_processing "sorted_channels" "${sorted_loc}/telly_sorted.sh" "${sorted_m3u}" "${sorted_loc}" "Sorted_Channels" "${sorted_epg}"

    # strip newlines
    tr -d '\n' < "${sorted_loc}/no_epg_channels.txt" > "${sorted_loc}/no_epg_channels.tmp1"
    # add commas
    sed "s/''/','/g" "${sorted_loc}/no_epg_channels.tmp1" > "${sorted_loc}/no_epg_channels.tmp"

    rm -f "${sorted_loc}/no_epg_channels.tmp1"

    no_epg_channels=$(< "${sorted_loc}/no_epg_channels.tmp")

    sed s/,.*/,/ "${sorted_channels}" > "${sorted_channels_no_group}"


#     ==== SD CHANNELS =================================
    if [ $create_sd_script == 1 ]; then
        echo "extract non-HD channels from ${sorted_channels_no_group}"
        echo "into ${sd_channels_file}"
        egrep -i -v -e " HD" "${sorted_channels_no_group}" > "${sd_channels_file}"

        sort < "${sd_channels_file}" | uniq > "${iptv_sd_unique}.tmp"
        # strip newlines
        tr -d '\n' < "${iptv_sd_unique}.tmp" > "${iptv_sd_unique}.tmp2"
        # strip trailing comma
        sed s/,$// "${iptv_sd_unique}.tmp2" > "${iptv_sd_unique}"
    
        rm -f "${iptv_sd_unique}.tmp"
        rm -f "${iptv_sd_unique}.tmp2"

        # now ${iptv_sd_unique} contains sorted, unique channels without trailing comma
        sd_channels=$(< "${iptv_sd_unique}")

        python m3u-epg-editor.py --sortchannels --m3uurl="$iptv_m3u_url" -e="$iptv_epg_url" -g "$CG" --channels="$no_epg_channels,$hd_channels" --outdirectory="$sd_loc" --outfilename="$sd_output_file"

        SDTV="$sd_loc/sdtv.m3u8"
        SDTV_EPG="$sd_loc/sdtv.xml"

        rm -f "${sd_loc}"/original.*

        # "${sd_loc}" now contains:
        #     sd.channels.only.txt   - sorted list of channels filtered by SD
        # [These next three were named according to $hd_output_file]
        #     sdtv.channels.txt      - sorted list of channels filtered by channel groups
        #     sdtv.m3u8              - sorted m3u8 containing channels from sorted filtered list
        #     sdtv.xml               - EPG file containing channels from sorted filtered list

        channel_processing "${SDTV_EPG}"

        script_processing "sd_channels" "${sd_loc}/telly_sd.sh" "${sd_m3u}" "${sd_loc}" "SDTV" "${SDTV_EPG}"

    fi

#     ==== HD CHANNELS =================================
    if [ $create_hd_script == 1 ]; then
        echo "extract HD channels from ${sorted_channels_no_group}"
        echo "into ${hd_channels_file}"
        egrep -i -e " HD" "${sorted_channels_no_group}" > "${hd_channels_file}"

        sort < "${hd_channels_file}" | uniq > "${iptv_hd_unique}.tmp"
        # strip newlines
        tr -d '\n' < "${iptv_hd_unique}.tmp" > "${iptv_hd_unique}.tmp2"
        # strip trailing comma
        sed s/,$// "${iptv_hd_unique}.tmp2" > "${iptv_hd_unique}"

        rm -f "${iptv_hd_unique}.tmp"
        rm -f "${iptv_hd_unique}.tmp2"

        # now ${iptv_hd_unique} contains sorted, unique channels without trailing comma
        hd_channels=$(< "${iptv_hd_unique}")

        python m3u-epg-editor.py --sortchannels --m3uurl="$iptv_m3u_url" -e="${iptv_epg_url}" -g "$CG" --channels="$no_epg_channels,$sd_channels" --outdirectory="$hd_loc" --outfilename="$hd_output_file"

        HDTV="$hd_loc/hdtv.m3u8"
        HDTV_EPG="$hd_loc/hdtv.xml"

        rm -f "${hd_loc}"/original.*
    
        # "${hd_loc}" now contains:
        #     hd.channels.only.txt - sorted list of channels filtered by SD
        # [These next three were named according to $hd_output_file]
        #     hdtv.channels.txt    - sorted list of channels filtered by channel groups
        #     hdtv.m3u8            - sorted m3u8 containing channels from sorted filtered list
        #     hdtv.xml             - EPG file containing channels from sorted filtered list

        channel_processing "${HDTV_EPG}"

        script_processing "hd_channels" "${hd_loc}/telly_hd.sh" "${hd_m3u}" "${hd_loc}" "HDTV" "${HDTV_EPG}"

    fi

else
    echo no "${m3u_editor_loc}"
fi   

