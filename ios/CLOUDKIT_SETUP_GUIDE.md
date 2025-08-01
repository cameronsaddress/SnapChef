# CloudKit Setup Guide for SnapChef Challenge System

## Overview
This guide provides step-by-step instructions for setting up CloudKit in the Apple Developer Console to support the SnapChef challenge system.

## Prerequisites
- Apple Developer Account
- Access to CloudKit Dashboard: https://icloud.developer.apple.com
- SnapChef app bundle ID: `com.snapchef.app`

## Step 1: Access CloudKit Dashboard

1. Go to https://icloud.developer.apple.com
2. Sign in with your Apple Developer account
3. Select "CloudKit Database"
4. Choose the SnapChef container: `iCloud.com.snapchefapp.app`

## Step 2: Create Record Types

Navigate to "Schema" → "Record Types" and create the following:

### Challenge Record Type
Click "+" to add new record type named `Challenge`:

| Field Name | Type | Indexed | Queryable | Sortable |
|------------|------|---------|-----------|----------|
| id | String | ✓ | ✓ | ✓ |
| title | String | | ✓ | |
| description | String | | | |
| type | String | ✓ | ✓ | |
| category | String | ✓ | ✓ | |
| difficulty | Int(64) | ✓ | ✓ | |
| points | Int(64) | | | |
| coins | Int(64) | | | |
| requirements | String | | | |
| startDate | Date/Time | ✓ | ✓ | ✓ |
| endDate | Date/Time | ✓ | ✓ | ✓ |
| isActive | Int(64) | ✓ | ✓ | |
| isPremium | Int(64) | ✓ | ✓ | |
| participantCount | Int(64) | | | |
| completionCount | Int(64) | | | |
| imageURL | String | | | |
| badgeID | String | | | |
| teamBased | Int(64) | | | |
| minTeamSize | Int(64) | | | |
| maxTeamSize | Int(64) | | | |

### UserChallenge Record Type
Create record type `UserChallenge`:

| Field Name | Type | Indexed | Queryable | Sortable |
|------------|------|---------|-----------|----------|
| userID | String | ✓ | ✓ | |
| challengeID | Reference(Challenge) | ✓ | ✓ | |
| status | String | ✓ | ✓ | |
| progress | Double | | | |
| startedAt | Date/Time | ✓ | | ✓ |
| completedAt | Date/Time | ✓ | | ✓ |
| earnedPoints | Int(64) | | | |
| earnedCoins | Int(64) | | | |
| proofImageURL | String | | | |
| notes | String | | | |
| teamID | String | ✓ | ✓ | |

### Team Record Type
Create record type `Team`:

| Field Name | Type | Indexed | Queryable | Sortable |
|------------|------|---------|-----------|----------|
| id | String | ✓ | ✓ | |
| name | String | | ✓ | |
| description | String | | | |
| captainID | String | ✓ | | |
| memberIDs | String(List) | | | |
| challengeID | Reference(Challenge) | ✓ | ✓ | |
| totalPoints | Int(64) | | | ✓ |
| createdAt | Date/Time | ✓ | | ✓ |
| inviteCode | String | ✓ | ✓ | |
| isPublic | Int(64) | | | |
| maxMembers | Int(64) | | | |

### Leaderboard Record Type
Create record type `Leaderboard`:

| Field Name | Type | Indexed | Queryable | Sortable |
|------------|------|---------|-----------|----------|
| userID | String | ✓ | ✓ | |
| userName | String | | | |
| avatarURL | String | | | |
| totalPoints | Int(64) | ✓ | | ✓ |
| weeklyPoints | Int(64) | ✓ | | ✓ |
| monthlyPoints | Int(64) | ✓ | | ✓ |
| challengesCompleted | Int(64) | | | |
| currentStreak | Int(64) | | | |
| longestStreak | Int(64) | | | |
| lastUpdated | Date/Time | ✓ | | ✓ |
| region | String | ✓ | ✓ | |

### Additional Record Types
Also create:
- `TeamMessage`
- `Achievement`
- `CoinTransaction`

(Follow similar pattern with fields from CloudKitSchema.swift)

## Step 3: Create Indexes

Navigate to "Schema" → "Indexes" and create:

1. **Active Challenges Index**
   - Record Type: Challenge
   - Fields: startDate (QUERYABLE), isActive (QUERYABLE)

2. **User Challenges Index**
   - Record Type: UserChallenge
   - Fields: userID (QUERYABLE), status (QUERYABLE)

3. **Global Leaderboard Index**
   - Record Type: Leaderboard
   - Field: totalPoints (SORTABLE)

4. **Team Rankings Index**
   - Record Type: Team
   - Fields: challengeID (QUERYABLE), totalPoints (SORTABLE)

## Step 4: Create Subscriptions

Navigate to "Schema" → "Subscriptions" and create:

1. **Challenge Updates**
   - Name: `challenge-updates`
   - Record Type: Challenge
   - Fires on: Create, Update
   - Notification Type: Silent

2. **Team Messages**
   - Name: `team-messages`
   - Record Type: TeamMessage
   - Fires on: Create
   - Notification Type: Alert

3. **Leaderboard Updates**
   - Name: `leaderboard-updates`
   - Record Type: Leaderboard
   - Fires on: Update
   - Notification Type: Silent

## Step 5: Configure Security

Navigate to "Schema" → "Security Roles":

1. **Challenge Record**
   - World: Read only
   - Authenticated: Read only
   - Creator: Read/Write

2. **UserChallenge Record**
   - World: No Access
   - Authenticated: Create
   - Creator: Read/Write

3. **Team Record**
   - World: Read only
   - Authenticated: Create/Read
   - Creator: Read/Write

4. **Leaderboard Record**
   - World: Read only
   - Authenticated: Read only
   - Creator: Read/Write

## Step 6: Deploy to Production

1. Test thoroughly in Development environment
2. Navigate to "Deploy to Production"
3. Select all schema changes
4. Click "Deploy"
5. Monitor deployment status

## Step 7: Test CloudKit Integration

1. Run the app on two different devices
2. Create a challenge on Device A
3. Verify it syncs to Device B
4. Update progress on Device B
5. Verify sync back to Device A

## Troubleshooting

### Common Issues:

1. **"No iCloud account" error**
   - Ensure device is signed into iCloud
   - Check Settings → iCloud → iCloud Drive is ON

2. **Records not syncing**
   - Check CloudKit Dashboard for errors
   - Verify subscription setup
   - Check network connectivity

3. **Permission errors**
   - Review security roles configuration
   - Ensure proper authentication

## Monitoring

Use CloudKit Dashboard to monitor:
- Request rates
- Error logs
- Storage usage
- Active subscriptions

## Next Steps

1. Implement push notification handling for subscriptions
2. Add conflict resolution for concurrent edits
3. Implement offline support with sync queue
4. Add analytics tracking for challenge engagement