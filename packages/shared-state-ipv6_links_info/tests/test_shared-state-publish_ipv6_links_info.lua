local utils = require "lime.utils"
local node_status = require 'lime.node_status'
local iwinfo = require('iwinfo')



package.path = package.path .. ";packages/shared-state-ipv6_links_info/files/usr/bin/?;;"
require ("shared-state-publish_ipv6_links_info")

local clients =[[fe80::c24a:ff:fefc:3abd%br-lan
fe80::a2f3:c1ff:fe46:2895%br-lan
fe80::916c:59b5:275c:1f85%br-lan
fe80::6afb:b90d:7651:f8d6%br-lan
fe80::16cc:20ff:feda:4eaf%br-lan]]

local routers =[[fe80::c24a:ff:fefc:3abd%br-lan
fe80::a2f3:c1ff:fe46:2895%br-lan
fe80::16cc:20ff:feda:4eaf%br-lan]]

it('a simple test to get links info and assert requiered fields are present', function()
    stub(utils, "unsafe_shell", function (cmd)

        if cmd == "ping -i 0.1 -c 2 ff02::2%br-lan 2> /dev/null | awk '{if ($3 == \"from\") print substr($4, 1, length($4)-1)}'| sort -u -r" then
            return routers
        elseif cmd == "ip -6 address show br-lan | awk '{if ($1 == \"inet6\") print $2}' | grep fe80 | awk -F/ '{print $1}'" then
            return "fe80::c24a:ff:fefc:3abd"
        elseif cmd == "ping -i 0.1 -c 2 ff02::1%br-lan 2> /dev/null | awk '{if ($3 == \"from\") print substr($4, 1, length($4)-1)}'| sort -u -r " then
            return clients
        end
        return nil
    end)

    local links_info = {}

    links_info = get_neighbours()
    utils.printJson(links_info)
    assert.is.equal("fe80::a2f3:c1ff:fe46:2895", links_info.routers[1].dst_ip)
    assert.is.equal("fe80::c24a:ff:fefc:3abd", links_info.routers[1].src_ip)
    assert.is.equal("fe80::916c:59b5:275c:1f85", links_info.clients[1].dst_ip)
    assert.is.equal("fe80::c24a:ff:fefc:3abd", links_info.clients[1].src_ip)
end)
