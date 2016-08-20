# SCRIPTs collection to run VMX, Northstar and IPMPLSView on Openstack + Contrail

This repository contains the colleciton of scripts to automate the setup and testing  of Northstar on Openstack

## Generic Requirements

* Working system of Openstack or Openstack + Contrail

* All scripts in this repo can be installed in Openstack server itself or on any linux machines outside Openstack system

* If the scripts on this repo are going to be run from separate machine (for further reference, let us call it "client machine"):

   * the script is tested on Linux and OSX

   * Install the following package on the client machine:
      * Python 2.7

   * Install the following python modules:
      * python-novaclient
      * python-neutronclient
      * python-heatclient
      * python-glanceclient
      * python-keystoneclient
      * vncdotool
      * requests
 
