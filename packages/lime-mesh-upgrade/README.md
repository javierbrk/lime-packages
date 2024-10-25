# Mesh config 
This package can help you change lime-community of all the routers in a network from a single node. 

## Description and steps 
1- A node must become main node, the main node will generate a new
lime-community for all the others. And expose it in the local network via
shared-state-async. 
2- The main node announces the new config over shared-state-async.
3- Other nodes with this package will get the news and try to get the config.
4- Once all the nodes have the config in their tmp folder the main node user
will be able to schedule the safe reboot of all the nodes (this last step is
done synchronously). 
5- After the specified time (60s default) all the nodes will start the safe
reboot process and the nodes will reboot. 
6- The nodes will report that the new config has to be confirmed.
7- The main node user will verify that everything is in place an press the confirm button. 
8- If the config is not confirmed after 600 seconds the routers will go back to the previous config.

