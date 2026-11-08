-- Run diagnostics before this migration. Resolve duplicates manually; do not discard revisions.
SELECT institution_id, content_type, content_key, COUNT(*) AS published_count
FROM pm_education_catalog
WHERE status = 'published'
GROUP BY institution_id, content_type, content_key
HAVING COUNT(*) > 1;

-- Apply only when the query above returns zero rows.
-- The slash delimiter is not allowed in catalog keys, so generated slots cannot collide.
ALTER TABLE pm_education_catalog
 ADD COLUMN published_slot VARCHAR(255) GENERATED ALWAYS AS (
  CASE WHEN status = 'published' THEN CONCAT(institution_id, '/', content_type, '/', content_key) ELSE NULL END
 ) STORED,
 ADD UNIQUE KEY uq_single_published (published_slot);
