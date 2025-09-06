CREATE TABLE IF NOT EXISTS `taxi_owner` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` VARCHAR(50) NOT NULL,       -- Mã công ty (VD: CRS)
  `funds` INT NOT NULL DEFAULT 0,          -- Quỹ công ty
  `citizenid` VARCHAR(50) DEFAULT NULL,    -- citizenid chủ (NULL = chưa có chủ)
  `sell_price` INT DEFAULT NULL,           -- Giá rao bán (NULL = không bán)
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_company` (`company_id`)
);
