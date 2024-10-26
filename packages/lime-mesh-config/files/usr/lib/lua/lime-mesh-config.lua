#!/usr/bin/env lua

local config = require "lime.config"
local utils = require "lime.utils"
local fs = require("nixio.fs")
local json = require 'luci.jsonc'
local eupgrade = require 'eupgrade'

local mesh_config = {
    -- posible transaction states are derived from upgrade states
    transaction_states = {
        NO_TRANSACTION = "NO_TRANSACTION",
        STARTED = "STARTED", -- there is a transaction in progress
        ABORTED = "ABORTED",
        FINISHED = "FINISHED"
    },
    -- posible upgrade states enumeration
    config_states = {
        DEFAULT = "DEFAULT", -- When no config has changed
        WORKING = "WORKING", -- when a user starts changing the config
        READY_FOR_APLY = "READY_FOR_APLY", -- the config is set in the node and is ready to reboot 
        RESTART_SCHEDULED = "RESTART_SCHEDULED", -- the node will reboot in xx seconds 
        CONFIRMATION_PENDING = "CONFIRMATION_PENDING", -- the node rebooted and the configuration is not confirmed 
        CONFIRMED = "CONFIRMED", -- the configuration has been set and the user was able to confirm the change
        ERROR = "ERROR",
        ABORTED = "ABORTED"
    },
    -- Main node specific states
    main_node_states = {
        NO = "NO",
        STARTING = "STARTING",
        MAIN_NODE = "MAIN_NODE"
    },
    -- list of possible errors
    errors = {
        CONFIRMATION_TIME_OUT = "confirmation_timeout",
        ABORTED = "aborted",
        CONFIG_FAIL = "firmware_file_not_found",
        INVALID_CONFIG_FILE = "invalid_firmware_file",
        SAFE_REBOOT_ERROR = "safe reboot is not available"
    },
    fw_path = "",
    safe_restart_confirm_timeout = 600,
    safe_restart_start_time_out = 60,
    max_retry_conunt = 4,
    safe_restart_start_mark = 0,
    lime_community_path = "/etc/config/" .. config.UCI_COMMUNITY_NAME,
    new_lime_community_path = "/tmp/" .. config.UCI_COMMUNITY_NAME

}

local function registrar(texto)
    utils.unsafe_shell('logger -p daemon.info -t "async: mesh_config" "' .. texto .. '" ')
end

function mesh_config.get_current_config_hash()
    return utils.file_sha256(mesh_config.lime_community_path)
end
function mesh_config.get_new_config_hash()
    return utils.file_sha256(mesh_config.new_lime_community_path)
end

function mesh_config.generate_escaped_text(bigText)
    -- Escape the text for JSON
    local escapedText = bigText:gsub('"', '\\"') -- Escape double quotes
    escapedText = escapedText:gsub('\n', '\\n') -- Escape newlines
    escapedText = escapedText:gsub('\r', '\\r') -- Escape carriage returns
    escapedText = escapedText:gsub('\t', '\\t') -- Escape tabs
    return escapedText
end

function mesh_config.generate_original_text(escapedText)
    -- Unescape the text from JSON
    local originalText = escapedText:gsub('\\"', '"') -- Unescape double quotes
    originalText = originalText:gsub('\\n', '\n') -- Unescape newlines
    originalText = originalText:gsub('\\r', '\r') -- Unescape carriage returns
    originalText = originalText:gsub('\\t', '\t') -- Unescape tabs
    return originalText
end

-- One may just ask for the config or ask because it will start a new
-- transaction
-- @start_new_transaction yould be true to start a new transaction
function mesh_config.get_comunity_config(start_new_transaction)
    -- if (start_new_transaction) then
    --     mesh_config.change_state(mesh_config.config_states.WORKING)
    --     mesh_config.change_main_node_state(mesh_config.main_node_states.STARTING)
    -- end
    local filecontent = utils.read_file(mesh_config.lime_community_path)
    return mesh_config.generate_escaped_text(filecontent)
end

function mesh_config.get_new_comunity_config()
    local filecontent = utils.read_file(mesh_config.new_lime_community_path)
    return mesh_config.generate_escaped_text(filecontent)
end

