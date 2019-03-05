# Simple Router

* Write P4 program
* Fill out sX-commands.txt file(s), which can be used to populate any intial
  table entries. NOTE: uses bmv2 commands, which is slightly different than
  the SimpleSumeSwitch commands
* Create topology.json file
* Compile P4 program and launch Mininet topology `$ make`
* Note which thrift port each switch is running on. The initial port value
  is 9090 and it increments by 1 for each additional switch
* Note which switch interface is used for control traffic. It will always
  be of the form sX-eth1.
* Start control-plane (in P4-NetFPGA-CS344 repo): For example,
  `# ./control_plane.py --mode bmv2 --thrift_port 9090 --iface s1-eth1 --config topos/single-router.json`
* Open xterm on hosts:
  `mininet> xterm h1 h2`

