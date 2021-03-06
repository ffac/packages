#!/usr/bin/lua

site = require("gluon.site")
local uci = require("simple-uci").cursor()

--- wrapper for calling systemcommands
function cmd(_command)
        local f = io.popen(_command)
        local l = f:read("*a")
        f:close()
        return l
end

--- first of all, get the right 2.4GHz wifi interface
local interface24 = false
local interface50 = false
if uci:get('wireless', 'radio0', 'hwmode') then
        chanR0 = tonumber(uci:get('wireless', 'radio0', 'channel'))
        if chanR0 < 16 then
                interface24 = 'radio0'
                chanR1 = tonumber(uci:get('wireless', 'radio1', 'channel'))
                if chanR1 then
                        if chanR1 > 15 then
                               interface50 = 'radio1'
                        end
                end
        elseif chanR0 > 15  then
                interface50 = 'radio0'
                chanR1 = tonumber(uci:get('wireless', 'radio1', 'channel'))
                if chanR1 then
                        if chanR1 < 16 then
                                interface24 = 'radio1'
                        end
                end
        else
                os.exit(0) -- something went wrong
        end
end

--- determine country according to 5G
if interface50 then
        channel50 = uci:get('wireless', interface50, 'channel')
        if channel50 == '32' or channel50 == '68' or channel50 == '169' or channel50 == '173' then
                country = 'DE'
        elseif channel50 == '138' or channel50 == '142' or channel50 == '144'  then
                country = 'US'
        else
                country = 'TW'
        end
end

if interface24 then
        channel24 = uci:get('wireless', interface24, 'channel')
        if channel24 == '13' then
                country = 'JP'
        elseif channel24 == '12' then
                country = 'DE'
        else
                country = 'TW'
        end
end

if interface24 and interface50 then
        if channel24 == '13' then
                if channel50 == '32' or channel50 == '34' or channel50 == '68' or channel50 == '96' or channel50 == '138' or channel50 == '142' or channel50 == '144' or channel50 == '149' or channel50 == '151' or channel50 == '153' or channel50 == '155' or channel50 == '157' or channel50 == '159' or channel50 == '161' or channel50 == '165' or channel50 == '169' or channel50 == '173' then
                        country = 'DE'
                end
        end
end

--- 2.4G
--- set values (1st pass)
if interface24 then
        uci:set('wireless', interface24, 'country', country)
        uci:set('wireless', interface24, 'htmode', 'HT20')
        uci:save('wireless')
        uci:commit('wireless')
        t = cmd('sleep 2')
        t = cmd('/sbin/wifi')
        t = cmd('sleep 10')
--- get maximum available power and step
        t = cmd('iwinfo ' .. interface24 .. ' txpowerlist | tail -n 2 | head -n 1 | awk \'{print $1}\'')
        maximumTxPowerDb = string.gsub(t, "\n", "")
        maximumTxPowerDb = tonumber(maximumTxPowerDb)

        if maximumTxPowerDb < 30 then
                t = cmd('iwinfo ' .. interface24 .. ' txpowerlist | wc -l')
                maximumTxPower = string.gsub(t, "\n", "")
                maximumTxPower = tonumber(maximumTxPower)-1
        else
                t = cmd('iwinfo ' .. interface24 .. ' txpowerlist | grep -n "19 dBm" | cut -f1 -d\':\'')
                maximumTxPower = string.gsub(t, "\n", "")
                maximumTxPower = tonumber(maximumTxPower)-1
        end
--- set values (2nd pass)
        uci:set('wireless', interface24, 'txpower', maximumTxPower)
        uci:save('wireless')
        uci:commit('wireless')
end

--- 5G
if interface50 then
        if interface50 == 'radio0' or interface50 == 'radio1' then
                uci:set('wireless', interface50, 'country', country)
                VHT = cmd('iwinfo ' .. interface50 .. ' htmodelist|xargs -n 1|sort|tail -n1')
                if string.match(VHT, 'HT') then
                        uci:set('wireless', interface50, 'htmode', VHT)
                end
                --- set values (1st pass)
                uci:save('wireless')
                uci:commit('wireless')
                t = cmd('sleep 2')
                t = cmd('/sbin/wifi')
                t = cmd('sleep 10')
                --- get maximum available power and step
                t = cmd('iwinfo ' .. interface50 .. ' txpowerlist | tail -n 2 | head -n 1 | awk \'{print $1}\'')
                maximumTxPowerDb = string.gsub(t, "\n", "")
                maximumTxPowerDb = tonumber(maximumTxPowerDb)
                if maximumTxPowerDb < 30 then
                        t = cmd('iwinfo ' .. interface50 .. ' txpowerlist | wc -l')
                        maximumTxPower = string.gsub(t, "\n", "")
                        maximumTxPower = tonumber(maximumTxPower)-1
                else
                        t = cmd('iwinfo ' .. interface50 .. ' txpowerlist | grep -n "19 dBm" | cut -f1 -d\':\'')
                        maximumTxPower = string.gsub(t, "\n", "")
                        maximumTxPower = tonumber(maximumTxPower)-1
                end
                --- set values (2nd pass)
                uci:set('wireless', interface50, 'txpower', maximumTxPower)
                uci:save('wireless')
                uci:commit('wireless')
        end
        t = cmd('sleep 2')
        t = cmd('/sbin/wifi')
        t = cmd('sleep 2')
end
