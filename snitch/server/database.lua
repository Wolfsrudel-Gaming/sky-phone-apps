SnitchDatabase = { Ready = false }

local ready_callbacks = {}

local MIGRATIONS = {
    [[
        CREATE TABLE IF NOT EXISTS `snitch_accounts` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `username` VARCHAR(20) NOT NULL,
            `username_key` VARCHAR(20) NOT NULL,
            `email` VARCHAR(120) NOT NULL,
            `password_hash` VARCHAR(255) NOT NULL,
            `owner_identifier` VARCHAR(64) NOT NULL,
            `avatar_color` VARCHAR(16) NOT NULL DEFAULT 'sunset',
            `bio` VARCHAR(160) NOT NULL DEFAULT '',
            `banned` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_snitch_username` (`username_key`),
            UNIQUE KEY `uniq_snitch_email` (`email`),
            KEY `idx_snitch_owner` (`owner_identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `snitch_sessions` (
            `imei` VARCHAR(32) NOT NULL,
            `account_id` INT UNSIGNED NOT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`imei`),
            KEY `idx_snitch_session_account` (`account_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `snitch_streams` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `account_id` INT UNSIGNED NOT NULL,
            `title` VARCHAR(80) NOT NULL,
            `category` VARCHAR(32) NOT NULL,
            `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `ended_at` TIMESTAMP NULL DEFAULT NULL,
            `peak_viewers` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
            `unique_viewers` INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`),
            KEY `idx_snitch_stream_account` (`account_id`, `started_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `snitch_donations` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `stream_id` INT UNSIGNED NOT NULL,
            `streamer_account_id` INT UNSIGNED NOT NULL,
            `donor_account_id` INT UNSIGNED NOT NULL,
            `donor_identifier` VARCHAR(64) NOT NULL,
            `payout_identifier` VARCHAR(64) NOT NULL,
            `gross` INT UNSIGNED NOT NULL,
            `fee` INT UNSIGNED NOT NULL,
            `tax` INT UNSIGNED NOT NULL,
            `net` INT UNSIGNED NOT NULL,
            `message` VARCHAR(120) NOT NULL DEFAULT '',
            `paid_out` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_snitch_donation_streamer` (`streamer_account_id`, `created_at`),
            KEY `idx_snitch_donation_stream` (`stream_id`),
            KEY `idx_snitch_donation_pending` (`payout_identifier`, `paid_out`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    -- Streams that were live when the server stopped never received an end time.
    [[
        UPDATE `snitch_streams` SET `ended_at` = CURRENT_TIMESTAMP WHERE `ended_at` IS NULL
    ]],
}

---Runs the callback once the tables exist (immediately if they already do).
function SnitchDatabase.OnReady(callback)
    if SnitchDatabase.Ready then
        CreateThread(callback)
        return
    end
    ready_callbacks[#ready_callbacks + 1] = callback
end

MySQL.ready(function()
    for index = 1, #MIGRATIONS do
        local success, error_message = pcall(MySQL.query.await, MIGRATIONS[index])
        if not success then
            SnitchUtil.Log('error', 'Database setup failed at step %s: %s', index, tostring(error_message))
            return
        end
    end

    SnitchDatabase.Ready = true
    SnitchUtil.Log('info', 'Database ready.')
    for index = 1, #ready_callbacks do
        CreateThread(ready_callbacks[index])
    end
    ready_callbacks = {}
end)
