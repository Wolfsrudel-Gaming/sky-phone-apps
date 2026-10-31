ShadowDatabase = { Ready = false }

local MIGRATIONS = {
    [[
        CREATE TABLE IF NOT EXISTS `shadow_devices` (
            `imei` VARCHAR(32) NOT NULL,
            `alias` VARCHAR(32) NOT NULL,
            `owner_identifier` VARCHAR(64) NOT NULL,
            `pin_hash` VARCHAR(128) NULL DEFAULT NULL,
            `failed_attempts` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `locks_in_row` TINYINT UNSIGNED NOT NULL DEFAULT 0,
            `locked_until` INT UNSIGNED NOT NULL DEFAULT 0,
            `alias_changed_at` INT UNSIGNED NOT NULL DEFAULT 0,
            `unlocked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`imei`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    -- channel posts and private messages. author_identifier is only for admins.
    [[
        CREATE TABLE IF NOT EXISTS `shadow_messages` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `channel` VARCHAR(32) NULL DEFAULT NULL,
            `thread_id` INT UNSIGNED NULL DEFAULT NULL,
            `is_ad` TINYINT(1) NOT NULL DEFAULT 0,
            `imei` VARCHAR(32) NOT NULL,
            `alias` VARCHAR(32) NOT NULL,
            `author_identifier` VARCHAR(64) NOT NULL,
            `body` VARCHAR(500) NOT NULL,
            `created_at` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_shadow_channel` (`channel`, `id`),
            KEY `idx_shadow_thread` (`thread_id`, `id`),
            KEY `idx_shadow_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `shadow_threads` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `imei_a` VARCHAR(32) NOT NULL,
            `imei_b` VARCHAR(32) NOT NULL,
            `alias_a` VARCHAR(32) NOT NULL,
            `alias_b` VARCHAR(32) NOT NULL,
            `topic` VARCHAR(120) NOT NULL DEFAULT '',
            `last_at` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_shadow_thread_a` (`imei_a`),
            KEY `idx_shadow_thread_b` (`imei_b`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
}

MySQL.ready(function()
    for index = 1, #MIGRATIONS do
        local success, error_message = pcall(MySQL.query.await, MIGRATIONS[index])
        if not success then
            ShadowUtil.Log('error', 'Database setup failed at step %s: %s', index, tostring(error_message))
            return
        end
    end
    ShadowDatabase.Ready = true
end)
