# Vision High-Res Flow (Opus 4.8)

Scenario-based flows for leveraging Opus 4.8's high-resolution vision capability
(short side up to 2576px) in harness-review.

> **Resolution limit**: A short side of 2576px is the operational safe limit. For images
> exceeding it, pre-resizing is recommended.
> For the detailed guide, see [`docs/opus-4-7-vision-usage.md`](../../../docs/opus-4-7-vision-usage.md).

---

## Scenario 1: PDF page review

When making a PDF (spec, design document, release notes, etc.) the review target.

### Flow

1. **Identify the page range**

   Passing the entire PDF at once consumes a lot of tokens, so first understand the page structure.

   ```
   Read tool: file_path="<path>.pdf", pages="1-5"
   ```

2. **Check the effective DPI per page**

   If the PDF's DPI is high, the short side may exceed 2576px after rendering.
   If it exceeds, ask for a re-export at a lower DPI (see the usage guide for details).

3. **Load the target review pages with Read**

   ```
   Read tool: file_path="<path>.pdf", pages="<target page range>"
   ```

   The Read tool passes the pages specified by the pages parameter to the vision model.
   Up to 20 pages can be specified per call.

4. **Pass to the Reviewer agent**

   Feed the loaded page content into the harness-review review flow (Step 2: 5 aspects).
   The Reviewer evaluates including visual layout, figures/tables, and code snippets.

5. **Batch processing (when there are many pages)**

   For PDFs over 20 pages, split into batches of 20 pages.

   ```
   pages="1-20"  → review → record findings
   pages="21-40" → review → record findings
   ...
   Finally integrate the verdict across all
   ```

### Criteria

PDF review treats reviewer_profile as `static` and evaluates the following:

| Aspect | Check content |
|--------|---------------|
| **Quality** | Whether figures/tables are sufficiently explained, whether the ordering of steps is clear |
| **Accessibility** | Whether there are image-only pages without alt text |
| **AI Residuals** | Incomplete markers such as "TODO", "TBD", "Draft" |

---

## Scenario 2: Architecture Diagram review

When making an image such as a system architecture diagram, ER diagram, or sequence diagram the review target.

### Flow

1. **Check the image resolution**

   ```bash
   # macOS: check resolution with sips
   sips -g pixelWidth -g pixelHeight diagram.png

   # If ImageMagick is available
   identify diagram.png
   ```

   If the short side is 2576px or less, it can be passed directly with the Read tool.
   If it exceeds, pre-resize (see the usage guide for details).

2. **Load the image with the Read tool**

   ```
   Read tool: file_path="diagram.png"
   ```

   Opus 4.8 can see up to 2576px, so it can also parse fine labels and arrows.

3. **Prepare the context to pass to the Reviewer agent**

   ```
   Please review the following architecture diagram.
   Target: the <diagram type (architecture / ER / sequence, etc.)> of <system name>
   Review aspects: <review purpose (consistency check / change-diff check / security check, etc.)>
   ```

4. **Evaluation items**

   | Aspect | Check content |
   |--------|---------------|
   | **Security** | Whether the auth flow, authorization boundaries, and encryption requirements are reflected in the diagram |
   | **Quality** | Whether inter-component dependencies are clear and single responsibility is maintained |
   | **Performance** | Whether likely bottlenecks (synchronous processing / N+1 / no cache, etc.) are visualized |

5. **Cross-check against implementation code**

   After the diagram review, cross-check the corresponding implementation code via the Code Review flow to confirm consistency.

---

## Scenario 3: UI screenshot review

When scoring a Web / mobile UI screenshot with the `--ui-rubric` option.

### Flow

1. **Prepare the screenshot**

   Capture a screenshot of the target page/component.
   In Retina / HiDPI environments, it is often twice the logical pixel size.

   ```bash
   # macOS: screencapture command
   screencapture -x screenshot.png

   # Check resolution
   sips -g pixelWidth -g pixelHeight screenshot.png
   ```

2. **Check resolution and resize (as needed)**

   If the short side exceeds 2576px, resize (see the usage guide for details).
   If 2576px or less, it can be passed as-is with the Read tool.

3. **Evaluate with harness-review --ui-rubric**

   ```
   /harness-review --ui-rubric
   ```

   Before running, load the screenshot with the Read tool and pass it to the Reviewer agent:

   ```
   Read tool: file_path="screenshot.png"
   ```

4. **4-axis scoring (see ui-rubric.md)**

   | Axis | Evaluation content |
   |------|--------------------|
   | **Design Quality** | Visual hierarchy, whitespace, color consistency |
   | **Originality** | Uniqueness, brand expression |
   | **Craft** | Pixel precision, animation, micro-interactions |
   | **Functionality** | Completeness of the user flow, consideration of error states |

5. **Comparison across resolutions (mobile / tablet / desktop)**

   Read the screenshots of each resolution consecutively in the same session, and
   have the Reviewer agent evaluate responsive support all together.

   ```
   Read tool: file_path="mobile.png"    # ~375×812
   Read tool: file_path="tablet.png"    # ~768×1024
   Read tool: file_path="desktop.png"   # ~1440×900
   ```

---

## How to connect with the Reviewer Agent

In any of the 3 scenarios above, the connection to the Reviewer agent after loading
the image / PDF with the Read tool follows this common pattern.

### Connection in breezing mode

When the Lead receives a task with vision input from a Worker:

1. The Worker returns with the image/PDF path included in `files_changed`
2. The Lead loads that path with the Read tool and runs the review with the vision context attached
3. The Reviewer agent returns a verdict in the `review-result.v1` schema

```json
// Example of additional context passed to the Reviewer
{
  "vision_inputs": [
    { "type": "image", "path": "diagram.png", "role": "architecture_diagram" },
    { "type": "pdf",  "path": "spec.pdf",    "role": "specification", "pages": "1-10" }
  ],
  "review_context": "Review of a change that includes images/PDFs"
}
```

### Reviewer behavior when receiving image input

- The Reviewer treats image input the same as "normal diff text" and returns `review-result.v1`
- In `observations[].location`, write it like `"diagram.png:whole"` / `"spec.pdf:p3"`
- When critical / major cannot be determined from the image alone, keep it at `minor` or `recommendation`
- The criteria (critical / major / minor / recommendation) do not change based on the presence of vision input

---

## Batch processing guidelines

When reviewing multiple images / PDF pages consecutively:

| Situation | Recommended approach |
|-----------|----------------------|
| PDF of 20 pages or fewer | Specify all pages in a single Read |
| PDF of 21 pages or more | Split into batches of 20 pages → integrate findings |
| 1-5 images | Consecutive Read → review all together |
| 6 or more images | Batch in groups of 5 → integrate the verdict at the end |
| Mixed high-resolution images | Process after pre-resizing (see the usage guide) |

In batch processing, accumulate each batch's `observations`, and after all batches
complete, decide the final verdict based on the presence of `critical` / `major`.
