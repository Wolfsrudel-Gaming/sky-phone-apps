-- Donations: the viewer's bank account is charged, the platform keeps its fee,
-- taxes go to the state account and the rest is paid to the character that owns
-- the streamer account. Offline owners are paid the next time they load in.

SnitchDonations = {}

local cooldowns = {}
local busy = {}
local payout_locks = {}

local function with_payout_lock(identifier, callback)
    local waited = 0
    while payout_locks[identifier] do
        if waited >= 10000 then
            SnitchUtil.Log('error', 'Payout lock for %s timed out.', identifier)
            return
        end
        Wait(50)
        waited = waited + 50
    end
    payout_locks[identifier] = true
    local success, error_message = pcall(callback)
    payout_locks[identifier] = nil
    if not success then
        SnitchUtil.Log('error', 'Payout for %s failed: %s', identifier, tostring(error_message))
    end
end

local function record_payout_transaction(identifier, amount, reason, source)
    SnitchBank.RecordTransaction(identifier, {
        sender_identifier = 'snitch',
        sender_name = 'Snitch',
        receiver_identifier = identifier,
        receiver_name = SnitchBank.GetName(source) or identifier,
        value = amount,
        type = 'deposit',
        reason = reason,
    }, source)
end

---Pays one donation right away if the owner is online. Otherwise it stays pending.
local function pay_donation(identifier, donation_id, net, reason)
    with_payout_lock(identifier, function()
        if not SnitchBank.IsOnline(identifier) then
            return
        end
        local claimed = MySQL.update.await(
            'UPDATE `snitch_donations` SET `paid_out` = 1 WHERE `id` = ? AND `paid_out` = 0',
            { donation_id }
        )
        if claimed ~= 1 then
            return
        end
        if net <= 0 then
            return
        end
        local paid, owner_source = SnitchBank.DepositToIdentifier(identifier, net, reason)
        if not paid then
            MySQL.update.await('UPDATE `snitch_donations` SET `paid_out` = 0 WHERE `id` = ?', { donation_id })
            return
        end
        record_payout_transaction(identifier, net, reason, owner_source)
    end)
end

