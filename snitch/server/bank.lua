-- ESX player money and okokBanking society accounts.
-- Personal money is the ESX 'bank' account, which okokBanking shows as the
-- private account. Taxes and the optional platform fee go to okokBanking
-- societies through its documented server exports.

SnitchBank = {}

local ESX = exports.es_extended:getSharedObject()
local BANK_RESOURCE = 'okokBanking'

function SnitchBank.GetIdentifier(source)
    local player = ESX.GetPlayerFromId(source)
    return player and player.identifier or nil
end

function SnitchBank.GetName(source)
    local player = ESX.GetPlayerFromId(source)
    return player and player.getName() or nil
end

function SnitchBank.IsOnline(identifier)
    return ESX.GetPlayerFromIdentifier(identifier) ~= nil
end

function SnitchBank.GetBalance(source)
    local player = ESX.GetPlayerFromId(source)
    local account = player and player.getAccount('bank')
    return account and account.money or 0
end

---Removes money from the player's bank account if the balance covers it.
function SnitchBank.Withdraw(source, amount, reason)
    local player = ESX.GetPlayerFromId(source)
    if not player then
        return false, 'player_unavailable'
    end
    local account = player.getAccount('bank')
    if not account or account.money < amount then
        return false, 'insufficient_funds'
    end
    player.removeAccountMoney('bank', amount, reason)
    return true
end

function SnitchBank.Deposit(source, amount, reason)
    local player = ESX.GetPlayerFromId(source)
    if not player then
        return false
    end
    player.addAccountMoney('bank', amount, reason)
    return true
end

---Pays an online character by identifier. Returns false when they are offline.
function SnitchBank.DepositToIdentifier(identifier, amount, reason)
    local player = ESX.GetPlayerFromIdentifier(identifier)
    if not player then
        return false
    end
    player.addAccountMoney('bank', amount, reason)
    return true, player.source
end

function SnitchBank.GetOnlineIdentifiers()
    local identifiers = {}
    for _, player in pairs(ESX.GetExtendedPlayers()) do
        identifiers[#identifiers + 1] = player.identifier
    end
    return identifiers
end

local function bank_available()
    return GetResourceState(BANK_RESOURCE) == 'started'
end

---Adds money to an okokBanking society account.
function SnitchBank.DepositToSociety(society, amount)
    if amount <= 0 then
        return true
    end
    if not bank_available() then
        SnitchUtil.Log('error', 'okokBanking is not started; %s for society %s was not booked.', amount, society)
        return false
    end
    local success, error_message = pcall(function()
        exports[BANK_RESOURCE]:AddMoney(society, amount)
    end)
    if not success then
        SnitchUtil.Log('error', 'okokBanking AddMoney(%s, %s) failed: %s', society, amount, tostring(error_message))
    end
    return success
end

---Writes an entry into the okokBanking transaction history (V2 export).
function SnitchBank.RecordTransaction(identifier, transaction, source)
    if not Config.Donations.BankTransactions or not bank_available() then
        return
    end
    local success, error_message = pcall(function()
        exports[BANK_RESOURCE]:AddTransaction(identifier, transaction, source)
    end)
    if not success then
        SnitchUtil.Log('debug', 'okokBanking AddTransaction failed: %s', tostring(error_message))
    end
end

local function check_society(society, purpose)
    if not society then
        return
    end
    local success, account = pcall(function()
        return exports[BANK_RESOURCE]:GetAccount(society)
    end)
    if not success or account == nil or account == false then
        SnitchUtil.Log(
            'warn',
            'okokBanking society "%s" (%s) was not found. Create it or change Config.Donations.',
            society,
            purpose
        )
    end
end

CreateThread(function()
    while GetResourceState(BANK_RESOURCE) == 'starting' do
        Wait(500)
    end
    if not bank_available() then
        SnitchUtil.Log('warn', 'okokBanking is not running. Taxes and platform fees cannot be booked.')
        return
    end
    check_society(Config.Donations.StateAccount, 'taxes')
    check_society(Config.Donations.PlatformAccount or nil, 'platform fee')
end)
