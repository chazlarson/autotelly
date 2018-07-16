# AutoTelly
AutoTelly is a set of bash scripts to help process your IPTV files for use with [telly](https://github.com/tombowditch/telly).

It's basically a front-end to [m3u-epg-editor](https://github.com/jjssoftware/m3u-epg-editor.git) with a couple extra bits.

The script will filter m3u and epg files on user-specified groups, removing channels which have no EPG data, and build a sorted m3u and epg file.

It can also:
* create m3u and epg containing just HD channels.
* create m3u and epg containing just SD channels.
* create shell scripts to run telly from this location.
* add channel numbers to the EPG to improve Plex' guide display

There is some processing using sed and awk that rely on the GNU versions rather than the OS X versions.  On OS X, the script will attempt to install homebrew and then gnu-sed and gawk.

## Using AutoTelly

1) Clone the repository
2) copy config.cfg.defaults to config.cfg
3) edit config.cfg as desired
4) run ./autotelly.sh

```
| => ./autotelly.sh
updating homebrew...
Already up to date.
Warning: gnu-sed 4.5 is already installed and up-to-date
To reinstall 4.5, run `brew reinstall gnu-sed`
Warning: gawk 4.2.1 is already installed and up-to-date
To reinstall 4.2.1, run `brew reinstall gawk`
retrieving m3u-epg-editor...
updating https://github.com/jjssoftware/m3u-epg-editor

Already up to date.

clearing directories
/Users/cl186073/dev/autotelly/m3u-epg-editor
2018-07-02T09:31:34.545943 performing HTTP GET request to http://api.vaders.tv/vget?username=REDACTED&password=REDACTED&format=ts
2018-07-02T09:31:39.025371 saving retrieved m3u file: /Users/cl186073/dev/autotelly/sorted/original.m3u8
2018-07-02T09:31:39.026915 parsing m3u into a list of objects
2018-07-02T09:31:39.106425 m3u contains 1287 items
2018-07-02T09:31:39.106578 keeping channel groups in this list['united states']
2018-07-02T09:31:39.114897 filtered m3u contains 92 items
2018-07-02T09:31:39.116040 desired channel sort order: ['united states']
2018-07-02T09:31:39.116230 saving new m3u file: /Users/cl186073/dev/autotelly/sorted/sorted.m3u8
2018-07-02T09:31:39.118351 performing HTTP GET request to http://vaders.tv/p2.xml.gz
2018-07-02T09:31:39.408556 saving retrieved epg file: /Users/cl186073/dev/autotelly/sorted/original.gz
2018-07-02T09:31:40.938887 extracting retrieved epg file to: /Users/cl186073/dev/autotelly/sorted/original.xml
2018-07-02T09:31:41.301525 creating new xml epg for 92 m3u items
2018-07-02T09:31:43.486716 creating channel element for I1204.28055.schedulesdirect.org
. . .
2018-07-02T09:31:43.605281 creating channel element for ReelzChannel.us
2018-07-02T09:31:43.941583 creating programme elements for A&E HD
. . . 
2018-07-02T09:31:51.902196 creating programme elements for Weather Channel HD
2018-07-02T09:31:52.287958 saving new epg xml file: /Users/cl186073/dev/autotelly/sorted/sorted.xml

Processing /Users/cl186073/dev/autotelly/sorted/sorted.xml

Performing VADER_SPECIFIC channel-number processing

Sorted and filtered M3U available here: /Users/cl186073/dev/autotelly/sorted/sorted.m3u8
Sorted and filtered EPG available here: /Users/cl186073/dev/autotelly/sorted/sorted.xml

Use the former when you start telly:
telly -listen 127.0.0.1:8077 \
-playlist=/Users/cl186073/dev/autotelly/sorted/sorted.m3u8 \
-temp /Users/cl186073/dev/autotelly/sorted \
-streams 5 \
-friendlyname Sorted_Channels \
-deviceid 10000009 \
-logrequests

Copy the latter somewhere that Plex can see it and
enter the URL/path when asked during DVR setup
```
### Configurable Options

