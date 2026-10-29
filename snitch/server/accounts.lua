-- Snitch accounts. A login belongs to the phone (IMEI) it was made on, so
-- whoever holds that phone stays logged in. Payouts always go to the character
-- that created the account, never to whoever is currently logged in.

SnitchAccounts = {}

local DEVICE_CACHE_MS = 15000
local AVATAR_COLORS = {
    sunset = true, ocean = true, lime = true, grape = true, ember = true, steel = true,
}

local SESSION_CACHE_MS = 15000

local accounts_by_id = {}
local device_cache = {}
local session_cache = {}
local login_limiter = SnitchUtil.NewLimiter(Config.Accounts.LoginAttemptsPerMinute, 60)

local function to_profile(account, source)
    return {
        id = account.id,
        username = account.username,
        email = account.email,
        avatarColor = account.avatar_color,
        bio = account.bio,
        createdAt = account.created_at,
        isPayoutOwner = source ~= nil and SnitchBank.GetIdentifier(source) == account.owner_identifier,
    }
end

---Public data other players may see.
function SnitchAccounts.PublicProfile(account)
    return {
        id = account.id,
        username = account.username,
        avatarColor = account.avatar_color,
    }
end

local function load_account(account_id)
    local cached = accounts_by_id[account_id]
    if cached then
        return cached
    end
    local row = MySQL.single.await(
        'SELECT `id`, `username`, `email`, `owner_identifier`, `avatar_color`, `bio`, `banned`, '
            .. 'UNIX_TIMESTAMP(`created_at`) AS `created_at` FROM `snitch_accounts` WHERE `id` = ?',
        { account_id }
    )
    if not row then
        return nil
    end
    row.banned = row.banned == 1 or row.banned == true
    accounts_by_id[account_id] = row
    return row
end

SnitchAccounts.Load = load_account

---Returns the IMEI of the phone the player is currently using.
local function get_device_imei(source)
    local cached = device_cache[source]
    local now = GetGameTimer()
    if cached and now - cached.checked < DEVICE_CACHE_MS then
        return cached.imei
    end

    local success, identity = pcall(function()
        return exports.sky_phone:GetOnlineDeviceBySource(source)
    end)
    local imei = success and type(identity) == 'table' and identity.imei or nil
    if type(imei) ~= 'string' then
        imei = nil
    end
    device_cache[source] = { checked = now, imei = imei }
    return imei
end

---Returns the logged-in account for the phone the player holds, or nil and an error code.
function SnitchAccounts.GetForSource(source)
    local imei = get_device_imei(source)
    if not imei then
        return nil, 'no_phone'
    end
    local now = GetGameTimer()
    local cached = session_cache[imei]
    local account_id
    if cached and now - cached.checked < SESSION_CACHE_MS then
        account_id = cached.accountId
    else
        account_id = MySQL.scalar.await(
            'SELECT `account_id` FROM `snitch_sessions` WHERE `imei` = ?',
            { imei }
        ) or false
        session_cache[imei] = { checked = now, accountId = account_id }
    end
    if not account_id then
        return nil, 'not_logged_in'
    end
    local account = load_account(account_id)
    if not account then
        return nil, 'not_logged_in'
    end
    if account.banned then
        return nil, 'account_banned'
    end
    return account, nil, imei
end

local function create_session(imei, account_id)
    MySQL.query.await(
        'REPLACE INTO `snitch_sessions` (`imei`, `account_id`) VALUES (?, ?)',
        { imei, account_id }
    )
    session_cache[imei] = nil
end

local function forget_sessions(account_id)
    for imei, cached in pairs(session_cache) do
        if cached.accountId == account_id then
            session_cache[imei] = nil
        end
    end
end

local function validate_username(value)
    if type(value) ~= 'string' then
        return nil
    end
    local accounts = Config.Accounts
    if #value < accounts.UsernameMinLength or #value > accounts.UsernameMaxLength then
        return nil
    end
    if not value:match('^[%w_]+$') then
        return nil
    end
    return value
end

local function validate_email(value)
    if type(value) ~= 'string' or #value > 120 then
        return nil
    end
    local email = value:lower():match('^%s*(.-)%s*$')
    if not email:match('^[%w%._%%+%-]+@[%w%.%-]+%.%a%a+$') or email:find('..', 1, true) then
        return nil
    end
    return email
end

local function validate_password(value)
    if type(value) ~= 'string' then
        return nil
    end
    local length = utf8.len(value)
    if not length or length < Config.Accounts.PasswordMinLength or length > Config.Accounts.PasswordMaxLength then
        return nil
    end
    return value
end

SnitchRpc.Register('auth:status', nil, function(source)
    local account, error_code = SnitchAccounts.GetForSource(source)
    if not account then
        if error_code == 'not_logged_in' then
            return SnitchUtil.Ok({ account = false })
        end
        return SnitchUtil.Fail(error_code)
    end
    return SnitchUtil.Ok({ account = to_profile(account, source) })
end)

