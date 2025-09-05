-- Quỹ của từng công ty taxi
CREATE TABLE IF NOT EXISTS `taxi_owner` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` VARCHAR(50) NOT NULL,   -- ví dụ "CRS", "VTX"
  `funds` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_company` (`company_id`)
);

-- Xe chính chủ của từng công ty
CREATE TABLE IF NOT EXISTS `taxi_owner_vehicles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` VARCHAR(50) NOT NULL,   -- để link về công ty
  `model` VARCHAR(50) NOT NULL,
  `plate` VARCHAR(20) NOT NULL,
  `price` INT NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_plate` (`plate`)
);
