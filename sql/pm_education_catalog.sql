-- Versioned content catalog for PM Education. Apply after pm_education.sql.
-- Published revisions are immutable. Drafts may be edited until published.
CREATE TABLE IF NOT EXISTS pm_education_catalog (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
 institution_id VARCHAR(80) NOT NULL,
 content_type ENUM('course','exam','credential') NOT NULL,
 content_key VARCHAR(80) NOT NULL,
 revision INT UNSIGNED NOT NULL,
 status ENUM('draft','published','retired') NOT NULL DEFAULT 'draft',
 payload_json LONGTEXT NOT NULL,
 source_hash VARCHAR(64) NULL,
 source_kind ENUM('development','ingame') NOT NULL DEFAULT 'development',
 created_by VARCHAR(64) NOT NULL DEFAULT 'system',
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 published_at TIMESTAMP NULL DEFAULT NULL,
 PRIMARY KEY(id),
 UNIQUE KEY uq_content_revision (institution_id,content_type,content_key,revision),
 KEY idx_active_content (institution_id,content_type,status,content_key)
);
CREATE TABLE IF NOT EXISTS pm_education_catalog_audit (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
 catalog_id BIGINT UNSIGNED NOT NULL,
 institution_id VARCHAR(80) NOT NULL,
 actor_citizenid VARCHAR(64) NOT NULL,
 action VARCHAR(40) NOT NULL,
 notes VARCHAR(1000) NULL,
 recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(id),
 KEY idx_catalog_audit (catalog_id,id)
);
-- Existing credentials and attempts remain authoritative. A future migration
-- must bind new attempts to a catalog revision without rewriting historical rows.
