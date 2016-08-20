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
 

## Client machine configuration

### configure the default environment variable

Copy openstackrc.example as openstackrc and adjust the parameters according to your setup

   ```
   export CINDER_VERSION="2"
   export OS_AUTH_URL="http://x.x.x.x:5000/v2.0"
   export OS_IDENTITY_API_VERSION="2.0"
   export OS_NO_CACHE="1"
   export OS_PASSWORD="mysecret"
   export OS_TENANT_NAME="admin"
   export OS_VOLUME_API_VERSION="2"


   # optional only if using openstack + contrail

   export CONTRAIL_URL="http://x.x.x.x:8082"
  
   export PYDIR=""
   export HEAT="${PYDIR}heat"
   export NEUTRON="${PYDIR}neutron"
   export NOVA="${PYDIR}nova"
   export PYTHON="${PYDIR}python"
   export GLANCE="${PYDIR}glance"
   export KEYSTONE="${PYDIR}keystone"


   ```
