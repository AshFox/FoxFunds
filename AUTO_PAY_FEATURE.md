# Auto-Pay Feature Documentation

## Overview

The Auto-Pay feature in FoxFunds allows users to set up recurring transactions that are automatically processed on their due dates. This feature is perfect for managing regular bills, subscriptions, income, and other periodic financial transactions.

## Features

### 1. Recurring Transaction Management
- **Create recurring transactions** with monthly or yearly frequencies
- **Edit existing recurring transactions** to modify amount, frequency, or description
- **Pause/activate** recurring transactions without deleting them
- **Delete recurring transactions** when no longer needed
- **View all recurring transactions** in a dedicated management screen

### 2. Automatic Processing
- **Background processing** checks for due transactions every hour
- **Automatic transaction creation** when recurring transactions are due
- **Notification system** alerts users when transactions are processed
- **Manual processing** option for immediate execution

### 3. Smart Notifications
- **Due date reminders** sent 1 day before transactions are due
- **Processing confirmations** when auto-pay transactions are created
- **Overdue alerts** for missed payments
- **Customizable notification channels** for different types of alerts

### 4. Dashboard Integration
- **Upcoming auto-pay widget** shows transactions due in the next 7 days
- **Visual indicators** for overdue, due today, and upcoming transactions
- **Quick access** to recurring transaction management
- **Real-time status updates**

## How to Use

### Creating a Recurring Transaction

1. **From the main dashboard:**
   - Tap the "+" button to add a new transaction
   - Fill in the transaction details (amount, category, description)
       - Check the "Make this a recurring transaction" checkbox
    - Select the frequency (Monthly or Yearly)
   - Tap "Add Transaction"

2. **From the recurring transactions screen:**
   - Tap the "+" button in the recurring transactions screen
   - Fill in all required fields
   - Tap "Save"

### Managing Recurring Transactions

1. **Access the management screen:**
   - Tap the repeat icon (🔄) next to "Transaction History" on the dashboard
   - Or use the test button (🐛) in the app bar for testing

2. **Available actions:**
   - **Play/Pause button:** Activate or deactivate a recurring transaction
   - **Edit button:** Modify transaction details
   - **Delete button:** Remove the recurring transaction permanently

### Monitoring Auto-Pay Activity

1. **Dashboard widget:** View upcoming transactions in the "Upcoming Auto-Pay" card
2. **Notifications:** Receive alerts for due dates and processed transactions
3. **Transaction history:** See automatically created transactions in the main transaction list

## Technical Implementation

### Core Components

1. **AutoPayService** (`lib/services/auto_pay_service.dart`)
   - Manages background processing
   - Handles notifications
   - Provides manual processing methods

2. **RecurringTransaction Model** (`lib/models/recurring_transaction.dart`)
   - Defines recurring transaction structure
   - Calculates due dates
   - Determines if transactions are due

3. **DatabaseService** (`lib/services/database_service.dart`)
   - CRUD operations for recurring transactions
   - Automatic processing logic
   - Transaction creation from recurring templates

4. **UI Components**
   - `RecurringTransactionsScreen`: Management interface
   - `UpcomingAutoPayWidget`: Dashboard widget
   - `AddTransactionScreen`: Creation interface
   - `TestAutoPayScreen`: Testing interface

### Database Schema

```sql
CREATE TABLE recurring_transactions (
  id TEXT PRIMARY KEY,
  amount REAL NOT NULL,
  categoryId TEXT NOT NULL,
  description TEXT NOT NULL,
  frequency TEXT NOT NULL,
  startDate TEXT NOT NULL,
  endDate TEXT,
  isActive INTEGER NOT NULL,
  lastProcessedDate TEXT
)
```

### Background Processing

The auto-pay service runs a timer that checks for due transactions every hour:

```dart
Timer.periodic(const Duration(hours: 1), (timer) {
  processDueTransactions();
});
```

### Notification System

- **Channels:** Separate channels for auto-pay confirmations and reminders
- **Scheduling:** Notifications scheduled 1 day before due dates
- **Content:** Includes transaction amount, description, and due status

## Testing

### Test Screen

Access the test screen via the bug icon (🐛) in the app bar to:

1. **Create test transactions** with various due dates
2. **Manually process** due transactions
3. **Schedule notifications** for testing
4. **View logs** of all operations
5. **Monitor recurring transaction status**

### Test Scenarios

1. **Create a monthly recurring transaction**
   - Set start date to 30 days ago
   - Verify it shows as "DUE" in the test screen
   - Process it manually and verify transaction creation

2. **Test notification scheduling**
   - Create a transaction due tomorrow
   - Schedule notifications
   - Verify notification appears (may require device testing)

3. **Test frequency calculations**
   - Create monthly and yearly transactions
   - Verify next due dates are calculated correctly

## Configuration

### Notification Permissions

The app requires notification permissions for:
- Auto-pay confirmations
- Due date reminders
- Overdue alerts

### Background Processing

The auto-pay service initializes when the app starts and continues running in the background.

### Timezone Handling

The system uses the device's local timezone for all date calculations and notifications.

## Troubleshooting

### Common Issues

1. **Transactions not processing automatically:**
   - Check if the recurring transaction is active
   - Verify the due date calculation
   - Ensure the app has been opened recently (for background processing)

2. **Notifications not appearing:**
   - Check notification permissions
   - Verify notification channels are created
   - Test with the manual scheduling function

3. **Incorrect due dates:**
   - Check the start date of the recurring transaction
   - Verify the frequency setting
   - Use the test screen to debug date calculations

### Debug Tools

1. **Test Screen:** Use the bug icon to access comprehensive testing tools
2. **Logs:** View operation logs in the test screen
3. **Manual Processing:** Force process due transactions manually
4. **Database Inspection:** Use the test screen to view all recurring transactions

## Future Enhancements

### Planned Features

1. **Advanced Scheduling:**
   - Custom due dates (e.g., "15th of every month")
   - End dates for recurring transactions
   - Skip specific occurrences

2. **Enhanced Notifications:**
   - Multiple reminder intervals
   - Custom notification messages
   - Email notifications

3. **Analytics:**
   - Auto-pay spending reports
   - Success rate tracking
   - Cost savings analysis

4. **Integration:**
   - Calendar integration
   - Export to other financial apps
   - Bank account linking

### Performance Optimizations

1. **Efficient Processing:**
   - Batch processing for multiple transactions
   - Optimized database queries
   - Reduced background processing frequency

2. **Battery Optimization:**
   - Smart scheduling based on usage patterns
   - Reduced notification frequency
   - Background processing limits

## Support

For issues or questions about the auto-pay feature:

1. Use the test screen to debug problems
2. Check the logs for error messages
3. Verify database integrity
4. Test with manual processing first

The auto-pay feature is designed to be reliable and user-friendly, providing automated financial management while maintaining full user control over all transactions. 