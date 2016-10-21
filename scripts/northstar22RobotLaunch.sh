#!/bin/bash

# Author : Roslan Zaki


# find the full program path
if (echo $0 | grep -q -e '^/') ;then
 full_prog=$0;
else
 full_prog=`pwd`/$0
fi

progName=`basename ${full_prog}`
scriptPath=`dirname ${full_prog}`


# MAIN definition
# MAINDIR="/opt/openstack-ns"
cmd="NorthStar_Robot"
vmTopology="basic7"
ha_install=0
custom_heat=0
custom_image=0
yes=0
zone='nj'
robotImage='robot'
envFile='robot.env'
createVM=1
display_help=0
runRobotOnly=0
defaultRobotTest="test-REST-unit.robot"

#heat_name="northstar210.3instances.floating.heat"
centos_version="6"
repo='http://172.25.152.2/repos/northstar/6.5/os/x86_64/Packages/'
buildDownload="${jenkins_url}job/${jenkins_build}/lastSuccessfulBuild/artifact/artifacts/ns-test.tbz2"

SSH="ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
SCP="scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
jenkins_url="http://172.25.152.51:8080/jenkins/"
jenkins_build="PCS2.1.0"

# Parse argmuments
while [[ $# > 0 ]]; do
    key="$1"
    case $key in
        --id)
        customer="$2"
        shift # past argument
        ;;
        --ha)
        ha_install=1
        shift # past argument
        ;;
        --zone)
        zone="$2"
        shift # past argument
        ;;
        --topo)
        topology="$2"
        shift # past argument
        ;;
        --help)
        display_help=1
        shift # past argument
        ;;
        --build)
        jenkins_build="$2"
        shift # past argument
        ;; 
        --url)
        download_url="$2"
        shift # past argument
        ;;     
        --vmx)
        vmx_stack="$2"
        shift # past argument
        ;;   
        --runRobotOnly)
        runRobotOnly=1
        shift # past argument
        ;;                      
        --yes)
        yes=1
        ;;
        *)
                # unknown option
        ;;
    esac
    shift # past argument or value
done




function display_help() {

    echo 
    echo "HELP"
    echo
    echo "northstar22RobotLaunch -i <customer-name> <other-options>"
    echo
    echo "Options:"
    echo " --id              : <customer-name> MANDATORY" 
    echo " --zone            : <zone>"
    echo " --topo            : <topology>"
    echo " --heat            : <heat template>"
    echo " --help            : <help menu>"    
    echo " --img             : <application image>"
    echo " --build           : <build used for robot testing>"
    echo " --url             : <URL link to download and install Northstar App>"
    echo " --yes             : <Yes, please delete existing stack without confirming>"
    echo " --vmx             : <connect to existing VMX topology>"
    echo " --runRobotOnly    : <run robot tests>"
    echo
    echo " Usage example:"
    echo " ./northstar21RobotLaunch.sh -i roslan500 -z nj"


}


function initialize_parameters() {

# display help
if [ $display_help -eq 1 ]; then
    display_help
    exit 1

fi


# Verify customer name is provided
if [ "X$customer" == "X" ]; then
    echo
    echo "Please provide customer name !!"
    display_help
    exit 1
else
	echo $customer | grep "-" > /dev/null
	if  [ $? -eq 0 ]; then
		echo "Use of hyphen (-) is not allowed in the customer name. Please use underscore (_) instead"
		exit 1
	fi
fi


# verify that zone is provided else use 'nj'
if [ "X$zone" == "X" ]; then
    zone=${zone}  # if no option provided, use default zone 'nj'
fi

# verify that topology is provided else use 'basic7'
if [ "X$topology" == "X" ]; then
    topology=${vmTopology}  # if no option provided, use default topology 'basic7'
fi

# verify whether single node or HA cluster is used
# if HA set to node number to 3
if [ $ha_install -eq 1 ]; then
        stackName="robotHA_${customer}"
        nodeNumber=3
else
        stackName="robot_${customer}"
        nodeNumber=1
fi


echo "vmx_stack = $vmx_stack"

# verify if vmx stack is specified
# if vmx stack name exists, do not create stack again
if [ "X${vmx_stack}" == "X" ]; then
    vmx_stackName="${topology}-${stackName}"
    
else
    ${OPENSTACK} stack list | grep ${vmx_stack} > /dev/null
    if [ $? -eq 0 ]; then  
        vmx_stackName=${vmx_stack}
        createVM=0  
   
    else   
        echo " ERROR !! ${vmx_stack} is not found"
        echo " Exit "
        exit 1  
    fi
fi


# create stack name for NS and robot
ns_stackName="northstar-${stackName}"
robot_stackName="linux-${stackName}"
buildDownload="${jenkins_url}job/${jenkins_build}/lastSuccessfulBuild/artifact/artifacts/ns-test.tbz2"
stack_list="${robot_stackName} ${vmx_stackName} ${ns_stackName}" # create the stack lists

echo "vmx stack name : $stack_list"


}




