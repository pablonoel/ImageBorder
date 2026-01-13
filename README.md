# ImageBorder

Batch-process images by adding a uniform border and padding to a fixed aspect ratio using ImageMagick 7.

## What it does
- Border thickness in % = `border_pct` of the narrowest side (min(width, height)).
- Pads (no crop) to the target aspect ratio using canvas extent, centered.
- Writes output to an auto-created subfolder in the input directory.
- Output names include the aspect/orientation and border percentage.

## Requirements
- ImageMagick 7 (`magick` must be on your PATH)

Install on macOS:
```bash
brew install imagemagick
```

## Usage
```bash
./image_border.sh /path/to/input [border_color] [orientation] [border_pct]
```

### Arguments
- `border_color` (optional): ImageMagick color name. Default: `white`.
- `orientation` (optional): `landscape` or `portrait`. Default: `landscape`.
- `border_pct` (optional): Percent or decimal. Examples: `10`, `10%`, `0.10`. Default: `10`.

## Examples
```bash
# 10% white border, pad to 5x4 (landscape)
./image_border.sh ./in white landscape 10

# 8% black border, pad to 4x5 (portrait)
./image_border.sh ./in black portrait 8

# 12.5% border using decimal form
./image_border.sh ./in white landscape 0.125
```

## Output
The script creates an output folder inside the input folder:
```
processed_<aspect>_<orientation>_border<border_pct>
```

Example:
```
processed_5x4_landscape_border10
```

Output filenames are:
```
<original_name>_<aspect>_<orientation>_border<border_pct>.<ext>
```

## Notes
- Supported input formats: jpg, jpeg, png, tif, tiff, webp (top-level only; non-recursive).
- If no images match, the script exits without error.
- For troubleshooting, `magick -version` is printed at start.
