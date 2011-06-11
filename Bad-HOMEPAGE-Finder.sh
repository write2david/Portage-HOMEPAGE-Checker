#!/bin/bash

# You may want to run it like this: time ./Bad-HOMEPAGE-Finder.sh > ~/Bad-HOMEPAGEs-on-`date +%m-%d-%y`.txt

# Then you can, in another terminal, watch the output:  tail -f ~/Bad-HOMEPAGEs-on-`date +%m-%d-%y`.txt

# https://github.com/write2david/Portage-HOMEPAGE-Checker/

# Current version of this script is available here:
# https://github.com/write2david/Portage-HOMEPAGE-Checker/raw/master/Find-Portage-HOMEPAGE-Problems.sh 

echo
echo 
echo "Welcome to the Portage Tree Homepage Checker"
echo 
echo "   The current version is available at:"
echo "   https://github.com/write2david/Portage-HOMEPAGE-Checker"
echo
echo "   This script depends on the 'sys-process/time' package."
echo
echo
echo "We will test all HOMEPAGE variables in your Portage tree."
echo "     We will find HOMEPAGES (and sometimes SRC_URI's) that don't load."
echo
echo




# STEP 1

# Find all ebuilds and grep their HOMEPAGE line
# Remove "HOMEPAGE="
# Remove all double-quotes
# Sometimes more than one URL is listed on the same HOMEPAGE line, so convert spaces to new lines
# Sometimes people add stuff to HOMEPAGE besides the URL, like comments -- so get rid of all entries that don't include "http://"]


echo
echo
echo "1) Getting list of all HOMEPAGE's in the Portage Tree."
echo "     (this will take a few moments)..."
echo

# Homepages may be commented out, so in the following line, we grep for HOMEPAGE only if it is at the beginning of the line.  See http://bugs.gentoo.org/show_bug.cgi?id=366957

/usr/bin/time -f %E -o /tmp/PTHC-Find-Homepages.txt find /usr/portage/ -name '*.ebuild' -type f -exec grep '^HOMEPAGE' '{}' \; | sed 's/HOMEPAGE=//' | sed 's/"//g' | sed 's/\ /\n/g' | grep http:// > /tmp/PortageHomepages-Unsorted.txt

sort /tmp/PortageHomepages-Unsorted.txt | uniq > /tmp/PortageHomepages.txt

echo "     Number of unique HOMEPAGE URL's in Portage tree: `wc -l /tmp/PortageHomepages.txt | awk '{ print $1}'`"
echo
echo "     Amount of time it took to find them all: `cat /tmp/PTHC-Find-Homepages.txt`."
echo
echo
echo


# STEP 2

# check all the sites (with "wget --spider") to see if the URL's are either good or broken

echo "2) Checking each HOMEPAGE in the Portage tree to see if it is accessible..."
echo
echo "     This process will take a while."
echo
echo "     You can monitor the progress by running this command in another terminal:"
echo "        tail -f /tmp/PortageHomepagesTested.txt"
echo
rm -f /tmp/PortageHomepagesTested.txt > /dev/null

# /usr/bin/time -p -o /tmp/PTHC-Check-Each-Homepage.txt wget --spider -nv -i /tmp/PortageHomepages.txt -o /tmp/PortageHomepagesTested.txt --timeout=10 --tries=3 --waitretry=10 --no-check-certificate --no-cookies
# The command above takes forever, run 3 instances of wget in parallel, idea taken from http://www.linuxjournal.com/content/downloading-entire-web-site-wget#comment-325493
# here we also change wget command from -o to -a, so that each wget doesn't overwrite the file, but instead appends to it

# NOTE:  you can increase speed by adding more instances of wget (change "-P 3" to something like "-P 15")
#     but I don't think my DNS server likes that many lookups so quickly, after a while it stops resolving
#     So, if you want to increase parallelization further, it might be best to run your own DNS server like unbound
/usr/bin/time -f %E -o /tmp/PTHC-Check-Each-Homepage.txt cat /tmp/PortageHomepages.txt | xargs -n1 -P 3 -i wget --spider -nv -a /tmp/PortageHomepagesTested.txt --timeout=10 --tries=3 --waitretry=10 --no-check-certificate --no-cookies -O /dev/null {}


echo "     Amount of time this step took: `cat /tmp/PTHC-Check-Each-Homepage.txt`"
echo


echo
echo
echo "3) Processing the results..."
echo
echo



# STEP 3

# Remove the websites without issues ('200 OK' HTTP status code) from the list
#	and get the HTTP codes all the HOMEPAGES that have issues.


