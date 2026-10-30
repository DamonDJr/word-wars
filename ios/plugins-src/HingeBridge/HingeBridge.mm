// HingeBridge.mm — tells Word Wars how an iPhone Duo is folded, and what glass
// the game is on.
//
// A few times a second, and whenever the hinge moves, it writes a handful of
// lines to a file in the app's caches where the game's `_poll_hinge`
// (scripts/game.gd) reads them:
//
//     hinge 2 1.95 partial      the hinge: raw status, angle in radians, status name
//     view 669.0 951.0          the game view's size, in points
//     class 2 2                 horizontal and vertical size class, as UIKit says
//     orient 3                  the scene's interface orientation
//     device 1                  how the phone is held (UIDeviceOrientation), lock or no lock
//     fold 0.0 461.5 669.0 28.0 the active division (the crease), in view points
//     fold -                    ...or none: this OS reports divisions and there is none
//     occl 420.0 8.0 38.0 38.0  an active occlusion (the cover display's camera)
//
// A line is only there when the system answered it: no `hinge` on a device
// without one, no `fold` on an OS without reserved regions. There is no engine
// binding and no header from Godot in here, which is the point: the engine and
// this file do not have to agree about anything but some lines of text.
//
// ## Why the fold is read and not worked out
//
// The first version of this wrote the hinge angle alone, and the game decided
// "bent" from it and guessed where the crease was (5.5% of the long side,
// centred). The division region is the system's own answer to both questions:
// active only while the device is partly open, and its frame is where the
// crease actually is, margins included. On the cover display, which has no
// crease whatever the hinge says, it reports none, which the angle could not
// tell apart from a bent inner display.
//
// ## Why it is written against the Objective-C runtime and not the SDK
//
// UIHingeInteraction and the reserved regions arrived in iOS 27.1. Written
// against their headers this file would not compile on a runner whose Xcode is
// older. Looked up by name at run time it compiles anywhere, and on a device or
// an OS without them it reports what it can, which on an iPhone is the size of
// the glass. The one thing taken from the 27.1 headers when they are there is
// the names of the hinge status values, which Apple does not publish as numbers.
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
// Crash, or hold anything up. Every step that can fail returns quietly, every
// entry point is wrapped, the file is only written when what it says changes,
// and nothing is attached until the app has a window — so a game on a device
// where any of this is wrong plays exactly as it did before the file existed.

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const kHingeFile = @"hinge.txt";
// How often the size, the regions and the orientation lock are looked at. The
// hinge itself reports as it moves; these have no callback a plain view can use.
static const NSTimeInterval kTick = 0.15;

static id sInteraction = nil;
static __weak UIView *sHost = nil;
static NSTimer *sTimer = nil;
static BOOL sHinge = NO;
static NSInteger sStatus = 0;
static double sAngle = 0.0;
static NSString *sLast = nil;
static NSUInteger sMask = 0;

static void HingeWrite(NSString *text) {
	if ([text isEqualToString:sLast]) {
		return;
	}
	sLast = [text copy];

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
		[text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
	}
}

// The status's own name, where the SDK this was compiled with has the enum. Apple
// documents the four cases and not their numbers, so the number alone means
// nothing; built without the 27.1 headers this says "-" and the game goes by the
// fold region, then the angle.
static NSString *StatusName(NSInteger status) {
#if defined(__IPHONE_27_1) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_1
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
	if (status == UIHingeStatusClosed) {
		return @"closed";
	}
	if (status == UIHingeStatusPartiallyOpen) {
		return @"partial";
	}
	if (status == UIHingeStatusFullyOpen) {
		return @"open";
	}
	if (status == UIHingeStatusUnknown) {
		return @"unknown";
	}
#pragma clang diagnostic pop
#endif
	return @"-";
}

