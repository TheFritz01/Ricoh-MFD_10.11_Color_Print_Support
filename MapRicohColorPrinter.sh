#!/bin/bash
##  Aaron Stovall
##  4/1/2016
##
##  Map Ricoh MP C4501 and MP C4502 printers using a generic PCL_XL Printer Driver via pxlcolor.  
##  Requires GhostScript, Foomatic, and PXLmono
##
##  This script was mostly borrowed from Matt Broughton located here: http://tinyurl.com/oepe5go
##  I only made modifications to map the printer and make it run completely silent 


## Define Variables  
site="6th Floor, West Side"
server="printserver01"
domain="example.com"
printer="Printer02"
driver="/Library/Printers/PPDs/Contents/Resources/en.lproj/Generic-PCL_6_PCL_XL_Printer-pxlcolor.ppd.gz"

## Map Printer
## The Secret Sauce for me to get Color working was to add the PrintoutMode=Normal.  By default it will go with Normal.Greyscale. 
/usr/sbin/lpadmin -E -p $printer -L "$site" -E -v lpd://$server.$domain/$printer -P $driver -o PrintoutMode=Normal; cupsenable $printer; cupsaccept $printer;
/usr/sbin/lpadmin -p $printer -o printer-is-shared=false -o auth-info-required=negotiate

############################################################
# scan for existing queues...
#
# we want only the queue name so strip the leading directories
# and the .ppd suffix...
# we're using only `awk' here instead of `grep',`dirname', and `basename'
# because awk should ALWAYS be available on OS X while the others may not


# set the CUPS ppd directory variable

CUPS_PPD_DIR="/etc/cups/ppd/"

## awk cannot handle an escaped \+ (plus sign), \t (tab), or \* (asterick)
## so use . (any character) or define the character to use
## in the regexp

TAB=`printf "\t"`
STAR=`printf "\*"`

QUEUE_KEY_1=${STAR}cupsFilter\:${TAB}\"application.vnd.cups-pdf\ 0\ foomatic-rip\"
QUEUE_KEY_2=${STAR}"FoomaticRIPCommandLine"
# scan for existing foomatic-rip queues...
#
# we want only the queue name so strip the leading directories and the .ppd suffix...

QUEUE=( `awk "/${QUEUE_KEY_1}/||/${QUEUE_KEY_2}/ {print FILENAME;nextfile;}" ${CUPS_PPD_DIR}* | awk '{n=split($0,a,"/"); split(a[n],b,".ppd");print b[1];}'` )

############################################################
#set -x
if [ ${#QUEUE[@]} -eq 0 ]; then
	echo "No printers match the modification criteria." "$LOGFILE"
fi

anyMods="no"
if [ ${#QUEUE[@]} -gt 0 ]; then
	for NAME in ${QUEUE[@]} ; do
	echo The printer queue $NAME should be modified.
		echo "The printer queue $NAME should be modified." "$LOGFILE"
#	read -p "Do you want to continue? (y,n)  " continued
	continued="Y"
	if [[ "$continued" != [yY] ]]; then
#		printf "No action will be taken for printer ${NAME}.\n\n\n"
		echo "No action will be taken for printer ${NAME}." "$LOGFILE"
	else
#		printf "Please enter you administrator's password if prompted.\n"
		sleep 3
		sudo echo
		sudo sed -e '/^\*NickName/s/recommended/El Capitan Modified/g' \
-e '/^\*FoomaticRIPCommandLine/s/\"gs /\"\/usr\/local\/bin\/gs /g'  \
-e '/FoomaticRIPCommandLine/,/^\*End/s/sIjsServer=hpijs/sIjsServer=\/usr\/local\/bin\/hpijs/g' \
-e  '/^\*FoomaticRIPCommandLine/,/^\*End/s/(gs /(\/usr\/local\/bin\/gs /g' \
-e  '/^\*FoomaticRIPCommandLine/,/^\*End/s/ min12xxw/ \/usr\/local\/bin\/min12xxw/g' \
-e  '/^\*FoomaticRIPCommandLine/,/^\*End/s/ pnm2ppa/ \/usr\/local\/bin\/pnm2ppa/g' ${CUPS_PPD_DIR}${NAME}.ppd > /private/tmp/xx${NAME}.ppd
		sudo /bin/mv /private/tmp/xx${NAME}.ppd ${CUPS_PPD_DIR}${NAME}.ppd
		sudo chown root:_lp ${CUPS_PPD_DIR}${NAME}.ppd
		sudo chmod 644 ${CUPS_PPD_DIR}${NAME}.ppd
		echo "Printer ${NAME} Modified." "$LOGFILE"
		anyMods="yes"
	fi

done
	

fi
if [ ${anyMods} = "yes" ]; then
#
##########################
# Check the Mac OS version
MACOS_VERSION_FILE=/System/Library/CoreServices/SystemVersion.plist

MACOS_VERSION=$(awk '/ProductVersion/ {while (RLENGTH<4) {match($0,"[0-9]+([.][0-9]+)*");x=substr($0,RSTART,RLENGTH);getline;};print x;}' "${MACOS_VERSION_FILE}")

MAJOR_VERSION=$(echo ${MACOS_VERSION}|awk '{split($0,a,".");print a[1];nextfile;}')
MINOR_VERSION=$(echo ${MACOS_VERSION}|awk '{split($0,a,".");print a[2];nextfile;}')
MICRO_VERSION=$(echo ${MACOS_VERSION}|awk '{split($0,a,".");print a[3];nextfile;}')

if [ 10 -eq ${MAJOR_VERSION:-10} -a 5 -le ${MINOR_VERSION} ] ; then
 ## Restart CUPS
 	sudo chown root:_lp ${CUPS_PPD_DIR}${NAME}.ppd
	sudo launchctl unload /System/Library/LaunchDaemons/org.cups.cupsd.plist
	sudo launchctl load /System/Library/LaunchDaemons/org.cups.cupsd.plist
	echo Restarting CUPS.
	echo "Restarting CUPS." "$LOGFILE"
elif  [ 10 -eq ${MAJOR_VERSION:-10} -a 4 -ge ${MINOR_VERSION} ] ; then ## OS X 10.3.x or OS X 10.4.x
## Restart printing services
	sudo chown root:lp ${CUPS_PPD_DIR}${NAME}.ppd
	sudo /System/Library/StartupItems/PrintingServices/PrintingServices stop
	sleep 1
	sudo /System/Library/StartupItems/PrintingServices/PrintingServices start
fi

fi

exit 0
