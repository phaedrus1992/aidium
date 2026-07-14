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

#import "ESStatusPreferences.h"
#import "AIStatusController.h"
#import "ESEditStatusGroupWindowController.h"
#import <AIUtilities/AIAlternatingRowOutlineView.h>
#import <AIUtilities/AIAutoScrollView.h>
#import <AIUtilities/AIImageAdditions.h>
#import <AIUtilities/AIImageDrawingAdditions.h>
#import <AIUtilities/AIImageTextCell.h>
#import <AIUtilities/AIOutlineViewAdditions.h>
#import <AIUtilities/AIVerticallyCenteredTextCell.h>
#import <Adium/AIAccount.h>
#import <Adium/AIAccountControllerProtocol.h>
#import <Adium/AIEditStateWindowController.h>
#import <Adium/AIStatusGroup.h>
#import <Adium/AIStatusMenu.h>

#define STATE_DRAG_TYPE @"AIState"

@interface ESStatusPreferences ()
- (void)configureOtherControls;
- (void)configureAutoAwayStatusStatePopUp;
- (void)saveTimeValues;
- (void)_selectStatusWithUniqueID:(NSNumber *)uniqueID inPopUpButton:(NSPopUpButton *)inPopUpButton;

- (void)reselectDraggedItems:(NSArray *)theDraggedItems;
- (void)changedAutoAwayStatus:(id)sender;
- (void)changedFastUserSwitchingStatus:(id)sender;
- (void)changedScreenSaverStatus:(id)sender;

- (BOOL)addItemIfNeeded:(NSMenuItem *)menuItem
		   toPopUpButton:(NSPopUpButton *)popUpButton
	alreadyShowingAnItem:(BOOL)alreadyShowing;

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

- (void)newState;
- (void)deleteState;
@end

@implementation ESStatusPreferences

- (NSString *)paneIdentifier
{
	return @"Status";
}
- (NSString *)paneName
{
	return AILocalizedString(@"Status", nil);
}
- (NSImage *)paneIcon
{
	return 
	return nowShowing;
}
- (void)changedAutoAwayStatus:(id)sender
{
	AIStatus *statusState = [[sender representedObject] objectForKey:@"AIStatus"];

	[adium.preferenceController setPreference:[statusState uniqueStatusID]
									   forKey:KEY_STATUS_AUTO_AWAY_STATUS_STATE_ID
										group:PREF_GROUP_STATUS_PREFERENCES];

	showingSubmenuItemInAutoAway = [self addItemIfNeeded:sender
										   toPopUpButton:popUp_autoAwayStatusState
									alreadyShowingAnItem:showingSubmenuItemInAutoAway];
}

- (void)changedFastUserSwitchingStatus:(id)sender
{
	AIStatus *statusState = [[sender representedObject] objectForKey:@"AIStatus"];

	[adium.preferenceController setPreference:[statusState uniqueStatusID]
									   forKey:KEY_STATUS_FUS_STATUS_STATE_ID
										group:PREF_GROUP_STATUS_PREFERENCES];

	showingSubmenuItemInFastUserSwitching = [self addItemIfNeeded:sender
													toPopUpButton:popUp_fastUserSwitchingStatusState
											 alreadyShowingAnItem:showingSubmenuItemInFastUserSwitching];
}

- (void)changedScreenSaverStatus:(id)sender
{
	AIStatus *statusState = [[sender representedObject] objectForKey:@"AIStatus"];

	[adium.preferenceController setPreference:[statusState uniqueStatusID]
									   forKey:KEY_STATUS_SS_STATUS_STATE_ID
										group:PREF_GROUP_STATUS_PREFERENCES];

	showingSubmenuItemInScreenSaver = [self addItemIfNeeded:sender
											  toPopUpButton:popUp_screenSaverStatusState
									   alreadyShowingAnItem:showingSubmenuItemInScreenSaver];
}

/*!
 * @brief Control text did end editing
 *
 * In an attempt to get closer to a live-apply of preferences, save the preference when the
 * text field loses focus.  See saveTimeValues for more information.
 */
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
	[self saveTimeValues];
}

/*!
 * @brief Save time text field values
 *
 * We can't get notified when the associated NSStepper is clicked, so we just save as requested.
 * This method should be called before the view closes.
 */
- (void)saveTimeValues
{
	[adium.preferenceController setPreference:[NSNumber numberWithDouble:([textField_idleMinutes doubleValue] * 60.0)]
									   forKey:KEY_STATUS_REPORT_IDLE_INTERVAL
										group:PREF_GROUP_STATUS_PREFERENCES];

	[adium.preferenceController
		setPreference:[NSNumber numberWithDouble:([textField_autoAwayMinutes doubleValue] * 60.0)]
			   forKey:KEY_STATUS_AUTO_AWAY_INTERVAL
				group:PREF_GROUP_STATUS_PREFERENCES];
}

@end
