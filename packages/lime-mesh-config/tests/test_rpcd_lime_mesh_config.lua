local test_utils = require "tests.utils"
local json = require("luci.jsonc")
local eupgrade = require 'eupgrade'
local libuci = require 'uci'
local uci
local testFileName = "packages/lime-mesh-config/files/usr/libexec/rpcd/lime-mesh-config"
local limeRpc
local rpcdCall = test_utils.rpcd_call


local sample_config= [[
config lime system
	option deferable_reboot_uptime_s '654321' # reboot every 7.5 days 

config lime networkmesh_config = require 'lime-mesh-config'
	option main_ipv4_address '10.1.128.0/16/17'
	option anygw_dhcp_start '2562'
	option anygw_dhcp_limit '30205'
	option batadv_orig_interval '5000'

config lime wifi		
	option country 'ES'	
	option ap_ssid 'Calafou-to-be-configured'
	option apname_ssid 'Calafou/%H-to-be-configured'
	option ieee80211s_mesh_id 'libremesh'

config lime-wifi-band '2ghz' 
	option channel '1'
	option htmode 'HT40'
	list modes 'ap'	
	list modes 'apname'
	list modes 'ieee80211s'
	option distance '300'

config lime-wifi-band '5ghz'
	option channel '36'
	option htmode 'VHT80'
	list modes 'ieee80211s'
	option distance '300'

config net lan1onlymesh
	option linux_name 'lan1'
	#list protocols lan # we want all the protocols but LAN, as this ethernet port will be used for meshing, not for clients access
	list protocols anygw
	list protocols batadv:%N1
	list protocols babeld:17

config net lan2onlymesh
	option linux_name 'lan2'
	#list protocols lan # we want all the protocols but LAN, as this ethernet port will be used for meshing, not for clients access
	list protocols anygw
	list protocols batadv:%N1
	list protocols babeld:17

config generic_uci_config prometheus
	list uci_set "prometheus-node-exporter-lua.main.listen_interface=lan"

config run_asset prometheus_enable
	option asset 'community/prometheus_enable'
	option when 'ATFIRSTBOOT'
]]

describe('general rpc testing', function()
    local snapshot -- to revert luassert stubs and spies

    before_each('', function()
        limeRpc = test_utils.load_lua_file_as_function(testFileName)

        snapshot = assert:snapshot()
        uci = test_utils.setup_test_uci()
        stub(utils, 'read_file', function(command)
            return sample_config
        end)
        snapshot = assert:snapshot()
        uci:set('mesh-config', 'main', "mesh-config")
        uci:set('mesh-config', 'main', "transaction_state", "DEFAULT")
        uci:set('mesh-config', 'main', "retry_count",0)
        uci:save('mesh-config')
        uci:commit('mesh-config')
    end)

    after_each('', function()
        snapshot:revert()
        test_utils.teardown_test_uci(uci)
        test_utils.teardown_test_dir()
    end)

    it('test list methods', function()
        local response = rpcdCall(limeRpc, {'list'})
        assert.is.equal("value", response.become_main_node.url)
        assert.is.equal("value", response.start_config_transaction.file_contents)
        assert.is.equal(0, response.abort.no_params)
        assert.is.equal(0, response.start_safe_reboot.confirm_timeout)
        assert.is.equal(0, response.get_node_status.no_params)

    end)

    it('test get status different timeouts', function()
        local response = rpcdCall(limeRpc, {'call', 'get_node_status'}, '{}')
        print(response)
        utils.printJson(response)
    end)

    it('test start_safe_config ', function()
        local response = rpcdCall(limeRpc, {'call', 'get_node_status'}, '{}')
        print(response)
        utils.printJson(response)
        local contents = '{"file_contents":"' .. response["lime-config"] .. '"}'
        print(contents)
        local response = rpcdCall(limeRpc, {'call', 'start_config_transaction'}, contents)
    end)
    it('test get_comunity_config ', function()
        local response = rpcdCall(limeRpc, {'call', 'get_comunity_config'}, '{}')
        print(response)
        utils.printJson(response)
    end)

end)
