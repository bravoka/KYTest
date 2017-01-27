#!/bin/bash

# This script was made to upgrade Splunk 6.4.1 to Splunk 6.5.1 before applying Splunk configuratiouns
# version 1.00
# modified by: K.Y.
# last modified: 1/26/2017
# this script should be run as root
 


# stop Splunk service
(cd /opt/splunk/bin && ./splunk stop)

# download version 6.5.1 to local
wget -O /opt/splunk-6.5.1-f74036626f0c-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=6.5.1&product=splunk&filename=splunk-6.5.1-f74036626f0c-Linux-x86_64.tgz&wget=true'

# unzip the tar file
tar zxvf /opt/splunk-6.5.1-f74036626f0c-Linux-x86_64.tgz -C /opt/

# start splunk service
(cd /opt/splunk/bin && ./splunk start --accept-license --answer-yes)



# TO DO:
# If upgrade was successful > create a text file somewhere saying the installation was successful.










