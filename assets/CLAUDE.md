# Assets Directory

Frontend assets for VSM Phoenix web interface.

## Files in this directory:

- `tailwind.config.js` - Tailwind CSS configuration

## Subdirectories:

### css/
- `app.css` - Main application styles

### js/
- `app.js` - Main JavaScript entry point

### vendor/
- Third-party vendored assets

## Purpose:
Contains all frontend assets including:
- CSS styles and Tailwind configuration
- JavaScript for interactivity
- Static assets and images
- Vendor libraries

## Build Process:
Assets are processed by esbuild:
```bash
# Watch and rebuild assets
mix assets.build

# Build for production
mix assets.deploy
```

## Styling:
Uses Tailwind CSS for utility-first styling:
- Responsive design
- Dark mode support
- Component classes
- Custom utilities

## JavaScript:
Phoenix LiveView integration:
- WebSocket connections
- Live DOM updates
- Hook system
- Event handling

## Integration:
- LiveView hooks for real-time updates
- Chart.js for telemetry visualization
- WebSocket for live data
- CSS for VSM system status indicators