function spawn_Northstar_and_JunosVM() {

	echo "Spawning Northstar and JunosVM"
    echo 
    echo "bash -x northstar_launch.sh -y -i ${stackName} -z ${zone}"
    if [ -e ${url} ]; then 
        bash -x northstar_launch.sh -y -i ${stackName} -z ${zone} -u ${url} 
    else
        bash -x northstar_launch.sh -y -i ${stackName} -z ${zone}
    fi
    # Todo : Need to get return code from the script to know if the script is successful

}


function findIP_NS_JunosVM() {
# find the ip address of Northstar App and JunosVM

    echo "Find IP address for NS with stackname : ${ns_stackName}"
    resources=`cat data/${ns_stackName}/network_list.txt`
    if [ $nodeNumber -eq 1 ]; then

        app_ip[1]=`echo "${resources}" | grep "app_port_eth0"  | awk '{print $11}' | sed s'/["}]//g'`
        junosvm_ip[1]=`echo "${resources}" | grep "junosvm_port_em1"  | awk '{print $11}' | sed s'/["}]//g'`
    fi

    echo "NS IP       : ${app_ip[1]}"
    echo "Junos VM IP : ${junosvm_ip[1]}"

}





################
###
###  VMX Creation  
###
################

function spawn_VMX_topo() {

    local stackName=$1
    local zone=$2
    local topology=$3

    local maxSpawn=10
    local counter=1
    while [ true ]; do
    
        Banner "Spawning VMX with ${topology} topology"
        if [ $counter -gt 1 ]; then
            echo "  Trying to respawn # ${counter}"
        fi
        
        if [ $topology = "custom" ]; then
            echo "Launching ankit script here"
        else 
            ./vmx_01_setup.sh -i ${stackName} -z ${zone} -t ${topology} -y        

        fi
        local return_code=$?
        if [ $return_code -ne 0 ];then
            echo "Discovered that VMX topology is incorrect after VMX spawning"
            echo "Please wait.. Re-spawning is underway"
            counter=`expr $counter + 1`
            sleep 2;
        else
            break;
        fi
        if [ $counter -gt $maxSpawn ];then
            echo "ERROR: Maximum spawn of ${maxSpawn} has reached"
            echo "Unable to proceed with spawning"
            echo "Please notify system admin"
            exit 1
        fi
    done      
    
    
   

}


function verify_vmx_topo() {

    echo "Verifying VM topology and terminate the script if it is incorrect"
    ./vmx_99_verify_topo.sh -s ${vmx_stackName}
    if [ $? -ne 0 ]; then
        echo "ERROR !! Incorrect topology detected"
        exit 1
    fi
    
    
}


function save_config() {

    echo "Saving base configuration to base_config.txt"
    local vmx_list=`cat ${MGMT_IP} | awk '/vmx/{print $2}'`
    local fileName="base_config.txt"
    cmd="configure private;save $fileName; commit; exit"
    echo $vmx_list
    echo $cmd
    for vmx in ${vmx_list}; do
        ${PYTHON} connect.py --debug --ipv4 ${vmx} --username northstar --password northstar --protocol ssh --cmd "$cmd"
    done
    
    



}



function vmx_topology() {

    if [ $createVM -eq 1 ]; then
        if [ $runRobotOnly -eq 0 ]; then
            spawn_VMX_topology ${stackName} ${zone} ${topology} 
            sleep 30
        fi
    fi
    verify_vmx_topo
    echo "continue"


}




function pcep_bgpLS() {

	echo "Configure BGP LS"
    echo
    bash -x vmx_99_connect_to_pcs.sh -s ${vmx_stackName} -t ${topology} -p ${app_ip[1]} -b ${junosvm_ip[1]}    

}






#########
##  ROBOT
#########


function spawn_robot() {
    
    local maxSpawn=5
    local counter=1
    while [ true ]; do
        if [ $counter -gt 1 ]; then
            echo "  Trying to respawn # ${counter}"
        fi
        bash -x linux_launch.sh -y -i ${stackName} -a ${robotImage}
        if [ $? -ne 0 ];then
            echo "Discovered issue with spawning robot VM"
            echo "Please wait.. Re-spawning is underway"
            counter=`expr $counter + 1`
            sleep 2;
        else
            break;
        fi
        if [ $counter -gt ${maxSpawn} ];then
            echo "ERROR: Maximum spawn of ${maxSpawn} has reached"
            echo "Unable to proceed with spawning"
            echo "Please notify system admin"
            exit 1
        fi
    done  


}