---Pays every pending donation of a character in one booking.
function SnitchDonations.PayPending(identifier)
    with_payout_lock(identifier, function()
        local rows = MySQL.query.await(
            'SELECT `id`, `net` FROM `snitch_donations` WHERE `payout_identifier` = ? AND `paid_out` = 0',
            { identifier }
        )
        if not rows or #rows == 0 then
            return
        end

        local ids, total = {}, 0
        for index = 1, #rows do
            ids[index] = rows[index].id
            total = total + rows[index].net
        end
        local placeholders = ('?,'):rep(#ids):sub(1, -2)
        local claimed = MySQL.update.await(
            ('UPDATE `snitch_donations` SET `paid_out` = 1 WHERE `paid_out` = 0 AND `id` IN (%s)'):format(placeholders),
            ids
        )
        if claimed ~= #ids then
            SnitchUtil.Log('error', 'Pending payout for %s claimed %s of %s rows; skipped.', identifier, claimed, #ids)
            return
        end
        if total <= 0 then
            return
        end

        local reason = 'Snitch: Auszahlung offener Spenden'
        local paid, owner_source = SnitchBank.DepositToIdentifier(identifier, total, reason)
        if not paid then
            MySQL.update.await(
                ('UPDATE `snitch_donations` SET `paid_out` = 0 WHERE `id` IN (%s)'):format(placeholders),
                ids
            )
            return
        end
        record_payout_transaction(identifier, total, reason, owner_source)
        SnitchUtil.Log('info', 'Paid %s pending donations (%s) to %s.', #ids, total, identifier)
    end)
end

local function process_donation(source, account, stream, amount, message)
    local streamer = SnitchAccounts.Load(stream.accountId)
    if not streamer then
        return SnitchUtil.Fail('stream_not_found')
    end
    local donor_identifier = SnitchBank.GetIdentifier(source)
    if not donor_identifier then
        return SnitchUtil.Fail('player_unavailable')
    end
    if donor_identifier == streamer.owner_identifier then
        return SnitchUtil.Fail('own_stream')
    end

    local split = SnitchSplit.FromConfig(amount)
    local withdrawn, withdraw_error = SnitchBank.Withdraw(
        source,
        split.gross,
        ('Snitch: Spende an @%s'):format(streamer.username)
    )
    if not withdrawn then
        return SnitchUtil.Fail(withdraw_error)
    end
    cooldowns[source] = os.time()

    local inserted, donation_id = pcall(MySQL.insert.await,
        'INSERT INTO `snitch_donations` (`stream_id`, `streamer_account_id`, `donor_account_id`, `donor_identifier`, '
            .. '`payout_identifier`, `gross`, `fee`, `tax`, `net`, `message`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        {
            stream.id, streamer.id, account.id, donor_identifier, streamer.owner_identifier,
            split.gross, split.fee, split.tax, split.net, message,
        }
    )
    if not inserted or not donation_id then
        SnitchBank.Deposit(source, split.gross, 'Snitch: Rueckbuchung')
        return SnitchUtil.Fail('server_error')
    end

    SnitchBank.RecordTransaction(donor_identifier, {
        sender_identifier = donor_identifier,
        sender_name = SnitchBank.GetName(source) or account.username,
        receiver_identifier = 'snitch',
        receiver_name = 'Snitch',
        value = split.gross,
        type = 'withdraw',
        reason = ('Spende an @%s'):format(streamer.username),
    }, source)

    SnitchBank.DepositToSociety(Config.Donations.StateAccount, split.tax)
    if Config.Donations.PlatformAccount then
        SnitchBank.DepositToSociety(Config.Donations.PlatformAccount, split.fee)
    end

    -- The stream may have ended while the donation was written; the money still counts.
    local live_stream = SnitchStreams.Get(stream.id)
    if live_stream then
        SnitchStreams.RecordDonation(live_stream, SnitchAccounts.PublicProfile(account), split, message)
    end

    pay_donation(
        streamer.owner_identifier,
        donation_id,
        split.net,
        ('Snitch: Spende von @%s'):format(account.username)
    )

    SnitchUtil.Log('info', 'Donation %s: @%s -> @%s gross %s fee %s tax %s net %s.',
        donation_id, account.username, streamer.username, split.gross, split.fee, split.tax, split.net)
    return SnitchUtil.Ok({ split = split, balance = SnitchBank.GetBalance(source) })
end

SnitchRpc.Register('donate', { perMinute = 20 }, function(source, payload)
    local account, error_code = SnitchAccounts.GetForSource(source)
    if not account then
        return SnitchUtil.Fail(error_code)
    end
    if type(payload) ~= 'table' then
        return SnitchUtil.Fail('invalid_request')
    end

    local donations = Config.Donations
    local amount = payload.amount
    if not SnitchUtil.IsInteger(amount) or amount < donations.Minimum or amount > donations.Maximum then
        return SnitchUtil.Fail('invalid_amount')
    end
    amount = math.floor(amount)

    local message = ''
    if payload.message ~= nil then
        local cleaned, message_error = SnitchUtil.CleanText(payload.message, donations.MessageMaxLength, true)
        if not cleaned then
            return SnitchUtil.Fail(message_error)
        end
        message = cleaned
    end

    local membership = SnitchStreams.GetMembership(source)
    local stream = membership and membership.role == 'viewer'
        and membership.streamId == payload.streamId
        and SnitchStreams.Get(membership.streamId)
    if not stream then
        return SnitchUtil.Fail('not_in_stream')
    end
    if os.time() - (cooldowns[source] or 0) < donations.CooldownSeconds then
        return SnitchUtil.Fail('cooldown')
    end
    if busy[source] then
        return SnitchUtil.Fail('busy')
    end

    busy[source] = true
    local success, result = pcall(process_donation, source, account, stream, amount, message)
    busy[source] = nil
    if not success then
        SnitchUtil.Log('error', 'Donation by %s failed: %s', source, tostring(result))
        return SnitchUtil.Fail('server_error')
    end
    return result
end)

AddEventHandler('esx:playerLoaded', function(_, player)
    if type(player) == 'table' and player.identifier then
        SnitchDonations.PayPending(player.identifier)
    end
end)

SnitchDatabase.OnReady(function()
    for _, identifier in ipairs(SnitchBank.GetOnlineIdentifiers()) do
        SnitchDonations.PayPending(identifier)
    end
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
    busy[source] = nil
end)
