# Customer UI map

`customer-ui-map.svg` is a standalone vector map exported from the audited customer UI inventory. It contains screen IDs, the scheduled booking journey, supporting overlays, shared components, backend limitations and the recommended enhancement order.

Open the SVG in a browser to inspect it. Drag it onto a FigJam canvas to use it as a visual reference. This is an SVG asset, not a native `.jam` file: FigJam may import it as one image, so its arrows are not native editable connectors. Keep native FigJam notes alongside it to track review progress. Figma Design can also import the SVG for vector-layer editing.

Regenerate from the repository root with:

```powershell
python scripts/export-customer-ui-map.py
```

Update `docs/customer-ui-inventory.md` and the export script together when the implemented flow changes. All UI review statuses start pending; implementation existence is not visual approval. No application behavior is changed by this export.