function install_robot_framework() {


	${SSH} root@${robotIPAddress} 'cat /etc/yum.conf | grep "proxy=http://172.25.152.2:8080"; if [ $? -eq 1 ]; then `echo "proxy=http://172.25.152.2:8080" >> /etc/yum.conf`; fi'

	# Download the latest build
    echo "Downloading from ${buildDownload}"
    ${SSH} root@${robotIPAddress} "curl -O ${buildDownload}"

    # extract the regression file package and change the /root directory ownership to root:root
    ${SSH} root@${robotIPAddress} "tar xvjf ns-test.tbz2; chown -R root:root /root"


	# install regression test
	${SSH} root@${robotIPAddress} "rpm -Uvh NorthStar-regression*"

}



function install_python_modules() {


    PIP="/opt/northstar/thirdparty/python/bin/pip2.7"
    

    # install the additional modules
    ${SSH} root@${robotIPAddress} "$PIP install pytz"
    ${SSH} root@${robotIPAddress} "$PIP install robotframework-debuglibrary"
    
    # install NTP on robotVM
    ${SSH} root@${robotIPAddress} 'yum install ntp ntpdate ntp-doc -y; chkconfig ntpd on; sed -i "s/server/# server/g" /etc/ntp.conf; echo "server 172.25.152.2" >> /etc/ntp.conf' || true
    ${SSH} root@${robotIPAddress} 'mv /etc/localtime /etc/localtime.bak; ln -s /usr/share/zoneinfo/America/New_York /etc/localtime; sed -i "/ZONE/ d" /etc/sysconfig/clock; service ntpd restart' || true
    sleep 10
    ${SSH} root@${robotIPAddress} 'ntpq -p' || true

    # install NTP on northstar VM
    ${SSH} root@${app_ip[1]} 'yum install ntp ntpdate ntp-doc -y; chkconfig ntpd on; sed -i "s/server/# server/g" /etc/ntp.conf; echo "server 172.25.152.2" >> /etc/ntp.conf' || true
    ${SSH} root@${app_ip[1]} 'mv /etc/localtime /etc/localtime.bak; ln -s /usr/share/zoneinfo/America/New_York /etc/localtime; sed -i "/ZONE/ d" /etc/sysconfig/clock; service ntpd restart' || true
    sleep 10
    ${SSH} root@${app_ip[1]} 'ntpq -p' || true


}


function change_password() {

    # Changing password from 'adminadmin' to 'admin1' in Northstar App
    # Copy the public key is copied to the robot topology directory
    ${SSH} root@${app_ip[1]} "net_setup.py --init-password --system-password-new admin1"
    ${SSH} root@${app_ip[1]} "node /opt/northstar/utils/change_admin_pw.js admin1"
    ${SSH} root@${robotIPAddress} "cp ~/.ssh/id_rsa /opt/northstar/regressionTests/regression-tests/robot/official/topology/"  
    
    


}


function get_all_ip() {
    # Get the public IP address and install into ${MGMT_IP} temporary file     
    stacks=$@    
	
	# create temporary files 
    local TMP1=`mktemp /tmp/roslanXXXXXXX`
    chmod 600 ${TMP1}
	
	MGMT_IP=`mktemp /tmp/roslanXXXXXXX`
    chmod 600 ${MGMT_IP}
    
    for stack in ${stacks}; do   
        ./stack.sh --list -s ${stack} | grep -v "fpc" 2> /dev/null >> ${TMP1}
    done
    
	cat ${TMP1}
	cat ${TMP1} | cut -d"-" -f 2 | sed -e 's/_re//g'  -e 's/northstar_junosvm/vrr/g' -e 's/northstar_app/pcs/g'  > ${MGMT_IP}	
    cat ${MGMT_IP}
	rm -f ${TMP1}
    
    

}


function upload_topo_template() {


    TMP=`mktemp /tmp/kkkkXXXXXXX`
    chmod 600 ${TMP}
    # TODO : have config files for this

    echo "Regression test configuration root\@${robotIPAddress}"

        case ${topology} in
        basic7)
            echo "# Regression test configuration using ${vmTopology}"
            DESTINATION="/opt/northstar/regressionTests/regression-tests/robot/official/topology/ns-7-2.txt"
            ${SCP} robotTemplate/${topology}.template root@${robotIPAddress}:${DESTINATION}
            (cat<<EOF
BEGIN{m["pcs"]="\${PCS}";m["vmx101"]="\${node1:mgmt}";m["vmx102"]="\${node2:mgmt}";m["vmx103"]="\${node3:mgmt}";m["vmx104"]="\${node4:mgmt}";m["vmx105"]="\${node5:mgmt}";m["vmx106"]="\${node6:mgmt}";m["vmx107"]="\${node7:mgmt}";m["vrr"]="\${vrr:mgmt}"};(\$1 in m) {print m[\$1] "\t" \$2}
EOF
            )  > ${TMP}
            # Now inject the current config
			cat ${TMP}
            awk -f ${TMP} < ${MGMT_IP} | ${SSH} root@${robotIPAddress} "cat >> ${DESTINATION}"
            ;;
        *)
            echo "# Unknown network configuration  ${VM_TOPOLOGY}"
            ;;
    esac
    rm -f ${TMP}
    
}


