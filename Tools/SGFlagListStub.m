// Stand-in for spoti.pw's flag table. The real SGFlagList.m is generated from a decrypted
// Spotify IPA by spoti.pw's scripts/extract-flags.py and is gitignored upstream, so a fresh
// submodule checkout does not have it — and without it FlagsPage.m fails to link
// (undefined SGFlagTable / SGFlagCount). The root Makefile compiles this stub instead,
// only when the real file is missing: the tweak links, the All-flags page simply lists
// zero flags. To get the full table, run:
//   Sources/EeveeSpotifyC/SubRepos/spoti.pw/scripts/extract-flags.py <decrypted Spotify .ipa>
// which writes the real SGFlagList.m into the submodule and this stub stops being compiled.
#import "Features/Flags/Flags.h"

const SGFlagDef SGFlagTable[1] = {{0, SGFlagUnknown, 0, 0, 0}};
const NSUInteger SGFlagCount = 0;
