# Electricity Network Project

This project manages and analyzes electricity network data for a specific region. It includes geospatial data, SQL initialization scripts, and documentation in multiple languages.

## Project Structure

- **reseau_electrique.html**: Main HTML file for visualizing or documenting the network.
- **Documents/**: Additional documentation and resources.
- **GeoJson/**: Contains geospatial data files:
  - `electricity_network.geojson`: GeoJSON data for the electricity network.
  - `wilaya_boundaries_from_docs.geojson`: GeoJSON data for administrative boundaries.
- **init-scripts/**: SQL scripts for initializing and seeding the database:
  - `01-init-extensions.sql` to `07-seed-data.sql`: Setup, schema creation, authentication, network data, indexes, views, and seed data.
- **tableDescription/**: Table descriptions in Arabic and French:
  - `ar_table_description.md`
  - `fr_table_description.md`

## Getting Started

1. Review the SQL scripts in `init-scripts/` to set up your database.
2. Use the GeoJSON files for mapping or GIS analysis.
3. Refer to the documentation in `Documents/` and `tableDescription/` for details on data structure and usage.

## License

Specify your license here.
