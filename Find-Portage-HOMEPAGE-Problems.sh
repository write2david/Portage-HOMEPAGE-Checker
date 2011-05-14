#!/bin/bash

# # https://github.com/write2david/Portage-HOMEPAGE-Checker/

# Current version of this script is available here:
# https://github.com/write2david/Portage-HOMEPAGE-Checker/raw/master/Find-Portage-HOMEPAGE-Problems.sh 


# It may be interesting to you to prefix this script with "time"

# This script is for checking whether the HOMEPAGE variable in ebuilds are valid.

# This script tests all the HOMEPAGE variables in all the ebuilds in the Portage tree.  For that HOMEPAGE URL's that done have a 200 (OK) or 302 (redirect) HTTP status code, this script displays that URL, what the status code is, and which ebuilds use it.  Then bugs can be filed on bugs.gentoo.org so that the HOMEPAGE can be updated.


# STEP 1

# [Find all ebuilds and grep their HOMEPAGE line
# Remove "HOMEPAGE="
# Remove all double-quotes
# Sometimes more than one URL is listed on the same HOMEPAGE line, so convert spaces to new lines
# Sometimes people add stuff to HOMEPAGE besides the URL, like comments or the string "${HOMEPAGE}"  -- so get rid of all entries that don't include "http"]


find /usr/portage/ -name '*.ebuild' -type f -exec grep HOMEPAGE '{}' \; | sed 's/HOMEPAGE=//' | sed 's/"//g' | sed 's/\ /\n/g' | grep http:// > /tmp/PortageHomepages-Unsorted.txt

sort /tmp/PortageHomepages-Unsorted.txt | uniq > /tmp/PortageHomepages.txt

echo "Number of unique HOMEPAGE URL's:" && wc -l /tmp/PortageHomepages.txt | awk '{ print $1}'



# STEP 2

# check all the sites (with "wget --spider") to see if the URL's are good or broken

wget --spider -nv -i /tmp/PortageHomepages.txt -o /tmp/PortageHomepagesTested.txt --timeout=10 --tries=3 --waitretry=10 --no-check-certificate --no-cookies



# STEP 3

# Go through the results of the previous command and remove all the "200" lines ("OK"), so that we are left with only the problem sites. Keep only the "http" lines, and remove the ":" that wget puts in at the end of the lines. Sometimes the following command will list sites that wget identified as a "broken link" because it was a redirect (302).  These are false-positives and we'll deal with them in a bit.

grep -v '200 OK' /tmp/PortageHomepagesTested.txt | grep -v '200 Ok' | grep http | sed 's/:$//g' > /tmp/PortageHomepagesWithIssues.txt



# STEP 4

# Get the HTTP codes all the HOMEPAGES that have issues

wget -i /tmp/PortageHomepagesWithIssues.txt -o /tmp/PortageHomepagesLogs.txt -O /tmp/PortageHomepageDump



# STEP 5

# Filter out the URL's that have 302 redirects, which are okay. The URL for the 302 redirets is 3 lines before the "302 redirect" message, and is the 3rd field in awk's estimation

grep 302 /tmp/PortageHomepagesLogs.txt -B 3 | head -n1 | awk '{ print $3}' > /tmp/PortageHomepagesWith302.txt



# STEP 6

# Combine both the list of problematic homepages with the list of 302 homepages, and then remove all the duplicate lines so that only the unique lines (the non-302 errors) remain

cat /tmp/PortageHomepagesWith302.txt >> /tmp/PortageHomepagesWithIssues.txt

sort /tmp/PortageHomepagesWithIssues.txt | uniq -u > /tmp/RealPortageHomepageIssues.txt

rm /tmp/PortageHome*



# STEP 7

echo ""
echo "There are `wc -l /tmp/RealPortageHomepageIssues.txt | awk '{print $1}'` HOMEPAGES that have issues."
echo ""
echo ""



for i in $(cat /tmp/RealPortageHomepageIssues.txt) ; do
echo ""
echo "HOMEPAGE with a problem...    $i"
wget $i -o /tmp/RealProblemLog.txt -O /tmp/RealProblemDump
tail -n2 /tmp/RealProblemLog.txt | head -n1 | awk '{ print $4 " " $5 " "$6 " " $7 " " $8 " " $9}' > /tmp/RealProblemCode.txt
echo "   ...Type of problem with this URL...   `cat /tmp/RealProblemCode.txt`"
echo "   ...Searching Portage tree for all ebuilds that use this HOMEPAGE." 
echo ""
find /usr/portage/ -name '*.ebuild' -type f -print | xargs -i grep -l $i {}
echo ""
echo ""
# Remove temporary files that wget produced in this "for/done" section:
rm /tmp/RealProblemLog.txt
rm /tmp/RealProblemDump
done


# Last step of cleanup
rm /tmp/RealPortageHomepageIssues.txt



#[file a bug]

#http://bugs.gentoo.org/enter_bug.cgi?product=Gentoo%20Linux&format=guided

#Select Applications, remove URL


#Invalid HOMEPAGE for



#The site will not load because 

#[URL]