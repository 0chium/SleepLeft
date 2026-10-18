#import <UIKit/UIKit.h>
#import <Accessibility/Accessibility.h>
#import <objc/runtime.h>
#import <substrate.h>
#include "Countdown.h"

// Minimal declarations independently written from inspected interface contracts.
@interface FMMAlarm : NSObject
- (BOOL)isSleepAlarm;
- (BOOL)isEnabled;
- (NSDate *)nextFireDateAfterDate:(NSDate *)date;
@end
@interface FMMCell : UITableViewCell <AXCustomContentProvider>
- (UILabel *)detailLabel;
- (UIView *)digitalClockLabel;
@end

@interface FMMState : NSObject
@property(nonatomic, strong) FMMAlarm *alarm;
@property(nonatomic, copy) NSString *base;
@property(nonatomic, strong) NSDate *occurrence;
@property(nonatomic, strong) NSLayoutConstraint *nativeWidth;
@property(nonatomic, strong) NSLayoutConstraint *expandedWidth;
@end
@implementation FMMState
@end

static char stateKey;
static FMMState *State(id cell) { return objc_getAssociatedObject(cell, &stateKey); }

// Validate ABI shape before installing hooks or calling private methods.
static BOOL Contract(Class cls, SEL selector, const char *result, NSArray<NSString *> *args) {
    Method m = class_getInstanceMethod(cls, selector);
    if (!m || method_getNumberOfArguments(m) != args.count + 2) return NO;
    char *type = method_copyReturnType(m);
    BOOL ok = type && strcmp(type, result) == 0;
    free(type);
    for (NSUInteger i = 0; ok && i < args.count; ++i) {
        type = method_copyArgumentType(m, (unsigned int)i + 2);
        ok = type && strcmp(type, args[i].UTF8String) == 0;
        free(type);
    }
    return ok;
}

