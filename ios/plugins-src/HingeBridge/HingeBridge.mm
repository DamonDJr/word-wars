// HingeBridge.mm — tells Word Wars how far an iPhone Duo is open.
//
// The whole of it: add a UIHingeInteraction to the game's view and, whenever the
// hinge moves, write one line — `<status> <angle>` — to a file in the app's
// caches where the game's `_poll_hinge` (scripts/game.gd) reads it. There is no
// engine binding and no header from Godot in here, which is the point: the
// engine and this file do not have to agree about anything but a line of text.
//
// ## Why it is written against the Objective-C runtime and not the SDK
//
// UIHingeInteraction arrived in iOS 27.1. Written against its headers this file
// would not compile on any runner whose Xcode is older, and the build that
// matters most right now is the one that runs on whatever image is current.
// Looked up by name at run time it compiles anywhere, and on a device or an OS
// that does not have the class it does nothing at all, which is exactly what a
// non-folding iPhone should get.
//
// ## Why it is Objective-C++ and not Objective-C
//
// The two functions at the bottom are called by code Godot generates into the
// exported project, and that code is C++: it declares `void hinge_bridge_init();`
// and the linker looks for the C++-mangled name. Compiled as plain Objective-C
// they come out with C names and the link fails with "declaration possibly
// missing extern \"C\"" — which is what the first CI run of this file did. As a
// .mm they get the mangling Godot asked for, and nothing else here changes.
//
// ## What it must never do
//
// Crash, or hold anything up. Every step that can fail returns quietly, the
// handler is wrapped, and the whole thing is attached from the main queue after
// the app has had a chance to make its window — so a game on a device where any
// of this is wrong plays exactly as it did before the file existed.

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const kHingeFile = @"hinge.txt";

static id sInteraction = nil;
static NSString *sLast = nil;
static int sTries = 0;

static void HingeWrite(NSInteger status, double angle) {
	NSString *line = [NSString stringWithFormat:@"%ld %.3f", (long)status, angle];
	if ([line isEqualToString:sLast]) {
		return;
	}
	sLast = line;

	// Caches first, which is what Godot's `OS.get_cache_dir()` is. Documents too,
	// because that is what `user://` is and the game reads it as a fallback — one
	// of the two being the other's name on some engine version costs nothing.
	NSArray<NSNumber *> *dirs = @[ @(NSCachesDirectory), @(NSDocumentDirectory) ];
	for (NSNumber *d in dirs) {
		NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(
				(NSSearchPathDirectory)d.integerValue, NSUserDomainMask, YES);
		if (paths.count == 0) {
			continue;
		}
		NSString *path = [paths[0] stringByAppendingPathComponent:kHingeFile];
		[line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
	}
}

// The view the game draws into: the first window's root view controller's view.
static UIView *HostView(void) {
	UIApplication *app = [UIApplication sharedApplication];
	if (app == nil) {
		return nil;
	}
	for (UIScene *scene in app.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		for (UIWindow *window in ((UIWindowScene *)scene).windows) {
			UIViewController *vc = window.rootViewController;
			if (vc != nil && vc.viewIfLoaded != nil) {
				return vc.viewIfLoaded;
			}
		}
	}
	return nil;
}

static BOOL Attach(void) {
	if (sInteraction != nil) {
		return YES;
	}
	Class cls = NSClassFromString(@"UIHingeInteraction");
	if (cls == Nil) {
		return NO; // an OS without a hinge
	}
	SEL initSel = NSSelectorFromString(@"initWithUpdateHandler:");
	id obj = [cls alloc];
	if (obj == nil || ![obj respondsToSelector:initSel]) {
		return NO;
	}
	UIView *host = HostView();
	if (host == nil) {
		return NO; // no window yet; the caller retries
	}

	void (^handler)(id, id) = ^(id interaction, id update) {
		@try {
			id hinge = [update valueForKey:@"hinge"];
			if (hinge == nil || hinge == (id)[NSNull null]) {
				return; // left the hierarchy: keep the last word rather than guess
			}
			NSInteger status = [[hinge valueForKey:@"status"] integerValue];
			double angle = [[hinge valueForKey:@"angle"] doubleValue];
			HingeWrite(status, angle);
		} @catch (NSException *e) {
		}
	};

	id (*initFn)(id, SEL, id) = (id(*)(id, SEL, id))objc_msgSend;
	id interaction = initFn(obj, initSel, handler);
	if (interaction == nil) {
		return NO;
	}
	[host addInteraction:(id<UIInteraction>)interaction];
	sInteraction = interaction;
	return YES;
}

static void TryAttach(void) {
	@try {
		if (Attach() || ++sTries >= 120) {
			return;
		}
	} @catch (NSException *e) {
		return;
	}
	// The window may not exist yet; try again shortly, for a minute at most.
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
			dispatch_get_main_queue(), ^{
				TryAttach();
			});
}

// Called by the engine at startup, through the plugin's `initialization` entry.
// C++ linkage on purpose: see the note at the top.
void hinge_bridge_init() {
	dispatch_async(dispatch_get_main_queue(), ^{
		TryAttach();
	});
}

void hinge_bridge_deinit() {
	sInteraction = nil;
}
