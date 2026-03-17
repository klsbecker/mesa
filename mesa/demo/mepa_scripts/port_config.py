# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

#!/usr/bin/python

import sys
import json
import os, subprocess
from collections import OrderedDict
import optparse
port_count = 20

class PortConfig:

    def __init__(self,port_no):
        self.port_no = port_no

    def usage(self):
        st = """
               {}
                               Port Config Application

                              Given port number is : {}



               Port config Application is done with the mepa-cmd utility
               the proceedure is demonstarted below, run this script after
               executing mepa-demo-edsx

               1. # mepa-cmd dev create {}
               This will create a dev for the the port_no {}


               2. # mepa-cmd dev attach {} [qsgmii| sfi | sgmii]
               This will attach the dev to the serdes ports of EDS X
               if the platform is not EDSX the error will be displayed here

               3. # mepa-cmd dev conf {} -f filename
               This will configure the dev from the file file should be present in
               /root/mepa_scripts/

               This is an automated step and the steps should be followed in the same
               order, when used with mepa-cmd
               {}
              """.format('-'*80, self.port_no, self.port_no, self.port_no, self.port_no, self.port_no, '-'*80)
        print (st)

    def mepa_cmd(self, cmd):
        return os.system("{} 2>&1 > /dev/null".format(cmd))

    def mepa_cmd_json(self, string):
        print(string)
        return os.popen(string).read()

    def mepa_cmd_json_api(self, json_str, api):
        call_api = "echo [{},{}{}] | mepa-cmd -i call {}".format(self.port_no, json_str, "}", api)
        print("Command = > {}\n\n".format(call_api))
        return os.system("{} 2>&1 > /dev/null".format(call_api))

def main():
    parser = optparse.OptionParser()

    parser.add_option('-p', dest = 'port',
                      type = 'int',
                      help = 'specify the port number')
    parser.add_option('-i', dest = 'interface',
                      type = 'string',
                      help = 'specify the interface')
    parser.add_option('-f', dest = 'file',
                      type = 'string',
                      help = 'specify the file') 
    (options, args) = parser.parse_args()
    
    if (options.port == None):
            print (parser.usage)
            exit(0)
    else:
            port_no = options.port

    if (options.file == None):
            print (parser.usage)
            exit(0)
    else:
            file_name = options.file
    Pc = PortConfig(port_no)
    Pc.usage()

    #step 1
    port_no = Pc.port_no
    rc = Pc.mepa_cmd("mepa-cmd dev create {}".format(port_no));
    if (int(rc) != 0):
        print ("Error in creating dev")
        exit(0)

    result = Pc.mepa_cmd_json("echo [{}] | mepa-cmd -i call meba_phy_info_get".format(port_no - 1))
    string = json.loads(result)
    print( " Dev Created for device : {}" .format(string["result"][1]["part_number"]))


    #step 2

    if (options.interface == None):
         interface = "sfi"
    else:
         interface = options.interface

    rc = Pc.mepa_cmd("mepa-cmd dev attach {} {}".format(port_no, interface));
    if (int(rc) != 0):
        print ("Error in attaching dev to the switch")
        exit(0)

    #step 3
    
    rc = Pc.mepa_cmd("mepa-cmd dev conf {} -f {}".format(port_no, file_name))
    if (int(rc) != 0):
        print ("Error in configuring the device")
        exit(0)

if __name__ == "__main__":
    main()