static void Clear(FMMCell *cell) {
    FMMState *s = State(cell);
    if (!s) return;
    cell.detailLabel.text = s.base;
    s.expandedWidth.active = NO;
    s.nativeWidth.active = YES;
    objc_setAssociatedObject(cell, &stateKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *FMMFormatDuration(uint64_t seconds, BOOL spoken) {
    if (spoken) {
        // VoiceOver receives full units through Apple's formatter, on demand.
        NSDateComponentsFormatter *f = [NSDateComponentsFormatter new];
        f.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
        f.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
        return [f stringFromTimeInterval:(NSTimeInterval)seconds];
    }
    return [NSString stringWithFormat:@"%llu hrs %llu mins %llu secs",
        (unsigned long long)(seconds / 3600),
        (unsigned long long)((seconds / 60) % 60),
        (unsigned long long)(seconds % 60)];
}

// AXCustomContentProvider is a protocol, not a writable UIView property.
// Supply its accessor pair only on the specific Clock cell. Preserve any native
// content and construct our immutable AXCustomContent only when queried.
static char customContentKey;
static NSArray *(*OriginalCustomContent)(id, SEL);
static void (*OriginalSetCustomContent)(id, SEL, NSArray *);
static NSArray *CustomContent(FMMCell *cell, SEL cmd) {
    NSArray *native = OriginalCustomContent ? OriginalCustomContent(cell, cmd)
        : objc_getAssociatedObject(cell, &customContentKey);
    NSMutableArray *items = [native isKindOfClass:NSArray.class] ? [native mutableCopy] : [NSMutableArray array];
    FMMState *s = State(cell);
    NSTimeInterval remaining = [s.occurrence timeIntervalSinceNow];
    if (s && std::isfinite(remaining) && remaining > 0) {
        NSString *label = s.alarm.isEnabled ? @"Time remaining" : @"Configured time remaining";
        AXCustomContent *content = [AXCustomContent customContentWithLabel:label
            value:FMMFormatDuration(FMMSeconds(remaining), YES)];
        [items addObject:content];
    }
    return items;
}
static void SetCustomContent(FMMCell *cell, SEL cmd, NSArray *items) {
    if (OriginalSetCustomContent) OriginalSetCustomContent(cell, cmd, items);
    else objc_setAssociatedObject(cell, &customContentKey, items, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

static BOOL Render(FMMCell *cell, NSDate *now) {
    FMMState *s = State(cell);
    if (!s) return NO;
    if (!s.occurrence || [s.occurrence compare:now] != NSOrderedDescending) {
        // No copy, mutation, manager call, persistence or recurrence arithmetic.
        id date = [s.alarm nextFireDateAfterDate:now];
        s.occurrence = [date isKindOfClass:NSDate.class] && [date compare:now] == NSOrderedDescending ? date : nil;
    }
    UILabel *label = cell.detailLabel;
    CGFloat width = CGRectGetWidth(label.bounds);
    CGFloat before = width > 0 ? [label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height : 0;
    if (!s.occurrence) {
        label.text = s.base;
        return NO;
    }
    uint64_t seconds = FMMSeconds([s.occurrence timeIntervalSinceDate:now]);
    NSString *suffix = FMMFormatDuration(seconds, NO);
    label.text = s.base.length ? [NSString stringWithFormat:@"%@ - %@", s.base, suffix] : suffix;
    CGFloat after = width > 0 ? [label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height : 0;
    return fabs(before - after) > 0.5;
}

@interface FMMCoordinator : NSObject
@property(nonatomic, weak) UITableViewController *controller;
@property(nonatomic, strong) NSTimer *timer;
+ (instancetype)shared;
- (void)reconcile;
- (void)stop;
- (void)invalidateDates;
@end
@implementation FMMCoordinator
+ (instancetype)shared {
    static FMMCoordinator *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [self new]; });
    return shared;
}
- (instancetype)init {
    if ((self = [super init])) {
        NSNotificationCenter *n = NSNotificationCenter.defaultCenter;
        for (NSString *name in @[UIApplicationDidBecomeActiveNotification, UISceneDidActivateNotification,
                UIApplicationSignificantTimeChangeNotification, NSSystemTimeZoneDidChangeNotification,
                NSSystemClockDidChangeNotification, NSCurrentLocaleDidChangeNotification,
                UIContentSizeCategoryDidChangeNotification]) {
            [n addObserver:self selector:@selector(changed:) name:name object:nil];
        }
        for (NSString *name in @[UIApplicationWillResignActiveNotification, UISceneWillDeactivateNotification]) {
            [n addObserver:self selector:@selector(inactive:) name:name object:nil];
        }
    }
    return self;
}
- (void)changed:(NSNotification *)note {
    (void)note;
    // UIKit and model access stay on the main thread, including system events.
    dispatch_async(dispatch_get_main_queue(), ^{ [self invalidateDates]; [self reconcile]; });
}
- (void)inactive:(NSNotification *)note { (void)note; [self stop]; }
- (void)stop { [self.timer invalidate]; self.timer = nil; }
- (void)invalidateDates {
    for (id cell in self.controller.tableView.visibleCells) State(cell).occurrence = nil;
}
- (BOOL)canUpdate {
    UIWindow *window = self.controller.viewIfLoaded.window;
    return window && !window.hidden && UIApplication.sharedApplication.applicationState == UIApplicationStateActive
        && window.windowScene.activationState == UISceneActivationStateForegroundActive;
}
- (NSUInteger)renderVisible {
    NSDate *now = NSDate.date;
    NSUInteger count = 0;
    BOOL heightChanged = NO;
    UITableView *table = self.controller.tableView;
    for (FMMCell *cell in table.visibleCells) {
        if (State(cell)) {
            heightChanged |= Render(cell, now);
            if (State(cell).occurrence) ++count;
        }
    }
    // Native automatic row sizing, only when text actually changes height.
    if (heightChanged && !table.hasUncommittedUpdates) { [table beginUpdates]; [table endUpdates]; }
    return count;
}
- (void)reconcile {
    if (![self canUpdate] || ![self renderVisible]) { [self stop]; return; }
    if (self.timer) return;
    __weak FMMCoordinator *weakSelf = self;
    self.timer = [NSTimer timerWithTimeInterval:1 repeats:YES block:^(NSTimer *timer) {
        (void)timer;
        FMMCoordinator *coordinator = weakSelf;
        if (![coordinator canUpdate] || ![coordinator renderVisible]) [coordinator stop];
    }];
    self.timer.fireDate = [NSDate dateWithTimeIntervalSince1970:floor(NSDate.date.timeIntervalSince1970) + 1];
    self.timer.tolerance = 0.05;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}
@end

static void (*OriginalRefresh)(FMMCell *, SEL, FMMAlarm *, BOOL);
static void Refresh(FMMCell *cell, SEL cmd, FMMAlarm *alarm, BOOL animated) {
    Clear(cell);
    OriginalRefresh(cell, cmd, alarm, animated);
    if (!alarm || !Contract(alarm.class, @selector(isSleepAlarm), "B", @[])
        || !Contract(alarm.class, @selector(isEnabled), "B", @[])
        || !Contract(alarm.class, @selector(nextFireDateAfterDate:), "@", @[@"@"]) || alarm.isSleepAlarm) return;
    if (![cell.detailLabel isKindOfClass:UILabel.class]) return;
    FMMState *s = [FMMState new];
    s.alarm = alarm;
    s.base = cell.detailLabel.text ?: @"";
    // Native shared layout pins the subtitle to the time label's narrow width.
    // Replace only that exact relationship to use the row's available width.
    for (NSLayoutConstraint *c in cell.contentView.constraints) {
        if (c.active && c.firstItem == cell.detailLabel && c.firstAttribute == NSLayoutAttributeTrailing
            && c.secondItem == cell.digitalClockLabel && c.secondAttribute == NSLayoutAttributeTrailing
            && c.relation == NSLayoutRelationEqual && c.multiplier == 1 && c.constant == 0) {
            s.nativeWidth = c;
            break;
        }
    }
    if (!s.nativeWidth) return; // Unsupported layout: leave Apple's row intact.
    s.expandedWidth = [cell.detailLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor];
    s.expandedWidth.priority = s.nativeWidth.priority;
    s.nativeWidth.active = NO;
    s.expandedWidth.active = YES;
    objc_setAssociatedObject(cell, &stateKey, s, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    Render(cell, NSDate.date);
    dispatch_async(dispatch_get_main_queue(), ^{ [[FMMCoordinator shared] reconcile]; });
}

static void (*OriginalReuse)(FMMCell *, SEL);
static void Reuse(FMMCell *cell, SEL cmd) { Clear(cell); OriginalReuse(cell, cmd); }
static void (*OriginalMove)(FMMCell *, SEL);
static void Move(FMMCell *cell, SEL cmd) {
    OriginalMove(cell, cmd);
    dispatch_async(dispatch_get_main_queue(), ^{ [[FMMCoordinator shared] reconcile]; });
}
static void (*OriginalAppear)(UITableViewController *, SEL, BOOL);
static void Appear(UITableViewController *controller, SEL cmd, BOOL animated) {
    OriginalAppear(controller, cmd, animated);
    FMMCoordinator *coordinator = [FMMCoordinator shared];
    coordinator.controller = controller;
    [coordinator invalidateDates];
    [coordinator reconcile];
}
static void (*OriginalDisappear)(UITableViewController *, SEL, BOOL);
static void Disappear(UITableViewController *controller, SEL cmd, BOOL animated) {
    FMMCoordinator *coordinator = [FMMCoordinator shared];
    if (coordinator.controller == controller) { [coordinator stop]; coordinator.controller = nil; }
    OriginalDisappear(controller, cmd, animated);
}

__attribute__((constructor)) static void Initialize(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.mobiletimer"]) return;
    NSOperatingSystemVersion os = NSProcessInfo.processInfo.operatingSystemVersion;
    if (os.majorVersion < 17 || os.majorVersion > 18) return;
    Class cell = NSClassFromString(@"MTAAlarmTableViewCell");
    Class controller = NSClassFromString(@"MTAAlarmTableViewController");
    if (!cell || !controller || ![cell isSubclassOfClass:UITableViewCell.class]
        || ![controller isSubclassOfClass:UITableViewController.class]
        || !Contract(cell, @selector(refreshUI:animated:), "v", @[@"@", @"B"])
        || !Contract(cell, @selector(detailLabel), "@", @[])
        || !Contract(cell, @selector(digitalClockLabel), "@", @[])
        || !Contract(cell, @selector(prepareForReuse), "v", @[])
        || !Contract(cell, @selector(didMoveToWindow), "v", @[])
        || !Contract(controller, @selector(viewDidAppear:), "v", @[@"B"])
        || !Contract(controller, @selector(viewWillDisappear:), "v", @[@"B"])) return;
    SEL content = @selector(accessibilityCustomContent);
    SEL setContent = @selector(setAccessibilityCustomContent:);
    BOOL hasContent = class_getInstanceMethod(cell, content) != NULL;
    BOOL hasSetter = class_getInstanceMethod(cell, setContent) != NULL;
    if ((hasContent && !Contract(cell, content, "@", @[]))
        || (hasSetter && !Contract(cell, setContent, "v", @[@"@"]))) return;
    if (hasContent) MSHookMessageEx(cell, content, (IMP)CustomContent, (IMP *)&OriginalCustomContent);
    else class_addMethod(cell, content, (IMP)CustomContent, "@@:");
    if (hasSetter) MSHookMessageEx(cell, setContent, (IMP)SetCustomContent, (IMP *)&OriginalSetCustomContent);
    else class_addMethod(cell, setContent, (IMP)SetCustomContent, "v@:@");
    class_addProtocol(cell, @protocol(AXCustomContentProvider));
    MSHookMessageEx(cell, @selector(refreshUI:animated:), (IMP)Refresh, (IMP *)&OriginalRefresh);
    MSHookMessageEx(cell, @selector(prepareForReuse), (IMP)Reuse, (IMP *)&OriginalReuse);
    MSHookMessageEx(cell, @selector(didMoveToWindow), (IMP)Move, (IMP *)&OriginalMove);
    MSHookMessageEx(controller, @selector(viewDidAppear:), (IMP)Appear, (IMP *)&OriginalAppear);
    MSHookMessageEx(controller, @selector(viewWillDisappear:), (IMP)Disappear, (IMP *)&OriginalDisappear);
}