#=========
#===OLD===
# wget -i /tmp/PortageHomepagesWithIssues.txt -o /tmp/PortageHomepagesLogs.txt -O /tmp/PortageHomepageDump
# The command above takes forever, run 3 instances of wget in parallel, idea taken from http://www.linuxjournal.com/content/downloading-entire-web-site-wget#comment-325493
# here we also change wget command from -o to -a, so that each wget doesn't overwrite the file, but instead appends to it
# NOTE:  you can increase speed by adding more instances of wget (change "-P 3" to something like "-P 15")
#     but I don't think my DNS server likes that many lookups so quickly, after a while it stops resolving
#     So, if you want to increase parallelization further, it might be best to run your own DNS server like unbound
# ========
# ========



rm -f /tmp/PortageHomepagesLogs.txt > /dev/null

# First Remove all the "200" lines ("OK"), so that we are left with only the problem sites.
#   Then we get the error code for the sites that have issues
#   And we want to keep only the "http" lines, and remove the ":" that wget puts in at the end of the lines.

/usr/bin/time -f %E -o /tmp/PTHC-Processing-Results-1.txt grep -v '200 OK' /tmp/PortageHomepagesTested.txt | grep -v '200 Ok' | grep http | sed 's/:$//g' > /tmp/PortageHomepagesWithIssues.txt
echo "     Amount of time *PART 1* of this step took: `cat /tmp/PTHC-Processing-Results-1.txt`"
echo
echo "     You can monitor *PART 2* with this command:"
echo "        tail -f /tmp/PortageHomepagesLogs.txt"
echo 
echo 

/usr/bin/time -f %E -o /tmp/PTHC-Processing-Results-2.txt cat /tmp/PortageHomepagesWithIssues.txt | xargs -n1 -P 3 -i wget --no-check-certificate --timeout=10 --tries=3 --waitretry=10 --no-check-certificate --no-cookies -nv -a /tmp/PortageHomepagesLogs.txt -O /dev/null {}
echo "     Amount of time *PART 2* of this step took: `cat /tmp/PTHC-Processing-Results-2.txt`"



#=========
#===OLD===
# Filter out the URL's that have 302 redirects, which are okay.
# The 302 status codes will be listed by wget in the file as "302 MovedTemporarily" (no space) and "302 Found"
#
# This is not needed anymore, with the switch to "-nv" in the previous wget command
# grep -E '302 MovedTemporarily|302 Found' /tmp/PortageHomepagesLogs.txt -B 3 | head -n1 | awk '{ print $3}' > /tmp/PortageHomepagesWith302.txt

# Combine both the list of problematic homepages with the list of 302 homepages, and then remove all the duplicate lines so that only the unique lines (the non-302 errors) remain
# cat /tmp/PortageHomepagesWith302.txt >> /tmp/PortageHomepagesWithIssues.txt


# STEP 2.5 -OLD
# GO through the results of the previous command and get all the DNS resolution errors (which is something the next step doesn't catch)
# grep 'unable to resolve host address' /tmp/PortageHomepagesTested.txt > /tmp/RealPortageHomepageIssues-DNS-ISSUES.txt
# pull only the URL (the 7th field), then get only the characters a-z, A-Z, 0-9, and period (that is, remove the quotes)
# cat /tmp/PortageHomepageIssues-DNS-ISSUES.txt | awk '{ print $7}' | sed s/[^a-zA-Z0-9.]//g > /tmp/RealPortageHomepageIssues-DNS-ISSUES.txt 
# sort /tmp/PortageHomepagesWithIssues.txt | uniq -u > /tmp/RealPortageHomepageIssues.txt
# ========
# ========




# Format for /tmp/PortageHomepagesLogs.txt is:   URL on one line, the issue is on the next line, repeat.
# Look for each type of issue, get the line that identifies the issue, also grab the preceding,
#    then remove the lines that ID the issue, then make sure to get lines that only start with a URL
#    then remove lines that have '%' which must (?) be a carryover from the ebuild
#    then remove the colons at the end, which wget adds in.

echo
echo "     Finishing up this step..."
echo

grep '403: Forbidden' /tmp/PortageHomepagesLogs.txt -B 2 | grep -v '403: Forbidden' | grep -E '^http' | grep -v '%' | sed s/:$//g > /tmp/PTHC-403.txt

grep '404: Not Found' /tmp/PortageHomepagesLogs.txt -B 2 | grep -v '404: Not Found' | grep -E '^http' | grep -v '%' | sed s/:$//g > /tmp/PTHC-404.txt

grep '500: Internal Server Error' /tmp/PortageHomepagesLogs.txt -B 2 | grep -v '500: Internal Server Error' | grep -E '^http' | grep -v '%' | sed s/:$//g > /tmp/PTHC-500.txt

