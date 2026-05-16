import 'organise_plan.dart';

/// Mock AI planner. Real version in Phase 8.1 would call Gemini /
/// an on-device model. For the web slice we return a deterministic,
/// hand-curated plan against the demo tree so the UI has something
/// realistic to render.
class OrganisePlanner {
  const OrganisePlanner();

  OrganisePlan proposeForDownloads() => const OrganisePlan(
        title: 'Tidy /Downloads',
        actions: [
          OrganiseAction(
            sourcePath: '/Downloads/IMG_20260314_193045.jpg',
            targetPath: '/Pictures/2026-03/birthday-cake.jpg',
            reason: 'photo · detected: candles, cake, indoor',
          ),
          OrganiseAction(
            sourcePath: '/Downloads/invoice-2026-03.pdf',
            targetPath: '/Documents/Bills/2026-03-internet.pdf',
            reason: 'invoice · vendor: ISP · month: 2026-03',
          ),
          OrganiseAction(
            sourcePath: '/Downloads/scan_001.pdf',
            targetPath: '/Documents/Receipts/2026-04-12-coffee.pdf',
            reason: 'receipt · merchant: coffee shop · OCR total 4.80',
          ),
          OrganiseAction(
            sourcePath: '/Downloads/recipe-pasta.md',
            targetPath: '/Documents/Recipes/pasta-garlic-oil.md',
            reason: 'recipe · pasta · 3 ingredients',
          ),
          OrganiseAction(
            sourcePath: '/Downloads/screenshot 2026-04-02 at 09.12.png',
            targetPath: '/Pictures/Screenshots/2026-04-02-0912.png',
            reason: 'screenshot · normalised filename',
          ),
        ],
      );
}