// The view the game draws into: the root view of Godot's own window, found by its
// controller's class prefix; failing that the key window's, failing that any.
static UIView *HostView(void) {
	UIApplication *app = [UIApplication sharedApplication];
	if (app == nil) {
		return nil;
	}
	UIView *key = nil;
	UIView *any = nil;
	for (UIScene *scene in app.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		for (UIWindow *window in ((UIWindowScene *)scene).windows) {
			UIViewController *vc = window.rootViewController;
			UIView *v = vc.viewIfLoaded;
			if (v == nil) {
				continue;
			}
			if ([NSStringFromClass([vc class]) hasPrefix:@"GDT"]) {
				return v;
			}
			if (window.isKeyWindow && key == nil) {
				key = v;
			}
			if (any == nil) {
				any = v;
			}
		}
	}
	return key != nil ? key : any;
}

static void Report(void);

// Puts the hinge interaction on `host`, or moves it there if the game's view has
// changed. On an OS without the class this does nothing, every time, cheaply.
static void Attach(UIView *host) {
	if (sInteraction != nil) {
		if (sHost != host) {
			[sHost removeInteraction:(id<UIInteraction>)sInteraction];
			[host addInteraction:(id<UIInteraction>)sInteraction];
			sHost = host;
		}
		return;
	}
	Class cls = NSClassFromString(@"UIHingeInteraction");
	if (cls == Nil) {
		return; // an OS without a hinge
	}
	SEL initSel = NSSelectorFromString(@"initWithUpdateHandler:");
	if (![cls instancesRespondToSelector:initSel]) {
		return;
	}

	void (^handler)(id, id) = ^(id interaction, id update) {
		@try {
			id hinge = [update valueForKey:@"hinge"];
			if (hinge == nil || hinge == (id)[NSNull null]) {
				return; // left the hierarchy: keep the last word rather than guess
			}
			sStatus = [[hinge valueForKey:@"status"] integerValue];
			sAngle = [[hinge valueForKey:@"angle"] doubleValue];
			sHinge = YES;
			Report();
		} @catch (NSException *e) {
		}
	};

	id obj = [cls alloc];
	id (*initFn)(id, SEL, id) = (id(*)(id, SEL, id))objc_msgSend;
	id interaction = initFn(obj, initSel, handler);
	if (interaction == nil) {
		return;
	}
	[host addInteraction:(id<UIInteraction>)interaction];
	sInteraction = interaction;
	sHost = host;
}

// `+[UIViewReservedRegionKind divisionRegionKind]` and its sibling, by name.
static id RegionKind(NSString *name) {
	Class k = NSClassFromString(@"UIViewReservedRegionKind");
	SEL s = NSSelectorFromString(name);
	if (k == Nil || ![k respondsToSelector:s]) {
		return nil;
	}
	id (*fn)(id, SEL) = (id(*)(id, SEL))objc_msgSend;
	return fn(k, s);
}

// The active reserved regions of one kind over `view`, or nil where the OS has
// no such thing — which is different from an empty array, an OS that has them
// and reports none.
static NSArray *Regions(UIView *view, NSString *kindName) {
	SEL q = NSSelectorFromString(@"reservedRegionsOfKind:");
	if (![view respondsToSelector:q]) {
		return nil;
	}
	id kind = RegionKind(kindName);
	if (kind == nil) {
		return nil;
	}
	id (*fn)(id, SEL, id) = (id(*)(id, SEL, id))objc_msgSend;
	id out = fn(view, q, kind);
	return [out isKindOfClass:[NSArray class]] ? (NSArray *)out : @[];
}

static void AppendRegions(NSMutableString *out, NSArray *regions, NSString *tag) {
	for (id r in regions) {
		if (![[r valueForKey:@"active"] boolValue]) {
			continue;
		}
		CGRect f = [[r valueForKey:@"frame"] CGRectValue];
		[out appendFormat:@"%@ %.1f %.1f %.1f %.1f\n", tag, f.origin.x, f.origin.y,
				f.size.width, f.size.height];
	}
}

