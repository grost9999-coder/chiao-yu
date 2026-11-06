# Multi-image recipe recognition

The Processing photo picker accepts up to 10 images at a time. Camera capture remains available.
Images use the same bounded, on-device Vision OCR bridge, sequentially, with per-image status and
text. A failed image does not discard successful pages or stop remaining images. Original images
are not stored in recipes; the combined source text and editable costed ingredients are saved.

Only completed, selected pages enter the merged text. Entire pages with identical normalized text
are included once. Different pages that repeat ingredient names or disagree on recipe name, raw
weight/price, or finished weight require review before generating the ingredient preview. Users can
exclude individual pages, merge again, or edit the combined text and explicitly generate a preview.
No names, ingredient quantities, or different prices are silently combined into one recipe row.

Merged text is limited to 20,000 characters, with a visible error instead of silent truncation.
Users can split imports or deselect pages. Existing per-image limits remain 25 MB and a 2400-pixel
long-edge normalized JPEG. The app holds only one photo preview plus per-page text, reducing peak
memory. Existing text/batch data remains unchanged until successful merge and explicit application.
Cancel stops the remaining queue and ignores an in-flight result; already completed pages can be
merged manually. Switching vendors/unmounting also invalidates pending results.

Tests: `recipe-multi.test.cjs` checks queue serialization, partial failure, deduplication, exclusion,
limits, and cancellation. `recipe-multi-browser.cjs` exercises the real iPhone WebKit UI with mocked
native OCR transport; the existing native Vision image tests and iOS compile remain in CI.
Physical iPhone multi-photo picker and camera permission behavior need installed-build validation.