grep '503: Service Unavailable' /tmp/PortageHomepagesLogs.txt -B 2 | grep -v '503: Service Unavailable' | grep -E '^http' | grep -v '%' | sed s/:$//g > /tmp/PTHC-503.txt

grep '410: Gone' /tmp/PortageHomepagesLogs.txt -B 2 | grep -v '410: Gone' | grep -E '^http' | grep -v '%' | sed s/:$//g > /tmp/PTHC-410.txt

grep 'unable to resolve host address' /tmp/PortageHomepagesLogs.txt -B 2 | grep -v 'unable to resolve host address' | grep -E '^http' | grep -v '%' | sed s/:$//g > /tmp/PTHC-DNS.txt



# STEP 7

# Display the useful information.

echo
echo
echo "4) Producing Results..."
echo


# REPORT EBUILDS WITH DNS ISSUES
echo
echo "  --> There are `wc -l /tmp/PTHC-DNS.txt | awk '{print $1}'` HOMEPAGES that have *DNS* issues."
echo ""
echo "     The URL's, and the ebuilds that contain them, are being recorded in"
echo "       /tmp/PTHC-DNS-Results.txt..."
echo 
rm -f /tmp/PTHC-DNS-Results.txt > /dev/null

echo "     There are `wc -l /tmp/PTHC-DNS.txt | awk '{print $1}'` HOMEPAGES that have *DNS* issues." >> /tmp/PTHC-DNS-Results.txt
echo >> /tmp/PTHC-DNS-Results.txt
echo "Need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable. No distinction is made in the output below, even though it says \"HOMEPAGE with a problem\"" >> /tmp/PTHC-DNS-Results.txt 
echo "" >> /tmp/PTHC-DNS-Results.txt

for i in $(cat /tmp/PTHC-DNS.txt) ; do
echo "" >> /tmp/PTHC-DNS-Results.txt
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-DNS-Results.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." >> /tmp/PTHC-DNS-Results.txt
echo "" >> /tmp/PTHC-DNS-Results.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-DNS-Results.txt
echo "" >> /tmp/PTHC-DNS-Results.txt
echo "" >> /tmp/PTHC-DNS-Results.txt
done




# REPORT EBUILDS WITH 403 ISSUES

echo
echo
echo "  --> There are `wc -l /tmp/PTHC-403.txt | awk '{print $1}'` HOMEPAGES that have *403 Forbidden* issues."
echo ""
echo "     The URL's, and the ebuilds that contain them, are being recorded in"
echo "       /tmp/PTHC-403-Results.txt..."
echo 
rm -f /tmp/PTHC-403-Results.txt > /dev/null

echo "     There are `wc -l /tmp/PTHC-403.txt | awk '{print $1}'` HOMEPAGES that have *403 Forbidden* issues." >> /tmp/PTHC-403-Results.txt
echo >> /tmp/PTHC-403-Results.txt
echo "Need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable. No distinction is made in the output below, even though it says HOMEPAGE with a problem" >> /tmp/PTHC-403-Results.txt 
echo "" >> /tmp/PTHC-403-Results.txt

for i in $(cat /tmp/PTHC-403.txt) ; do
echo "" >> /tmp/PTHC-403-Results.txt
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-403-Results.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." >> /tmp/PTHC-403-Results.txt
echo "" >> /tmp/PTHC-403-Results.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-403-Results.txt
echo "" >> /tmp/PTHC-403-Results.txt
echo "" >> /tmp/PTHC-403-Results.txt
done



# REPORT EBUILDS WITH 404 ISSUES
echo
echo
echo
echo "  --> There are `wc -l /tmp/PTHC-404.txt | awk '{print $1}'` HOMEPAGES that have *404 Not Found* issues."
echo ""
echo ""
echo "     The URL's, and the ebuilds that contain them, are being recorded in"
echo "       /tmp/PTHC-404-Results.txt..."
echo 
rm -f /tmp/PTHC-404-Results.txt > /dev/null

echo "     There are `wc -l /tmp/PTHC-404.txt | awk '{print $1}'` HOMEPAGES that have *404 Not Found* issues." >> /tmp/PTHC-404-Results.txt
echo >> /tmp/PTHC-404-Results.txt
echo "Need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable. No distinction is made in the output below, even though it says HOMEPAGE with a problem" >> /tmp/PTHC-404-Results.txt 
echo "" >> /tmp/PTHC-404-Results.txt

for i in $(cat /tmp/PTHC-404.txt) ; do
echo "" >> /tmp/PTHC-404-Results.txt
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-404-Results.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." >> /tmp/PTHC-404-Results.txt
echo "" >> /tmp/PTHC-404-Results.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-404-Results.txt
echo "" >> /tmp/PTHC-404-Results.txt
echo "" >> /tmp/PTHC-404-Results.txt
done