-- ! Read status from UCI or load defuautl inicialization from code
function mesh_config.get_node_status()
    local uci = config.get_uci_cursor()
    local config_data = {}
    config_data.lime_config = uci:get('mesh-config', 'main', 'lime_config') -- only main node will show the config being distributed until confirmation or error 
    config_data.transaction_state = mesh_config.state()
    --if safe reboot is running and we where scheduled ... then we are in fact
    --waiting for confirmation
    local safe_reboot_pid = tonumber(utils.unsafe_shell("cat /tmp/run/safe-reboot.pid 2>/dev/null"))
    if (config_data.transaction_state == mesh_config.config_states.RESTART_SCHEDULED) then
        if (safe_reboot_pid and safe_reboot_pid > 1) then
            mesh_config.change_state(mesh_config.config_states.CONFIRMATION_PENDING)
        end
    end
    config_data.transaction_state = uci:get('mesh-config', 'main', 'transaction_state')
    config_data.error = uci:get('mesh-config', 'main', 'error')
    config_data.retry_count = tonumber(uci:get('mesh-config', 'main', 'retry_count'))
    config_data.timestamp = tonumber(uci:get('mesh-config', 'main', 'timestamp'))
    config_data.safe_restart_start_mark = tonumber(uci:get('mesh-config', 'main', 'safe_restart_start_mark')) or
                                              mesh_config.safe_restart_start_mark
    mesh_config.safe_restart_start_mark = config_data.safe_restart_start_mark
    config_data.safe_restart_start_time_out = tonumber(uci:get('mesh-config', 'main', 'safe_restart_start_time_out')) or
                                                  mesh_config.safe_restart_start_time_out
    mesh_config.safe_restart_start_time_out = mesh_config.safe_restart_start_time_out
    config_data.safe_restart_confirm_timeout =
        tonumber(uci:get('mesh-config', 'main', 'safe_restart_confirm_timeout')) or
            mesh_config.safe_restart_confirm_timeout
    mesh_config.safe_restart_confirm_timeout = config_data.safe_restart_confirm_timeout
    config_data.main_node = mesh_config.main_node_state()
    config_data.board_name = eupgrade._get_board_name()
    config_data.current_config_hash = mesh_config.get_current_config_hash()
    config_data.new_config_hash = mesh_config.get_new_config_hash()
    config_data.node_ip = uci:get("network", "lan", "ipaddr")

    config_data.safe_restart_remining = (mesh_config.safe_restart_start_time_out -
                                            (os.time() - mesh_config.safe_restart_start_mark) > 0 and
                                            mesh_config.safe_restart_start_time_out -
                                            (os.time() - mesh_config.safe_restart_start_mark) or -1)
    config_data.safe_restart_remining = (mesh_config.safe_restart_start_time_out -
                                            (os.time() - mesh_config.safe_restart_start_mark) > 0 and
                                            mesh_config.safe_restart_start_time_out -
                                            (os.time() - mesh_config.safe_restart_start_mark) or -1)
    config_data.confirm_remining = safe_reboot_pid
    return config_data
end

function mesh_config.set_new_comunity_config(new_comunity_file)
    utils.write_file(mesh_config.new_lime_community_path, mesh_config.generate_original_text(new_comunity_file))
end

-- Function that check if tihs node have all things needed to became a main node
-- Then, call update shared state with the proper info
-- @new_comunity_file new file to be shared as escaped text file
function mesh_config.start_config_transaction(new_comunity_file)
    if not new_comunity_file then
        if not utils.file_exists(mesh_config.new_lime_community_path) then
            return {
                code = "NO_NEW_CONFIG",
                error = "No new config provided"
            }
        end
    else
        -- write new lime_community in path
        mesh_config.set_new_comunity_config(new_comunity_file)
    end

    if (mesh_config.change_main_node_state(mesh_config.main_node_states.MAIN_NODE) and
        mesh_config.change_state(mesh_config.config_states.READY_FOR_APLY)) then
        local uci = config.get_uci_cursor()
        -- only main node will show the config being distributed until confirmation or error 
        uci:set('mesh-config', 'main', 'lime_config', mesh_config.get_new_comunity_config())
        uci:set('mesh-config', 'main', 'timestamp', os.time())
        uci:save('mesh-config')
        uci:commit('mesh-config')

        mesh_config.trigger_shared_state_publish()

        return {
            code = "SUCCESS",
            error = ""
        }
    else
        return {
            code = "NO_ABLE_TO_BECOME_MAIN_NODE",
            error = "Not able to start main node "
        }
    end
