# Opus 4.7 Vision Usage Guide

Operational guide for the vision capabilities strengthened in Opus 4.7 (resolution limit ~2576px).
Applies to PDF, diagram, and UI screenshot review in harness-review.

> **Source**: the vision specification described in the Claude / Opus 4.7 release notes and the Claude Code documentation.
> "Safe up to 2576px on the short edge" is a value based on these documents; do not use any other number.

---

## Basic guidelines

### Resolution limit

**2576px on the short edge** is the operational safe limit for Opus 4.7 vision.

| Image size | Handling |
|-----------|------|
| Short edge 2576px or less | Pass directly with the Read tool |
| Short edge over 2576px | **Pre-resize required** (see below) |

- "Short edge" is the smaller of width and height. Example: a 3840×2160 image has a short edge = 2160px (within the limit)
- Example: a 5000×3000 image has a short edge = 3000px (over the limit → resize required)
- Even if the long edge exceeds 2576px, there is no problem as long as the short edge is 2576px or less

---

## Pre-resize procedure when exceeding 2576px

### macOS (sips command)

```bash
# Check resolution
sips -g pixelWidth -g pixelHeight input.png

# Resize: fit the larger of the long/short edge to 2576px
sips -Z 2576 input.png --out output.png
```

`-Z 2576` fits the long edge to 2576px while preserving the aspect ratio.
It works the same way when the short edge exceeds 2576px (e.g., portrait images).

### ImageMagick (cross-platform)

```bash
# Resize: shrink so neither dimension exceeds 2576px (preserving aspect ratio)
convert input.png -resize 2576x2576\> output.png
```

`\>` is a modifier that "shrinks only when the original size is larger than the specified value".
Images 2576px or smaller are unchanged.

### Batch-resize multiple files (macOS sips)

```bash
# Resize all PNGs in the current directory and output to resized/
mkdir -p resized
for f in *.png; do
  sips -Z 2576 "$f" --out "resized/$f"
done
```

---

## Notes for PDFs

PDFs are passed to the vision model **per page**.
If the rendering resolution (DPI) of each page is high, a single page can exceed 2576px.

### Relationship between DPI and effective resolution

| DPI | Effective resolution of an A4 page (height × width) | Short edge |
|-----|-------------------------------|------|
| 72 dpi  | 595 × 842 px | 595px (within limit) |
| 150 dpi | 1240 × 1754 px | 1240px (within limit) |
| 200 dpi | 1654 × 2340 px | 1654px (within limit) |
| 250 dpi | 2067 × 2926 px | 2067px (within limit) |
| 300 dpi | 2480 × 3508 px | 2480px (within limit) |
| 360 dpi | 2976 × 4210 px | **2976px (over limit)** |

For A4, up to 300 dpi is mostly safe. 360 dpi and above requires caution.

### Adjust the PDF DPI and re-export (Ghostscript)

```bash
# Re-export at 150 dpi (also reduces file size)
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
   -dPDFSETTINGS=/screen \
   -sOutputFile=output_150dpi.pdf input.pdf

# Explicitly specify a particular resolution
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
   -dCompatibilityLevel=1.4 \
   -dDownsampleColorImages=true \
   -dColorImageResolution=200 \
   -sOutputFile=output_200dpi.pdf input.pdf
```

### Reading a PDF with the Read tool

```
Read tool: file_path="spec.pdf", pages="1-5"
```

- Specify the page range to read with the `pages` parameter (e.g., `"1-5"`, `"3"`, `"10-20"`)
- Up to 20 pages can be specified in a single request
- Split PDFs longer than 20 pages into 20-page chunks when reading

---

## Memory consumption reference

When passing multiple high-resolution images, token consumption increases. Use the following to adjust the number of images.

| Resolution per image | Approximate token consumption (vision input) |
|------------------------|-------------------------------|
| 512 × 512 px | ~85 tokens |
| 1024 × 1024 px | ~340 tokens |
| 2048 × 2048 px | ~1360 tokens |
| 2576 × 2576 px | ~2100 tokens (near the limit) |

> The above are approximate values. Actual consumption varies with the image content, compression rate, and the model's internal processing.

### Conversion examples for passing N images

| Count × resolution | Approximate token consumption |
|--------------|----------------|
| 5 × 2576px | ~10,500 tokens |
| 10 × 2576px | ~21,000 tokens |
| 20 × 2048px | ~27,200 tokens |

With Opus 4.7's 1M context window, these stay within roughly 2–3% of the total.
However, when processing many high-resolution images in the same session, batch splitting is recommended.

---

## Common errors and remedies

| Symptom | Cause | Remedy |
|------|------|------|
| Read tool does not return the image | Wrong file path, or an unsupported format | Check the path. Limited to PNG / JPG / GIF / WebP / PDF |
| Review result says "image is unclear" | Resolution is too low (e.g., 100px or less) | Provide a higher-resolution version, or add a text supplement |
| Some PDF pages are missing | The pages specification exceeds the PDF's total page count | Keep `pages` within the valid range |
| Slow / timeout | Passing too many high-resolution images | Batch-split into groups of 5 for processing |

---

## Related documents

- [`skills/harness-review/references/vision-high-res-flow.md`](../skills/harness-review/references/vision-high-res-flow.md) — flows for typical scenarios (PDF / diagram / UI screenshot)
- [`skills/harness-review/SKILL.md`](../skills/harness-review/SKILL.md) — harness-review main skill definition
- [`docs/CLAUDE-feature-table.md`](CLAUDE-feature-table.md) — Opus 4.7 feature list (vision 2576px entry)