// Make UIKit ask the game again which ways it may be held, whenever the answer
// has changed.
//
// The game locks the cover display to portrait and frees the inner one, through
// Godot, which answers `supportedInterfaceOrientations` from that setting. But
// since iOS 16 the system only asks when told the answer has changed, so a lock
// set while the glass was landscape was not acted on until the phone was turned
// by hand: closed from a landscape inner display, the cover screen stayed on its
// side. This is the telling, and if the glass is held a way that is no longer
// allowed, the request to turn.
static void FollowOrientationLock(UIView *host) {
	if (@available(iOS 16.0, *)) {
		UIViewController *vc = host.window.rootViewController;
		UIWindowScene *scene = host.window.windowScene;
		if (vc == nil || scene == nil) {
			return;
		}
		UIInterfaceOrientationMask mask = vc.supportedInterfaceOrientations;
		if (mask == sMask) {
			return;
		}
		sMask = mask;
		[vc setNeedsUpdateOfSupportedInterfaceOrientations];
		UIInterfaceOrientation now = scene.effectiveGeometry.interfaceOrientation;
		if (now != UIInterfaceOrientationUnknown && (mask & (1 << now)) == 0) {
			UIWindowSceneGeometryPreferencesIOS *prefs =
					[[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask];
			[scene requestGeometryUpdateWithPreferences:prefs errorHandler:nil];
		}
	}
}

static void Report(void) {
	@try {
		UIView *host = HostView();
		if (host == nil) {
			return; // no window yet; the timer asks again
		}
		Attach(host);
		FollowOrientationLock(host);

		NSMutableString *out = [NSMutableString string];
		if (sHinge) {
			// Twentieths of a radian, three degrees: fine enough for "how bent",
			// coarse enough that folding the phone is not a file write per frame.
			[out appendFormat:@"hinge %ld %.2f %@\n", (long)sStatus,
					round(sAngle * 20.0) / 20.0, StatusName(sStatus)];
		}
		CGSize b = host.bounds.size;
		[out appendFormat:@"view %.1f %.1f\n", b.width, b.height];
		UITraitCollection *tc = host.traitCollection;
		[out appendFormat:@"class %ld %ld\n", (long)tc.horizontalSizeClass,
				(long)tc.verticalSizeClass];
		if (@available(iOS 16.0, *)) {
			UIWindowScene *scene = host.window.windowScene;
			if (scene != nil) {
				[out appendFormat:@"orient %ld\n",
						(long)scene.effectiveGeometry.interfaceOrientation];
			}
		}
		// The sensor's answer, which the cover display's portrait lock does not
		// change: it is how the game knows the phone was turned on its side
		// before it was opened, and so which way up the inner display should be.
		[out appendFormat:@"device %ld\n", (long)[UIDevice currentDevice].orientation];
		NSArray *division = Regions(host, @"divisionRegionKind");
		if (division != nil) {
			NSUInteger before = out.length;
			AppendRegions(out, division, @"fold");
			if (out.length == before) {
				[out appendString:@"fold -\n"];
			}
		}
		NSArray *occlusion = Regions(host, @"occlusionRegionKind");
		if (occlusion != nil) {
			AppendRegions(out, occlusion, @"occl");
		}
		HingeWrite(out);
	} @catch (NSException *e) {
	}
}

static void Start(void) {
	if (sTimer != nil) {
		return;
	}
	// UIDevice only tracks the sensor while somebody has asked it to. Never
	// ended: the game wants it for as long as it runs.
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	sTimer = [NSTimer timerWithTimeInterval:kTick
									repeats:YES
									  block:^(NSTimer *t) {
										  Report();
									  }];
	[[NSRunLoop mainRunLoop] addTimer:sTimer forMode:NSRunLoopCommonModes];
}

// Called by the engine at startup, through the plugin's `initialization` entry.
// C++ linkage on purpose: see the note at the top.
void hinge_bridge_init() {
	dispatch_async(dispatch_get_main_queue(), ^{
		@try {
			Start();
			Report();
		} @catch (NSException *e) {
		}
	});
}

void hinge_bridge_deinit() {
	[sTimer invalidate];
	sTimer = nil;
	sInteraction = nil;
}