end

function mesh_config.check_safereboot_is_working()
    local result = os.execute("safe-reboot --help >/dev/null 2>&1")
    local exit_code = result and (result / 256) or result
    if exit_code == 1 then
        -- this means that  is ready to work
        return true
    end
    mesh_config.report_error(mesh_config.errors.SAFE_REBOOT_ERROR)
    return false
end

-- function mesh_config.start_firmware_upgrade_transaction()
--     -- todo(kon): do all needed checks also with the main node state etc..
--     -- Expose eupgrade folder to uhttp (this is the best place to do it since
--     --    all the files are present)
--     if mesh_config.main_node_state() ~= mesh_config.main_node_states.STARTING then
--         return {
--             code = "BAD_NODE_STATE",
--             error = "This node main state status is not starting"
--         }
--     end
--     local download_status = mesh_config.check_eupgrade_download_failed()
--     if download_status ~= eupgrade.STATUS_DOWNLOADED then
--         return {
--             code = "NO_FIRMWARE_AVAILABLE",
--             error = "No new firmware file downloaded"
--         }
--     end
--     -- this is redundant but there is an scenario when download information is
--     -- outdated and this check is necesary
--     local latest = eupgrade.is_new_version_available(true)
--     if not latest then
--         mesh_config.change_state(mesh_config.config_states.DEFAULT)
--         return {
--             code = "NO_NEW_VERSION",
--             error = "No new version is available"
--         }
--     end
--     mesh_config.set_fw_path(latest['images'][1])
--     mesh_config.share_firmware_packages()
--     -- Check if local json file exists
--     if not utils.file_exists(mesh_config.LATEST_JSON_PATH) then
--         mesh_config.report_error(mesh_config.errors.NO_LATEST_AVAILABLE)

--         return {
--             code = "NO_LOCAL_JSON",
--             error = "Local json file not found"
--         }
--     end
--     -- Check firmware packages are shared properly
--     -- we could check if the shared folder is empty or not and what files are present. Not needed imho
--     if not utils.file_exists(mesh_config.FIRMWARE_SHARED_FOLDER) then
--         return {
--             code = "NO_SHARED_FOLDER",
--             error = "Shared folder not found"
--         }
--     end
--     -- If we get here is supposed that everything is ready to be a main node
--     mesh_config.inform_download_location(latest['version'])
--     mesh_config.trigger_sheredstate_publish()
--     return {
--         code = "SUCCESS",
--         error = ""
--     }
-- end

-- Shared state functions --
----------------------------
function mesh_config.report_error(error)
    local uci = config.get_uci_cursor()
    uci:set('mesh-config', 'main', 'error', error)
    uci:save('mesh-config')
    uci:commit('mesh-config')
    mesh_config.change_state(mesh_config.config_states.ERROR)
end

-- Validate if the config has already started
function mesh_config.started()
    local status = mesh_config.state()
    return mesh_config.is_active(status)
    -- todo(javi): what happens if a mesh_config has started more than an hour ago ? should this node abort it ?
end
--- state of the transaction
function mesh_config.state()
    local uci = config.get_uci_cursor()
    local state = uci:get('mesh-config', 'main', 'transaction_state')
    if (state == nil) then
        uci:set('mesh-config', 'main', 'transaction_state', mesh_config.config_states.DEFAULT)
        uci:save('mesh-config')
        uci:commit('mesh-config')
        return mesh_config.config_states.DEFAULT
    end
    return state
end

--- returns the state of the main node
function mesh_config.main_node_state()
    local uci = config.get_uci_cursor()
    local main_node_state = uci:get('mesh-config', 'main', 'main_node')
    if (main_node_state == nil) then
        uci:set('mesh-config', 'main', 'main_node', mesh_config.main_node_states.NO)
        uci:save('mesh-config')
        uci:commit('mesh-config')
        return mesh_config.main_node_states.NO
    end
    return main_node_state
end

