# Priv Directory

Private application resources including static assets, translations, and compiled files.

## Directory Structure:

### gettext/
Internationalization and localization files:
- `en/LC_MESSAGES/` - English translations
  - `default.po` - Default message translations
  - `errors.po` - Error message translations

### static/
Static web assets served by Phoenix:
- `assets/` - Compiled JavaScript and CSS files
  - Minified and gzipped versions for production
  - Source maps for debugging
- `cache_manifest.json` - Asset versioning for cache busting

## Purpose:
Contains all non-Elixir resources that ship with the application:
- Compiled frontend assets
- Translation files
- Static images and files
- Database migrations (when using Ecto)

## Asset Pipeline:
- CSS and JS files are compiled from assets/
- Fingerprinted for cache invalidation
- Gzipped for optimal delivery
- Served directly by Phoenix in development
- Can be served by CDN in production

## Internationalization:
- Gettext provides translation infrastructure
- PO files contain translatable strings
- Supports multiple languages
- Runtime language switching

## Note:
This directory is included in releases and contains files needed at runtime. Do not store sensitive information here.