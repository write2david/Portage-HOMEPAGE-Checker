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
echo
echo "We will now test all HOMEPAGE variables in the Portage tree."
echo "     We'll find those that have DNS issues.  We'll also find those"
echo "     without a '200' (OK) or '302' (redirect) HTTP status code."
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

/usr/bin/time -p -o /tmp/PTHC-Find-Homepages.txt find /usr/portage/ -name '*.ebuild' -type f -exec grep '^HOMEPAGE' '{}' \; | sed 's/HOMEPAGE=//' | sed 's/"//g' | sed 's/\ /\n/g' | grep http:// > /tmp/PortageHomepages-Unsorted.txt

sort /tmp/PortageHomepages-Unsorted.txt | uniq > /tmp/PortageHomepages.txt

echo "     Number of unique HOMEPAGE URL's: `wc -l /tmp/PortageHomepages.txt | awk '{ print "     "$1}'`"
echo
echo "     Amount of time this step took: `cat /tmp/PTHC-Find-Homepages.txt | head -n 1 | awk '{ print $2}'`"
echo
echo
echo


# STEP 2

# check all the sites (with "wget --spider") to see if the URL's are either good or broken

echo "2) Checking each HOMEPAGE in the Portage tree to see if it is accessible..."
echo
echo "     This process will take a while."
echo "     You can monitor the progress by running this command in another terminal:"
echo "        tail -f /tmp/PortageHomepagesTested.txt"
echo

/usr/bin/time -p -o /tmp/PTHC-Check-Each-Homepage.txt wget --spider -nv -i /tmp/PortageHomepages.txt -o /tmp/PortageHomepagesTested.txt --timeout=10 --tries=3 --waitretry=10 --no-check-certificate --no-cookies
echo
echo "     Amount of time this step took: `cat /tmp/PTHC-Check-Each-Homepage.txt | head -n 1 | awk '{ print $2}'`"


echo
echo
echo "3) Processing the results..."
echo
echo


# STEP 2.5

# GO through the results of the previous command and get all the DNS resolution errors (which is something the next step doesn't catch)

grep 'unable to resolve host address' /tmp/PortageHomepagesTested.txt > /tmp/RealPortageHomepageIssues-DNS-ISSUES.txt

# pull only the URL (the 7th field), then get only the characters a-z, A-Z, 0-9, and period (that is, remove the quotes)
cat /tmp/PortageHomepageIssues-DNS-ISSUES.txt | awk '{ print $7}' | sed s/[^a-zA-Z0-9.]//g > /tmp/RealPortageHomepageIssues-DNS-ISSUES.txt 



# STEP 3

# Go through the results of the previous command and remove all the "200" lines ("OK"), so that we are left with only the problem sites. Keep only the "http" lines, and remove the ":" that wget puts in at the end of the lines. Sometimes the following command will list sites that wget identified as a "broken link" because it was a redirect (302).  These are false-positives and we'll deal with them in a bit.

grep -v '200 OK' /tmp/PortageHomepagesTested.txt | grep -v '200 Ok' | grep http | sed 's/:$//g' > /tmp/PortageHomepagesWithIssues.txt



# STEP 4

# Get the HTTP codes all the HOMEPAGES that have issues

# Removing redirects (302) from the list of "broken" HOMEPAGE's

wget -i /tmp/PortageHomepagesWithIssues.txt -o /tmp/PortageHomepagesLogs.txt -O /tmp/PortageHomepageDump



# STEP 5

# Filter out the URL's that have 302 redirects, which are okay. The URL for the 302 redirects is 3 lines before the "302 redirect" message, and is the 3rd field in awk's estimation

grep 302 /tmp/PortageHomepagesLogs.txt -B 3 | head -n1 | awk '{ print $3}' > /tmp/PortageHomepagesWith302.txt



# STEP 6

# Combine both the list of problematic homepages with the list of 302 homepages, and then remove all the duplicate lines so that only the unique lines (the non-302 errors) remain

cat /tmp/PortageHomepagesWith302.txt >> /tmp/PortageHomepagesWithIssues.txt

sort /tmp/PortageHomepagesWithIssues.txt | uniq -u > /tmp/RealPortageHomepageIssues.txt




# STEP 7

# Display the useful information.

echo
echo "4) Producing Results..."
echo
echo
echo "     There are `wc -l /tmp/RealPortageHomepageIssues-DNS-ISSUES.txt | awk '{print $1}'` HOMEPAGES that have DNS issues."
echo ""
echo ""
echo "     They are being recorded in /tmp/PTHC-Bad-DNS-Homepages.txt..."
echo 
rm -f /tmp/PTHC-Bad-DNS-Homepages.txt > /dev/null

for i in $(cat /tmp/RealPortageHomepageIssues-DNS-ISSUES.txt) ; do
echo "" >> /tmp/PTHC-Bad-DNS-Homepages.txt
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-Bad-DNS-Homepages.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." >> /tmp/PTHC-Bad-DNS-Homepages.txt
echo "   (need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable.)" >> /tmp/PTHC-Bad-DNS-Homepages.txt 
echo "" >> /tmp/PTHC-Bad-DNS-Homepages.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-Bad-DNS-Homepages.txt
echo "" >> /tmp/PTHC-Bad-DNS-Homepages.txt
echo "" >> /tmp/PTHC-Bad-DNS-Homepages.txt
done




echo
echo
echo
echo "     There are `wc -l /tmp/RealPortageHomepageIssues.txt | awk '{print $1}'` HOMEPAGES that have other issues."
echo ""
echo ""
echo "     They are being recorded in /tmp/PTHC-Missing-Homepages.txt"
echo 
rm -f /tmp/PTHC-Missing-Homepages.txt > /dev/null

for i in $(cat /tmp/RealPortageHomepageIssues.txt) ; do
echo ""
echo "HOMEPAGE with a problem...    $i" >> /tmp/PTHC-Missing-Homepages.txt
wget $i -o /tmp/RealProblemLog.txt -O /tmp/RealProblemDump
tail -n2 /tmp/RealProblemLog.txt | head -n1 | awk '{ print $4 " " $5 " "$6 " " $7 " " $8 " " $9}' > /tmp/RealProblemCode.txt
echo "   ...Type of problem with this URL...   `cat /tmp/RealProblemCode.txt`" >> /tmp/PTHC-Missing-Homepages.txt
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE."  >> /tmp/PTHC-Missing-Homepages.txt
echo "   (need to fix: currently, all ebuilds that reference this URL will be included, whether or not it is the HOMEPAGE variable or the SRC_URI variable.)" >> /tmp/PTHC-Missing-Homepages.txt 
echo "" >> /tmp/PTHC-Missing-Homepages.txt
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {} >> /tmp/PTHC-Missing-Homepages.txt
echo "" >> /tmp/PTHC-Missing-Homepages.txt
echo "" >> /tmp/PTHC-Missing-Homepages.txt
# Remove temporary files that wget produced in this "for/done" section:
rm /tmp/RealProblemLog.txt
rm /tmp/RealProblemDump
done


# Last step of cleanup
# rm /tmp/RealPortageHomepageIssues*
# rm /tmp/PortageHome*



echo
echo
echo 
echo "5) Follow-up..."
echo "     Now you can file bug reports: http://bugs.gentoo.org/enter_bug.cgi?product=Gentoo%20Linux&format=guided"
echo 
echo
echo "     Select \"Applications\"  and enter \"Invalid HOMEPAGE for [package name]\"."
echo
echo "     Mention something like: \"The HOMEPAGE will not load because [what type of error].  The HOMEPAGE is:  [URL].\"" 
echo
echo
