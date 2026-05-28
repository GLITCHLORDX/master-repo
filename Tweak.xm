#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isRingerMuted;
- (void)setRingerMuted:(BOOL)muted;
- (void)_setRingerMuted:(BOOL)muted;
@end

static UIWindow *glhFallbackWindow = nil;
static UIView *glhPill = nil;
static dispatch_block_t glhHideBlock = nil;
static NSTimeInterval glhLastShowTime = 0;
static BOOL glhLastKnownSilent = NO;

static BOOL GLHIsSilent(void) {
    Class cls = NSClassFromString(@"SBMediaController");
    if (cls && [cls respondsToSelector:@selector(sharedInstance)]) {
        id media = [cls sharedInstance];
        if (media && [media respondsToSelector:@selector(isRingerMuted)]) {
            return ((BOOL (*)(id, SEL))objc_msgSend)(media, @selector(isRingerMuted));
        }
    }
    return glhLastKnownSilent;
}

static NSString *GLHIconPath(BOOL silent) {
    NSString *name = silent ? @"bell_silent_red.png" : @"bell_normal_gray.png";
    NSString *path = [@"/Library/Application Support/SilentPillHUD" stringByAppendingPathComponent:name];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) return path;
    return [[@"/Library/MobileSubstrate/DynamicLibraries/SilentPillHUD.bundle" stringByAppendingPathComponent:name] copy];
}

static UIWindow *GLHFrontSpringBoardWindow(void) {
    NSArray *windows = [[UIApplication sharedApplication] windows];
    UIWindow *best = nil;
    CGFloat bestLevel = -CGFLOAT_MAX;

    for (UIWindow *w in windows) {
        if (!w || w == glhFallbackWindow || w.hidden || w.alpha <= 0.01) continue;
        if (CGRectIsEmpty(w.bounds)) continue;
        if (w.windowLevel >= bestLevel) {
            best = w;
            bestLevel = w.windowLevel;
        }
    }

    return best;
}

static UIWindow *GLHFallbackWindow(void) {
    CGRect screen = [UIScreen mainScreen].bounds;

    if (!glhFallbackWindow) {
        glhFallbackWindow = [[UIWindow alloc] initWithFrame:screen];
        glhFallbackWindow.backgroundColor = [UIColor clearColor];
        glhFallbackWindow.userInteractionEnabled = NO;
        glhFallbackWindow.rootViewController = [UIViewController new];
        glhFallbackWindow.windowLevel = UIWindowLevelAlert + 10000.0;
    }

    glhFallbackWindow.frame = screen;
    glhFallbackWindow.hidden = NO;
    return glhFallbackWindow;
}

static UIView *GLHHUDHostView(void) {
    UIWindow *front = GLHFrontSpringBoardWindow();
    if (front) return front;
    return GLHFallbackWindow();
}

static CGFloat GLHSafeTopForView(UIView *host) {
    CGFloat top = 14.0;
    if (@available(iOS 11.0, *)) {
        CGFloat inset = host.safeAreaInsets.top;
        if (inset > 0) top = inset + 6.0;
    }
    return top;
}

static void GLHShowSilentPillWithState(BOOL silent) {
    dispatch_async(dispatch_get_main_queue(), ^{
        glhLastKnownSilent = silent;

        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - glhLastShowTime < 0.06) return;
        glhLastShowTime = now;

        UIView *host = GLHHUDHostView();
        if (!host) return;

        if (glhHideBlock) {
            dispatch_block_cancel(glhHideBlock);
            glhHideBlock = nil;
        }

        [glhPill removeFromSuperview];
        glhPill = nil;

        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat screenW = screen.size.width;

        CGFloat pillW = MIN(screenW - 92.0, 222.0);
        CGFloat pillH = 44.0;
        CGFloat pillX = (screenW - pillW) / 2.0;
        CGFloat pillY = GLHSafeTopForView(host);

        UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(pillX, pillY, pillW, pillH)];
        pill.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.40];
        pill.layer.cornerRadius = pillH / 2.0;
        pill.layer.masksToBounds = YES;
        pill.layer.borderWidth = 0.6;
        pill.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.10].CGColor;
        pill.alpha = 0.0;
        pill.transform = CGAffineTransformMakeScale(0.985, 0.985);

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = pill.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.alpha = 0.96;
        [pill addSubview:blurView];

        UIImageView *icon = [[UIImageView alloc] initWithFrame:CGRectMake(13.0, 7.0, 30.0, 30.0)];
        icon.image = [UIImage imageWithContentsOfFile:GLHIconPath(silent)];
        icon.contentMode = UIViewContentModeScaleAspectFit;
        icon.clipsToBounds = NO;
        [pill addSubview:icon];

        UIView *line = [[UIView alloc] initWithFrame:CGRectMake(55.0, 9.0, 0.8, 26.0)];
        line.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
        [pill addSubview:line];

        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(68.0, 7.0, pillW - 80.0, 17.0)];
        title.text = @"Silent Mode";
        title.textColor = [UIColor whiteColor];
        title.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        title.textAlignment = NSTextAlignmentLeft;
        title.backgroundColor = [UIColor clearColor];
        [pill addSubview:title];

        UILabel *status = [[UILabel alloc] initWithFrame:CGRectMake(68.0, 23.0, pillW - 80.0, 14.0)];
        status.text = silent ? @"On" : @"Off";
        status.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
        status.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        status.textAlignment = NSTextAlignmentLeft;
        status.backgroundColor = [UIColor clearColor];
        [pill addSubview:status];

        [host addSubview:pill];
        [host bringSubviewToFront:pill];
        glhPill = pill;

        [UIView animateWithDuration:0.14 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            pill.alpha = 1.0;
            pill.transform = CGAffineTransformIdentity;
        } completion:nil];

        glhHideBlock = dispatch_block_create(DISPATCH_BLOCK_INHERIT_QOS_CLASS, ^{
            [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                pill.alpha = 0.0;
                pill.transform = CGAffineTransformMakeScale(0.99, 0.99);
            } completion:^(BOOL finished) {
                [pill removeFromSuperview];
                if (glhPill == pill) glhPill = nil;
                if (glhFallbackWindow && glhFallbackWindow.subviews.count == 0) glhFallbackWindow.hidden = YES;
            }];
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), glhHideBlock);
    });
}

static void GLHShowSilentPill(void) {
    GLHShowSilentPillWithState(GLHIsSilent());
}

%hook SBHUDController

- (void)presentHUDView:(id)view autoDismissWithDelay:(double)delay {
    if ([view isKindOfClass:NSClassFromString(@"SBRingerHUDView")]) {
        GLHShowSilentPill();
        return;
    }
    %orig;
}

%end

%hook SBMediaController

- (void)setRingerMuted:(BOOL)muted {
    %orig;
    GLHShowSilentPillWithState(muted);
}

- (void)_setRingerMuted:(BOOL)muted {
    %orig;
    GLHShowSilentPillWithState(muted);
}

%end
