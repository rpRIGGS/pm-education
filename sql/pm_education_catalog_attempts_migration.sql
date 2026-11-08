-- Apply after pm_education.sql and pm_education_catalog.sql.
-- Nullable for attempts recorded before catalog integration.
ALTER TABLE pm_education_attempts
 ADD COLUMN catalog_revision_id BIGINT UNSIGNED NULL,
 ADD KEY idx_attempt_catalog_revision (catalog_revision_id);