# REPORT EBUILDS WITH 500 ISSUES
echo
echo
echo
echo "  --> There are `wc -l /tmp/PTHC-500.txt | awk '{print $1}'` HOMEPAGES that have *500 Internal Server Error* issues."
echo ""
echo ""
echo "     The URL's, and the ebuilds that contain them, are being recorded in"
echo "       /tmp/PTHC-500-Results.txt..."
echo 
rm -f /tmp/PTHC-500-Results.txt > /dev/null

echo "     There are `wc -l /tmp/PTHC-500.txt | awk '{print $1}'` HOMEPAGES that have *500 Internal Server Error* issues." >> /tmp/PTHC-404-Results.txt
echo >> /tmp/PTHC-500-Results.txt
echo "Need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable. No distinction is made in the output below, even though it says HOMEPAGE with a problem" >> /tmp/PTHC-500-Results.txt 
echo "" >> /tmp/PTHC-500-Results.txt

for i in $(cat /tmp/PTHC-500.txt) ; do
echo "" >> /tmp/PTHC-500-Results.txt
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-500-Results.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." >> /tmp/PTHC-500-Results.txt
echo "" >> /tmp/PTHC-500-Results.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-500-Results.txt
echo "" >> /tmp/PTHC-500-Results.txt
echo "" >> /tmp/PTHC-500-Results.txt
done



# REPORT EBUILDS WITH 503 ISSUES
echo
echo
echo
echo "  --> There are `wc -l /tmp/PTHC-503.txt | awk '{print $1}'` HOMEPAGES that have *503 Service Unavailable* issues."
echo ""
echo ""
echo "     The URL's, and the ebuilds that contain them, are being recorded in"
echo "       /tmp/PTHC-503-Results.txt..."
echo 
rm -f /tmp/PTHC-503-Results.txt > /dev/null

echo "     There are `wc -l /tmp/PTHC-503.txt | awk '{print $1}'` HOMEPAGES that have *503 Service Unavailable* issues." >> /tmp/PTHC-503-Results.txt
echo >> /tmp/PTHC-503-Results.txt
echo "Need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable. No distinction is made in the output below, even though it says HOMEPAGE with a problem" >> /tmp/PTHC-503-Results.txt 
echo "" >> /tmp/PTHC-503-Results.txt

for i in $(cat /tmp/PTHC-503.txt) ; do
echo "" >> /tmp/PTHC-503-Results.txt
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-503-Results.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." >> /tmp/PTHC-503-Results.txt
echo "" >> /tmp/PTHC-503-Results.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-503-Results.txt
echo "" >> /tmp/PTHC-503-Results.txt
echo "" >> /tmp/PTHC-503-Results.txt
done



# REPORT EBUILDS WITH 410 ISSUES
echo
echo
echo "  --> There are `wc -l /tmp/PTHC-410.txt | awk '{print $1}'` HOMEPAGES that have *410 Gone* issues."
echo ""
echo ""
echo "     The URL's, and the ebuilds that contain them, are being recorded in"
echo "       /tmp/PTHC-410-Results.txt..."
echo 
rm -f /tmp/PTHC-410-Results.txt > /dev/null

echo "     There are `wc -l /tmp/PTHC-410.txt | awk '{print $1}'` HOMEPAGES that have *410 Gone* issues." >> /tmp/PTHC-410-Results.txt
echo >> /tmp/PTHC-410-Results.txt
echo "Need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable. No distinction is made in the output below, even though it says HOMEPAGE with a problem" >> /tmp/PTHC-410-Results.txt 
echo "" >> /tmp/PTHC-410-Results.txt

for i in $(cat /tmp/PTHC-410.txt) ; do
echo "" >> /tmp/PTHC-410-Results.txt
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-410-Results.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." >> /tmp/PTHC-410-Results.txt
echo "" >> /tmp/PTHC-410-Results.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-410-Results.txt
echo "" >> /tmp/PTHC-410-Results.txt
echo "" >> /tmp/PTHC-410-Results.txt
done




# Last step of cleanup
# rm /tmp/RealPortageHomepageIssues*
# rm /tmp/PortageHome*



echo
echo
echo 
echo "5) Follow-up..."
echo
echo "     Now you can file bug reports: http://bugs.gentoo.org/enter_bug.cgi?product=Gentoo%20Linux&format=guided"
echo 
echo "		(first, double-check that someone hasn't filed a bug already)"
echo
echo
echo "     Select \"Applications\" and enter a Description like \"Invalid HOMEPAGE for [package name]\"."
echo
echo "     Mention something like: \"The HOMEPAGE will not load because [what type of error].  The HOMEPAGE is:  [URL].\"" 
echo
echo
