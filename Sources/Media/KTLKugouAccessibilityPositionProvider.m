#import "KTLKugouAccessibilityPositionProvider.h"
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <math.h>

static NSString *const KTLKugouBundleIdentifier = @"com.kugou.mac.Music";
static NSString *const KTLKugouElapsedIdentifier = @"listen_playView_playedTime_Label";
static NSString *const KTLKugouDurationIdentifier = @"listen_playView_fullTime_Label";

static id KTLAXCopyAttribute(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = NULL;
    AXError error = AXUIElementCopyAttributeValue(element, attribute, &value);
    if (error != kAXErrorSuccess || !value) return nil;
    return CFBridgingRelease(value);
}

static AXUIElementRef KTLFindElement(AXUIElementRef element,
                                    NSString *targetIdentifier,
                                    NSUInteger depth,
                                    NSUInteger *visited) {
    if (!element || depth > 18 || *visited >= 12000) return NULL;
    (*visited)++;
    NSString *identifier = KTLAXCopyAttribute(element, kAXIdentifierAttribute);
    if ([identifier isEqualToString:targetIdentifier]) {
        return (AXUIElementRef)CFRetain(element);
    }

    NSArray *children = KTLAXCopyAttribute(element, kAXChildrenAttribute);
    if (![children isKindOfClass:NSArray.class]) return NULL;
    for (id child in children) {
        AXUIElementRef result = KTLFindElement((__bridge AXUIElementRef)child,
                                              targetIdentifier,
                                              depth + 1,
                                              visited);
        if (result) return result;
    }
    return NULL;
}

static NSString *KTLTimeTextForElement(AXUIElementRef element) {
    id rawText = KTLAXCopyAttribute(element, kAXDescriptionAttribute);
    if (![rawText isKindOfClass:NSString.class] || [rawText length] == 0) {
        rawText = KTLAXCopyAttribute(element, kAXValueAttribute);
    }
    return [rawText isKindOfClass:NSString.class] ? rawText : nil;
}

@implementation KTLKugouAccessibilityPositionProvider

+ (BOOL)parseElapsedTimeText:(NSString *)text elapsed:(NSTimeInterval *)elapsed {
    if (![text isKindOfClass:NSString.class]) return NO;
    NSString *trimmed = [text stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *components = [trimmed componentsSeparatedByString:@":"];
    if (components.count != 2 && components.count != 3) return NO;

    NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
    NSMutableArray<NSNumber *> *numbers = [NSMutableArray arrayWithCapacity:components.count];
    for (NSString *component in components) {
        if (component.length == 0 || [component rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
            return NO;
        }
        [numbers addObject:@(component.longLongValue)];
    }

    long long seconds = numbers.lastObject.longLongValue;
    if (seconds >= 60) return NO;
    long long total = 0;
    if (numbers.count == 2) {
        total = numbers[0].longLongValue * 60 + seconds;
    } else {
        long long minutes = numbers[1].longLongValue;
        if (minutes >= 60) return NO;
        total = numbers[0].longLongValue * 3600 + minutes * 60 + seconds;
    }
    if (total < 0) return NO;
    if (elapsed) *elapsed = (NSTimeInterval)total;
    return YES;
}

+ (BOOL)shouldAdoptElapsed:(NSTimeInterval)accessibilityElapsed
          estimatedElapsed:(NSTimeInterval)estimatedElapsed {
    if (!isfinite(accessibilityElapsed) || !isfinite(estimatedElapsed) || accessibilityElapsed < 0) {
        return NO;
    }
    return fabs(accessibilityElapsed - estimatedElapsed) >= 2.0;
}

+ (BOOL)isAccessibilityDuration:(NSTimeInterval)accessibilityDuration
  compatibleWithExpectedDuration:(NSTimeInterval)expectedDuration {
    if (!isfinite(accessibilityDuration) || !isfinite(expectedDuration) ||
        accessibilityDuration <= 0 || expectedDuration <= 0) {
        return NO;
    }
    return fabs(accessibilityDuration - expectedDuration) < 4.0;
}

- (BOOL)isAuthorized {
    return AXIsProcessTrusted();
}

- (BOOL)requestAuthorization {
    NSDictionary *options = @{ (__bridge id)kAXTrustedCheckOptionPrompt: @YES };
    return AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (NSNumber *)currentElapsedTimeForExpectedDuration:(NSTimeInterval)expectedDuration {
    if (!self.isAuthorized) return nil;
    NSArray<NSRunningApplication *> *applications =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:KTLKugouBundleIdentifier];
    for (NSRunningApplication *application in applications) {
        if (application.terminated) continue;
        AXUIElementRef applicationElement = AXUIElementCreateApplication(application.processIdentifier);
        NSUInteger elapsedVisited = 0;
        AXUIElementRef elapsedElement = KTLFindElement(applicationElement,
                                                      KTLKugouElapsedIdentifier,
                                                      0,
                                                      &elapsedVisited);
        NSUInteger durationVisited = 0;
        AXUIElementRef durationElement = KTLFindElement(applicationElement,
                                                       KTLKugouDurationIdentifier,
                                                       0,
                                                       &durationVisited);
        CFRelease(applicationElement);
        if (!elapsedElement || !durationElement) {
            if (elapsedElement) CFRelease(elapsedElement);
            if (durationElement) CFRelease(durationElement);
            continue;
        }

        NSString *elapsedText = KTLTimeTextForElement(elapsedElement);
        NSString *durationText = KTLTimeTextForElement(durationElement);
        CFRelease(elapsedElement);
        CFRelease(durationElement);
        NSTimeInterval elapsed = 0;
        NSTimeInterval duration = 0;
        if ([KTLKugouAccessibilityPositionProvider parseElapsedTimeText:elapsedText elapsed:&elapsed] &&
            [KTLKugouAccessibilityPositionProvider parseElapsedTimeText:durationText elapsed:&duration] &&
            [KTLKugouAccessibilityPositionProvider isAccessibilityDuration:duration
                                              compatibleWithExpectedDuration:expectedDuration]) {
            return @(elapsed);
        }
    }
    return nil;
}

@end
