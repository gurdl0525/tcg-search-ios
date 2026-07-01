# Card Search Publishing Fidelity Checklist

Figma file: https://www.figma.com/design/TlHWS79bFwcZ3wGu1AJ8gu/tcg-search

## Reference Frames

| State | Figma node | Reference PNG | Simulator PNG | Status |
| --- | --- | --- | --- | --- |
| Home Light | 2122:5 | /private/tmp/tcg-home-light.png | /var/folders/x1/vcyf5c8j0nj8q4k34h5h7l9r0000gn/T/screenshot_optimized_20aac0a9-8d72-4d22-adf2-8d6852cea29e.jpg | pass |
| Filter Light | 2122:166 | /private/tmp/tcg-filter-light.png | /var/folders/x1/vcyf5c8j0nj8q4k34h5h7l9r0000gn/T/screenshot_optimized_75061637-3cb2-44ff-840c-a8cbf24710f2.jpg | pass |
| Results Light | 2157:12 | /private/tmp/tcg-results-light.png | /var/folders/x1/vcyf5c8j0nj8q4k34h5h7l9r0000gn/T/screenshot_optimized_487b614e-87d5-4642-bd11-0edb061c7b83.jpg | pass |
| Empty Light | 2157:100 | /private/tmp/tcg-empty-light.png | /private/tmp/tcg-empty-light-sim.png | pending |
| Loading Light | 2157:151 | /private/tmp/tcg-loading-light.png | /private/tmp/tcg-loading-light-sim.png | pending |
| Results Black | 2157:207 | /private/tmp/tcg-results-black.png | /var/folders/x1/vcyf5c8j0nj8q4k34h5h7l9r0000gn/T/screenshot_optimized_4c7a84bc-1a8c-4a67-9197-263be4d2f5b9.jpg | pass |
| Empty Black | 2157:295 | /private/tmp/tcg-empty-black.png | /private/tmp/tcg-empty-black-sim.png | pending |
| Loading Black | 2157:346 | /private/tmp/tcg-loading-black.png | /private/tmp/tcg-loading-black-sim.png | pending |

## Acceptance Criteria

- Home has compact search-first layout, no oversized marketing/header treatment.
- Home filter icon is visible and opens the same filter sheet as Results.
- Search Results is reached from Home search or filter apply, not bottom navigation.
- Bottom navigation labels are 홈, 컬렉션, 덱, 설정.
- Results grid uses image-first cards with actual card-image aspect, 10pt insets, language badge, and metadata below artwork.
- Filter sheet chip groups wrap horizontally like Figma, not as a vertical list.
- Filter sheet pack select, illustrator input, and character select match Figma relative order and sizing.
- Empty and Loading preserve the same background and top controls as Results.
- Black theme keeps icons white/visible and avoids high-glare green.
