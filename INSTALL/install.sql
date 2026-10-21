-- `citizenid` holds the character identifier of every framework (QBX/QB citizenid, ESX identifier).
CREATE TABLE IF NOT EXISTS `hype_rentacar_rentals` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(64) NOT NULL,
    `location` VARCHAR(50) NOT NULL,
    `model` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `plate` VARCHAR(8) NOT NULL,
    `hours` SMALLINT UNSIGNED NOT NULL,
    `price_per_hour` INT UNSIGNED NOT NULL,
    `discount` TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `rent_price` INT UNSIGNED NOT NULL,
    `deposit` INT UNSIGNED NOT NULL DEFAULT 0,
    `deposit_refund` INT UNSIGNED DEFAULT NULL,
    `payment` VARCHAR(20) NOT NULL,
    `picked_up` TINYINT(1) NOT NULL DEFAULT 1,
    `status` ENUM('active', 'returned', 'expired', 'interrupted', 'refunded') NOT NULL DEFAULT 'active',
    `rented_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NOT NULL,
    `ended_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_citizen_status` (`citizenid`, `status`),
    KEY `idx_status_expires` (`status`, `expires_at`),
    KEY `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Upgrading an existing table (older versions used VARCHAR(50)):
-- ALTER TABLE `hype_rentacar_rentals` MODIFY `citizenid` VARCHAR(64) NOT NULL;
