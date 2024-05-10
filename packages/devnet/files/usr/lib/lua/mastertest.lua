local repository = "http://10.13.0.2:8081/"
local lime_mesh_upgrade = require 'lime-mesh-upgrade'
local eupgrade = require 'eupgrade'


local network = require("lime.network")
print(tostring(network.primary_address()))
print(tostring(eupgrade.get_upgrade_api_url()))


local utils = require "lime.utils"
-- Uncoment for qemu
--os.execute('echo librerouter-v1 > /tmp/sysinfo/board_name')

print(eupgrade._get_board_name())
eupgrade.set_custom_api_url(repository)
print(tostring(eupgrade.get_upgrade_api_url()))
utils.printJson(eupgrade.is_new_version_available())

--lime_mesh_upgrade.become_main_node()
--utils.printJson(lime_mesh_upgrade.get_main_node_status())
--
--os.execute("sleep " .. tonumber(1))
--
--utils.printJson(lime_mesh_upgrade.get_main_node_status())
--
--while not (lime_mesh_upgrade.get_main_node_status().code == eupgrade.STATUS_DOWNLOADED) do
--
--    os.execute("sleep " .. tonumber(1))
--
--    utils.printJson(lime_mesh_upgrade.get_main_node_status())
--
--end
--
--utils.printJson(lime_mesh_upgrade.start_firmware_upgrade_transaction())
