/*
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 *
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AIContactStatusColoringPlugin.h"
#import "AIAbstractListController.h"
#import "AIListThemeWindowController.h"
#import <AIUtilities/AIColorAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIMutableOwnerArray.h>
#import <Adium/AIChat.h>
#import <Adium/AIContactControllerProtocol.h>
#import <Adium/AIContentTyping.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIListBookmark.h>
#import <Adium/AIListContact.h>
#import <Adium/AIListObject.h>
#import <Adium/AIMetaContact.h>

@interface AIContactStatusColoringPlugin ()
- (void)addToFlashSet:(AIListObject *)inObject;
- (void)removeFromFlashSet:(AIListObject *)inObject;
- (void)_applyColorToContact:(AIListContact *)inObject;
@end

@implementation AIContactStatusColoringPlugin

#define OFFLINE_IMAGE_OPACITY 0.5f
#define FULL_IMAGE_OPACITY 1.0f
#define OPACITY_REFRESH 0.2f

#define CONTACT_STATUS_COLORING_DEFAULT_PREFS @"ContactStatusColoringDefaults"

- (void)installPlugin
{
	// init
	flashingListObjects = 
		mobileLabelColor = nil;

		if ((awayEnabled = [[prefDict objectForKey:KEY_AWAY_ENABLED] boolValue])) {
			awayColor = [[[prefDict objectForKey:KEY_AWAY_COLOR] representedColor] retain];
			awayLabelColor = [[[prefDict objectForKey:KEY_LABEL_AWAY_COLOR] representedColor] retain];
			awayInvertedColor = [[awayColor colorWithInvertedLuminance] retain];
		}

		if ((idleEnabled = [[prefDict objectForKey:KEY_IDLE_ENABLED] boolValue])) {
			idleColor = [[[prefDict objectForKey:KEY_IDLE_COLOR] representedColor] retain];
			idleLabelColor = [[[prefDict objectForKey:KEY_LABEL_IDLE_COLOR] representedColor] retain];
			idleInvertedColor = [[idleColor colorWithInvertedLuminance] retain];
		}

		if ((signedOnEnabled = [[prefDict objectForKey:KEY_SIGNED_ON_ENABLED] boolValue])) {
			signedOnColor = [[[prefDict objectForKey:KEY_SIGNED_ON_COLOR] representedColor] retain];
			signedOnLabelColor = [[[prefDict objectForKey:KEY_LABEL_SIGNED_ON_COLOR] representedColor] retain];
			signedOnInvertedColor = [[signedOnColor colorWithInvertedLuminance] retain];
		}

		if ((signedOffEnabled = [[prefDict objectForKey:KEY_SIGNED_OFF_ENABLED] boolValue])) {
			signedOffColor = [[[prefDict objectForKey:KEY_SIGNED_OFF_COLOR] representedColor] retain];
			signedOffLabelColor = [[[prefDict objectForKey:KEY_LABEL_SIGNED_OFF_COLOR] representedColor] retain];
			signedOffInvertedColor = [[signedOffColor colorWithInvertedLuminance] retain];
		}

		if ((typingEnabled = [[prefDict objectForKey:KEY_TYPING_ENABLED] boolValue])) {
			typingColor = [[[prefDict objectForKey:KEY_TYPING_COLOR] representedColor] retain];
			typingLabelColor = [[[prefDict objectForKey:KEY_LABEL_TYPING_COLOR] representedColor] retain];
			typingInvertedColor = [[typingColor colorWithInvertedLuminance] retain];
		}

		if ((unviewedContentEnabled = [[prefDict objectForKey:KEY_UNVIEWED_ENABLED] boolValue])) {
			unviewedContentColor = [[[prefDict objectForKey:KEY_UNVIEWED_COLOR] representedColor] retain];
			unviewedContentLabelColor = [[[prefDict objectForKey:KEY_LABEL_UNVIEWED_COLOR] representedColor] retain];
			unviewedContentInvertedColor = [[unviewedContentColor colorWithInvertedLuminance] retain];
		}

		if ((onlineEnabled = [[prefDict objectForKey:KEY_ONLINE_ENABLED] boolValue])) {
			onlineColor = [[[prefDict objectForKey:KEY_ONLINE_COLOR] representedColor] retain];
			onlineLabelColor = [[[prefDict objectForKey:KEY_LABEL_ONLINE_COLOR] representedColor] retain];
			onlineInvertedColor = [[onlineColor colorWithInvertedLuminance] retain];
		}

		if ((awayAndIdleEnabled = [[prefDict objectForKey:KEY_IDLE_AWAY_ENABLED] boolValue])) {
			awayAndIdleColor = [[[prefDict objectForKey:KEY_IDLE_AWAY_COLOR] representedColor] retain];
			awayAndIdleLabelColor = [[[prefDict objectForKey:KEY_LABEL_IDLE_AWAY_COLOR] representedColor] retain];
			awayAndIdleInvertedColor = [[awayAndIdleColor colorWithInvertedLuminance] retain];
		}

		if ((offlineEnabled = [[prefDict objectForKey:KEY_OFFLINE_ENABLED] boolValue])) {
			offlineColor = [[[prefDict objectForKey:KEY_OFFLINE_COLOR] representedColor] retain];
			offlineLabelColor = [[[prefDict objectForKey:KEY_LABEL_OFFLINE_COLOR] representedColor] retain];
			offlineInvertedColor = [[offlineColor colorWithInvertedLuminance] retain];
		}

		if ((mobileEnabled = [[prefDict objectForKey:KEY_MOBILE_ENABLED] boolValue])) {
			mobileColor = [[[prefDict objectForKey:KEY_MOBILE_COLOR] representedColor] retain];
			mobileLabelColor = [[[prefDict objectForKey:KEY_LABEL_MOBILE_COLOR] representedColor] retain];
			mobileInvertedColor = [[mobileColor colorWithInvertedLuminance] retain];
		}

		offlineImageFading = [[prefDict objectForKey:KEY_LIST_THEME_FADE_OFFLINE_IMAGES] boolValue];

		// Update all objects
		if (!firstTime) {
			[[AIContactObserverManager sharedManager] updateAllListObjectsForObserver:self];
		}

	} else if ([group isEqualToString:PREF_GROUP_CONTACT_LIST]) {
		BOOL oldFlashUnviewedContentEnabled = flashUnviewedContentEnabled;

		flashUnviewedContentEnabled = [[prefDict objectForKey:KEY_CL_FLASH_UNVIEWED_CONTENT] boolValue];

		if (oldFlashUnviewedContentEnabled && !flashUnviewedContentEnabled) {
			// Clear our flash set if we aren't flashing for unviewed content now but we were before
			for (AIListContact *listContact in [[flashingListObjects copy] autorelease]) {
				[self removeFromFlashSet:listContact];
			}

			// Make our colors end up right (if we were on an off-flash) by updating all list objects
			[[AIContactObserverManager sharedManager] updateAllListObjectsForObserver:self];
		} else if (!oldFlashUnviewedContentEnabled && flashUnviewedContentEnabled) {
			if (!firstTime) {
				// Update all list objects so we start flashing
				[[AIContactObserverManager sharedManager] updateAllListObjectsForObserver:self];
			}
		}
	}
}

@end
