-- Run after pm_education_enrollment_revision_migration.sql.
-- Existing records retain NULL: their historical exam requirements are unknown.
ALTER TABLE pm_education_enrollments
 ADD COLUMN exam_revision_id BIGINT UNSIGNED NULL AFTER curriculum_revision_id,
 ADD KEY idx_exam_revision (exam_revision_id);