function set_publickey() {

    # disable strict host checking
    ${SSH} root@${robotIPAddress} 'sed -i "s/#   StrictHostKeyChecking ask/    StrictHostKeyChecking no/" /etc/ssh/ssh_config ; service sshd reload'

 
    # get robot public key
    local robotKey=`${SSH} root@${robotIPAddress} "cat ~/.ssh/id_rsa.pub"`

    # configure robot public key into all of VMXs
    local vmx_list=`cat ${MGMT_IP} | awk '/vmx/{print $2}'`
    cmd="configure private;set system login user northstar authentication ssh-rsa \"${robotKey}\";top;commit;exit"
    for vmx in ${vmx_list}; do
        ${PYTHON} connect.py --debug --ipv4 ${vmx} --username northstar --password northstar --protocol ssh --cmd "$cmd"
    done
    
    
    # configure robot public key into NS 
    ${PYTHON} connect.py --debug --ipv4 ${app_ip[1]} --username root --password admin1 --protocol ssh --cmd "echo ${robotKey} >> ~/.ssh/authorized_keys"

}




function display_setup() {

#	testing purposes
#	MGMT_IP="$scriptPath/ip_address.txt"

	echo
	echo " A) VMX"
	echo
	cat ${MGMT_IP} | awk '/vmx/{print " " $1 " " $2}'
	echo
	echo " credential VMX : northstar/northstar"
	echo
	echo
	echo " B) RobotVM"
	echo
	cat ${MGMT_IP} | awk '/linux/{print " " "robotVM  " $2}'
	echo
	echo " credential robotVM : root/r0b0t88"
	echo
	echo
	echo " C) NorthStar VM"
	echo
	cat ${MGMT_IP} | awk '/pcs/{print " " "NorthStarVM  " $2}'
	echo
	echo " credential NorthStar VM : root/admin1   UI: admin/admin1"	
	echo
	echo
	echo " D) JUNOS VM:"
	echo
	cat ${MGMT_IP} | awk '/vrr/{print " " "JUNOSVM  " $2}'
	echo
	echo " credential JUNOS VM : northstar/northstar"	
	echo	
	
	# remove the temporary file containing IP addresses
	rm -f ${MGMT_IP}
	

}



####################
## environment
####################


function export_env() {

    local environmentFile=$1
    local saveEnv="data/${vmx_stackName}/${environmentFile}"

    echo "export pcs_ip=\"${pcs_ip}\"" > ${saveEnv}
    echo "export robot_ip=\"${robot_ip}\"" >> ${saveEnv}
    echo "export vrr_ip=\"${vrr_ip}\"" >> ${saveEnv}
    
    echo "Save Env :"
    cat ${saveEnv}

}


function set_env() {

    echo "set_env"
 	robot_ip=`cat ${MGMT_IP} | awk '/linux/{print $2}'`
    pcs_ip=`cat ${MGMT_IP} | awk '/pcs/{print $2}'`
    vrr_ip=`cat ${MGMT_IP} | awk '/vrr/{print $2}'`
    echo "$pcs_ip $vrr_ip $robot_ip"
    export_env ${envFile}

}



####################
# robot Test
####################


function robot_tests() {

    echo "Running robot test .. .."
    ${SSH} root@${robotIPAddress} 'cd /opt/northstar/regressionTests/regression-tests/robot/official; ../run.sh -L DEBUG test-REST-unit.robot'
    
}


############################
## do northstar, vmx, robot
############################


function do_northstar() {

    if [ $runRobotOnly -eq 0 ]; then
        echo
        spawn_Northstar_and_JunosVM
        sleep 30
    fi
    findIP_NS_JunosVM


}


function do_vmx() {

    vmx_topology
    pcep_bgpLS
    

}





function do_robot() {

    echo "Robot stackname is ${robot_stackName}"

    stackInfo=`./vmx_99_get_fxp_ip.sh -s "${robot_stackName}"`
    robotIPAddress=`echo $stackInfo | awk -F":" '{print $3}'`
    echo "robotIP is $robotIPAddress"

    if [ $runRobotOnly -eq 0 ]; then
        spawn_robot
        sleep 30
    fi
    install_robot_framework
    install_python_modules
    change_password
    get_all_ip ${stack_list}
    upload_topo_template
    set_publickey
    save_config
    echo "Finished with do_robot"

}



function main() {

    initialize_parameters
    do_northstar
    do_vmx
    do_robot
    set_env
    display_setup
    robot_tests
    
    

}

# main program starts here
main
