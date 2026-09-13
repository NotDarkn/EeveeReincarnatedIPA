// Re-declares spoti.pw's settings entry point (Sources/EeveeSpotifyC/SubRepos/spoti.pw/tweak/
// Sources/Settings/SGModSettings.h) here so `import EeveeSpotifyC` is enough for Swift to see it —
// spoti.pw's own headers aren't under this umbrella, and don't need to be for just this one call.
// Keep this signature in sync with SGModSettingsPage() in the sub repo.
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

UIViewController *SGModSettingsPage(void);

NS_ASSUME_NONNULL_END