SnitchRpc.Register('auth:register', { perMinute = 4 }, function(source, payload)
    if type(payload) ~= 'table' then
        return SnitchUtil.Fail('invalid_request')
    end
    local username = validate_username(payload.username)
    if not username then
        return SnitchUtil.Fail('invalid_username')
    end
    local email = validate_email(payload.email)
    if not email then
        return SnitchUtil.Fail('invalid_email')
    end
    local password = validate_password(payload.password)
    if not password then
        return SnitchUtil.Fail('invalid_password')
    end

    local imei = get_device_imei(source)
    if not imei then
        return SnitchUtil.Fail('no_phone')
    end
    local identifier = SnitchBank.GetIdentifier(source)
    if not identifier then
        return SnitchUtil.Fail('player_unavailable')
    end

    local owned = MySQL.scalar.await(
        'SELECT COUNT(*) FROM `snitch_accounts` WHERE `owner_identifier` = ?',
        { identifier }
    )
    if (owned or 0) >= Config.Accounts.MaxAccountsPerCharacter then
        return SnitchUtil.Fail('account_limit')
    end

    local taken = MySQL.single.await(
        'SELECT `username_key` = ? AS `username_taken`, `email` = ? AS `email_taken` '
            .. 'FROM `snitch_accounts` WHERE `username_key` = ? OR `email` = ? LIMIT 1',
        { username:lower(), email, username:lower(), email }
    )
    if taken then
        return SnitchUtil.Fail((taken.username_taken == 1) and 'username_taken' or 'email_taken')
    end

    local password_hash = SnitchUtil.AwaitJs('hashPassword', 5000, password)
    if type(password_hash) ~= 'string' then
        return SnitchUtil.Fail('server_error')
    end

    local colors = {}
    for color in pairs(AVATAR_COLORS) do
        colors[#colors + 1] = color
    end
    table.sort(colors)

    local success, account_id = pcall(MySQL.insert.await,
        'INSERT INTO `snitch_accounts` (`username`, `username_key`, `email`, `password_hash`, '
            .. '`owner_identifier`, `avatar_color`) VALUES (?, ?, ?, ?, ?, ?)',
        { username, username:lower(), email, password_hash, identifier, colors[math.random(#colors)] }
    )
    if not success or not account_id then
        -- A concurrent registration can win the unique key between the check and the insert.
        return SnitchUtil.Fail('username_taken')
    end

    create_session(imei, account_id)
    local account = load_account(account_id)
    SnitchUtil.Log('info', 'Account @%s (%s) registered by %s.', username, account_id, identifier)
    return SnitchUtil.Ok({ account = to_profile(account, source) })
end)

SnitchRpc.Register('auth:login', nil, function(source, payload)
    if type(payload) ~= 'table' then
        return SnitchUtil.Fail('invalid_request')
    end
    if not login_limiter.Allow(source) then
        return SnitchUtil.Fail('rate_limited')
    end
    local email = validate_email(payload.email)
    if not email or type(payload.password) ~= 'string' or #payload.password > 256 then
        return SnitchUtil.Fail('invalid_credentials')
    end
    local imei = get_device_imei(source)
    if not imei then
        return SnitchUtil.Fail('no_phone')
    end

    local row = MySQL.single.await(
        'SELECT `id`, `password_hash`, `banned` FROM `snitch_accounts` WHERE `email` = ?',
        { email }
    )
    -- Hash even for unknown addresses so response time does not reveal accounts.
    local encoded = row and row.password_hash or 'scrypt$16384$8$1$AAAAAAAAAAAAAAAAAAAAAA==$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
    local valid = SnitchUtil.AwaitJs('verifyPassword', 5000, payload.password, encoded)
    if not row or valid ~= true then
        return SnitchUtil.Fail('invalid_credentials')
    end
    if row.banned == 1 or row.banned == true then
        return SnitchUtil.Fail('account_banned')
    end

    create_session(imei, row.id)
    return SnitchUtil.Ok({ account = to_profile(load_account(row.id), source) })
end)

SnitchRpc.Register('auth:logout', nil, function(source, payload)
    local account, _, imei = SnitchAccounts.GetForSource(source)
    if not account then
        return SnitchUtil.Ok({})
    end
    if type(payload) == 'table' and payload.everywhere == true then
        SnitchStreams.EndForAccount(account.id, 'logout')
        MySQL.query.await('DELETE FROM `snitch_sessions` WHERE `account_id` = ?', { account.id })
        forget_sessions(account.id)
    else
        SnitchStreams.LeaveAll(source, 'logout')
        MySQL.query.await('DELETE FROM `snitch_sessions` WHERE `imei` = ?', { imei })
        session_cache[imei] = nil
    end
    return SnitchUtil.Ok({})
end)

SnitchRpc.Register('profile:update', { perMinute = 10 }, function(source, payload)
    local account, error_code = SnitchAccounts.GetForSource(source)
    if not account then
        return SnitchUtil.Fail(error_code)
    end
    if type(payload) ~= 'table' then
        return SnitchUtil.Fail('invalid_request')
    end

    local color = payload.avatarColor
    if color ~= nil and not AVATAR_COLORS[color] then
        return SnitchUtil.Fail('invalid_color')
    end
    local bio = account.bio
    if payload.bio ~= nil then
        local cleaned = SnitchUtil.CleanText(payload.bio, 160, true)
        if not cleaned then
            return SnitchUtil.Fail('invalid_bio')
        end
        bio = cleaned
    end

    color = color or account.avatar_color
    MySQL.update.await(
        'UPDATE `snitch_accounts` SET `avatar_color` = ?, `bio` = ? WHERE `id` = ?',
        { color, bio, account.id }
    )
    account.avatar_color = color
    account.bio = bio
    return SnitchUtil.Ok({ account = to_profile(account, source) })
end)

AddEventHandler('playerDropped', function()
    device_cache[source] = nil
    login_limiter.Clear(source)
end)
