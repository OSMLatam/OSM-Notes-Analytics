-- Lists public.international_waters segments that have at least one closed fact
-- for DWH country_id -1. Aligns with OSM-Notes-Ingestion ocean regions
-- (processPlanetNotes_28_addInternationalWatersExamples.sql).
--
-- Output (tab-separated, unaligned): iw_id, iw_name, last_close_at
-- Used by: bin/dwh/exportAndPushCSVToGitHub.sh
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-05-03

\set ON_ERROR_STOP on

WITH match AS (
    SELECT
        iw.id AS iw_id,
        iw.name AS iw_name,
        f.action_at
    FROM dwh.facts f
        INNER JOIN dwh.dimension_countries dc
            ON f.dimension_id_country = dc.dimension_country_id
            AND dc.country_id = -1
        INNER JOIN public.notes n
            ON f.id_note = n.note_id
            AND n.longitude IS NOT NULL
            AND n.latitude IS NOT NULL
        INNER JOIN public.international_waters iw ON (
            (
                iw.geom IS NOT NULL
                AND (
                    ST_Contains(
                        ST_SetSRID(iw.geom, 4326),
                        ST_SetSRID(
                            ST_MakePoint(
                                n.longitude::DOUBLE PRECISION,
                                n.latitude::DOUBLE PRECISION
                            ),
                            4326
                        )
                    )
                    OR ST_Intersects(
                        ST_SetSRID(iw.geom, 4326),
                        ST_SetSRID(
                            ST_MakePoint(
                                n.longitude::DOUBLE PRECISION,
                                n.latitude::DOUBLE PRECISION
                            ),
                            4326
                        )
                    )
                )
            )
            OR (
                COALESCE(iw.is_special_point, FALSE)
                AND iw.point_coords IS NOT NULL
                AND ST_DWithin(
                    iw.point_coords,
                    ST_SetSRID(
                        ST_MakePoint(
                            n.longitude::DOUBLE PRECISION,
                            n.latitude::DOUBLE PRECISION
                        ),
                        4326
                    ),
                    0.001
                )
            )
        )
    WHERE f.action_comment = 'closed'
)

SELECT
    iw_id::TEXT
        || CHR(9)
        || REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(iw_name::TEXT, CHR(10), ' '),
                    CHR(13),
                    ' '
                ),
                CHR(9),
                ' '
            ),
            '|',
            '/'
        )
        || CHR(9)
        || MAX(action_at)::TEXT
FROM match
GROUP BY iw_id, iw_name
ORDER BY iw_name;
