-- Apply after pm_education_catalog.sql and before restarting PM Education.
-- NULL preserves existing enrollments as legacy configuration-based records.
ALTER TABLE pm_education_enrollments
 ADD COLUMN curriculum_revision_id BIGINT UNSIGNED NULL AFTER course_id,
 ADD KEY idx_curriculum_revision (curriculum_revision_id);
-- Never backfill historical enrollments with today's published revision:
-- doing so would silently change their original training obligations.