--- aborts current operation 
--- 
---@param silent_abortion boolean if true will not publish info in shared-state
function mesh_config.abort(silent_abortion)
    registrar("aborting.... ")
    if mesh_config.change_state(mesh_config.config_states.ABORTED) then
        local uci = config.get_uci_cursor()
        uci:set('mesh-config', 'main', 'retry_count', 0)
        uci:save('mesh-config')
        uci:commit('mesh-config')
        if silent_abortion == nil or silent_abortion == false then
            registrar("aborting.... triger publish ")

            mesh_config.trigger_shared_state_publish()
        end
        registrar("end aborting  ")

        -- todo(javi): stop and delete everything
        -- os.execute("rm ".. eupgrade.WORKDIR .."  -r >/dev/null 2>&1")
        -- kill posible safe upgrade command
        -- utils.unsafe_shell("kill $(ps| grep 'sh -c (( sleep " .. mesh_config.su_start_time_out ..
        --                       "; safe-upgrade upgrade'| awk '{print $1}')")
    end
    return {
        code = "SUCCESS",
        error = ""
    }
end

-- This line will genereate recursive dependencies like in pirania pakcage
function mesh_config.trigger_shared_state_publish()
    registrar("triger publish")
    utils.execute_daemonized("/usr/lib/lua/force_publish.sh mesh_config " .. utils.hostname() .. " transaction_state")
end

function mesh_config.change_main_node_state(newstate)
    local main_node_state = mesh_config.main_node_state()
    -- if newstate == main_node_state then return false end

    -- if newstate == mesh_config.main_node_states.STARTING and
    --     main_node_state ~= mesh_config.main_node_states.NO then
    --     return false
    -- if newstate == mesh_config.main_node_states.MAIN_NODE and main_node_state ~= mesh_config.main_node_states.STARTING then
    --     return false
    -- end
    -- todo: perfomr verifications

    local uci = config.get_uci_cursor()
    uci:set('mesh-config', 'main', 'main_node', newstate)
    uci:save('mesh-config')
    uci:commit('mesh-config')
    return true
end

-- ! changes the state of the upgrade and verifies that state transition is possible.
function mesh_config.change_state(newstate)
    local actual_state = mesh_config.state()
    -- If the state is the same just return
    if newstate == actual_state then
        return false
    end
    -- todo: perfomr checks
    -- if newstate == mesh_config.config_states.DOWNLOADING and actual_state ~= mesh_config.config_states.DEFAULT and
    --     actual_state ~= mesh_config.config_states.ERROR and actual_state ~= mesh_config.config_states.CONFIRMED and
    --     actual_state ~= mesh_config.config_states.ABORTED then
    --     return false
    -- elseif newstate == mesh_config.config_states.READY_FOR_UPGRADE and actual_state ~=
    --     mesh_config.config_states.DOWNLOADING then
    --     return false
    -- elseif newstate == mesh_config.config_states.UPGRADE_SCHEDULED and actual_state ~=
    --     mesh_config.config_states.READY_FOR_UPGRADE then
    --     return false
    -- elseif newstate == mesh_config.config_states.CONFIRMATION_PENDING and actual_state ~=
    --     mesh_config.config_states.UPGRADE_SCHEDULED then
    --     return false
    -- elseif newstate == mesh_config.config_states.CONFIRMED and actual_state ~=
    --     mesh_config.config_states.CONFIRMATION_PENDING then
    --     return false
    -- end
    -- todo(javi): verify other states and return false if it is not possible
    -- lets allow all types of state changes.
    local uci = config.get_uci_cursor()
    uci:set('mesh-config', 'main', 'transaction_state', newstate)
    uci:save('mesh-config')
    uci:commit('mesh-config')
    return true
end

