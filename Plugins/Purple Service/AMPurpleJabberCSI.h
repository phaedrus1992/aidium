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

#import <Foundation/Foundation.h>

@class ESPurpleJabberAccount;

NS_ASSUME_NONNULL_BEGIN

/// XEP-0352 Client State Indication (CSI)
///
/// Sends <active/> / <inactive/> state notifications to the server on app
/// foreground/background transitions.
@interface AMPurpleJabberCSI : NSObject {
	ESPurpleJabberAccount *_account;
	NSInteger _currentState;
}

/// Initialize with the owning Jabber account.
///
/// @param account The ESPurpleJabberAccount that owns this controller
/// @return An initialized instance
- (id)initWithAccount:(ESPurpleJabberAccount *)account;

/// Refresh the CSI state based on the current application foreground/background status.
/// Sends <active/> or <inactive/> as appropriate.
- (void)refreshState;

@end

NS_ASSUME_NONNULL_END
