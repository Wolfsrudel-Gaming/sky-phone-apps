-- Earnings dashboard for streamers.

-- SUM/COUNT come back as DECIMAL/BIGINT, which the MySQL driver may deliver as strings.
local function numbers(row, fields)
    if not row then
        return row
    end
    for index = 1, #fields do
        local field = fields[index]
        row[field] = tonumber(row[field]) or 0
    end
    return row
end

local function numbers_all(rows, fields)
    rows = rows or {}
    for index = 1, #rows do
        numbers(rows[index], fields)
    end
    return rows
end

SnitchRpc.Register('earnings:summary', { perMinute = 20 }, function(source)
    local account, error_code = SnitchAccounts.GetForSource(source)
    if not account then
        return SnitchUtil.Fail(error_code)
    end

    local totals = MySQL.single.await([[
        SELECT COUNT(*) AS `donations`,
               COALESCE(SUM(`gross`), 0) AS `gross`,
               COALESCE(SUM(`fee`), 0) AS `fee`,
               COALESCE(SUM(`tax`), 0) AS `tax`,
               COALESCE(SUM(`net`), 0) AS `net`,
               COALESCE(SUM(CASE WHEN `paid_out` = 0 THEN `net` ELSE 0 END), 0) AS `pending`
        FROM `snitch_donations` WHERE `streamer_account_id` = ?
    ]], { account.id })

    local streams = MySQL.query.await([[
        SELECT s.`id`, s.`title`, s.`category`, s.`peak_viewers` AS `peakViewers`,
               s.`unique_viewers` AS `uniqueViewers`,
               UNIX_TIMESTAMP(s.`started_at`) AS `startedAt`,
               UNIX_TIMESTAMP(COALESCE(s.`ended_at`, CURRENT_TIMESTAMP)) AS `endedAt`,
               COUNT(d.`id`) AS `donations`,
               COALESCE(SUM(d.`gross`), 0) AS `gross`,
               COALESCE(SUM(d.`fee`), 0) AS `fee`,
               COALESCE(SUM(d.`tax`), 0) AS `tax`,
               COALESCE(SUM(d.`net`), 0) AS `net`
        FROM `snitch_streams` s
        LEFT JOIN `snitch_donations` d ON d.`stream_id` = s.`id`
        WHERE s.`account_id` = ?
        GROUP BY s.`id`, s.`title`, s.`category`, s.`peak_viewers`, s.`unique_viewers`, s.`started_at`, s.`ended_at`
        ORDER BY s.`started_at` DESC
        LIMIT 20
    ]], { account.id })

    local days = MySQL.query.await([[
        SELECT DATE_FORMAT(`created_at`, '%Y-%m-%d') AS `day`,
               COALESCE(SUM(`gross`), 0) AS `gross`,
               COALESCE(SUM(`net`), 0) AS `net`
        FROM `snitch_donations`
        WHERE `streamer_account_id` = ? AND `created_at` >= CURRENT_DATE - INTERVAL 13 DAY
        GROUP BY `day`
        ORDER BY `day`
    ]], { account.id })

    local supporters = MySQL.query.await([[
        SELECT a.`username`, a.`avatar_color` AS `avatarColor`, SUM(d.`gross`) AS `total`
        FROM `snitch_donations` d
        JOIN `snitch_accounts` a ON a.`id` = d.`donor_account_id`
        WHERE d.`streamer_account_id` = ?
        GROUP BY a.`id`, a.`username`, a.`avatar_color`
        ORDER BY `total` DESC
        LIMIT 5
    ]], { account.id })

    return SnitchUtil.Ok({
        totals = numbers(totals, { 'donations', 'gross', 'fee', 'tax', 'net', 'pending' }),
        streams = numbers_all(streams, { 'id', 'peakViewers', 'uniqueViewers', 'startedAt', 'endedAt', 'donations', 'gross', 'fee', 'tax', 'net' }),
        days = numbers_all(days, { 'gross', 'net' }),
        supporters = numbers_all(supporters, { 'total' }),
        feePercent = Config.Donations.PlatformFeePercent,
        taxPercent = Config.Donations.TaxPercent,
    })
end)