-- this function will retry max_retry_conunt tymes in case of error 
-- It will only fetch new information if main node has aborted or main node is
-- ready for upgraade. Called by a shared state hook
function mesh_config.become_bot_node(main_node_upgrade_data)

    local actual_state = mesh_config.get_node_status()
    -- only abort if my main node has aborted
    if main_node_upgrade_data.transaction_state == mesh_config.config_states.ABORTED and
        main_node_upgrade_data.timestamp == actual_state.timestamp then
        registrar("main node has aborted")
        mesh_config.abort()
        return
    elseif main_node_upgrade_data.transaction_state == mesh_config.config_states.READY_FOR_APLY then
        if mesh_config.started() then
            registrar("node has already started")
            return
        else
            registrar("node has not started")

            if actual_state.timestamp == main_node_upgrade_data.timestamp and actual_state.new_config_hash ==
                main_node_upgrade_data.new_config_hash then
                main_node_upgrade_data.retry_count = actual_state.retry_count + 1
            else
                main_node_upgrade_data.retry_count = 0
            end
            if main_node_upgrade_data.retry_count < mesh_config.max_retry_conunt then
                registrar("seting upgrade info")
                if (mesh_config.set_mesh_config_info(main_node_upgrade_data, mesh_config.config_states.WORKING)) then

                    mesh_config.set_new_comunity_config(main_node_upgrade_data.lime_config)
                    if not (mesh_config.get_new_config_hash() == main_node_upgrade_data.new_config_hash) then
                        registrar("seting upgrade info")
                        mesh_config.abort()
                        return {
                            code = "NEW CONFIG FILE HASH FAILS",
                            error = "The hash of the new config file does not match the provided by main node"
                        }
                    end

                    if (mesh_config.change_main_node_state(mesh_config.main_node_states.NO) and
                        mesh_config.change_state(mesh_config.config_states.READY_FOR_APLY)) then
                        mesh_config.trigger_shared_state_publish()

                        return {
                            code = "SUCCESS",
                            error = ""
                        }
                    end
                end
            else
                registrar("max retry_count has been reached")
            end
        end
    end
    registrar("Main node is not ready for new config")

end

-- set download information for the new firmware from main node
function mesh_config.set_mesh_config_info(upgrade_data, transaction_state)
    local uci = config.get_uci_cursor()
    -- todo (javi): perform aditional checks
    -- then
    if (mesh_config.change_state(transaction_state)) then
        uci:set('mesh-config', 'main', "mesh_config")
        uci:set('mesh-config', 'main', 'new_config_hash', upgrade_data.new_config_hash)
        uci:set('mesh-config', 'main', 'safe_restart_start_time_out', upgrade_data.safe_restart_start_time_out)
        -- timestamp is used as id ... every node must have the same one
        uci:set('mesh-config', 'main', 'timestamp', upgrade_data.timestamp)
        uci:set('mesh-config', 'main', 'retry_count', upgrade_data.retry_count)
        uci:save('mesh-config')
        uci:commit('mesh-config')
        return true
    else
        return false
    end
    -- else
    --     return false
    -- end
end

function mesh_config.toboolean(str)
    if str == "true" then
        return true
    end
    return false
end

function mesh_config.start_safe_reboot(su_start_delay, su_confirm_timeout)
    local status = mesh_config.get_node_status()

    mesh_config.safe_restart_start_time_out = su_start_delay or status.safe_restart_start_time_out
    mesh_config.safe_restart_confirm_timeout = su_confirm_timeout or status.safe_restart_confirm_timeout

    if not mesh_config.check_safereboot_is_working() then
        mesh_config.report_error(mesh_config.errors.SAFE_REBOOT_ERROR)
        return {
            code = "NOT_ABLE_TO_SAFE_REBOOT",
            error = "safereboot is not working"
        }
    end
    if mesh_config.state() == mesh_config.config_states.READY_FOR_APLY then
        if utils.file_exists(mesh_config.new_lime_community_path) then
            utils.unsafe_shell("tar -czf /overlay/upper/.etc.last-good.tgz -C /overlay/upper/etc/ . >/dev/null 2>&1")
            utils.unsafe_shell("cp " .. mesh_config.new_lime_community_path .. " " .. mesh_config.lime_community_path ..
                                   ">/dev/null 2>&1")
            utils.unsafe_shell("lime-config >/dev/null 2>&1")
            mesh_config.change_state(mesh_config.config_states.RESTART_SCHEDULED)
            mesh_config.safe_restart_start_mark = os.time()
            local uci = config.get_uci_cursor()
            uci:set('mesh-config', 'main', 'safe_restart_start_mark', mesh_config.safe_restart_start_mark)
            uci:set('mesh-config', 'main', 'safe_restart_start_time_out', mesh_config.safe_restart_start_time_out)
            uci:set('mesh-config', 'main', 'safe_restart_confirm_timeout', mesh_config.safe_restart_confirm_timeout)
            uci:save('mesh-config')
            uci:commit('mesh-config')

            mesh_config.trigger_shared_state_publish()
            -- upgrade must be executed after a safe upgrade timeout to enable all nodes to start_safe_upgrade
            utils.execute_daemonized("sleep " .. mesh_config.safe_restart_start_time_out .. "; safe-reboot now -f " ..
                                         mesh_config.safe_restart_confirm_timeout .. " >/dev/null 2>&1")
            return {
                code = "SUCCESS",
                error = "",
                su_start_time_out = mesh_config.safe_restart_start_time_out,
                su_confirm_timeout = mesh_config.safe_restart_confirm_timeout

            }
        else
            mesh_config.report_error(mesh_config.errors.FW_FILE_NOT_FOUND)
            return {
                code = "NOT_ABLE_TO_START",
                error = "No new config available"
            }
        end
    else
        return {
            code = "NOT_READY_FOR_RESTART",
            error = "Not READY FOR RESTART"
        }
    end
