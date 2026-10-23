# Jol seat selection mockup

Generated with the built-in `image_gen` tool on 2026-10-23.

This is a visual concept for Jol. The driver, rating, vehicle, departure time and fare are illustrative. The image shows two states of the same screen. The driver seat is unavailable in both and excluded from passenger capacity.

- Left: all four passenger seats available.
- Right: A1 (front passenger) and B1 (rear left) occupied; B2 (rear center) and B3 (rear right) available.

## Final generation prompt

Use case: ui-mockup.
Create one high-resolution polished raster image of a native iPhone app UI for Jol, a Kazakhstan intercity travel and parcel app. The image is divided into TWO equally sized upright app screens side by side on a very light warm-gray background, front-on, perfectly aligned. This is a clean realistic app screenshot mockup, not a photograph of phones, not a marketing poster. Small outer labels above the screens: left "Все места свободны", right "Два места заняты". No extra explanatory text outside the UI.

Visual design: restrained native SwiftUI / iOS style, white rounded cards, excellent spacing, crisp readable Russian text, charcoal main text, secondary gray text. Jol dark emerald accent (#145E45), pale mint availability fills, light gray occupied seats. High contrast. App header brand exactly "Jol". Same layout, same driver, same route and identical car geometry in BOTH screens. No people holding devices, no tilted perspective, no decorative background, no watermark.

Each screen has:
1. A neat app navigation bar with back chevron, "Выбор места", and a small "Jol" wordmark.
2. A white driver card at the top: small circular avatar of a fictional male driver, name "Алихан", star rating "4,9", compact verification badge "Личность проверена". Vehicle line "Toyota Camry • Белая". A small tasteful side-view white sedan thumbnail in this card is optional.
3. Trip details "Алматы → Талдыкорган", "Сегодня, 14:30", price "3 500 ₸ / место".
4. The main large white card containing a beautiful, clearly recognizable TOP-DOWN CAR INTERIOR seat-selection drawing. Car nose points UP, windshield at top, outline of sedan body with subtle exterior wheels, rear at bottom. There are exactly FIVE physical seats total: driver seat at upper LEFT, ONE front passenger seat at upper RIGHT, and THREE individual rear passenger seats in a horizontal row. The driver's seat is neutral gray in BOTH panels, has a steering wheel and the small label "Водитель", and is never selectable. The FOUR passenger seats use codes A1 (front right), B1 (rear left as viewed on the image), B2 (rear center), B3 (rear right). Draw real recognizable rounded seat silhouettes with headrests. Do not draw any additional seats. The top-down view must clearly communicate actual front versus rear placement.
5. At the top of this map card, left screen says "Свободно 4 места", right says "Свободно 2 места".
6. At the bottom, a concise legend with a pale mint seat symbol "Свободно" and a gray seat symbol "Занято". Below that, a wide muted neutral rounded button labelled "Выберите место", since the user has not selected a seat yet. Native bottom home indicator.

CRITICAL EXACT AVAILABILITY:
LEFT screen: all FOUR passenger seats A1, B1, B2, B3 are AVAILABLE, identical pale mint fill with dark emerald border and text. Every passenger seat is visibly labelled "Свободно".
RIGHT screen: front passenger A1 is OCCUPIED and rear LEFT B1 is OCCUPIED. These TWO seats must both have clearly gray fill, a small lock or x indicator, and label "Занято". Rear CENTER B2 and rear RIGHT B3 remain AVAILABLE with the exact same mint fill and dark emerald border as the available seats in the left screen and labels "Свободно".
Do not accidentally mark the rear center or rear right as occupied. No selected state anywhere. Driver occupancy is separate and excluded from the count. Count and positions must be unambiguous and accurate.

Typography: native clean sans-serif, readable exact Cyrillic spelling, strong hierarchy, no invented paragraphs. Simple professional app design matching the green Jol app, as if showing two states of the same screen. Ensure the car seat diagram is the largest visual focus. Output one landscape image with both complete screens visible, neither cropped.
