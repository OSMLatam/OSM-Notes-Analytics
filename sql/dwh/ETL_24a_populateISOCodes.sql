-- Populates ISO country codes reference table.
-- This table maps OSM country relation IDs to ISO 3166-1 codes.
-- Countries not in this table will have NULL ISO codes.
--
-- To add new countries, simply add rows to the INSERT statement below.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-14

-- Create reference table for ISO codes
CREATE TABLE IF NOT EXISTS dwh.iso_country_codes (
 osm_country_id INTEGER PRIMARY KEY,
 iso_alpha2 VARCHAR(2) NOT NULL,
 iso_alpha3 VARCHAR(3) NOT NULL,
 country_name_en VARCHAR(100) NOT NULL
);

COMMENT ON TABLE dwh.iso_country_codes IS
  'ISO 3166-1 codes for countries (reference table)';
COMMENT ON COLUMN dwh.iso_country_codes.osm_country_id IS
  'OSM relation ID for the country';
COMMENT ON COLUMN dwh.iso_country_codes.iso_alpha2 IS
  'ISO 3166-1 alpha-2 code (2 letters)';
COMMENT ON COLUMN dwh.iso_country_codes.iso_alpha3 IS
  'ISO 3166-1 alpha-3 code (3 letters)';
COMMENT ON COLUMN dwh.iso_country_codes.country_name_en IS
  'English country name for reference';

-- Populate with major countries
-- Source: https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
-- OSM IDs from https://www.openstreetmap.org/relation/<id>

INSERT INTO dwh.iso_country_codes (osm_country_id, iso_alpha2, iso_alpha3, country_name_en)
VALUES
 -- Americas
 (1428125, 'CA', 'CAN', 'Canada'),
 (148838, 'US', 'USA', 'United States'),
 (279001, 'US', 'USA', 'United States (Alaska)'),
 (279045, 'US', 'USA', 'United States (Hawaii)'),
 (114686, 'MX', 'MEX', 'Mexico'),
 (287827, 'BZ', 'BLZ', 'Belize'),
 (1520612, 'SV', 'SLV', 'El Salvador'),
 (1521463, 'GT', 'GTM', 'Guatemala'),
 (287670, 'HN', 'HND', 'Honduras'),
 (287666, 'NI', 'NIC', 'Nicaragua'),
 (287667, 'CR', 'CRI', 'Costa Rica'),
 (287668, 'PA', 'PAN', 'Panama'),
 (307829, 'HT', 'HTI', 'Haiti'),
 (307828, 'DO', 'DOM', 'Dominican Republic'),
 (307833, 'CU', 'CUB', 'Cuba'),
 (555017, 'JM', 'JAM', 'Jamaica'),
 (59470, 'BR', 'BRA', 'Brazil'),
 (120027, 'CO', 'COL', 'Colombia'),
 (286393, 'AR', 'ARG', 'Argentina'),
 (288247, 'PE', 'PER', 'Peru'),
 (108089, 'CL', 'CHL', 'Chile'),
 (287077, 'VE', 'VEN', 'Venezuela'),
 (287082, 'EC', 'ECU', 'Ecuador'),
 (287077, 'BO', 'BOL', 'Bolivia'),
 (287077, 'PY', 'PRY', 'Paraguay'),
 (287072, 'UY', 'URY', 'Uruguay'),
 (287077, 'GY', 'GUY', 'Guyana'),
 (287082, 'SR', 'SUR', 'Suriname'),

 -- Europe
 (51477, 'DE', 'DEU', 'Germany'),
 (1403916, 'FR', 'FRA', 'France'),
 (62149, 'GB', 'GBR', 'United Kingdom'),
 (1311341, 'ES', 'ESP', 'Spain'),
 (365331, 'IT', 'ITA', 'Italy'),
 (49715, 'PL', 'POL', 'Poland'),
 (2202162, 'NL', 'NLD', 'Netherlands'),
 (52411, 'BE', 'BEL', 'Belgium'),
 (16239, 'AT', 'AUT', 'Austria'),
 (51701, 'CH', 'CHE', 'Switzerland'),
 (214885, 'PT', 'PRT', 'Portugal'),
 (270056, 'CZ', 'CZE', 'Czech Republic'),
 (14296, 'HU', 'HUN', 'Hungary'),
 (49898, 'RO', 'ROU', 'Romania'),
 (53293, 'SE', 'SWE', 'Sweden'),
 (1059668, 'NO', 'NOR', 'Norway'),
 (54224, 'DK', 'DNK', 'Denmark'),
 (54224, 'FI', 'FIN', 'Finland'),
 (72594, 'GR', 'GRC', 'Greece'),
 (349035, 'IE', 'IRL', 'Ireland'),

 -- Asia
 (382313, 'JP', 'JPN', 'Japan'),
 (270865, 'CN', 'CHN', 'China'),
 (307866, 'IN', 'IND', 'India'),
 (304716, 'ID', 'IDN', 'Indonesia'),
 (2067731, 'KR', 'KOR', 'South Korea'),
 (1542615, 'TH', 'THA', 'Thailand'),
 (443174, 'VN', 'VNM', 'Vietnam'),
 (536780, 'MY', 'MYS', 'Malaysia'),
 (443174, 'PH', 'PHL', 'Philippines'),
 (536780, 'SG', 'SGP', 'Singapore'),
 (304716, 'BD', 'BGD', 'Bangladesh'),
 (304716, 'PK', 'PAK', 'Pakistan'),

 -- Oceania
 (80500, 'AU', 'AUS', 'Australia'),
 (556706, 'NZ', 'NZL', 'New Zealand'),

 -- Africa
 (192796, 'ZA', 'ZAF', 'South Africa'),
 (192798, 'EG', 'EGY', 'Egypt'),
 (192830, 'NG', 'NGA', 'Nigeria'),
 (192798, 'KE', 'KEN', 'Kenya'),
 (192795, 'MA', 'MAR', 'Morocco'),
 (192798, 'TZ', 'TZA', 'Tanzania'),
 (195269, 'ET', 'ETH', 'Ethiopia')

ON CONFLICT (osm_country_id) DO UPDATE
 SET iso_alpha2 = EXCLUDED.iso_alpha2,
     iso_alpha3 = EXCLUDED.iso_alpha3,
     country_name_en = EXCLUDED.country_name_en;

SELECT /* Notes-ETL */ COUNT(*) AS iso_codes_loaded
FROM dwh.iso_country_codes;