end

function mesh_config.confirm()
    if mesh_config.get_node_status().transaction_state == mesh_config.config_states.CONFIRMATION_PENDING then
        local shell_output = utils.unsafe_shell("safe-reboot cancel >/dev/null 2>&1")
        if mesh_config.change_state(mesh_config.config_states.CONFIRMED) then
            mesh_config.trigger_shared_state_publish()
            return {
                code = "SUCCESS"
            }
        end

    end
    return {
        code = "NOT_READY_TO_CONFIRM",
        error = "NOT_READY_TO_CONFIRM"
    }
end

-- An active node is involved in a transaction 
function mesh_config.is_active(status)
    if status == mesh_config.config_states.DEFAULT or -- if an error has ocurred then there is no transaction
    status == mesh_config.config_states.ERROR or status == mesh_config.config_states.ABORTED or status ==
        mesh_config.config_states.CONFIRMED then
        return false
    end
    return true
end

function mesh_config.verify_network_consistency(network_state)
    utils.unsafe_shell('logger -p daemon.info -t "async: mesh_config" "verifying" ')
    local actual_status = mesh_config.get_node_status()

    local main_node = ""
    for node, s_s_data in pairs(network_state) do
        -- if any node has started an upgrade process and start one too?
        -- only fetch the info from the master node publication?
        if s_s_data.main_node == mesh_config.main_node_states.MAIN_NODE then
            if mesh_config.is_active(s_s_data.transaction_state) then
                if main_node == "" then
                    main_node = node
                    utils.unsafe_shell('logger -p daemon.info -t "async: mesh_config" "there is one main node ' ..
                                           main_node .. ' , ok"')
                else
                    utils.unsafe_shell(
                        'logger -p daemon.info -t "async: mesh_config" "there are two active main nodes ' .. node ..
                            ' and ' .. main_node .. ' , aborting"')
                    mesh_config.abort()
                    return
                end
            else
                -- there is an inactive main node 
                utils.unsafe_shell('logger -p daemon.info -t "async: mesh_config" "there is an inactive main node ' ..
                                       node .. ' "')
                if mesh_config.started() and network_state[node].timestamp == actual_status.timestamp then
                    -- i should abort too 
                    utils.unsafe_shell(
                        'logger -p daemon.info -t "async: mesh_config" "i should abort we share timestamps"')
                    mesh_config.abort()
                    utils.unsafe_shell(
                        'logger -p daemon.info -t "async: mesh_config" "i should not abort dont share timestamps"')
                end

            end
        end
    end
    -- there is only one main node
    if main_node ~= "" then
        if not mesh_config.started() and main_node ~= utils.hostname() then
            utils.unsafe_shell('logger -p daemon.info -t "async: mesh_config" "' .. utils.hostname() .. '  become ' ..
                                   main_node .. '\'s _bot_node "')
            mesh_config.become_bot_node(network_state[main_node])
        else
            utils.unsafe_shell('logger -p daemon.info -t "async: mesh_config" "already started a transaction "')
            if network_state[main_node].timestamp == actual_status.timestamp then
                -- "ok"
                utils.unsafe_shell(
                    'logger -p daemon.info -t "async: mesh_config" "main node and bot node timestamp are equal"')
            else
                -- I am in a transaction and main node is in an other
                utils.unsafe_shell(
                    'logger -p daemon.info -t "async: mesh_config" "main node and bot node timestamp are different"')
                mesh_config.abort(true)
                -- this will lead to a doble write to shared state.
                utils.unsafe_shell(
                    'logger -p daemon.info -t "async: mesh_config" "main node and bot node timestamp are different"')
                utils.unsafe_shell('logger -p daemon.info -t "async: mesh_config" " become_bot_node "')
                mesh_config.become_bot_node(network_state[main_node])
            end
        end
    end
end

return mesh_config