```
create_sd=1
create_hd=1
```
If 1, create HD or SD-only M3U and EPG files [0 to disable]

```
create_shell_scripts=1
```
If 1, generate shell scripts to run telly from this directory.

As a side effect of this being set, telly will be built or downloaded as specified below.

If set to 0, telly will not be built or downloaded.  Presumably you're generating files to use elsewhere, perhaps in a docker context, so there's no reason to build or retrieve telly.

```
add_channel_numbers=1
```
Plex' Live TV Guide is designed expecting channel numbers; if there are no channel numbers the guide appearance in suboptimal. Those channel numbers are specified using an "lcn" tag that most EPG providers don't use.

This will add those tags to the EPG XML file.  It's based on a post by hthighway to the telly Discord.

There are presently two flavors of channel number processing: Vaders.tv and iptv-epg.com.

Vaders stock EPG contains this:
```
    <channel id="I202.58646.schedulesdirect.org">
        <display-name>CNN News HD</display-name>
        <display-name>CNNHD</display-name>
        <display-name>202 CNNHD</display-name>
        <display-name>202</display-name>
        <display-name>CNN HD</display-name>
        <icon src="https://s3.amazonaws.com/schedulesdirect/assets/stationLogos/s58646_h3_aa.png" />
    </channel>
```

It appears that all the channels that I am interested in contain that "number-only" line, so the script will convert this:

```        <display-name>202</display-name>```
to this:
```        <lcn lang="en">202</lcn>```

iptv-epg.com stock EPG contains only a single display-name field:
```
    <channel id="AandE.us">
        <display-name lang="en">A&amp;E US</display-name>
        <url>http://www.yo.tv</url>
        <icon src="http://static.iptv-epg.com/us/AandE.us.png"/></channel>
```
This gets an arbitrary channel number appended:
```
    <channel id="AandE.us">
        <display-name lang="en">A&amp;E US</display-name><lcn lang="en">2</lcn>
        <url>http://www.yo.tv</url>
        <icon src="http://static.iptv-epg.com/us/AandE.us.png"/></channel>
```

If your M3U URL is not from vaders, the iptv-epg.com method is used.

```
m3u_url=http://api.vaders.tv/vget?username=REDACTED&password=REDACTED&format=ts
epg_url=http://vaders.tv/p2.xml.gz
```
Presently only tested with vaders.

```
channelgroups='united states','sports'
```
M3U/EPG will be filtered to include only these groups.  This value is passed straight to the m3u-epg-editor.

The rest of the configuration options probably won't change often.

```
m3u_editor_repo=https://github.com/jjssoftware/m3u-epg-editor.git
```
Perhaps you have your own fork that does something differently?  For example, I use my own fork that eliminates the 90-odd lines of channel and programme logging that are redacted above.

```
build_telly=1
build_telly_repo=https://github.com/tombowditch/telly
built_telly_exe=telly/bin/telly

latest_telly_url=https://github.com/tombowditch/telly/releases/download/v0.6.2/telly-darwin-amd64
latest_telly_exe=telly-darwin-amd64
```
These control whether telly is built or downloaded.

The "create_shell_scripts" option effectively overrides all this if it is set to 0.

Note that the download URL is the Mac OS X version.  If you're not running OS X, be sure to change that.

```
# directories for various things
original=original
sorted=sorted
HD=hd
SD=sd
m3u=m3u-epg-editor
```
These are the directories that various things get stored in.  Maybe you don't like my names.

All of them are relative to the directory where the autotelly script is run.

### Credits
Thanks to [haxcop](https://github.com/haxcop/AutomatedHMS) for the initial idea.  His is a PowerShell script, and I run OS X and linux.

### Todo

* expose more [m3u-epg-editor](https://github.com/jjssoftware/m3u-epg-editor.git) options.
* wider variety of channel-number processing

### Issues

If you have any problems with or questions about this thing, please open a [GitHub issue](/issues).
